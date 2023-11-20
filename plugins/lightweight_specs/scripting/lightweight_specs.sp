#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <solaris/stocks>

#define TEAM_SPECTATORS 1
#define NETVARSLENGTH   8

ConVar g_cvMinCmdRate;
ConVar g_cvMaxCmdRate;
ConVar g_cvMinUpdRate;
ConVar g_cvMaxUpdRate;
ConVar g_cvMinRate;
ConVar g_cvMaxRate;

char  g_szNetVars    [8][8];
float g_fLastAdjusted[MAXPLAYERS + 1];
bool  g_bSpecRates   [MAXPLAYERS + 1] = {true, ...};

public Plugin myinfo = {
    name        = "Lightweight Spectating",
    author      = "Visor",
    description = "Forces low rates on spectators",
    version     = "1.2",
    url         = "https://github.com/Attano/smplugins"
};

public void OnPluginStart() {
    g_cvMinCmdRate = FindConVar("sv_mincmdrate");
    g_cvMaxCmdRate = FindConVar("sv_maxcmdrate");
    g_cvMinUpdRate = FindConVar("sv_minupdaterate");
    g_cvMaxUpdRate = FindConVar("sv_maxupdaterate");
    g_cvMinRate    = FindConVar("sv_minrate");
    g_cvMaxRate    = FindConVar("sv_maxrate");

    RegConsoleCmd("sm_specrates", Cmd_Specrates);

    HookEvent("player_team", Event_PlayerTeam);
}

public void OnPluginEnd() {
    g_cvMinCmdRate.SetString(g_szNetVars[0]);
    g_cvMinUpdRate.SetString(g_szNetVars[2]);
}

public void OnConfigsExecuted() {
    g_cvMinCmdRate.GetString(g_szNetVars[0], NETVARSLENGTH);
    g_cvMaxCmdRate.GetString(g_szNetVars[1], NETVARSLENGTH);
    g_cvMinUpdRate.GetString(g_szNetVars[2], NETVARSLENGTH);
    g_cvMaxUpdRate.GetString(g_szNetVars[3], NETVARSLENGTH);
    g_cvMinRate.GetString(g_szNetVars[4],    NETVARSLENGTH);
    g_cvMaxRate.GetString(g_szNetVars[5],    NETVARSLENGTH);

    g_cvMinCmdRate.SetInt(30);
    g_cvMinUpdRate.SetInt(30);
}

Action Cmd_Specrates(int iClient, int iArgs) {
    if (iClient <= 0)
        return Plugin_Handled;

    if (!IsClientInGame(iClient))
        return Plugin_Handled;

    if (!ST_IsAdminClient(iClient))
        return Plugin_Handled;

    if (GetClientTeam(iClient) != 1)
        return Plugin_Handled;

    CPrintToChat(iClient, "SpecRates %s", g_bSpecRates[iClient] ? "{red}ON" : "{blue}OFF");
    g_bSpecRates[iClient] = !g_bSpecRates[iClient];
    CreateTimer(3.0, Timer_AdjustRates, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);

    return Plugin_Handled;
}

public void OnClientPutInServer(int iClient) {
    g_fLastAdjusted[iClient] = 0.0;
    g_bSpecRates   [iClient] = false;
}

void Event_PlayerTeam(Event eEvent, char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)
        return;

    CreateTimer(3.0, Timer_AdjustRates, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_AdjustRates(Handle timer, any iUserId) {
    int iClient = GetClientOfUserId(iUserId);
    if (iClient <= 0)
        return Plugin_Handled;

    AdjustRates(iClient);
    return Plugin_Handled;
}

public void OnClientSettingsChanged(int iClient) {
    AdjustRates(iClient);
}

void AdjustRates(int iClient) {
    if (iClient <= 0)
        return;

    if (!IsClientInGame(iClient))
        return;

    if (IsFakeClient(iClient))
        return;

    int iTeam = GetClientTeam(iClient);

    if (g_fLastAdjusted[iClient] >= GetEngineTime() - 1.0)
        return;

    g_fLastAdjusted[iClient] = GetEngineTime();

    if ((iTeam == TEAM_SPECTATORS && g_bSpecRates[iClient]) || iTeam > TEAM_SPECTATORS) {
        ResetRates(iClient);
    } else if (GetClientTeam(iClient) == TEAM_SPECTATORS && !g_bSpecRates[iClient]) {
        SetSpectatorRates(iClient);
    }
}

void SetSpectatorRates(int iClient) {
    SendConVarValue(iClient, g_cvMinCmdRate, "30");
    SendConVarValue(iClient, g_cvMaxCmdRate, "30");
    SendConVarValue(iClient, g_cvMinUpdRate, "30");
    SendConVarValue(iClient, g_cvMaxUpdRate, "30");
    SendConVarValue(iClient, g_cvMinRate,    "30000");
    SendConVarValue(iClient, g_cvMaxRate,    "30000");

    SetClientInfo(iClient, "cl_cmdrate",    "30");
    SetClientInfo(iClient, "cl_updaterate", "30");
}

void ResetRates(int iClient) {
    SendConVarValue(iClient, g_cvMinCmdRate, g_szNetVars[0]);
    SendConVarValue(iClient, g_cvMaxCmdRate, g_szNetVars[1]);
    SendConVarValue(iClient, g_cvMinUpdRate, g_szNetVars[2]);
    SendConVarValue(iClient, g_cvMaxUpdRate, g_szNetVars[3]);
    SendConVarValue(iClient, g_cvMinRate,    g_szNetVars[4]);
    SendConVarValue(iClient, g_cvMaxRate,    g_szNetVars[5]);

    SetClientInfo(iClient, "cl_cmdrate",    g_szNetVars[0]);
    SetClientInfo(iClient, "cl_updaterate", g_szNetVars[2]);
}