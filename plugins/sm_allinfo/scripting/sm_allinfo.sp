#pragma newdecls required
#pragma semicolon 1
#include <sourcemod>

public Plugin myinfo = {
    name        = "sm_allinfo",
    author      = "{7~11} TROLL",
    description = "Gets single clients steam id, name, and ip based on the amx version",
    version     = "2.1.1",
    url         = "www.711clan.net"
}

public void OnPluginStart() {
    RegAdminCmd("sm_allinfo", Command_Users, ADMFLAG_ROOT, "sm_allinfo <Clients Name>");
}

public Action Command_Users(int iClient, int iArgs) {
    int iTarget;
    if (iArgs < 1) {
        char szArg[MAX_NAME_LENGTH];
        GetCmdArg(1, szArg, sizeof(szArg));
        iTarget = FindTarget(iClient, szArg, false, false);
        if (!iTarget) {
            ReplyToCommand(iClient, "Could not find %s", szArg);
            return Plugin_Handled;
        }
    } else {
        ReplyToCommand(iClient, "Correct syntax: sm_allinfo playername");
        return Plugin_Handled;
    }

    // Gets client name
    char szName[MAX_NAME_LENGTH];
    GetClientName(iTarget, szName, sizeof(szName));

    // Gets clients Steam Id
    char szSteamId[32];
    GetClientAuthId(iTarget, AuthId_Steam2, szSteamId, sizeof(szSteamId), true);

    // Gets clients ip
    char szIP[32];
    GetClientIP(iTarget, szIP, sizeof(szIP));

    // Prints this to console to the admins
    PrintToConsole(iClient, ".:[Name: %s | Steam ID: %s | IP: %s]:.", szName, szSteamId, szIP);
    return Plugin_Handled;
}

// Gets client info apon joing server
public void OnClientPutInServer(int iClient) {
    // Gets client name
    char szName[MAX_NAME_LENGTH];
    GetClientName(iClient, szName, sizeof(szName));

    // Gets clients Steam Id
    char szSteamId[32];
    GetClientAuthId(iClient, AuthId_Steam2, szSteamId, sizeof(szSteamId), true);

    // Gets clients ip
    char szIP[32];
    GetClientIP(iClient, szIP, sizeof(szIP));

    // Checks to see if client is conncted -  also checks to see if client is a bot
    if (!IsClientConnected(iClient) || IsFakeClient(iClient))
        return;

    // Logs the info in this format (removing ^n to see if it effects logging
    char szPath[256];
    BuildPath(Path_SM, szPath, sizeof(szPath), "logs/allinfo_players.txt");
    LogToFile(szPath,".:[Name: %s | STEAMID: %s | IP: %s]:.", szName, szSteamId, szIP);
}