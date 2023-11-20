#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <l4d2util>

public Plugin myinfo = {
    name        = "Skip Tank Taunt",
    author      = "sorallll",
    description = "Skip the tank's taunt animation and speed up the obstacle animation.",
    version     = "1.0.5",
    url         = "https://forums.alliedmods.net/showthread.php?t=336707"
}

public void OnClientPutInServer(int iClient) {
    AnimHookEnable(iClient, OnTankAnimPre);
}

/**
* From left4dhooks.l4d2.cfg
* ACT_TERROR_HULK_VICTORY       792
* ACT_TERROR_HULK_VICTORY_B     793
* ACT_TERROR_RAGE_AT_ENEMY      794
* ACT_TERROR_RAGE_AT_KNOCKDOWN  795
**/
Action OnTankAnimPre(int iClient, int &iAnim) {
    if (GetClientTeam(iClient) != L4D2Team_Infected)    return Plugin_Continue;
    if (!IsPlayerAlive(iClient))                        return Plugin_Continue;
    if (GetInfectedClass(iClient) != L4D2Infected_Tank) return Plugin_Continue;
    if (IsInfectedGhost(iClient))                       return Plugin_Continue;
    if (L4D2_ACT_TERROR_HULK_VICTORY <= iAnim <= L4D2_ACT_TERROR_RAGE_AT_KNOCKDOWN) {
        iAnim = 0;
        SetEntPropFloat(iClient, Prop_Send, "m_flCycle", 1000.0);
        return Plugin_Changed;
    }
    return Plugin_Continue;
}