#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <collisionhook>

public Plugin myinfo = {
    name        = "L4D2 Jockeyed Survivor Ladder Fix",
    author      = "Visor",
    description = "Fixes jockeyed Survivors slowly sliding down the ladders",
    version     = "1.1",
    url         = "https://github.com/Attano/L4D2-Competitive-Framework"
};

public Action CH_PassFilter(int iTouch, int iPass, bool &bResult) {
    if ((IsJockeyedSurvivor(iTouch) || IsJockeyedSurvivor(iPass)) && (IsLadder(iTouch) || IsLadder(iPass))) {
        bResult = false;
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

bool IsLadder(int iEnt) {
    if (iEnt > 0 && IsValidEdict(iEnt) && IsValidEntity(iEnt)) {
        char szClsName[64];
        GetEdictClassname(iEnt, szClsName, sizeof(szClsName));
        return (StrContains(szClsName, "ladder") > 0);
    }
    return false;
}

bool IsJockeyedSurvivor(int iClient) {
    return (iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient) && GetClientTeam(iClient) == 2 && IsJockeyed(iClient));
}

bool IsJockey(int iClient) {
    return (iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient) && GetClientTeam(iClient) == 3 && GetEntProp(iClient, Prop_Send, "m_zombieClass") == 5);
}

bool IsJockeyed(int iClient) {
    return IsJockey(GetEntDataEnt2(iClient, FindSendPropInfo("CTerrorPlayer", "m_jockeyAttacker")));
}