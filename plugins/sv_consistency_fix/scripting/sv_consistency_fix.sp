#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>

public Plugin myinfo = {
    name        = "sv_consistency fixes",
    author      = "step, Sir",
    description = "Fixes multiple sv_consistency issues.",
    version     = "1.3",
    url         = "http://step.l4dnation.com/"
};

public void OnPluginStart() {
    if (!FileExists("whitelist.cfg"))
        SetFailState("Couldn't find whitelist.cfg");

    RegAdminCmd("sm_consistencycheck", Command_ConsistencyCheck, ADMFLAG_RCON, "Performs a consistency check on all players.");
    CreateConVar(
    "cl_consistencycheck_interval", "180.0",
    "Perform a consistency check after this amount of time (seconds) has passed since the last.",
    FCVAR_REPLICATED).SetInt(999999);
}

public void OnClientConnected(int iClient) {
    ClientCommand(iClient, "cl_consistencycheck");
}

Action Command_ConsistencyCheck(int iClient, int iArgs) {
    if (iArgs < 1) {
        ConsistencyCheck(0);
        return Plugin_Handled;
    }

    char szPlayer[32];
    GetCmdArg(1, szPlayer, sizeof(szPlayer));

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientConnected(i))
            continue;

        char szOther[32];
        GetClientName(i, szOther, sizeof(szOther));

        if (strcmp(szPlayer, szOther, false) == 0)
            ConsistencyCheck(i);
    }

    return Plugin_Handled;
}

void ConsistencyCheck(int iClient = 0) {
    if (iClient == 0) {
        for (int i = 1; i <= MaxClients; i++) {
            if (!IsClientInGame(i))
                continue;
            if (IsFakeClient(i))
                continue;
            ClientCommand(i, "cl_consistencycheck");
        }
        return;
    }

    ClientCommand(iClient, "cl_consistencycheck");
}