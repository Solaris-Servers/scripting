#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <l4d2util/constants>

ConVar g_cvSurvivorLimit;
int    g_iSurvivorLimit;

public Plugin myinfo = {
    name        = "Player Management Plugin",
    author      = "CanadaRox",
    description = "Player management! Swap players/teams and spectate!",
    version     = "7.0",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework/"
};

public void OnPluginStart() {
    RegAdminCmd("sm_fixbots",
    Cmd_FixBots, ADMFLAG_BAN,
    "sm_fixbots - Spawns survivor bots to match survivor_limit");

    g_cvSurvivorLimit = FindConVar("survivor_limit");
    g_iSurvivorLimit  = g_cvSurvivorLimit.IntValue;
    g_cvSurvivorLimit.AddChangeHook(ConVarChanged_SurvivorLimit);
}

public void OnMapStart() {
    HookEntityOutput("info_director", "OnGameplayStart", OnGameplayStart);
    IsMapLoaded(true, true);
}

public void OnMapEnd() {
    IsMapLoaded(true, false);
}

void OnGameplayStart(const char[] szOutput, int iCaller, int iActivator, float fDelay) {
    if (GetHumanCount()) RequestFrame(FixBotCount);
}

Action Cmd_FixBots(int iClient, int iArgs) {
    if (!IsMapLoaded())
        return Plugin_Handled;

    if (!GetHumanCount())
        return Plugin_Handled;

    RequestFrame(FixBotCount);
    return Plugin_Handled;
}

void ConVarChanged_SurvivorLimit(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    if (strcmp(szOldVal, szNewVal) == 0)
        return;

    g_iSurvivorLimit = g_cvSurvivorLimit.IntValue;

    if (!IsMapLoaded())
        return;

    if (!GetHumanCount())
        return;

    RequestFrame(FixBotCount);
}

void FixBotCount() {
    int iSurvivorCount = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (GetClientTeam(i) != L4D2Team_Survivor)
            continue;

        iSurvivorCount++;
    }

    if (iSurvivorCount < g_iSurvivorLimit) {
        int iBot;
        while (iSurvivorCount < g_iSurvivorLimit) {
            iSurvivorCount++;
            iBot = CreateFakeClient("k9Q6CK42");
            if (iBot != 0) {
                ChangeClientTeam(iBot, L4D2Team_Survivor);
                RequestFrame(OnFrame_KickBot, GetClientUserId(iBot));
            }
        }
    }

    if (iSurvivorCount > g_iSurvivorLimit) {
        for (int i = 1; i <= MaxClients && iSurvivorCount > g_iSurvivorLimit; i++) {
            if (!IsClientInGame(i))
                continue;

            if (!IsFakeClient(i))
                continue;

            if (GetClientTeam(i) != L4D2Team_Survivor)
                continue;

            iSurvivorCount--;
            KickClient(i);
        }
    }
}

void OnFrame_KickBot(int iUserId) {
    int iClient = GetClientOfUserId(iUserId);
    if (iClient > 0) KickClient(iClient);
}

stock int GetHumanCount() {
    int iHumans = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        iHumans++;
    }

    return iHumans;
}

bool IsMapLoaded(bool bSet = false, bool bVal = false) {
    static bool bLoaded;

    if (bSet)
        bLoaded = bVal;

    return bLoaded;
}