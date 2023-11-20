#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

ConVar g_cvHibernateWhenEmpty;
ConVar g_cvStopBots;
float  g_fLastDisconnectTime;
bool   g_bHibernateDisabled;

public void OnPluginStart() {
    g_cvHibernateWhenEmpty = FindConVar("sv_hibernate_when_empty");

    g_cvStopBots = FindConVar("sb_stop");
    g_cvStopBots.SetBool(true);
    ToggleStopBotsHook(true);

    HookEvent("player_disconnect", Event_PlayerDisconnect);
}

void ConVarChanged_HibernateWhenEmpty(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_cvHibernateWhenEmpty.SetBool(false);
}

void ConVarChanged_StopBots(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_cvStopBots.SetBool(true);
}

public void OnClientPutInServer(int iClient) {
    if (!IsFakeClient(iClient)) {
        if (!g_bHibernateDisabled) {
            // disable hibernation only once player joins
            g_cvHibernateWhenEmpty.SetBool(false);
            g_cvHibernateWhenEmpty.AddChangeHook(ConVarChanged_HibernateWhenEmpty);
        }
        ToggleStopBotsHook(false);
    }
}

public void OnMapStart() {
    static bool bFirstMapLoaded = false;
    if (bFirstMapLoaded) {
        CreateTimer(60.0, Timer_OnMapStart, _, TIMER_FLAG_NO_MAPCHANGE);
        ToggleStopBotsHook(false);
        return;
    }
    bFirstMapLoaded = true;
}

Action Timer_OnMapStart(Handle hTimer) {
    if (ServerIsEmpty())
        ServerCommand("quit");
    return Plugin_Stop;
}

void ToggleStopBotsHook(bool bEnable) {
    static bool bEnabled;
    if (!bEnabled && bEnable) {
        g_cvStopBots.AddChangeHook(ConVarChanged_StopBots);
        bEnabled = true;
    } else if (bEnabled && !bEnable) {
        g_cvStopBots.RemoveChangeHook(ConVarChanged_StopBots);
        bEnabled = false;
    }
}

void Event_PlayerDisconnect(Event hEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
    if (iClient <= 0)
        return;

    if (!IsClientConnected(iClient))
        return;

    if (IsFakeClient(iClient))
        return;

    float fDisconnectTime = GetGameTime();
    if (g_fLastDisconnectTime == fDisconnectTime)
        return;

    g_fLastDisconnectTime = fDisconnectTime;
    CreateTimer(0.5, Timer_PlayerDisconnect, fDisconnectTime, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_PlayerDisconnect(Handle hTimer, any fDisconnectTime) {
    if (fDisconnectTime != -1.0 && fDisconnectTime != g_fLastDisconnectTime)
        return Plugin_Stop;

    if (!ServerIsEmpty())
        return Plugin_Stop;

    ServerCommand("quit");
    return Plugin_Stop;
}

bool ServerIsEmpty() {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientConnected(i) && !IsFakeClient(i)) {
            return false;
        }
    }
    return true;
}