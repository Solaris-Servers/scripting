#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <left4dhooks>

bool g_bBlockSpawn[MAXPLAYERS + 1];

public Plugin myinfo = {
    name        = "Flying Ghosts",
    author      = "CanadaRox",
    description = "Allows ghosts to fly but only spawn like normal",
    version     = "1.0.0",
    url         = "https://github.com/CanadaRox/sourcemod-plugins/tree/master/flying_ghosts"
};

public void OnPluginStart() {
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    for (int i = 1; i <= MaxClients; i++) {
        g_bBlockSpawn[i] = false;
    }
}

public void OnClientPutInServer(int iClient) {
    g_bBlockSpawn[iClient] = false;
}

public void OnClientDisconnect(int iClient) {
    g_bBlockSpawn[iClient] = false;
}

public Action OnPlayerRunCmd(int iClient, int &iButtons) {
    static bool bInReload[MAXPLAYERS + 1];

    // Player is not our target
    if (!IsClientInGame(iClient) ||IsFakeClient(iClient) || !IsGhostInfected(iClient)) {
        bInReload[iClient] = false;
        return Plugin_Continue;
    }

    // Player was holding Reload, and now isn't. (Released)
    if (!(iButtons & IN_RELOAD) && bInReload[iClient]) {
        bInReload[iClient] = false;
        return Plugin_Continue;
    }

    // Player was not holding m2, and now is. (Pressed)
    if ((iButtons & IN_RELOAD) && !bInReload[iClient]) {
        bInReload[iClient] = true;
        if (GetEntityMoveType(iClient) == MOVETYPE_WALK) {
            SetEntityMoveType(iClient, MOVETYPE_NOCLIP);
            g_bBlockSpawn[iClient] = true;
        } else {
            SetEntityMoveType(iClient, MOVETYPE_WALK);
        }
    }

    // Player was not allowed to spawn
    if (GetEntityMoveType(iClient) == MOVETYPE_WALK) {
        if (g_bBlockSpawn[iClient]) g_bBlockSpawn[iClient] = view_as<bool>(GetEntityFlags(iClient) & FL_ONGROUND);
    }

    return Plugin_Continue;
}

public Action L4D_OnMaterializeFromGhostPre(int iClient) {
    return g_bBlockSpawn[iClient] ? Plugin_Handled : Plugin_Continue;
}

stock int IsGhostInfected(int client) {
    return GetClientTeam(client) == 3 && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_isGhost");
}