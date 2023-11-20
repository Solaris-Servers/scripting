#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>
#include <left4dhooks>

#define GAMEDATA_FILE "l4d2_charge_target_fix"
#define FUNCTION_NAME "CCharge::HandleCustomCollision"

#define KEY_ANIMSTATE    "CTerrorPlayer::m_PlayerAnimState"
#define KEY_FLAG_CHARGED "CTerrorPlayerAnimState::m_bCharged"

#define FSOLID_NOT_SOLID 0x0004 // Are we currently not solid?
#define KNOCKDOWN_DURATION_CHARGER 2.5

int  g_iChargeVictim  [MAXPLAYERS + 1] = {-1, ...};
int  g_iChargeAttacker[MAXPLAYERS + 1] = {-1, ...};
bool g_bNotSolid      [MAXPLAYERS + 1];

ConVar g_cvChargerCollision;
int    g_iChargerCollision;

ConVar g_cvKnockdownWindow;
float  g_fKnockdownWindow;

int g_iPlayerAnimStateOffs;
int g_iChargedOffs;

enum {
    CHARGER_COLLISION_PUMMEL = 1,
    CHARGER_COLLISION_GETUP  = (1 << 1)
};

// mid-way start from m_bCharged
enum AnimStateFlag {
    AnimState_WallSlammed   = 2,
    AnimState_GroundSlammed = 3,
}

methodmap AnimState {
    public AnimState(int iClient) {
        int iPtr = GetEntData(iClient, g_iPlayerAnimStateOffs, 4);
        if (iPtr == 0) ThrowError("Invalid pointer to \"CTerrorPlayer::CTerrorPlayerAnimState\" (client %d).", iClient);
        return view_as<AnimState>(iPtr);
    }
    public bool GetFlag(AnimStateFlag flag) {
        return view_as<bool>(LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iChargedOffs) + view_as<Address>(flag), NumberType_Int8));
    }
}

public Plugin myinfo = {
    name        = "[L4D2] Charger Target Fix",
    author      = "Forgetest",
    description = "Fix multiple issues with charger targets.",
    version     = "1.8",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

public void OnPluginStart() {
    InitGameData();

    g_cvChargerCollision = CreateConVar(
    "z_charge_pinned_collision", "3",
    "Enable collision to Infected Team on Survivors pinned by charger. 1 = Enable collision during pummel, 2 = Enable collision during get-up, 3 = Both, 0 = No collision at all.",
    FCVAR_SPONLY, true, 0.0, true, 3.0);
    g_iChargerCollision = g_cvChargerCollision.IntValue;
    g_cvChargerCollision.AddChangeHook(CvarChg_ChargerCollision);

    g_cvKnockdownWindow = CreateConVar(
    "charger_knockdown_getup_window", "0.1",
    "Duration between knockdown timer ends and get-up finishes. The higher value is set, the earlier Survivors become collideable when getting up from charger.",
    FCVAR_SPONLY, true, 0.0, true, 4.0);
    g_fKnockdownWindow = g_cvKnockdownWindow.FloatValue;
    g_cvKnockdownWindow.AddChangeHook(CvarChg_KnockdownWindow);

    HookEvent("round_start",          Event_RoundStart);
    HookEvent("player_incapacitated", Event_PlayerIncap);
    HookEvent("player_death",         Event_PlayerDeath);
    HookEvent("charger_pummel_end",   Event_ChargerPummelEnd);
    HookEvent("charger_killed",       Event_ChargerKilled);
    HookEvent("player_bot_replace",   Event_PlayerBotReplace);
    HookEvent("bot_player_replace",   Event_BotPlayerReplace);
}

void InitGameData() {
    GameData gmConf = new GameData(GAMEDATA_FILE);
    if (!gmConf) SetFailState("Missing gamedata \""...GAMEDATA_FILE..."\"");
    g_iPlayerAnimStateOffs = gmConf.GetOffset(KEY_ANIMSTATE);
    if (g_iPlayerAnimStateOffs == -1) SetFailState("Missing offset \""...KEY_ANIMSTATE..."\"");
    g_iChargedOffs = gmConf.GetOffset(KEY_FLAG_CHARGED);
    if (g_iChargedOffs == -1) SetFailState("Missing offset \""...KEY_FLAG_CHARGED..."\"");
    DynamicDetour dDetour = DynamicDetour.FromConf(gmConf, FUNCTION_NAME);
    if (!dDetour) SetFailState("Missing detour setup \""...FUNCTION_NAME..."\"");
    if (!dDetour.Enable(Hook_Pre, DTR_CCharge__HandleCustomCollision))
        SetFailState("Failed to detour \""...FUNCTION_NAME..."\"");
    delete dDetour;
    delete gmConf;
}

// Fix charger grabbing victims of other chargers
MRESReturn DTR_CCharge__HandleCustomCollision(int iAbility, DHookReturn dReturn, DHookParam hParams) {
    if (!GetEntProp(iAbility, Prop_Send, "m_hasBeenUsed"))
        return MRES_Ignored;

    int iCharger = GetEntPropEnt(iAbility, Prop_Send, "m_owner");
    if (iCharger == -1) return MRES_Ignored;

    int iTouch = hParams.Get(1);
    if (iTouch <= 0)
        return MRES_Ignored;

    if (iTouch > MaxClients)
        return MRES_Ignored;

    if (g_iChargeAttacker[iTouch] == -1) // free for attacks
        return MRES_Ignored;

    if (g_iChargeAttacker[iTouch] == iCharger) // about to slam my victim
        return MRES_Ignored;

    // basically invalid calls at here, block
    dReturn.Value = 0;
    return MRES_Supercede;
}

void CvarChg_ChargerCollision(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iChargerCollision = cv.IntValue;
}

void CvarChg_KnockdownWindow(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fKnockdownWindow = cv.FloatValue;
}

// Fix anomaly pummel that usually happens when a Charger is carrying someone and round restarts
void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    for (int i = 1; i <= MaxClients; i++) {
        // clear our stuff
        g_bNotSolid      [i] = false;
        g_iChargeVictim  [i] = -1;
        g_iChargeAttacker[i] = -1;

        if (!IsClientInGame(i))
            continue;

        // ~ CDirector::RestartScenario()
        // ~ CDirector::Restart()
        // ~ ForEachTerrorPlayer<RestartCleanup>()
        // ~ CTerrorPlayer::CleanupPlayerState()
        // ~ CTerrorPlayer::OnCarryEnded( (bClearBoth = true), (bSkipPummel = false), (bIsAttacker = true) )
        // ~ CTerrorPlayer::QueuePummelVictim( m_carryVictim.Get(), -1.0 )
        // CTerrorPlayer::UpdatePound()
        SetEntPropEnt(i, Prop_Send, "m_pummelVictim", -1);
        SetEntPropEnt(i, Prop_Send, "m_pummelAttacker", -1);

        // perhaps unnecessary
        L4D2_SetQueuedPummelStartTime(i, -1.0);
        L4D2_SetQueuedPummelVictim(i, -1);
        L4D2_SetQueuedPummelAttacker(i, -1);
    }
}

// Remove collision on Survivor going incapped because `CTerrorPlayer::IsGettingUp` returns false in this case
// Thanks to @Alan on discord for reporting.
void Event_PlayerIncap(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (g_iChargerCollision & CHARGER_COLLISION_PUMMEL)
        return;

    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)
        return;

    if (!IsClientInGame(iClient))
        return;

    if (GetClientTeam(iClient) != 2)
        return;

    int iQueuedPummelAttacker = L4D2_GetQueuedPummelAttacker(iClient);
    if (iQueuedPummelAttacker == -1 || !L4D2_IsInQueuedPummel(iQueuedPummelAttacker)) {
        if (GetEntPropEnt(iClient, Prop_Send, "m_pummelAttacker") == -1)
            return;
    }

    SetPlayerSolid(iClient, false);
    g_bNotSolid[iClient] = true;
}

// Clear arrays if the victim dies to slams
void Event_PlayerDeath(Event eEvent, const char[] name, bool dontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)
        return;

    if (!IsClientInGame(iClient))
        return;

    int iAttacker = g_iChargeAttacker[iClient];
    if (iAttacker == -1) return;

    if (L4D2_IsInQueuedPummel(iAttacker) && L4D2_GetQueuedPummelVictim(iAttacker) == iClient) {
        int iAbility = GetEntPropEnt(iAttacker, Prop_Send, "m_customAbility");
        SetEntPropFloat(iAbility, Prop_Send, "m_nextActivationTimer", 0.2, 0);
        SetEntPropFloat(iAbility, Prop_Send, "m_nextActivationTimer", L4D2_GetQueuedPummelStartTime(iAttacker) + 0.2, 1);
    }

    if (g_bNotSolid[iClient]) {
        SetPlayerSolid(iClient, true);
        g_bNotSolid[iClient] = false;
    }

    g_iChargeVictim[iAttacker] = -1;
    g_iChargeAttacker[iClient] = -1;
}

// Calls if charger has started pummelling.
void Event_ChargerPummelEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)
        return;

    if (!IsClientInGame(iClient))
        return;

    int iVictim = GetClientOfUserId(eEvent.GetInt("victim"));
    if (iVictim <= 0)
        return;

    if (!IsClientInGame(iVictim))
        return;

    if (~g_iChargerCollision & CHARGER_COLLISION_GETUP) {
        KnockdownPlayer(iVictim, KNOCKDOWN_CHARGER);
        ExtendKnockdown(iVictim, false);
    }

    if (g_bNotSolid[iVictim]) {
        SetPlayerSolid(iVictim, true);
        g_bNotSolid[iVictim] = false;
    }

    // Normal processes don't need special care
    g_iChargeVictim  [iClient] = -1;
    g_iChargeAttacker[iVictim] = -1;
}

// Calls if charger has slammed and before pummel, or simply is cleared before slam.
void Event_ChargerKilled(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)
        return;

    if (!IsClientInGame(iClient))
        return;

    int iVictim = g_iChargeVictim[iClient];
    if (iVictim == -1) return;

    if (~g_iChargerCollision & CHARGER_COLLISION_GETUP) {
        KnockdownPlayer(iVictim, KNOCKDOWN_CHARGER);
        RequestFrame(OnNextFrame_LongChargeKnockdown, GetClientUserId(iVictim)); // a small delay to be compatible with `l4d2_getup_fixes`
    }

    if (g_bNotSolid[iVictim]) {
        SetPlayerSolid(iVictim, true);
        g_bNotSolid[iVictim] = false;
    }

    g_iChargeVictim  [iClient] = -1;
    g_iChargeAttacker[iVictim] = -1;
}

void OnNextFrame_LongChargeKnockdown(int iUserId) {
    int iClient = GetClientOfUserId(iUserId);
    if (iClient <= 0)
        return;

    if (!IsClientInGame(iClient))
        return;

    ExtendKnockdown(iClient, true);
}

void Event_PlayerBotReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    HandlePlayerReplace(GetClientOfUserId(eEvent.GetInt("bot")), GetClientOfUserId(eEvent.GetInt("player")));
}

void Event_BotPlayerReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    HandlePlayerReplace(GetClientOfUserId(eEvent.GetInt("player")), GetClientOfUserId(eEvent.GetInt("bot")));
}

void HandlePlayerReplace(int iReplacer, int iReplacee) {
    if (iReplacer <= 0)
        return;

    if (!IsClientInGame(iReplacer))
        return;

    if (iReplacee <= 0)
        iReplacee = -1;

    if (GetClientTeam(iReplacer) == 3) {
        if (g_iChargeVictim[iReplacee] != -1) {
            g_iChargeVictim[iReplacer] = g_iChargeVictim[iReplacee];
            g_iChargeAttacker[g_iChargeVictim[iReplacee]] = iReplacer;
            g_iChargeVictim[iReplacee] = -1;
        }
    } else {
        if (g_iChargeAttacker[iReplacee] != -1) {
            g_iChargeAttacker[iReplacer] = g_iChargeAttacker[iReplacee];
            g_iChargeVictim[g_iChargeAttacker[iReplacee]] = iReplacer;
            g_iChargeAttacker[iReplacee] = -1;
        }
        if (g_bNotSolid[iReplacee]) {
            g_bNotSolid[iReplacer] = true;
            g_bNotSolid[iReplacee] = false;
        }
    }
}

public Action L4D_OnPouncedOnSurvivor(int iVictim, int iAttacker) {
    if (g_iChargeAttacker[iVictim] == -1)
        return Plugin_Continue;
    return Plugin_Handled;
}

public Action L4D2_OnJockeyRide(int iVictim, int iAttacker) {
    if (g_iChargeAttacker[iVictim] == -1)
        return Plugin_Continue;
    return Plugin_Handled;
}

public Action L4D_OnGrabWithTongue(int iVictim, int iAttacker) {
    if (g_iChargeAttacker[iVictim] == -1)
        return Plugin_Continue;
    return Plugin_Handled;
}

public void L4D2_OnStartCarryingVictim_Post(int iVictim, int iAttacker) {
    if (iVictim <= 0)
        return;

    if (!IsClientInGame(iVictim))
        return;

    if (!IsPlayerAlive(iVictim))
        return;

    g_iChargeVictim[iAttacker] = iVictim;
    g_iChargeAttacker[iVictim] = iAttacker;
}

public void L4D2_OnSlammedSurvivor_Post(int iVictim, int iAttacker, bool bWallSlam, bool bDeadlyCharge) {
    if (iVictim <= 0)
        return;

    if (!IsClientInGame(iVictim))
        return;

    if (!IsPlayerAlive(iVictim))
        return;

    g_iChargeVictim[iAttacker] = iVictim;
    g_iChargeAttacker[iVictim] = iAttacker;
    if (~g_iChargerCollision & CHARGER_COLLISION_PUMMEL) {
        Handle hTimer = CreateTimer(1.0, Timer_KnockdownRepeat, GetClientUserId(iVictim), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
        TriggerTimer(hTimer);
    }

    // compatibility with competitive 1v1
    if (!IsPlayerAlive(iAttacker))  {
        Event eEvent = CreateEvent("charger_killed");
        eEvent.SetInt("userid", GetClientUserId(iAttacker));
        Event_ChargerKilled(eEvent, "charger_killed", false);
        eEvent.Cancel();
    }

    int iJockey = GetEntPropEnt(iVictim, Prop_Send, "m_jockeyAttacker");
    if (iJockey != -1) Dismount(iJockey);

    int iSmoker = GetEntPropEnt(iVictim, Prop_Send, "m_tongueOwner");
    if (iSmoker != -1) L4D_Smoker_ReleaseVictim(iVictim, iSmoker);
}

Action Timer_KnockdownRepeat(Handle hTimer, int iUserId) {
    int iClient = GetClientOfUserId(iUserId);
    if (iClient <= 0)
        return Plugin_Stop;

    if (!IsClientInGame(iClient))
        return Plugin_Stop;

    if (GetClientTeam(iClient) != 2)
        return Plugin_Stop;

    if (!IsPlayerAlive(iClient))
        return Plugin_Stop;

    if (L4D_IsPlayerIncapacitated(iClient))
        return Plugin_Stop;

    int iQueuedPummelAttacker = L4D2_GetQueuedPummelAttacker(iClient);
    if (iQueuedPummelAttacker == -1 || !L4D2_IsInQueuedPummel(iQueuedPummelAttacker)) {
        if (GetEntPropEnt(iClient, Prop_Send, "m_pummelAttacker") == -1)
            return Plugin_Stop;
    }

    KnockdownPlayer(iClient, KNOCKDOWN_CHARGER);
    return Plugin_Continue;
}

void KnockdownPlayer(int iClient, int iReason) {
    SetEntProp(iClient, Prop_Send, "m_knockdownReason", iReason);
    SetEntPropFloat(iClient, Prop_Send, "m_knockdownTimer", GetGameTime(), 0);
}

void ExtendKnockdown(int iClient, bool bIsLongCharge) {
    float fExtendTime = 0.0;
    if (!bIsLongCharge) {
        float fAnimTime = 85 / 30.0;
        fExtendTime = fAnimTime - KNOCKDOWN_DURATION_CHARGER - g_fKnockdownWindow;
    } else {
        AnimState pAnim = AnimState(iClient);
        float fAnimTime = 0.0;
        if (((fAnimTime = 116 / 30.0), !pAnim.GetFlag(AnimState_WallSlammed)) && ((fAnimTime = 119 / 30.0), !pAnim.GetFlag(AnimState_GroundSlammed))) {
            ExtendKnockdown(iClient, false);
            return;
        }

        float fElaspedAnimTime = fAnimTime * GetEntPropFloat(iClient, Prop_Send, "m_flCycle");
        fExtendTime = fAnimTime - fElaspedAnimTime - KNOCKDOWN_DURATION_CHARGER - g_fKnockdownWindow;
    }

    if (fExtendTime >= 0.1)
        CreateTimer(fExtendTime, Timer_ExtendKnockdown, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_ExtendKnockdown(Handle hTimer, int iUserId) {
    int iClient = GetClientOfUserId(iUserId);
    if (iClient <= 0)
        return Plugin_Stop;

    if (!IsClientInGame(iClient))
        return Plugin_Stop;

    KnockdownPlayer(iClient, KNOCKDOWN_CHARGER);
    return Plugin_Stop;
}

void SetPlayerSolid(int iClient, bool bSolid) {
    int iFlags = GetEntProp(iClient, Prop_Data, "m_usSolidFlags");
    SetEntProp(iClient, Prop_Data, "m_usSolidFlags", bSolid ? (iFlags & ~FSOLID_NOT_SOLID) : (iFlags | FSOLID_NOT_SOLID));
}

void Dismount(int iClient) {
    int iFlags = GetCommandFlags("dismount");
    SetCommandFlags("dismount", iFlags & ~FCVAR_CHEAT);
    FakeClientCommand(iClient, "dismount");
    SetCommandFlags("dismount", iFlags);
}