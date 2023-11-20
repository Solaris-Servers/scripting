#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <colors>
#include <sdktools>

#include <solaris/team_manager>
#include <solaris/stocks>

#define TEAM_SPECTATORS 1
#define TEAM_SURVIVORS  2
#define TEAM_INFECTED   3

bool   g_bIsPvP;
bool   g_bIsSurvival;

bool   g_bLoadLate;
bool   g_bIsRoundLive;

bool   g_bTempBlock [MAXPLAYERS + 1];
float  g_fButtonTime[MAXPLAYERS + 1];

ConVar g_cvSpecTime;
float  g_fSpecTime;

ConVar g_cvGameMode;

public Plugin myinfo = {
    name        = "[L4D & L4D2] Simple AFK Manager VS",
    author      = "raziEiL [disawar1]",
    description = "Players constantly take slot on your server? Plugin take care of them",
    version     = "1.2",
    url         = "http://steamcommunity.com/id/raziEiL"
}

public void OnPluginStart() {
    g_cvSpecTime = CreateConVar(
    "sam_vs_spec_time", "45.0", "Time before idle player will be moved to spectator in seconds",
    FCVAR_NONE, true, 10.0, false, 0.0);
    g_fSpecTime = g_cvSpecTime.FloatValue;
    g_cvSpecTime.AddChangeHook(OnSpecTimeChange);

    g_cvGameMode = FindConVar("mp_gamemode");
    g_cvGameMode.AddChangeHook(OnGameModeChange);

    HookEvent("round_start",           Event_RoundStart);
    HookEvent("round_end",             Event_RoundEnd);
    HookEvent("map_transition",        Event_RoundEnd);
    HookEvent("finale_win",            Event_RoundEnd);
    HookEvent("player_left_safe_area", Event_PlayerLeftSafeArea);
    HookEvent("survival_round_start",  Event_SurvivalRoundStart);
    HookEvent("player_team",           Event_PlayerTeam);
    HookEvent("player_say",            Event_PlayerSay);

    CreateTimer(5.0, Timer_CheckIdles, _, TIMER_REPEAT);

    if (g_bLoadLate) {
        for (int i = 1; i <= MaxClients; i++) {
            if (!IsClientInGame(i))                  continue;
            if (IsFakeClient(i))                     continue;
            if (GetClientTeam(i) <= TEAM_SPECTATORS) continue;
            SetGameTime(i);
        }
    }
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bIsRoundLive = false;
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i)) continue;
        if (IsFakeClient(i))    continue;
        g_fButtonTime[i] = GetGameTime();
    }
}

void Event_RoundEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bIsRoundLive = false;
}

void Event_PlayerLeftSafeArea(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (g_bIsSurvival) return;
    g_bIsRoundLive = true;
}

void Event_SurvivalRoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bIsRoundLive = true;
}

void Event_PlayerTeam(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (eEvent.GetBool("disconnect")) return;
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)                             return;
    if (IsFakeClient(iClient))                    return; 
    if (eEvent.GetInt("team") <= TEAM_SPECTATORS) return;
    SetGameTime(iClient);
}

void Event_PlayerSay(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)                              return;
    if (GetClientTeam(iClient) <= TEAM_SPECTATORS) return;
    SetGameTime(iClient);
}

public void OnConfigsExecuted() {
    g_bIsPvP      = SDK_HasPlayerInfected();
    g_bIsSurvival = SDK_IsSurvival();
}

void OnGameModeChange(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bIsPvP      = SDK_HasPlayerInfected();
    g_bIsSurvival = SDK_IsSurvival();
}

void OnSpecTimeChange(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fSpecTime = g_cvSpecTime.FloatValue;
}

public void OnClientPutInServer(int iClient) {
    g_bTempBlock [iClient] = false;
    g_fButtonTime[iClient] = 0.0;
}

public void OnClientDisconnect(int iClient) {
    g_bTempBlock [iClient] = false;
    g_fButtonTime[iClient] = 0.0;
}

public void OnPlayerRunCmdPost(int iClient, int iButtons) {
    if (iClient <= 0)                              return;
    if (iClient > MaxClients)                      return;
    if (!IsClientInGame(iClient))                  return;
    if (IsFakeClient(iClient))                     return;
    if (!iButtons)                                 return;
    if (g_bTempBlock[iClient])                     return;
    if (GetClientTeam(iClient) <= TEAM_SPECTATORS) return;
    if (!IsPlayerAlive(iClient))                   return;
    SAM_PluseTime(iClient);
}

void SAM_PluseTime(int iClient) {
    SetGameTime(iClient);
    g_bTempBlock[iClient] = true;
    CreateTimer(5.0, Timer_Unlock, iClient);
}

Action Timer_Unlock(Handle hTimer, any iClient) {
    g_bTempBlock[iClient] = false;
    return Plugin_Stop;
}

Action Timer_CheckIdles(Handle hTimer) {
    if (!g_bIsRoundLive) return Plugin_Continue;
    static int   iTeam;
    static float fTheTime;
    fTheTime = GetGameTime();
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i)) continue;
        if (IsFakeClient(i))    continue;
        iTeam = GetClientTeam(i);
        if (!g_fButtonTime[i] || (fTheTime - g_fButtonTime[i]) <= g_fSpecTime)
            continue;
        if (iTeam <= TEAM_SPECTATORS || !IsPlayerAlive(i))
            continue;
        if (IsPlayerBussy(i)) {
            g_fButtonTime[i] = fTheTime;
            continue;
        }
        if (g_bIsPvP) {
            CPrintToChatAllEx(i, "{green}[{default}AFK Manager{green}] {teamcolor}%N{default} was moved to Spectator team (AFK)", i);
            ChangeClientTeam(i, TEAM_SPECTATORS);
            TM_SetPlayerTeam(i, TEAM_SPECTATORS);
        } else if (iTeam == TEAM_SURVIVORS) {
            CPrintToChatAllEx(i, "{green}[{default}AFK Manager{green}] {teamcolor}%N{default} is now idle (AFK)", i);
            SDK_GoAwayFromKeyboard(i);
        }
    }
    return Plugin_Continue;
}

void SetGameTime(int iClient) {
    g_fButtonTime[iClient] = GetGameTime();
}

bool IsPlayerBussy(int iClient) {
    return !IsPlayerAlive(iClient)                         ||
    IsSurvivorBussy(iClient)                               ||
    GetEntProp(iClient, Prop_Send, "m_isIncapacitated")    ||
    GetEntProp(iClient, Prop_Send, "m_isHangingFromLedge") ||
    GetEntProp(iClient, Prop_Send, "m_iHealth") == 1       ||
    IsInfectedBussy(iClient);
}

bool IsSurvivorBussy(int iClient) {
    return GetClientTeam(iClient) == TEAM_SURVIVORS &&
    GetEntProp(iClient, Prop_Send, "m_tongueOwner")    > 0 ||
    GetEntProp(iClient, Prop_Send, "m_pounceAttacker") > 0 ||
    GetEntProp(iClient, Prop_Send, "m_pummelAttacker") > 0 ||
    GetEntProp(iClient, Prop_Send, "m_jockeyAttacker") > 0;
}

bool IsInfectedBussy(int iClient) {
    return GetClientTeam(iClient) == TEAM_INFECTED &&
    GetEntProp(iClient, Prop_Send, "m_tongueVictim") > 0 ||
    GetEntProp(iClient, Prop_Send, "m_pounceVictim") > 0 ||
    GetEntProp(iClient, Prop_Send, "m_pummelVictim") > 0 ||
    GetEntProp(iClient, Prop_Send, "m_jockeyVictim") > 0;
}