#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

public Plugin myinfo = {
    name        = "L4D2 Tank & Charger M2 Fix",
    description = "Stops Shoves slowing the Tank and Charger Down",
    author      = "Sir, Visor",
    version     = "1.0",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};
 
public Action L4D_OnShovedBySurvivor(int iShover, int iShovee, const float fVec[3]) {
    if (!IsSurvivor(iShover))      return Plugin_Continue;
    if (!IsInfected(iShovee))      return Plugin_Continue;
    if (!IsTankOrCharger(iShovee)) return Plugin_Continue;
    return Plugin_Handled;
}

public Action L4D2_OnEntityShoved(int iShover, int iShovee, int iWeapon, float fVec[3], bool bIsHunterDeadstop) {
    if (!IsSurvivor(iShover))      return Plugin_Continue;
    if (!IsInfected(iShovee))      return Plugin_Continue;
    if (!IsTankOrCharger(iShovee)) return Plugin_Continue;
    return Plugin_Handled;
}

stock bool IsValidClient(int iClient) {
    if (iClient <= 0)         return false;
    if (iClient > MaxClients) return false;
    return IsClientInGame(iClient);
}

stock bool IsSurvivor(int iClient) {
    return IsValidClient(iClient) && GetClientTeam(iClient) == 2;
}

stock bool IsInfected(int iClient) {
    return IsValidClient(iClient) && GetClientTeam(iClient) == 3;
}

stock bool IsTankOrCharger(int iClient) {
    if (!IsPlayerAlive(iClient)) return false;
    int iZombieClass = GetEntProp(iClient, Prop_Send, "m_zombieClass");
    return (iZombieClass == 6 || iZombieClass == 8);
}