#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <colors>
#include <solaris/info>

#define TEAM_NONE       0
#define TEAM_SPECTATORS 1
#define TEAM_SURVIVORS  2
#define TEAM_INFECTED   3

GlobalForward
       g_fwdPlayerJoined;

ConVar g_cvJoinPrintEnabled;
bool   g_bJoinPrintEnabled;

ConVar g_cvJoinPrintTimer;
float  g_fJoinPrintTimer;

ConVar g_cvWelcomePrintEnabled;
bool   g_bWelcomePrintEnabled;

ConVar g_cvWelcomePrintTimer;
float  g_fWelcomePrintTimer;

public Plugin myinfo = {
    name        = "[Solaris] Connect Announce",
    author      = "0x0c, elias",
    description = "Solaris Servers Connect Announce",
    version     = "1.0.0",
    url         = "https://solaris-servers.ru/"
};

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    g_fwdPlayerJoined = new GlobalForward(
    "OnPlayerJoined", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Float);

    RegPluginLibrary("solaris_cannounce");
    return APLRes_Success;
}

public void OnPluginStart() {
    g_cvJoinPrintEnabled = CreateConVar(
    "l4d2_join_message_enabled", "1", "Whether or not to show join player messages.",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bJoinPrintEnabled = g_cvJoinPrintEnabled.BoolValue;
    g_cvJoinPrintEnabled.AddChangeHook(CvChg_JoinPrintEnabled);

    g_cvJoinPrintTimer = CreateConVar(
    "l4d2_join_message_timer", "2.0", "Time(sec) before join player message will be sent.",
    FCVAR_NONE, true, 0.1, false, 0.0);
    g_fJoinPrintTimer = g_cvJoinPrintTimer.FloatValue;
    g_cvJoinPrintTimer.AddChangeHook(CvChg_JoinPrintTimer);

    g_cvWelcomePrintEnabled = CreateConVar(
    "l4d2_welcome_message_enabled", "1", "Whether or not to welcome a player.",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bWelcomePrintEnabled = g_cvWelcomePrintEnabled.BoolValue;
    g_cvWelcomePrintEnabled.AddChangeHook(CvChg_WelcomePrintEnabled);

    g_cvWelcomePrintTimer = CreateConVar(
    "l4d2_welcome_message_timer", "10.0", "Time(sec) before welcome message will be sent to a joined player.",
    FCVAR_NONE, true, 0.1, false, 0.0);
    g_fWelcomePrintTimer = g_cvWelcomePrintTimer.FloatValue;
    g_cvWelcomePrintTimer.AddChangeHook(CvChg_WelcomePrintTimer);

    HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
    HookEvent("player_team",       Event_PlayerTeam);
}

void CvChg_JoinPrintEnabled(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bJoinPrintEnabled = g_cvJoinPrintEnabled.BoolValue;
}

void CvChg_JoinPrintTimer(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fJoinPrintTimer = g_cvJoinPrintTimer.FloatValue;
}

void CvChg_WelcomePrintEnabled(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bWelcomePrintEnabled = g_cvWelcomePrintEnabled.BoolValue;
}

void CvChg_WelcomePrintTimer(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fWelcomePrintTimer = g_cvWelcomePrintTimer.FloatValue;
}

public void OnClientConnected(int iClient) {
    if (!g_bJoinPrintEnabled)
        return;

    if (IsFakeClient(iClient))
        return;

    CPrintToChatAll("Player {olive}%N{default} is joining the game.", iClient);
}

public void OnClientPutInServer(int iClient) {
    if (IsFakeClient(iClient))
        return;

    IsPlayerJoiningTheGame(iClient, true, true);
}

void Event_PlayerTeam(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (eEvent.GetBool("disconnect"))
        return;

    int iUserId = eEvent.GetInt("userid");
    int iClient = GetClientOfUserId(iUserId);

    if (iClient <= 0)
        return;

    if (!IsClientInGame(iClient))
        return;

    if (IsFakeClient(iClient))
        return;

    if (!IsPlayerJoiningTheGame(iClient))
        return;

    IsPlayerJoiningTheGame(iClient, true, false);
    RequestFrame(OnClientRealGameJoining, iUserId);
}

void OnClientRealGameJoining(int iUserId) {
    int iClient = GetClientOfUserId(iUserId);
    if (iClient <= 0)
        return;

    static int iRank;
    iRank = Solaris_GetRank(iClient);

    static char szRank[16];
    szRank = "";

    if (iRank > 0)
        FormatEx(szRank, sizeof(szRank), "#%i ", iRank);

    static char szCountry[3];
    Solaris_GetCountry(iClient, szCountry, sizeof(szCountry));

    static char szCity[45];
    Solaris_GetCity(iClient, szCity, sizeof(szCity));

    static char szLocation[64];
    if (strlen(szCountry) > 0 && strlen(szCity) > 0)
        FormatEx(szLocation, sizeof(szLocation), " {green}[{default}%s, %s{green}]{default}", szCity, szCountry);
    else if (strlen(szCountry) > 0)
        FormatEx(szLocation, sizeof(szLocation), " {green}[{default}%s{green}]{default}", szCountry);

    static float fHours;
    fHours = Solaris_GetHours(iClient);

    DataPack dp = new DataPack();
    dp.WriteCell(iUserId);
    dp.WriteString(szRank);
    dp.WriteString(szLocation);
    dp.WriteFloat(fHours);

    if (g_bJoinPrintEnabled)
        CreateTimer(g_fJoinPrintTimer, Timer_Joined, dp, TIMER_FLAG_NO_MAPCHANGE);

    if (g_bWelcomePrintEnabled)
        CreateTimer(g_fWelcomePrintTimer, Timer_Welcome, iUserId, TIMER_FLAG_NO_MAPCHANGE);

    Call_StartForward(g_fwdPlayerJoined);
    Call_PushCell(iClient);
    Call_PushCell(iRank);
    Call_PushString(szLocation);
    Call_PushFloat(fHours);
    Call_Finish();
}

Action Timer_Joined(Handle hTimer, DataPack dp) {
    dp.Reset();

    static int iClient;
    iClient = GetClientOfUserId(dp.ReadCell());

    static char szRank[64];
    dp.ReadString(szRank, sizeof(szRank));

    static char szLocation[64];
    dp.ReadString(szLocation, sizeof(szLocation));

    static float fHours;
    fHours = dp.ReadFloat();

    delete dp;

    if (iClient <= 0)
        return Plugin_Stop;

    static char szColor[8];
    GetPlayerColor(iClient, szColor, sizeof(szColor));

    CPrintToChatAll("%sPlayer %s%N{default}%s has joined the game {green}({default}%.01fh{green}){default}.", szRank, szColor, iClient, szLocation, fHours);
    return Plugin_Stop;
}

Action Timer_Welcome(Handle hTimer, any iUserId) {
    Print_WelcomeMessage(iUserId);
    return Plugin_Stop;
}

void Print_WelcomeMessage(int iUserId) {
    int iClient = GetClientOfUserId(iUserId);
    if (iClient <= 0)
        return;

    if (!IsClientInGame(iClient))
        return;

    if (IsPlayerWelcomed(iClient, false, iUserId))
        return;

    static char szServerName[64];
    FindConVar("hostname").GetString(szServerName, sizeof(szServerName));

    IsPlayerWelcomed(iClient, true, iUserId);
    CPrintToChatEx(iClient, iClient, "{teamcolor} ");
    CPrintToChatEx(iClient, iClient, " {green}»{default} Hello and welcome {teamcolor}%N{default}!", iClient);
    CPrintToChatEx(iClient, iClient, " {green}»{default} You are playing on {teamcolor}%s{default}", szServerName);
    CPrintToChatEx(iClient, iClient, " {green}»{default} We have competitive configs {teamcolor}(ZoneMod, ProMod, etc.)");
    CPrintToChatEx(iClient, iClient, " {green}»{default} Use {teamcolor}!match{default} for selecting a config. For unloading - {teamcolor}!rmatch");
    CPrintToChatEx(iClient, iClient, " {green}»{default} {teamcolor}Good luck{default} and {teamcolor}Have fun{default}!");
    CPrintToChatEx(iClient, iClient, "{teamcolor} ");
}

void Event_PlayerDisconnect(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!g_bJoinPrintEnabled)
        return;

    eEvent.BroadcastDisabled = true;

    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)
        return;

    if (IsFakeClient(iClient))
        return;

    static char szReason[256];
    eEvent.GetString("reason", szReason, sizeof(szReason));

    if (strcmp(szReason, "Disconnect by user.") == 0)
        szReason = "";

    static char szColor[8];
    GetPlayerColor(iClient, szColor, sizeof(szColor));

    CPrintToChatAll("Player %s%N{default} has left the game. %s", szColor, iClient, szReason);
}

void GetPlayerColor(int iClient, char[] szBuffer, int iLen) {
    static const char szColor[][] = {
        "{olive}", // 0 TEAM_NONE
        "{green}", // 1 TEAM_SPECTATORS
        "{blue}",  // 2 TEAM_SURVIVORS
        "{red}"    // 3 TEAM_INFECTED
    };

    static int iIdx;
    iIdx = 0;

    if (IsClientInGame(iClient) && GetClientTeam(iClient) > TEAM_SPECTATORS)
        iIdx = GetClientTeam(iClient);

    strcopy(szBuffer, iLen, szColor[iIdx]);
}

bool IsPlayerJoiningTheGame(int iClient, bool bSet = false, bool bVal = false) {
    static bool bJoining[MAXPLAYERS + 1];

    if (bSet)
        bJoining[iClient] = bVal;

    return bJoining[iClient];
}

bool IsPlayerWelcomed(int iClient, bool bSet = false, int iUserId = 0) {
    static int iPlayerId[MAXPLAYERS + 1];

    if (bSet)
        iPlayerId[iClient] = iUserId;

    return iPlayerId[iClient] == iUserId;
}