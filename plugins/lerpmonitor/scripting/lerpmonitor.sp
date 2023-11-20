#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <readyup>
#include <solaris/team_manager>
#include <solaris/info>

#define ARRAY_STEAMID 0
#define ARRAY_LERP    1
#define ARRAY_CHANGES 2
#define ARRAY_COUNT   3

#define TEAM_SPECTATORS 1
#define TEAM_SURVIVORS  2
#define TEAM_INFECTED   3

ArrayList
       g_arrLerps;

ConVar g_cvAllowedLerpChanges;
int    g_iAllowedLerpChanges;

ConVar g_cvMinLerp;
float  g_fMinLerp;

ConVar g_cvMaxLerp;
float  g_fMaxLerp;

public Plugin myinfo = {
    name        = "Lerp Monitor",
    author      = "ProdigySim, Die Teetasse, vintik",
    description = "Monitors And Tracks Every Player's Lerp.",
    version     = "1.0",
    url         = "https://bitbucket.org/vintik/various-plugins"
};

public void OnPluginStart() {
    g_cvAllowedLerpChanges = CreateConVar(
    "sm_allowed_lerp_changes", "5",
    "Allowed number of lerp changes for a half",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_iAllowedLerpChanges = g_cvAllowedLerpChanges.IntValue;
    g_cvAllowedLerpChanges.AddChangeHook(CvChg_AllowedLerpChanges);

    g_cvMinLerp = CreateConVar(
    "sm_min_lerp", "0",
    "Minimum Value Of Lerp",
    FCVAR_NONE, true, 0.0, true, 500.0);
    g_fMinLerp = g_cvMinLerp.FloatValue;
    g_cvMinLerp.AddChangeHook(CvChg_MinLerp);

    g_cvMaxLerp = CreateConVar(
    "sm_max_lerp", "100",
    "Maximum Value Of Lerp",
    FCVAR_NONE, true, 0.0, true, 500.0);
    g_fMaxLerp = g_cvMaxLerp.FloatValue;
    g_cvMaxLerp.AddChangeHook(CvChg_MaxLerp);

    HookEvent("round_start", Event_RoundStart);
    HookEvent("player_team", Event_PlayerTeam);

    g_arrLerps = new ArrayList(ByteCountToCells(32));

    if (!IsInCaptainsMode()) {
        for (int i = 1; i <= MaxClients; i++) {
            if (!IsClientInGame(i))
                continue;

            if (IsFakeClient(i))
                continue;

            ProcessPlayerLerp(i);
        }
    }
}

void CvChg_AllowedLerpChanges(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iAllowedLerpChanges = g_cvAllowedLerpChanges.IntValue;
}

void CvChg_MinLerp(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fMinLerp = g_cvMinLerp.FloatValue;
}

void CvChg_MaxLerp(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fMaxLerp = g_cvMaxLerp.FloatValue;
}

public void OnMixStarted() {
    IsInCaptainsMode(true, true);
}

public void OnMixStopped() {
    IsInCaptainsMode(true, false);

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        ProcessPlayerLerp(i);
    }
}

public void OnMapEnd() {
    g_arrLerps.Clear();
}

public void OnClientSettingsChanged(int iClient) {
    if (IsInCaptainsMode())
        return;

    if (!IsClientInGame(iClient))
        return;

    if (IsFakeClient(iClient))
        return;

    ProcessPlayerLerp(iClient);
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    for (int i = 0; i < (g_arrLerps.Length / ARRAY_COUNT); i++) {
        g_arrLerps.Set((i * ARRAY_COUNT) + ARRAY_CHANGES, 0);
    }
}

void Event_PlayerTeam(Event eEvent, char[] szName, bool bDontBroadcast) {
    if (eEvent.GetInt("team") == TEAM_SPECTATORS)
        return;

    int iUserId = eEvent.GetInt("userid");
    if (GetClientOfUserId(iUserId) <= 0)
        return;

    CreateTimer(0.1, Timer_PlayerTeam, iUserId, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_PlayerTeam(Handle hTimer, int iUserId) {
    int iClient = GetClientOfUserId(iUserId);
    if (iClient <= 0)
        return Plugin_Stop;

    if (IsInCaptainsMode())
        return Plugin_Stop;

    if (!IsClientInGame(iClient))
        return Plugin_Stop;

    if (IsFakeClient(iClient))
        return Plugin_Stop;

    ProcessPlayerLerp(iClient);
    return Plugin_Stop;
}

void ProcessPlayerLerp(int iClient) {
    if (GetClientTeam(iClient) <= TEAM_SPECTATORS)
        return;

    if (TM_IsPlayerRespectating(iClient))
        return;

    float fNewLerpTime = Solaris_GetLerp(iClient);

    if ((FloatCompare(fNewLerpTime, g_fMinLerp) == -1) || (FloatCompare(fNewLerpTime, g_fMaxLerp) == 1)) {
        TM_SetPlayerTeam(iClient, TEAM_SPECTATORS);
        ChangeClientTeam(iClient, TEAM_SPECTATORS);
        CPrintToChatAllEx(iClient, "{green}[{default}Lerp Monitor{green}] {teamcolor}%N{default} was moved to Spectators for lerp {green}%.01f{default}!", iClient, fNewLerpTime);
        CPrintToChat(iClient, "{green}[{default}Lerp Monitor{green}]{default} Illegal lerp value: {blue}%.01f {green}({default}Min: {blue}%.01f{default}, Max: {blue}%.01f{green})", fNewLerpTime, g_fMinLerp, g_fMaxLerp);
        return;
    }

    static char szSteamId[32];
    GetClientAuthId(iClient, AuthId_Steam2, szSteamId, sizeof(szSteamId), true);

    int iIdx = g_arrLerps.FindString(szSteamId);
    if (iIdx == -1) {
        g_arrLerps.PushString(szSteamId);
        g_arrLerps.Push(fNewLerpTime);
        g_arrLerps.Push(0);
        return;
    }

    float fLastValidLerpTime = g_arrLerps.Get(iIdx + ARRAY_LERP);
    if (fLastValidLerpTime == fNewLerpTime)
        return;

    if (IsInReady() || g_iAllowedLerpChanges == 0) {
        CPrintToChatAllEx(iClient, "{green}[{default}Lerp Monitor{green}] {teamcolor}%N{default}'s lerp changed from {olive}%.01f{default} to {olive}%.01f", iClient, fLastValidLerpTime, fNewLerpTime);
        g_arrLerps.Set(iIdx + ARRAY_LERP, fNewLerpTime);
        return;
    }

    int iCount = g_arrLerps.Get(iIdx + ARRAY_CHANGES) + 1;
    CPrintToChatAllEx(iClient, "{green}[{default}Lerp Monitor{green}] {teamcolor}%N{default}'s lerp changed from {olive}%.01f{default} to {olive}%.01f {green}[{olive}%d{default}/{olive}%d{default} changes{green}]", iClient, fLastValidLerpTime, fNewLerpTime, iCount, g_iAllowedLerpChanges);

    if (iCount > g_iAllowedLerpChanges) {
        TM_SetPlayerTeam(iClient, TEAM_SPECTATORS);
        ChangeClientTeam(iClient, TEAM_SPECTATORS);
        CPrintToChat(iClient, "{green}[{default}Lerp Monitor{green}]{default} Illegal lerp change: {blue}%.01f{default}. Set previous value at {blue}%.01f{default} to play!", fNewLerpTime, fLastValidLerpTime);
        return;
    }

    g_arrLerps.Set(iIdx + ARRAY_CHANGES, iCount);
    g_arrLerps.Set(iIdx + ARRAY_LERP, fNewLerpTime);
}

public Action OnJoinTeamCmd(const int iClient, const int iTeam) {
    if (g_iAllowedLerpChanges == 0)
        return Plugin_Continue;

    float fNewLerpTime = Solaris_GetLerp(iClient);

    if ((FloatCompare(fNewLerpTime, g_fMinLerp) == -1) || (FloatCompare(fNewLerpTime, g_fMaxLerp) == 1)) {
        CPrintToChat(iClient, "{green}[{default}Lerp Monitor{green}]{default} Illegal lerp value: {blue}%.01f {green}({default}Min: {blue}%.01f{default}, Max: {blue}%.01f{green})", fNewLerpTime, g_fMinLerp, g_fMaxLerp);
        return Plugin_Handled;
    }

    static char szSteamId[32];
    GetClientAuthId(iClient, AuthId_Steam2, szSteamId, sizeof(szSteamId), true);

    static int iIdx;
    iIdx = g_arrLerps.FindString(szSteamId);

    if (iIdx != -1) {
        float fLastValidLerpTime = g_arrLerps.Get(iIdx + ARRAY_LERP);
        int iCount = g_arrLerps.Get(iIdx + ARRAY_CHANGES) + 1;
        if (iCount > g_iAllowedLerpChanges && fLastValidLerpTime != fNewLerpTime) {
            CPrintToChat(iClient, "{green}[{default}Lerp Monitor{green}]{default} Illegal lerp change: {blue}%.01f{default}. Set previous value at {blue}%.01f{default} to play!", fNewLerpTime, fLastValidLerpTime);
            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}

bool IsInCaptainsMode(bool bSet = false, bool bVal = false) {
    static bool bIsInCaptainsMode;

    if (bSet)
        bIsInCaptainsMode = bVal;

    return bIsInCaptainsMode;
}