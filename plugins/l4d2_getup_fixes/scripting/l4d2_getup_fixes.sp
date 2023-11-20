/**
 * Documentation
 *
 * =========================================================================================================
 *
 * Methods of `CTerrorPlayerAnimState` (peeks into `CTerrorPlayer`):
 *    [1]. `ResetMainActivity()`: Invoke recalculation of animation to be played.
 *
 * Flags of `CTerrorPlayerAnimState`:
 *    See `AnimStateFlag` for an incomplete list.
 *
 * =========================================================================================================
 *
 * Fixes for cappers respectively:
 *
 *    Smoker:
 *      1) [DISABLED] Charged get-ups keep playing during pull.         (Event_TongueGrab)
 *      2) [DISABLED] Punch/Rock get-up keeps playing during pull.      (Event_TongueGrab)
 *      3) Hunter get-up replayed when pull released.                   (Event_TongueGrab)
 *
 *    Jockey:
 *      1) No get-up if forced off by any other capper.                 (Event_JockeyRideEnd)
 *      2) Bowling/Wallslam get-up keeps playing during ride.           (Event_JockeyRide)
 *
 *    Hunter:
 *      1) Double get-up when pounce on charger victims.                (Event_ChargerPummelStart Event_ChargerKilled)
 *      2) Bowling/Pummel/Slammed get-up keeps playing when pounced.    (Event_LungePounce)
 *      3) Punch/Rock get-up keeps playing when pounced.                (Event_LungePounce)
 *
 *    Charger:
 *      1) Prevent get-up for self-clears.                              (Event_ChargerKilled)
 *      2) Fix no godframe for long get-up.                             (Event_ChargerKilled)
 *      3) Punch/Charger get-up keeps playing during carry.             (Event_ChargerCarryStart)
 *      4) Fix possible slammed get-up not playing on instant slam.     (L4D2_OnSlammedSurvivor_Post)
 *
 *    Tank:
 *      1) Double get-up if punch/rock on chargers with victims to die. (OnPlayerHit_Post OnKnockedDown_Post)
 *         Do not play punch/rock get-up to keep consistency.
 *      2) No get-up if do rock-punch combo.                            (OnPlayerHit_Post OnKnockedDown_Post)
 *      3) Double get-up if punch/rock on survivors in bowling.         (OnPlayerHit_Post OnKnockedDown_Post)
 */


#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2util>
#include <left4dhooks>

#undef REQUIRE_PLUGIN
#include <godframecontrol>
#define REQUIRE_PLUGIN

#define PLUGIN_VERSION "4.19"

#define GAMEDATA_FILE         "l4d2_getup_fixes"
#define KEY_ANIMSTATE         "CTerrorPlayer::m_PlayerAnimState"
#define KEY_FLAG_CHARGED      "CTerrorPlayerAnimState::m_bCharged"
#define KEY_RESETMAINACTIVITY "CTerrorPlayerAnimState::ResetMainActivity"

Handle g_hResetMainActivity;

int m_PlayerAnimState;
int m_bCharged;

// start from m_bCharged
enum AnimStateFlag  {
    AnimState_Charged         = 0,
    AnimState_Pummeled        = 1, // aka multi-charged
    AnimState_WallSlammed     = 2,
    AnimState_GroundSlammed   = 3,
    AnimState_Pounded         = 5, // Pummel get-up
    AnimState_TankPunched     = 7, // Rock get-up shares this
    AnimState_Pounced         = 9,
    AnimState_RiddenByJockey  = 14
};

methodmap AnimState {
    public AnimState(int iClient) {
        int iPtr = GetEntData(iClient, m_PlayerAnimState, 4);
        if (iPtr == 0) ThrowError("Invalid pointer to \"CTerrorPlayer::CTerrorPlayerAnimState\" (client %d).", iClient);
        return view_as<AnimState>(iPtr);
    }
    public void ResetMainActivity() {
        SDKCall(g_hResetMainActivity, this);
    }
    public bool GetFlag(AnimStateFlag eFlag) {
        return view_as<bool>(LoadFromAddress(view_as<Address>(this) + view_as<Address>(m_bCharged) + view_as<Address>(eFlag), NumberType_Int8));
    }
    public void SetFlag(AnimStateFlag eFlag, bool bVal) {
        StoreToAddress(view_as<Address>(this) + view_as<Address>(m_bCharged) + view_as<Address>(eFlag), view_as<int>(bVal), NumberType_Int8);
    }
};

bool g_bLateLoad;
bool g_bGodframeControl;

int g_iChargeVictim  [MAXPLAYERS + 1] = {-1, ...};
int g_iChargeAttacker[MAXPLAYERS + 1] = {-1, ...};

float g_fLastChargedEndTime[MAXPLAYERS + 1];

ConVar g_cvChargeDuration;
ConVar g_cvLongChargeDuration;
ConVar g_cvKeepWallSlamLongGetUp;
ConVar g_cvKeepLongChargeLongGetUp;

public Plugin myinfo = {
    name        = "[L4D2] Merged Get-Up Fixes",
    author      = "Forgetest",
    description = "Fixes all double/missing get-up cases.",
    version     = PLUGIN_VERSION,
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    g_bLateLoad = late;
    return APLRes_Success;
}

void LoadSDK() {
    GameData gdConf = new GameData(GAMEDATA_FILE);
    if (!gdConf) SetFailState("Missing gamedata \""...GAMEDATA_FILE..."\"");
    m_PlayerAnimState = gdConf.GetOffset(KEY_ANIMSTATE);
    if (m_PlayerAnimState == -1) SetFailState("Missing offset \""...KEY_ANIMSTATE..."\"");
    m_bCharged = gdConf.GetOffset(KEY_FLAG_CHARGED);
    if (m_bCharged == -1) SetFailState("Missing offset \""...KEY_FLAG_CHARGED..."\"");
    StartPrepSDKCall(SDKCall_Raw);
    if (!PrepSDKCall_SetFromConf(gdConf, SDKConf_Virtual, KEY_RESETMAINACTIVITY))
        SetFailState("Missing offset \""...KEY_RESETMAINACTIVITY..."\"");
    g_hResetMainActivity = EndPrepSDKCall();
    if (!g_hResetMainActivity)
        SetFailState("Failed to prepare SDKCall \""...KEY_RESETMAINACTIVITY..."\"");
    delete gdConf;
}

public void OnPluginStart() {
    LoadSDK();

    g_cvLongChargeDuration = CreateConVar(
    "gfc_long_charger_duration", "2.2",
    "God frame duration for long charger getup animations",
    FCVAR_NONE, true, 0.0, false, 0.0);

    g_cvKeepWallSlamLongGetUp = CreateConVar(
    "charger_keep_wall_charge_animation", "1",
    "Enable the long wall slam animation (with god frames)",
    FCVAR_NONE, true, 0.0, true, 1.0);

    g_cvKeepLongChargeLongGetUp = CreateConVar(
    "charger_keep_far_charge_animation", "0",
    "Enable the long 'far' slam animation (with god frames)",
    FCVAR_NONE, true, 0.0, true, 1.0);

    HookEvent("round_start",          Event_RoundStart);
    HookEvent("player_bot_replace",   Event_PlayerBotReplace);
    HookEvent("bot_player_replace",   Event_BotPlayerReplace);
    HookEvent("revive_success",       Event_ReviveSuccess);
    HookEvent("tongue_grab",          Event_TongueGrab);
    HookEvent("lunge_pounce",         Event_LungePounce);
    HookEvent("jockey_ride",          Event_JockeyRide);
    HookEvent("jockey_ride_end",      Event_JockeyRideEnd);
    HookEvent("player_death",         Event_PlayerDeath);
    HookEvent("charger_carry_start",  Event_ChargerCarryStart);
    HookEvent("charger_pummel_start", Event_ChargerPummelStart);
    HookEvent("charger_pummel_end",   Event_ChargerPummelEnd);
    HookEvent("charger_killed",       Event_ChargerKilled);

    if (g_bLateLoad) {
        for (int i = 1; i <= MaxClients; i++) {
            if (!IsClientInGame(i)) continue;
            OnClientPutInServer(i);
        }
    }
}

public void OnAllPluginsLoaded() {
    g_bGodframeControl = LibraryExists("l4d2_godframes_control_merge");
}

public void OnLibraryAdded(const char[] name) {
    if (strcmp(name, "l4d2_godframes_control_merge") == 0)
        g_bGodframeControl = true;
}

public void OnLibraryRemoved(const char[] name) {
    if (strcmp(name, "l4d2_godframes_control_merge") == 0)
        g_bGodframeControl = false;
}

public void OnConfigsExecuted() {
    if (!g_bGodframeControl) return;
    g_cvChargeDuration = FindConVar("gfc_charger_duration");
}

public void OnClientPutInServer(int iClient) {
    g_iChargeVictim      [iClient] = -1;
    g_iChargeAttacker    [iClient] = -1;
    g_fLastChargedEndTime[iClient] = 0.0;
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    for (int i = 1; i <= MaxClients; i++) {
        g_iChargeVictim      [i] = -1;
        g_iChargeAttacker    [i] = -1;
        g_fLastChargedEndTime[i] = 0.0;
    }
}

void Event_PlayerBotReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iReplacer = GetClientOfUserId(eEvent.GetInt("bot"));
    int iReplacee = GetClientOfUserId(eEvent.GetInt("player"));
    if (iReplacer && iReplacee) HandlePlayerReplace(iReplacer, iReplacee);
}

void Event_BotPlayerReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iReplacer = GetClientOfUserId(eEvent.GetInt("player"));
    int iReplacee = GetClientOfUserId(eEvent.GetInt("bot"));
    if (iReplacer && iReplacee) HandlePlayerReplace(iReplacer, iReplacee);
}

void HandlePlayerReplace(int iReplacer, int iReplacee) {
    if (GetClientTeam(iReplacer) == L4D2Team_Infected) {
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
    }
}


/**
 * Survivor Incap
 */
void Event_ReviveSuccess(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("subject"));
    if (iClient <= 0) return;
    AnimState pAnim = AnimState(iClient);
    pAnim.SetFlag(AnimState_GroundSlammed, false);
    pAnim.SetFlag(AnimState_WallSlammed,   false);
    pAnim.SetFlag(AnimState_Pounded,       false); // probably no need
    pAnim.SetFlag(AnimState_Pounced,       false); // probably no need
}


/**
 * Smoker
 */
void Event_TongueGrab(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("victim"));
    if (iClient <= 0) return;
    AnimState pAnim = AnimState(iClient);
    // Fix double get-up
    pAnim.SetFlag(AnimState_Pounced, false);
    // Commented to prevent unexpected buff
    // pAnim.SetFlag(AnimState_GroundSlammed, false);
    // pAnim.SetFlag(AnimState_WallSlammed,  false);
    // pAnim.SetFlag(AnimState_TankPunched,  false);
    // pAnim.SetFlag(AnimState_Pounded,      false);
    // pAnim.SetFlag(AnimState_Charged,      false);
}


/**
 * Hunter
 */
void Event_LungePounce(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("victim"));
    if (iClient <= 0) return;
    AnimState pAnim = AnimState(iClient);
    // Fix get-up keeps playing
    pAnim.SetFlag(AnimState_TankPunched, false);
    pAnim.SetFlag(AnimState_Charged,     false);
    pAnim.SetFlag(AnimState_Pounded,     false);
    pAnim.SetFlag(AnimState_WallSlammed, false);
}


/**
 * Jockey
 */
void Event_JockeyRide(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("victim"));
    if (iClient <= 0) return;
    // Fix get-up keeps playing
    AnimState pAnim = AnimState(iClient);
    pAnim.SetFlag(AnimState_Charged,     false);
    pAnim.SetFlag(AnimState_WallSlammed, false);
}

void Event_JockeyRideEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("victim"));
    if (iClient <= 0) return;
    // Fix no get-up
    AnimState(iClient).SetFlag(AnimState_RiddenByJockey, false);
}


/**
 * Charger
 */
void Event_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)             return;
    if (!IsClientInGame(iClient)) return;

    int iAttacker = g_iChargeAttacker[iClient];
    if (iAttacker == -1) return;

    g_iChargeVictim[iAttacker] = -1;
    g_iChargeAttacker[iClient] = -1;
}

void Event_ChargerCarryStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    /**
     * FIXME:
     * Tiny workaround for multiple chargers, but still glitchy.
     * I would think charging victims away from other chargers
     * is really an undefined behavior, better block it.
     */
    int iVictim = GetClientOfUserId(eEvent.GetInt("victim"));
    if (iVictim <= 0) return;
    // Fix get-up keeps playing
    AnimState pAnim = AnimState(iVictim);
    pAnim.SetFlag(AnimState_TankPunched,   false);
    pAnim.SetFlag(AnimState_Charged,       false);
    pAnim.SetFlag(AnimState_Pounded,       false);
    pAnim.SetFlag(AnimState_GroundSlammed, false);
    pAnim.SetFlag(AnimState_WallSlammed,   false);
}

// Pounces on survivors being carried will invoke this instantly.
void Event_ChargerPummelStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    int iVictim = GetClientOfUserId(eEvent.GetInt("victim"));
    if (iClient <= 0) return;
    if (iVictim <= 0) return;
    g_iChargeVictim  [iClient] = iVictim;
    g_iChargeAttacker[iVictim] = iClient;
}

// Take care of pummel transition and self-clears
void Event_ChargerKilled(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)             return;
    if (!IsClientInGame(iClient)) return;
    int iVictim = g_iChargeVictim[iClient];
    if (iVictim <= 0)             return;
    if (!IsClientInGame(iVictim)) return;
    AnimState pAnim = AnimState(iVictim);
    if (GetEntPropEnt(iVictim, Prop_Send, "m_pounceAttacker") != -1) {
        // Fix double get-up
        pAnim.SetFlag(AnimState_GroundSlammed, false);
        pAnim.SetFlag(AnimState_WallSlammed,   false);
    } else {
        int iAttacker = GetClientOfUserId(eEvent.GetInt("attacker"));
        if (iAttacker && iVictim == iAttacker) {
            if (!L4D_IsPlayerIncapacitated(iVictim)) {
                // No self-clear get-up
                pAnim.SetFlag(AnimState_GroundSlammed, false);
                pAnim.SetFlag(AnimState_WallSlammed,   false);
            }
        } else {
            // long charged get-up
            float fElaspedAnimTime = 0.0;
            if ((pAnim.GetFlag(AnimState_GroundSlammed) && ((fElaspedAnimTime = 119 / 30.0), g_cvKeepLongChargeLongGetUp.BoolValue))
            ||  (pAnim.GetFlag(AnimState_WallSlammed)   && ((fElaspedAnimTime = 116 / 30.0), g_cvKeepWallSlamLongGetUp.BoolValue))) {
                fElaspedAnimTime *= GetEntPropFloat(iVictim, Prop_Send, "m_flCycle");
                SetInvulnerableForSlammed(iVictim, g_cvLongChargeDuration.FloatValue - fElaspedAnimTime);
            } else {
                if (pAnim.GetFlag(AnimState_GroundSlammed) || pAnim.GetFlag(AnimState_WallSlammed)) {
                    float fDuration = 2.0;
                    if (g_cvChargeDuration != null) fDuration = g_cvChargeDuration.FloatValue;
                    SetInvulnerableForSlammed(iVictim, fDuration);
                }
                L4D2Direct_DoAnimationEvent(iVictim, ANIM_CHARGER_GETUP);
            }
            g_fLastChargedEndTime[iVictim] = GetGameTime();
        }
    }
    g_iChargeVictim  [iClient] = -1;
    g_iChargeAttacker[iVictim] = -1;
}

void Event_ChargerPummelEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    int iVictim = GetClientOfUserId(eEvent.GetInt("victim"));
    if (iClient <= 0) return;
    if (iVictim <= 0) return;
    AnimState pAnim = AnimState(iVictim);
    // Fix double get-up
    pAnim.SetFlag(AnimState_TankPunched, false);
    pAnim.SetFlag(AnimState_Pounced,     false);
    // Normal processes don't need special care
    g_iChargeVictim      [iClient] = -1;
    g_iChargeAttacker    [iVictim] = -1;
    g_fLastChargedEndTime[iVictim] = GetGameTime();
}

public void L4D2_OnSlammedSurvivor_Post(int iVictim, int iAttacker, bool bWallSlam, bool bDeadlyCharge) {
    if (iVictim <= 0)             return;
    if (!IsClientInGame(iVictim)) return;
    if (!IsPlayerAlive(iVictim))  return;

    g_iChargeVictim[iAttacker] = iVictim;
    g_iChargeAttacker[iVictim] = iAttacker;

    AnimState pAnim = AnimState(iVictim);
    pAnim.SetFlag(AnimState_Pounded,     false);
    pAnim.SetFlag(AnimState_Charged,     false);
    pAnim.SetFlag(AnimState_TankPunched, false);
    pAnim.SetFlag(AnimState_Pounced,     false);
    pAnim.ResetMainActivity();

    // compatibility with competitive 1v1
    if (!IsPlayerAlive(iAttacker)) {
        Event eEvent = CreateEvent("charger_killed");
        eEvent.SetInt("userid", GetClientUserId(iAttacker));
        Event_ChargerKilled(eEvent, "charger_killed", false);
        eEvent.Cancel();
    }
}


/**
 * Tank
 */
public void L4D_TankClaw_OnPlayerHit_Post(int iTank, int iClaw, int iPlayer) {
    if (GetClientTeam(iPlayer) != L4D2Team_Survivor) return;
    if (L4D_IsPlayerIncapacitated(iPlayer))          return;
    ProcessAttackedByTank(iPlayer);
}

public void L4D_OnKnockedDown_Post(int iClient, int iReason) {
    if (iReason != KNOCKDOWN_TANK)                   return;
    if (GetClientTeam(iClient) != L4D2Team_Survivor) return;
    ProcessAttackedByTank(iClient);
}

void ProcessAttackedByTank(int iVictim) {
    if (GetEntPropEnt(iVictim, Prop_Send, "m_pummelAttacker") != -1)
        return;
    AnimState pAnim = AnimState(iVictim);
    // Fix double get-up
    pAnim.SetFlag(AnimState_Charged, false);
    // Fix double get-up when punching charger with victim to die
    // Keep in mind that do not mess up with later attacks to the survivor
    if (GetGameTime() - g_fLastChargedEndTime[iVictim] <= 0.1) {
        pAnim.SetFlag(AnimState_TankPunched, false);
    } else {
        // Remove charger get-up that doesn't pass the check above
        pAnim.SetFlag(AnimState_GroundSlammed, false);
        pAnim.SetFlag(AnimState_WallSlammed,   false);
        pAnim.SetFlag(AnimState_Pounded,       false);
        // Restart the get-up sequence if already playing
        pAnim.ResetMainActivity();
    }
}

stock void SetInvulnerableForSlammed(int iClient, float fDuration) {
    if (!IsPlayerAlive(iClient)) return;
    if (!g_bGodframeControl) {
        CountdownTimer cTimer = L4D2Direct_GetInvulnerabilityTimer(iClient);
        if (cTimer == CTimer_Null) return;
        CTimer_Start(cTimer, fDuration);
        return;
    }
    GiveClientGodFrames(iClient, fDuration, 8); // 1 - Hunter. 2 - Smoker. 4 - Jockey. 8 - Charger. fk u
}