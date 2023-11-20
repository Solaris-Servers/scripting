#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <left4dhooks>

public Plugin myinfo = {
    name        = "L4D2 No Post-Jockeyed Shoves",
    author      = "Sir",
    description = "L4D2 has a nasty bug which Survivors would exploit and this fixes that. (Holding out a melee and spamming shove, even if the jockey was behind you, would self-clear yourself after the Jockey actually landed.",
    version     = "1.0",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public Action L4D_OnShovedBySurvivor(int iShover, int iShovee, const float fVec[3]) {
    if (!IsSurvivor(iShover)) return Plugin_Continue;
    if (!IsJockey(iShovee))   return Plugin_Continue;
    if (!IsJockeyed(iShover)) return Plugin_Continue;
    return Plugin_Handled;
}

public Action L4D2_OnEntityShoved(int iShover, int iShovee, int iWeapon, float fVec[3], bool bIsHunterDeadstop) {
    if (!IsSurvivor(iShover)) return Plugin_Continue;
    if (!IsJockey(iShovee))   return Plugin_Continue;
    if (!IsJockeyed(iShover)) return Plugin_Continue;
    return Plugin_Handled;
}

// check if client is valid
stock bool IsValidClient(int iClient) {
    if (iClient <= 0)         return false;
    if (iClient > MaxClients) return false;
    return IsClientInGame(iClient);
}

// check if client is on survivor team
stock bool IsSurvivor(int iClient) {
    return IsValidClient(iClient) && GetClientTeam(iClient) == 2;
}

// check if client is on infected team
stock bool IsInfected(int iClient) {
    return IsValidClient(iClient) && GetClientTeam(iClient) == 3;
}

// check if client is a jockey
stock bool IsJockey(int iClient) {
    if (!IsInfected(iClient))                                 return false;
    if (!IsPlayerAlive(iClient))                              return false;
    if (GetEntProp(iClient, Prop_Send, "m_zombieClass") != 5) return false;
    return true;
}

stock bool IsJockeyed(int iClient) {
    return GetEntPropEnt(iClient, Prop_Send, "m_jockeyAttacker") > 0;
}