#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <solaris/stocks>

ConVar g_cvGameMode;
bool   g_bIsVersus;

public Plugin myinfo = {
    name    = "Fix frozen tanks",
    version = "2.0",
    author  = "sheo",
}

public void OnPluginStart() {
    g_cvGameMode = FindConVar("mp_gamemode");
    g_cvGameMode.AddChangeHook(ConVarChanged);
    HookEvent("player_incapacitated", Event_PlayerIncap);
}

public void OnConfigsExecuted() {
    g_bIsVersus = SDK_HasPlayerInfected();
}

void ConVarChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bIsVersus = SDK_HasPlayerInfected();
}

void Event_PlayerIncap(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!g_bIsVersus) return;
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient > 0 && IsPlayerTank(iClient)) CreateTimer(1.0, Timer_KillTank, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_KillTank(Handle hTimer) {
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsPlayerTank(i))  continue;
        if (!IsIncapitated(i)) continue;
        ForcePlayerSuicide(i);
    }
    return Plugin_Stop;
}

bool IsIncapitated(int iClient) {
    return view_as<bool>(GetEntProp(iClient, Prop_Send, "m_isIncapacitated"));
}

bool IsPlayerTank(int iClient) {
    if (IsClientInGame(iClient) && GetClientTeam(iClient) == 3) {
        if (GetEntProp(iClient, Prop_Send, "m_zombieClass") == 8)
            return true;
    }
    return false;
}