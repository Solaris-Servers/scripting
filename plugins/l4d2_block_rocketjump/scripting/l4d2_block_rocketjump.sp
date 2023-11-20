#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define MAXENTITY 2048

bool g_bRocketJumpExploit[MAXENTITY + 1];
bool g_bStepOnEntitiy   [MAXPLAYERS + 1];

char g_szClsName[][] = {
    "infected",
    "tank_rock",
    "vomitjar_projectile",
    "molotov_projectile",
    "pipe_bomb_projectile",
    "grenade_launcher_projectile",
    "spitter_projectile",
    "witch"
};

public Plugin myinfo = {
    name        = "Block Rocket Jump Exploit",
    author      = "DJ_WEST, HarryPotter",
    description = "Block rocket jump exploit (with grenade launcher/vomitjar/pipebomb/molotov/common/spit/rock)",
    version     = "1.4",
    url         = "https://forums.alliedmods.net/showthread.php?t=122371"
}

public void OnEntityCreated(int iEnt, const char[] szClsName) {
    if (!IsValidEntityIndex(iEnt)) return;
    switch (szClsName[0]) {
        case 'i', 't', 'v', 'm', 'p', 'g', 's', 'w': {
            if (!IsItCase(szClsName)) return;
            g_bRocketJumpExploit[iEnt] = true;
        }
    }
}

public void OnEntityDestroyed(int iEnt) {
    if (!IsValidEntityIndex(iEnt)) return;
    g_bRocketJumpExploit[iEnt] = false;
}

public void OnPlayerRunCmdPost(int iClient, int iButtons) {
    if (!IsClientInGame(iClient))    return;
    if (GetClientTeam(iClient) != 2) return; 
    if (!IsPlayerAlive(iClient))     return;
    int iEnt = GetEntPropEnt(iClient, Prop_Data, "m_hGroundEntity");
    if (iEnt > MaxClients && g_bRocketJumpExploit[iEnt]) {
        g_bStepOnEntitiy[iClient] = true;
        return;
    }
    if (g_bStepOnEntitiy[iClient]) {
        float flVel[3];
        GetEntPropVector(iClient, Prop_Data, "m_vecAbsVelocity", flVel);
        flVel[2] = 0.0;
        TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, flVel);
    }
    g_bStepOnEntitiy[iClient] = false;
}

stock bool IsItCase(const char[] szClsName) {
    for (int i = 0; i < sizeof(g_szClsName); i++) {
        if (strcmp(g_szClsName[i], szClsName) != 0) continue;
        return true;
    }
    return false;
}

stock bool IsValidEntityIndex(int iEnt) {
    return (MaxClients + 1 <= iEnt <= GetMaxEntities());
}