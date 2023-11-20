#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <colors>
#include <sdktools>

#include <solaris/team_manager>
#include <solaris/stocks>

#define TEAM_SPECTATORS 1

bool g_bLostConnection[MAXPLAYERS + 1];

public void OnPluginStart() {
    CreateTimer(0.5, TimingOutCheck, _, TIMER_REPEAT);
}

public void OnClientPutInServer(int iClient) {
    if (IsFakeClient(iClient)) return;
    g_bLostConnection[iClient] = false;
}

public void OnClientDisconnect(int iClient) {
    if (IsFakeClient(iClient)) return;
    g_bLostConnection[iClient] = false;
}

public Action TimingOutCheck(Handle hTimer) {
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i)) continue;
        if (IsFakeClient(i))    continue;
        if (g_bLostConnection[i] && !IsClientTimingOut(i)) {
            CPrintToChatAllEx(i, "{green}[{teamcolor}!{green}]{default} Player {teamcolor}%N{default} has {olive}restored connection{default} to the server.", i);
            g_bLostConnection[i] = false;
        }
        if (GetClientTeam(i) > TEAM_SPECTATORS) {
            if (!g_bLostConnection[i] && IsClientTimingOut(i)) {
                CPrintToChatAllEx(i, "{green}[{teamcolor}!{green}]{default} Player {teamcolor}%N{default} has {green}lost connection{default} to the server.", i);
                g_bLostConnection[i] = true;
            }
        }
    }
    return Plugin_Continue;
}