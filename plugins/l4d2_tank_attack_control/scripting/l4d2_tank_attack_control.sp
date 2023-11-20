#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <left4dhooks>
#include <l4d2_nobhaps>

#undef REQUIRE_PLUGIN
#include <solaris/versus_manager>
#define REQUIRE_PLUGIN

ConVar g_cvBlockPunchRock;
bool   g_bBlockPunchRock;

ConVar g_cvBlockJumpRock;
bool   g_bBlockJumpRock;

ConVar g_cvOverhandOnly;
bool   g_bOverhandOnly;

ConVar g_cvJumpRockCooldown;
float  g_fJumpRockCooldown;

bool   g_bJumped       [MAXPLAYERS + 1];
float  g_fCooldownTime [MAXPLAYERS + 1];
int    g_iQueuedThrow  [MAXPLAYERS + 1];
float  g_fThrowQueuedAt[MAXPLAYERS + 1];

bool   g_bVersusManager;

public Plugin myinfo = {
    name        = "[L4D2] Tank Attack Control / Jump Rock Cooldown Hybrid",
    author      = "vintik, CanadaRox, Jacob, Visor, Spoon",
    description = "Remake of https://github.com/Stabbath/ProMod/blob/master/addons/sourcemod/scripting/l4d_tank_control.sp.",
    version     = "0.9",
    url         = "https://github.com/spoon-l4d2"
}

any Native_GetCoolDownTime(Handle hPlugin, int iNumParams) {
    int iClient = GetNativeCell(1);
    if (iClient <= 0)         ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);
    if (iClient > MaxClients) ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);
    return RoundToFloor(g_fCooldownTime[iClient]);
}

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    CreateNative("L4D2_GetTankCoolDownTime", Native_GetCoolDownTime);
    RegPluginLibrary("l4d2_tank_attack_control");
    return APLRes_Success;
}

public void OnPluginStart() {
    g_cvBlockPunchRock = CreateConVar(
    "l4d2_block_punch_rock", "1", "Block tanks from punching and throwing a rock at the same time",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bBlockPunchRock = g_cvBlockPunchRock.BoolValue;
    g_cvBlockPunchRock.AddChangeHook(OnCvarChange);

    g_cvBlockJumpRock = CreateConVar(
    "l4d2_block_jump_rock", "0", "Block tanks from jumping and throwing a rock at the same time",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bBlockJumpRock = g_cvBlockJumpRock.BoolValue;
    g_cvBlockJumpRock.AddChangeHook(OnCvarChange);

    g_cvOverhandOnly = CreateConVar(
    "l4d2_tank_overhand_only", "0", "Force Tank to only throw overhand rocks.",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bOverhandOnly = g_cvOverhandOnly.BoolValue;
    g_cvOverhandOnly.AddChangeHook(OnCvarChange);

    g_cvJumpRockCooldown = CreateConVar(
    "l4d2_jump_rock_cooldown", "20", "Sets cooldown for jump rock ability",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_fJumpRockCooldown = g_cvJumpRockCooldown.FloatValue;
    g_cvJumpRockCooldown.AddChangeHook(OnCvarChange);

    HookEvent("round_start", Event_RoundStart);
    HookEvent("tank_spawn",  Event_TankSpawn);
}

public void OnAllPluginsLoaded() {
    g_bVersusManager = LibraryExists("solaris_versus_manager");
}

public void OnLibraryAdded(const char[] szName) {
    if (strcmp(szName, "solaris_versus_manager") == 0)
        g_bVersusManager = true;
}

public void OnLibraryRemoved(const char[] szName) {
    if (strcmp(szName, "solaris_versus_manager") == 0)
        g_bVersusManager = false;
}

public void OnClientPutInServer(int iClient) {
    g_bJumped       [iClient] = false;
    g_fCooldownTime [iClient] = 0.0;
    g_fThrowQueuedAt[iClient] = 0.0;
}

public void OnClientDisconnet(int iClient) {
    g_bJumped       [iClient] = false;
    g_fCooldownTime [iClient] = 0.0;
    g_fThrowQueuedAt[iClient] = 0.0;
}

void OnCvarChange(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bBlockPunchRock   = g_cvBlockPunchRock.BoolValue;
    g_bBlockJumpRock    = g_cvBlockJumpRock.BoolValue;
    g_bOverhandOnly     = g_cvOverhandOnly.BoolValue;
    g_fJumpRockCooldown = g_cvJumpRockCooldown.FloatValue;
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    for (int i = 1; i <= MaxClients; i++) {
        g_bJumped       [i] = false;
        g_fCooldownTime [i] = 0.0;
        g_fThrowQueuedAt[i] = 0.0;
    }
}

void Event_TankSpawn(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (IsFakeClient(iClient)) return;

    bool bHidemessage = false;
    char szBuffer[3];
    if (GetClientInfo(iClient, "rs_hidemessage", szBuffer, sizeof(szBuffer))) {
        bHidemessage = view_as<bool>(StringToInt(szBuffer));
    }

    if (!bHidemessage && !g_bOverhandOnly) {
        CPrintToChat(iClient, "{red}[{default}Tank Rock Selector{red}]");
        CPrintToChat(iClient, "{red}Use {olive}-> {default}Underhand throw");
        CPrintToChat(iClient, "{red}Melee {olive}-> {default}One hand overhand");
        CPrintToChat(iClient, "{red}Reload {olive}-> {default}Two hand overhand");
    }

    g_bJumped       [iClient] = false;
    g_fCooldownTime [iClient] = 0.0;
    g_fThrowQueuedAt[iClient] = 0.0;
}

public Action OnPlayerRunCmd(int iClient, int &iButtons) {
    if (!IsClientInGame(iClient) || IsFakeClient(iClient) || GetClientTeam(iClient) != 3 || GetEntProp(iClient, Prop_Send, "m_zombieClass") != 8 || IsInfectedGhost(iClient)) {
        g_bJumped[iClient] = false;
        return Plugin_Continue;
    }

    int iEntityFlags = GetEntityFlags(iClient);
    if ((iButtons & IN_JUMP) && ShouldCancelJump(iClient)) {
        iButtons &= ~IN_JUMP;
        g_bJumped[iClient] = false;
    } else if ((iButtons & IN_JUMP) && !(iEntityFlags & FL_ONGROUND)) {
        g_bJumped[iClient] = true;
    } else {
        g_bJumped[iClient] = false;
    }

    if (g_bOverhandOnly) {
        g_iQueuedThrow[iClient] = 3;
    } else {
        if (iButtons & IN_RELOAD) {
            g_iQueuedThrow[iClient] = 3;
            iButtons |= IN_ATTACK2;
        } else if (iButtons & IN_USE) {
            g_iQueuedThrow[iClient] = 2;
            iButtons |= IN_ATTACK2;
        } else {
            g_iQueuedThrow[iClient] = 1;
        }
    }

    return Plugin_Continue;
}

public Action L4D_OnCThrowActivate(int iAbility) {
    if (!IsValidEntity(iAbility)) {
        LogMessage("Invalid 'ability_throw' index: %d. Continuing throwing.", iAbility);
        return Plugin_Continue;
    }
    int iClient = GetEntPropEnt(iAbility, Prop_Data, "m_hOwnerEntity");
    if (GetClientButtons(iClient) & IN_ATTACK) {
        if (g_bBlockPunchRock) return Plugin_Handled;
        if (g_bVersusManager) {
            if (Solaris_BlockPunchRock())
                return Plugin_Handled;
        }
    }
    int iEntityFlags = GetEntityFlags(iClient);
    if (!(iEntityFlags & FL_ONGROUND)) {
        return Plugin_Continue;
    }
    g_fThrowQueuedAt[iClient] = GetGameTime();
    return Plugin_Continue;
}

public Action L4D2_OnSelectTankAttack(int iClient, int &iSequence) {
    if (iSequence > 48 && g_iQueuedThrow[iClient]) {
        if (g_bJumped[iClient]) PutJumpRockOnCooldown(iClient);
        iSequence = g_iQueuedThrow[iClient] + 48;
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

bool ShouldCancelJump(int iClient) {
    if (IsJumpRockReady(iClient))
        return false;
    return (1.5 > GetGameTime() - g_fThrowQueuedAt[iClient]);
}

void PutJumpRockOnCooldown(int iClient) {
    if (!IsJumpRockReady(iClient)) return;

    g_fCooldownTime[iClient] = g_fJumpRockCooldown;

    int iUserId = GetClientUserId(iClient);
    DataPack dp;
    CreateDataTimer(1.0, Timer_Countdown, dp, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    dp.WriteCell(iUserId);
    dp.WriteCell(iClient);
}

Action Timer_Countdown(Handle hTimer, DataPack dp) {
    dp.Reset();
    int iUserId = dp.ReadCell();
    int iClient = dp.ReadCell();

    if (GetClientOfUserId(iUserId) <= 0) {
        g_fCooldownTime[iClient] = 0.0;
        return Plugin_Stop;
    }

    g_fCooldownTime[iClient]--;

    if (g_fCooldownTime[iClient] <= 0.0) {
        g_fCooldownTime[iClient] = 0.0;
        return Plugin_Stop;
    }

    return Plugin_Continue;
}

bool IsJumpRockReady(int iClient) {
    if (g_bBlockJumpRock)
        return false;
    if (g_bVersusManager) {
        if (Solaris_BlockJumpRock())
            return false;
    }
    if (IsClientBlockedBH(iClient))
        return false;
    if (g_fCooldownTime[iClient] > 0.0)
        return false;
    return true;
}

bool IsInfectedGhost(int iClient) {
    return view_as<bool>(GetEntProp(iClient, Prop_Send, "m_isGhost", 1));
}