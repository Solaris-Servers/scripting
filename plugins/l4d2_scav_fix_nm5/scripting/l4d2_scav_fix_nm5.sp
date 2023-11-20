#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

// Timer
Handle g_hTimer;
ConVar g_cvGameMode;

public Plugin myinfo = {
    name        = "L4D2 No Mercy Rooftop Scavenge Fix",
    author      = "Ratchet",
    description = "Fixes No Mercy 5 scavenge.",
    version     = "1.0",
    url         = "https://forums.alliedmods.net/showthread.php?p=1648508"
}

public void OnMapStart() {
    char szMapName[128];
    GetCurrentMap(szMapName, sizeof(szMapName));
    if (g_hTimer != null) {
        KillTimer(g_hTimer);
        g_hTimer = null;
    }
    if (strcmp(szMapName, "c8m5_rooftop") != 0)
        return;
    g_cvGameMode = FindConVar("mp_gamemode");
    char sGameMode[32];
    g_cvGameMode.GetString(sGameMode, sizeof(sGameMode));
    if (strcmp(sGameMode, "scavenge") != 0)
        return;
    g_hTimer = CreateTimer(15.0, Scavg_hTimer, _, TIMER_REPEAT);
}

public Action Scavg_hTimer(Handle hTimer, any iClient) {
    FindMisplacedCans();
    FindAliveFallenSurvivors();
    return Plugin_Continue;
}

stock void FindMisplacedCans() {
    int iEnt = -1;
    while ((iEnt = FindEntityByClassname(iEnt, "weapon_gascan")) != -1) {
        if (!IsValidEntity(iEnt))
            continue;
        float position[3];
        GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", position);
        if (position[2] <= 500.0) {
            // HACK HACK! Although it's impossible for can to go to 0 0 0 in NM5
            if (position[0] > 0.0 && position[1] > 0.0 && position[2])
                Ignite(iEnt);
        }
    }
}

stock void FindAliveFallenSurvivors() {
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i))
            continue;
        float fPosition[3];
        GetEntPropVector(i, Prop_Send, "m_vecOrigin", fPosition);
        if (fPosition[2] <= 500.0) {
            if (fPosition[0] > 0.0 && fPosition[1] > 0.0 && fPosition[2])
                ForcePlayerSuicide(i);
        }
    }
}

stock void Ignite(int iEntity) {
    AcceptEntityInput(iEntity, "ignite");
}