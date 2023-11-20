#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <l4d2util>

/* NOTES:
- Make bots/replacing players get hooked if they're currently pulled (bot_replace, player_replace)
- Check for Capper on OnNextFrame on Tongue Release Event for additional scenario?
- No support for more than 1 smoker. (Add?)
*/

bool g_bLateLoad;
bool g_bPlayerPulled[MAXPLAYERS + 1];

ConVar g_cvTongueDelayTank;
ConVar g_cvTongueDelaySurvivor;

float g_fTongueDelayTank;
float g_fTongueDelaySurvivor;

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    g_bLateLoad = bLate;
    return APLRes_Success;
}

public Plugin myinfo = {
    name        = "Tongue Timer",
    author      = "Sir",
    description = "Modify the Smoker's tongue ability timer in certain scenarios.",
    version     = "1.2",
    url         = "Nope"
}

public void OnPluginStart() {
    // ConVars
    g_cvTongueDelayTank = CreateConVar(
    "l4d2_tongue_delay_tank", "8.0",
    "How long of a cooldown does the Smoker get on a quick clear by Tank punch/rock? (Vanilla = ~0.5s)");
    g_fTongueDelayTank = g_cvTongueDelayTank.FloatValue;
    g_cvTongueDelayTank.AddChangeHook(ConvarChanged);

    g_cvTongueDelaySurvivor = CreateConVar(
    "l4d2_tongue_delay_survivor", "4.0",
    "How long of a cooldown does the Smoker get on a quick clear by Survivors? (Vanilla = ~0.5s)");
    g_fTongueDelaySurvivor = g_cvTongueDelaySurvivor.FloatValue;
    g_cvTongueDelaySurvivor.AddChangeHook(ConvarChanged);

    // Events
    HookEvent("round_start",         Event_TongueRelease);
    HookEvent("player_bot_replace",  Event_Replace);
    HookEvent("bot_player_replace",  Event_Replace);
    HookEvent("tongue_grab",         Event_TongueGrab);
    HookEvent("tongue_release",      Event_TongueRelease);
    HookEvent("tongue_pull_stopped", Event_TonguePullStopped);

    if (g_bLateLoad) {
        for (int i = 1; i <= MaxClients; i++) {
            if (IsClientInGame(i))
                OnClientPutInServer(i);
        }
    }
}

// ----------------------------------------------
//             SDKHOOKS STUFF
// ----------------------------------------------
public void OnClientPutInServer(int iClient) {
    SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &iDamageType, int &iWeapon, float fDamageForce[3], float fDamagePosition[3]) {
    if (!IsValidClient(iVictim))
        return Plugin_Continue;
    if (!IsValidClient(iAttacker))
        return Plugin_Continue;
    if (GetClientTeam(iVictim) != 2)
        return Plugin_Continue;
    if (GetClientTeam(iAttacker) != 3)
        return Plugin_Continue;
    if (!g_bPlayerPulled[iVictim])
        return Plugin_Continue;
    if (GetEntProp(iAttacker, Prop_Send, "m_zombieClass") != 8)
        return Plugin_Continue;

    // Find and Store smoker.
    int iSmoker = FindSmoker();
    ClearPulls();

    if (iSmoker == 0) return Plugin_Continue;

    float fTime = GetGameTime();
    float fTimeStamp;
    float fDuration;
    // Couldn't retrieve the ability timer.
    if (!GetInfectedAbilityTimer(iSmoker, fTimeStamp, fDuration))
        return Plugin_Continue;
    // Duration will be used as the new "m_timestamp"
    // If the smoker's pull delay is already longer than what we want it to be, don't bother.
    fDuration = fTime + g_fTongueDelayTank;
    if (fDuration > fTimeStamp)
        SetInfectedAbilityTimer(iSmoker, fDuration, g_fTongueDelayTank);
    return Plugin_Continue;
}

// ----------------------------------------------
//                    EVENTS
// ----------------------------------------------
public void Event_TongueGrab(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iVictim = GetClientOfUserId(eEvent.GetInt("victim"));
    if (IsValidClient(iVictim) && GetClientTeam(iVictim) == 2)
        g_bPlayerPulled[iVictim] = true;
}

public void Event_TonguePullStopped(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iVictim = GetClientOfUserId(eEvent.GetInt("victim"));
    int iSmoker = GetClientOfUserId(eEvent.GetInt("smoker"));
    if (IsValidClient(iVictim) && IsValidAliveSmoker(iSmoker) && GetClientTeam(iVictim) == 2)
        RequestFrame(OnSmokerSurvivorClear, iSmoker);
}

public void Event_TongueRelease(Event eEvent, const char[] szName, bool bDontBroadcast) {
    RequestFrame(OnNextFrame);
}

public void Event_Replace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iBot    = GetClientOfUserId(eEvent.GetInt("bot"));
    int iPlayer = GetClientOfUserId(eEvent.GetInt("player"));

    // Bot replaced a player.
    if (StrEqual(szName, "player_bot_replace", false)) {
        if (g_bPlayerPulled[iPlayer]) {
            g_bPlayerPulled[iBot]    = true;
            g_bPlayerPulled[iPlayer] = false;
        }
    } else if (g_bPlayerPulled[iBot]) {
        g_bPlayerPulled[iPlayer] = true;
        g_bPlayerPulled[iBot]    = false;
    }
}

public void ClearPulls() {
    for (int i = 1; i <= MaxClients; i++) {
        g_bPlayerPulled[i] = false;
    }
}

// ----------------------------------------------
//             REQUESTFRAMES (Next Frame)
// ----------------------------------------------
void OnNextFrame(any iVictim) {
    ClearPulls();
}

public void OnSmokerSurvivorClear(any iSmoker) {
    if (IsValidAliveSmoker(iSmoker)) {
        float fTime = GetGameTime();
        float fTimeStamp;
        float fDuration;
        // Couldn't retrieve the ability timer.
        if (!GetInfectedAbilityTimer(iSmoker, fTimeStamp, fDuration))
            return;
        // Duration will be used as the new "m_timestamp"
        // If the smoker's pull delay is already longer than what we want it to be, don't bother.
        fDuration = fTime + g_fTongueDelaySurvivor;

        if (fDuration > fTimeStamp)
            SetInfectedAbilityTimer(iSmoker, fDuration, g_fTongueDelaySurvivor);
    }
}

// ----------------------------------------------
//                 CONVARS
// ----------------------------------------------
void ConvarChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fTongueDelayTank     = g_cvTongueDelayTank.FloatValue;
    g_fTongueDelaySurvivor = g_cvTongueDelaySurvivor.FloatValue;
}

// ----------------------------------------------
//                 STOCKS
// ----------------------------------------------
bool IsValidClient(int iClient) {
    if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient) || !IsPlayerAlive(iClient))
        return false;
    return true;
}

bool IsValidAliveSmoker(int iClient) {
    if (!IsValidClient(iClient) || GetClientTeam(iClient) != 3)
        return false;
    return GetEntProp(iClient, Prop_Send, "m_zombieClass") == 1;
}

int FindSmoker() {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsValidAliveSmoker(i))
            return i;
    }
    return 0;
}