#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <collisionhook>

ConVar g_cvRockFix;
bool   g_bRockFix;

ConVar g_cvPullThrough;
bool   g_bPullThrough;

ConVar g_cvRockThroughIncap;
bool   g_bRockThroughIncap;

bool   g_bIsPulled[MAXPLAYERS + 1];

public Plugin myinfo = {
    name        = "L4D2 Collision Adjustments",
    author      = "Sir",
    version     = "1.0",
    description = "Allows messing with pesky Collisions in Left 4 Dead 2",
    url         = "https://github.com/SirPlease/SirCoding"
};

public void OnPluginStart() {
    g_cvRockFix = CreateConVar(
    "collision_tankrock_common", "1",
    "Will Rocks go through Common Infected (and also kill them) instead of possibly getting stuck on them?",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bRockFix = g_cvRockFix.BoolValue;
    g_cvRockFix.AddChangeHook(ConVarChanged_RockFix);

    g_cvPullThrough = CreateConVar(
    "collision_smoker_common", "1",
    "Will Pulled Survivors go through Common Infected?",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bPullThrough = g_cvPullThrough.BoolValue;
    g_cvPullThrough.AddChangeHook(ConVarChanged_PullThrough);

    g_cvRockThroughIncap = CreateConVar(
    "collision_tankrock_incap", "1",
    "Will Rocks go through Incapacitated Survivors? (Won't go through new incaps caused by the Rock",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bRockThroughIncap = g_cvRockThroughIncap.BoolValue;
    g_cvRockThroughIncap.AddChangeHook(ConVarChanged_RockThroughIncap);

    HookEvent("round_start",        Event_RoundStart);
    HookEvent("round_end",          Event_RoundEnd);
    HookEvent("player_bot_replace", Event_PlayerBotReplace);
    HookEvent("bot_player_replace", Event_BotPlayerReplace);
    HookEvent("tongue_grab",        Event_TongueGrab);
    HookEvent("tongue_release",     Event_TongueRelease);
}

void ConVarChanged_RockFix(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bRockFix = g_cvRockFix.BoolValue;
}

void ConVarChanged_PullThrough(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bPullThrough = g_cvPullThrough.BoolValue;
}

void ConVarChanged_RockThroughIncap(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bRockThroughIncap = g_cvRockThroughIncap.BoolValue;
}

public Action CH_PassFilter(int iTouch, int iPass, bool &bResult) {
    if (!IsValidEdict(iTouch) || !IsValidEdict(iPass))
        return Plugin_Continue;

    static int  iLength = 20;
    static char szClsName[2][20];
    GetEdictClassname(iTouch, szClsName[0], iLength);
    GetEdictClassname(iPass,  szClsName[1], iLength);

    if (strcmp(szClsName[0], "infected") == 0) {
        if (g_bRockFix && strcmp(szClsName[1], "tank_rock") == 0) {
            bResult = false;
            return Plugin_Handled;
        }

        if (g_bPullThrough && IsSurvivor(iPass) && g_bIsPulled[iPass]) {
            bResult = false;
            return Plugin_Handled;
        }
    } else if (strcmp(szClsName[1], "infected") == 0) {
        if (g_bRockFix && strcmp(szClsName[0], "tank_rock") == 0) {
            bResult = false;
            return Plugin_Handled;
        }

        if (g_bPullThrough && IsSurvivor(iTouch) && g_bIsPulled[iTouch]) {
            bResult = false;
            return Plugin_Handled;
        }
    } else if (strcmp(szClsName[0], "tank_rock") == 0) {
        if (g_bRockThroughIncap && IsIncapacitated(iPass)) {
            bResult = false;
            return Plugin_Handled;
        }
    } else if (strcmp(szClsName[1], "tank_rock") == 0) {
        if (g_bRockThroughIncap && IsIncapacitated(iTouch)) {
            bResult = false;
            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    for (int i = 1; i <= MaxClients; i++) {
        g_bIsPulled[i] = false;
    }
}

void Event_RoundEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    for (int i = 1; i <= MaxClients; i++) {
        g_bIsPulled[i] = false;
    }
}

void Event_PlayerBotReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    HandlePlayerReplace(GetClientOfUserId(eEvent.GetInt("bot")), GetClientOfUserId(eEvent.GetInt("player")));
}

void Event_BotPlayerReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    HandlePlayerReplace(GetClientOfUserId(eEvent.GetInt("player")), GetClientOfUserId(eEvent.GetInt("bot")));
}

void HandlePlayerReplace(int iReplacer, int iReplacee) {
    g_bIsPulled[iReplacer] = g_bIsPulled[iReplacee];
    g_bIsPulled[iReplacee] = false;
}

void Event_TongueGrab(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iVictim = GetClientOfUserId(eEvent.GetInt("victim"));
    g_bIsPulled[iVictim] = true;
}

void Event_TongueRelease(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iVictim = GetClientOfUserId(eEvent.GetInt("victim"));
    g_bIsPulled[iVictim] = false;
}

bool IsValidClient(int iClient) {
    if (iClient <= 0 || iClient > MaxClients)
        return false;
    return IsClientInGame(iClient);
}

bool IsSurvivor(int iClient) {
    return IsValidClient(iClient) && GetClientTeam(iClient) == 2;
}

bool IsIncapacitated(int iClient) {
    if (!IsSurvivor(iClient))
        return false;
    if (!IsPlayerAlive(iClient))
        return false;
    if (GetEntProp(iClient, Prop_Send, "m_isIncapacitated") > 0)
        return true;
    return false;
}