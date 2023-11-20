#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <colors>
#include <sdktools>
#include <left4dhooks>
#include <l4d2util>

#include <solaris/votes>
#include <solaris/team_manager>

#undef REQUIRE_PLUGIN
#include <confogl>
#include <witch_and_tankifier>
#include <readyup>
#define REQUIRE_PLUGIN

#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))
#define SIZE_OF_INT 2147483647

// - Some Additions -

bool          g_bDKR;
bool          g_bIsConfoglEnabled;
bool          g_bIsRoundStarted;
bool          g_bIsRoundLive;
bool          g_bIsWitchAndTankifierAvailable;

char          g_szQueuedTankSteamId[64] = "";
char          g_szPassTankSteamId  [64] = "";

ArrayList     g_arrWhosHadTank;
ArrayList     g_arrWhosHadTankPersistent;

ConVar        g_cvTankPercent;
bool          g_bTankPercent;
bool          g_bTankDisable;
int           g_iTankPercent;
float         g_fTankFlow;

ConVar        g_cvWitchPercent;
bool          g_bWitchPercent;
bool          g_bWitchDisable;
int           g_iWitchPercent;
float         g_fWitchFlow;

ConVar        g_cvBossBuffer;
float         g_fBossBuffer;

int           g_iTankFrustration = -1;
float         g_fTankGrace;

GlobalForward g_fwdChooseTank;
GlobalForward g_fwdTankGiven;
GlobalForward g_fwdTankControlReset;

SolarisVote   g_SolarisVoteTankControl;
SolarisVote   g_SolarisVoteBoss;

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    CreateNative("TankControlEQ_SetTank",           Native_SetTank);
    CreateNative("TankControlEQ_GetTank",           Native_GetTank);
    CreateNative("TankControlEQ_GetWhosHadTank",    Native_GetWhosHadTank);
    CreateNative("TankControlEQ_GetWhosNotHadTank", Native_GetWhosNotHadTank);
    CreateNative("TankControlEQ_ClearWhosHadTank",  Native_ClearWhosHadTank);
    CreateNative("TankControlEQ_GetTankPool",       Native_GetTankPool);

    CreateNative("BossPercent_UpdateBossPercents",  Native_UpdateBossPercents);
    CreateNative("BossPercent_TankEnabled",         Native_TankEnabled);
    CreateNative("BossPercent_WitchEnabled",        Native_WitchEnabled);
    CreateNative("BossPercent_TankPercent",         Native_TankPercent);
    CreateNative("BossPercent_WitchPercent",        Native_WitchPercent);
    CreateNative("BossPercent_CurrentPercent",      Native_CurrentPercent);

    g_fwdChooseTank = new GlobalForward(
    "TankControlEQ_OnChooseTank",
    ET_Event, Param_String);

    g_fwdTankGiven = new GlobalForward(
    "TankControlEQ_OnTankGiven",
    ET_Ignore, Param_String);

    g_fwdTankControlReset = new GlobalForward(
    "TankControlEQ_OnTankControlReset",
    ET_Ignore, Param_String);

    RegPluginLibrary("l4d_boss_percent");
    return APLRes_Success;
}

// - Natives - //

any Native_SetTank(Handle hPlugin, int iNumParams) {
    int iLength;
    GetNativeStringLength(1, iLength);
    if (iLength <= 0)
        return 0;
    // Retrieve the arg
    char[] szSteamId = new char[iLength + 1];
    GetNativeString(1, szSteamId, iLength + 1);
    // Queue that bad boy
    strcopy(g_szQueuedTankSteamId, sizeof(g_szQueuedTankSteamId), szSteamId);
    return 0;
}

any Native_GetTank(Handle hPlugin, int iNumParams) {
    int iTankClientId = GetValidInfectedClientBySteamId(g_szQueuedTankSteamId);
    return iTankClientId;
}

any Native_GetWhosHadTank(Handle hPlugin, int iNumParams) {
    return CloneHandle(g_arrWhosHadTank, hPlugin);
}

any Native_ClearWhosHadTank(Handle hPlugin, int iNumParams) {
    // Create our pool of players to choose from
    ArrayList arrInfectedPool = new ArrayList(64);
    AddTeamSteamIdsToArray(arrInfectedPool, 3);
    //remove infected players from had tank pool
    RemoveSteamIdsFromArray(g_arrWhosHadTank, arrInfectedPool);
    RemoveSteamIdsFromArray(g_arrWhosHadTankPersistent, arrInfectedPool);
    delete arrInfectedPool;
    return 0;
}

any Native_GetWhosNotHadTank(Handle hPlugin, int iNumParams) {
    ArrayList arrInfectedPool = new ArrayList(64);
    AddTeamSteamIdsToArray(arrInfectedPool, 3);
    // Remove players who've already had tank from the pool.
    RemoveSteamIdsFromArray(arrInfectedPool, g_arrWhosHadTankPersistent);
    char szSteamId[64];
    for (int i = 0; i < arrInfectedPool.Length; i++) {
        arrInfectedPool.GetString(i, szSteamId, sizeof(szSteamId));
    }
    Handle hClonedHandle = CloneHandle(arrInfectedPool, hPlugin);
    delete arrInfectedPool;
    return hClonedHandle;
}

any Native_GetTankPool(Handle hPlugin, int iNumParams) {
    ArrayList arrInfectedPool = new ArrayList(64);
    AddTeamSteamIdsToArray(arrInfectedPool, 3);
    // Remove players who've already had tank from the pool.
    RemoveSteamIdsFromArray(arrInfectedPool, g_arrWhosHadTank);
    // If the infected pool is empty, reset pool of players
    if (!arrInfectedPool.Length) AddTeamSteamIdsToArray(arrInfectedPool, 3);
    char szSteamId[64];
    for (int i = 0; i < arrInfectedPool.Length; i++) {
        arrInfectedPool.GetString(i, szSteamId, sizeof(szSteamId));
    }
    Handle hClonedHandle = CloneHandle(arrInfectedPool, hPlugin);
    delete arrInfectedPool;
    return hClonedHandle;
}

any Native_UpdateBossPercents(Handle hPlugin, int iNumParams) {
    CreateTimer(0.1, Timer_SaveBossFlows, _, TIMER_FLAG_NO_MAPCHANGE);
    return 0;
}

any Native_TankEnabled(Handle hPlugin, int iNumParams) {
    return g_bTankPercent;
}

any Native_WitchEnabled(Handle hPlugin, int iNumParams) {
    return g_bWitchPercent;
}

any Native_TankPercent(Handle hPlugin, int iNumParams) {
    return g_iTankPercent;
}

any Native_WitchPercent(Handle hPlugin, int iNumParams) {
    return g_iWitchPercent;
}

any Native_CurrentPercent(Handle hPlugin, int iNumParams) {
    return RoundToNearest(GetBossProximity() * 100.0);
}

public Plugin myinfo = {
    name        = "L4D2 Boss Flow Announce & L4D2 Tank Control",
    author      = "ProdigySim, Jahze, Stabby, CircleSquared, CanadaRox, arti, Sir, devilesk (added !passtank command by H.se)",
    version     = "???",
    description = "Announce boss flow percents and Distributes the role of the tank evenly throughout the team!"
};

public void OnPluginStart() {
    g_SolarisVoteTankControl = (new SolarisVote()).ForInfected()
                                                  .RestrictToGamemodes(GM_VERSUS)
                                                  .SetRequiredVotes(RV_MORETHANHALF)
                                                  .SetSuccessMessage("Tank has been passed")
                                                  .OnSuccess(VoteCallback_PassTank);

    g_SolarisVoteBoss = (new SolarisVote()).RestrictToGamemodes(GM_VERSUS)
                                           .SetRequiredVotes(RV_MORETHANHALF)
                                           .RestrictToFirstHalf()
                                           .RestrictToBeforeRoundStart()
                                           .SetSuccessMessage("Applying custom spawns...")
                                           .OnSuccess(VoteCallback_BossVote);

    g_cvTankPercent = CreateConVar(
    "l4d_tank_percent", "1",
    "Display Tank flow percentage in chat");
    g_bTankPercent = g_cvTankPercent.BoolValue;
    g_cvTankPercent.AddChangeHook(ConVarChange_BossPercentages);

    g_cvWitchPercent = CreateConVar(
    "l4d_witch_percent", "1",
    "Display Witch flow percentage in chat");
    g_bWitchPercent = g_cvWitchPercent.BoolValue;
    g_cvWitchPercent.AddChangeHook(ConVarChange_BossPercentages);

    // For Tank Percents
    g_cvBossBuffer = FindConVar("versus_boss_buffer");
    g_fBossBuffer  = g_cvBossBuffer.FloatValue;
    g_cvBossBuffer.AddChangeHook(ConVarChange_BossBuffer);

    // Event hooks
    HookEvent("player_left_safe_area", Event_PlayerLeftSafeArea, EventHookMode_PostNoCopy);
    HookEvent("round_start",           Event_RoundStart,         EventHookMode_PostNoCopy);
    HookEvent("round_end",             Event_RoundEnd,           EventHookMode_PostNoCopy);
    HookEvent("player_team",           Event_PlayerTeam,         EventHookMode_PostNoCopy);
    HookEvent("tank_killed",           Event_TankKilled,         EventHookMode_PostNoCopy);
    HookEvent("player_death",          Event_PlayerDeath,        EventHookMode_Post);
    HookEvent("player_say",            Event_PlayerSay,          EventHookMode_Post);

    // Admin commands
    RegAdminCmd("sm_tankshuffle",    Cmd_TankShuffle,    ADMFLAG_SLAY, "Re-picks at random someone to become tank.");
    RegAdminCmd("sm_givetank",       Cmd_GiveTank,       ADMFLAG_SLAY, "Gives the tank to a selected player");
    RegAdminCmd("sm_addtankpool",    Cmd_AddTankPool,    ADMFLAG_SLAY, "Adds selected player to tank pool.");
    RegAdminCmd("sm_queuetank",      Cmd_AddTankPool,    ADMFLAG_SLAY, "Adds selected player to tank pool.");
    RegAdminCmd("sm_removetankpool", Cmd_RemoveTankPool, ADMFLAG_SLAY, "Removes selected player from tank pool.");
    RegAdminCmd("sm_dequeuetank",    Cmd_RemoveTankPool, ADMFLAG_SLAY, "Removes selected player from tank pool.");

    // Initialise the tank arrays/data values
    g_arrWhosHadTank           = new ArrayList(64);
    g_arrWhosHadTankPersistent = new ArrayList(64);

    // Register the boss commands
    RegConsoleCmd("sm_tankpool", Cmd_TankPool, "Shows who is in the pool of possible tanks.");
    RegConsoleCmd("sm_tank",     Cmd_Boss,     "Shows who is becoming the tank.");
    RegConsoleCmd("sm_boss",     Cmd_Boss,     "Shows who is becoming the tank.");
    RegConsoleCmd("sm_witch",    Cmd_Boss,     "Shows who is becoming the tank.");
    RegConsoleCmd("sm_cur",      Cmd_Boss,     "Shows who is becoming the tank.");
    RegConsoleCmd("sm_current",  Cmd_Boss,     "Shows who is becoming the tank.");
    RegConsoleCmd("sm_passtank", Cmd_PassTank);
    RegConsoleCmd("sm_voteboss", Cmd_BossVote);
    RegConsoleCmd("sm_bossvote", Cmd_BossVote);

    // Load translations (for targeting player)
    LoadTranslations("common.phrases");
}

public void OnAllPluginsLoaded() {
    g_bIsWitchAndTankifierAvailable = LibraryExists("witch_and_tankifier");
}

public void OnLibraryAdded(const char[] szName) {
    if (strcmp(szName, "witch_and_tankifier") == 0)
        g_bIsWitchAndTankifierAvailable = true;
}

public void OnLibraryRemoved(const char[] szName) {
    if (strcmp(szName, "witch_and_tankifier") == 0)
        g_bIsWitchAndTankifierAvailable = false;
}

// - Boss flow percentages - //

void ConVarChange_BossPercentages(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bTankPercent  = g_cvTankPercent.BoolValue;
    g_bWitchPercent = g_cvWitchPercent.BoolValue;
}

// - Boss Buffer Cvar - //

void ConVarChange_BossBuffer(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fBossBuffer = g_cvBossBuffer.FloatValue;
}

// - Hooked Events - //

/**
 * When a player leaves the start area, choose a tank and output to all.
 */
void Event_PlayerLeftSafeArea(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (g_bIsRoundLive)
        return;

    g_bIsRoundLive = true;
    // Only choose a tank if nobody has been queued or queued tank is not a valid infected player
    if (!g_szQueuedTankSteamId[0] || GetValidInfectedClientBySteamId(g_szQueuedTankSteamId) == -1)
        ChooseTank();

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        PrintBossPercents(i);
    }

    OutputTankToAll();

    if (!g_bIsConfoglEnabled) {
        for (int i = 1; i <= MaxClients; i++) {
            if (!IsClientInGame(i))
                continue;

            if (IsFakeClient(i))
                continue;

            if (GetClientTeam(i) != L4D2Team_Infected)
                continue;

            if (TM_IsPlayerRespectating(i))
                continue;

            CPrintToChat(i, "{red}[{default}Tank Control{red}] {olive}You{default} can swap the tank with {red}!passtank{default} command");
        }
    }
}

public void OnRoundIsLive() {
    if (g_bIsRoundLive)
        return;

    g_bIsRoundLive = true;
    // Only choose a tank if nobody has been queued or queued tank is not a valid infected player
    if (!g_szQueuedTankSteamId[0] || GetValidInfectedClientBySteamId(g_szQueuedTankSteamId) == -1)
        ChooseTank();

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        PrintBossPercents(i);
    }

    OutputTankToAll();

    if (!g_bIsConfoglEnabled) {
        for (int i = 1; i <= MaxClients; i++) {
            if (!IsClientInGame(i))
                continue;

            if (IsFakeClient(i))
                continue;

            if (GetClientTeam(i) != L4D2Team_Infected)
                continue;

            if (TM_IsPlayerRespectating(i))
                continue;

            CPrintToChat(i, "{red}[{default}Tank Control{red}] {olive}You{default} can swap the tank with {red}!passtank{default} command");
        }
    }
}

/**
 * When the round ends, reset the active tank.
 */
void Event_RoundEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bIsRoundStarted        = false;
    g_bIsRoundLive           = false;
    g_szQueuedTankSteamId[0] = '\0';
}

/**
 * When the queued tank switches teams, choose a new one
 */
void Event_PlayerTeam(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!g_bIsRoundStarted)
        return;

    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)
        return;

    int iOldTeam = eEvent.GetInt("oldteam");
    if (iOldTeam != L4D2Team_Infected)
        return;

    /*
    * Triggers for disconnects as well as forced-swaps and whatnot.
    * Allows us to always reliably detect when the current Tank player loses control due to unnatural reasons.
    */
    if (!IsFakeClient(iClient)) {
        if (GetInfectedClass(iClient) == L4D2Infected_Tank) {
            g_iTankFrustration = GetTankFrustration(iClient);
            g_fTankGrace = CTimer_GetRemainingTime(GetFrustrationTimer(iClient));

            // Slight fix due to the timer seemingly always getting stuck between 0.5s~1.2s even after Grace period has passed.
            // CTimer_IsElapsed still returns false as well.
            if (g_fTankGrace < 0.0 || g_iTankFrustration < 100)
                g_fTankGrace = 0.0;
        }
    }

    char szTmpSteamId[64];
    GetClientAuthId(iClient, AuthId_Steam2, szTmpSteamId, sizeof(szTmpSteamId));
    if (strcmp(g_szQueuedTankSteamId, szTmpSteamId) == 0) {
        RequestFrame(ChooseTank);
        RequestFrame(OutputTankToAll);
    }
}

/**
 * When the tank dies, requeue a player to become tank (for finales)
 */
void Event_TankKilled(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!g_bIsRoundStarted)
        return;

    g_iTankFrustration = -1;
    ChooseTank();
}

void Event_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!g_bIsRoundStarted)
        return;

    int iVictim = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iVictim <= 0)
        return;

    if (!IsClientInGame(iVictim))
        return;

    if (GetInfectedClass(iVictim) != L4D2Infected_Tank)
        return;

    ChooseTank();
}

/**
 * On Dark Carnival: Remix there is a script to display custom boss percentages to users via chat.
 * We can "intercept" this message and read the boss percentages from the message.
 * From there we can add them to our Ready Up menu and to our !boss commands
 */
void Event_PlayerSay(Event eEvent, const char[] szName, bool bDontBroadcast) {
    // If the current map is not part of the Dark Carnival: Remix campaign, don't continue
    if (!IsDKR())
        return;

    // Check if the message is not from a user (Which means its from the map script)
    int iUserId = eEvent.GetInt("userid", 0);
    if (iUserId != 0)
        return;

    // Get the message text
    char szMsg[128];
    eEvent.GetString("text", szMsg, sizeof(szMsg), "");

    // If the message contains "The Tank" we can try to grab the Tank Percent from it
    if (StrContains(szMsg, "The Tank", false) > -1) g_iTankPercent = FindNumbers(szMsg);
    // If the message contains "The Witch" we can try to grab the Witch Percent from it
    if (StrContains(szMsg, "The Witch", false) > -1) g_iWitchPercent = FindNumbers(szMsg);
}

// - Admin Commands - //

/**
 * Give the tank to a random player.
 */
Action Cmd_TankShuffle(int iClient, int iArgs) {
    ChooseTank();
    OutputTankToAll();
    return Plugin_Handled;
}

/**
 * Give the tank to a specific player.
 */
Action Cmd_GiveTank(int iClient, int iArgs) {
    // Who are we targetting?
    char szArg[MAX_NAME_LENGTH];
    GetCmdArg(1, szArg, sizeof(szArg));

    // Try and find a matching player
    int iTarget = FindTarget(iClient, szArg);
    if (iTarget == -1)
        return Plugin_Handled;

    // Set the tank
    if (IsClientInGame(iTarget) && !IsFakeClient(iTarget)) {
        // Checking if on our desired team
        if (GetClientTeam(iTarget) != L4D2Team_Infected || TM_IsPlayerRespectating(iTarget)) {
            if (iClient) CPrintToChat(iClient, "{red}[{default}Tank Control{red}] {green}%N{default} is not in the infected team. Unable to give tank", iTarget);
            return Plugin_Handled;
        }

        char szSteamId[64];
        GetClientAuthId(iTarget, AuthId_Steam2, szSteamId, sizeof(szSteamId));
        g_szQueuedTankSteamId = szSteamId;
        OutputTankToAll();
    }

    return Plugin_Handled;
}

/**
 * Adds specific player to tank pool.
 */
Action Cmd_AddTankPool(int iClient, int iArgs) {
    // Who are we targetting?
    char szArg[MAX_NAME_LENGTH];
    GetCmdArg(1, szArg, sizeof(szArg));

    // Try and find a matching player
    int iTarget = FindTarget(iClient, szArg);
    if (iTarget == -1)
        return Plugin_Handled;

    // Set the tank
    if (IsClientInGame(iTarget) && !IsFakeClient(iTarget)) {
        // Checking if on our desired team
        if (GetClientTeam(iTarget) != L4D2Team_Infected || TM_IsPlayerRespectating(iTarget)) {
            CPrintToChat(iClient, "{red}[{default}Tank Control{red}] {green}%N{default} is not in the infected team. Unable to add to tank pool!", iTarget);
            return Plugin_Handled;
        }

        char szSteamId[64];
        GetClientAuthId(iTarget, AuthId_Steam2, szSteamId, sizeof(szSteamId));

        // Remove player from list of who had tank
        int iIdx = g_arrWhosHadTank.FindString(szSteamId);
        if (iIdx != -1)
            g_arrWhosHadTank.Erase(iIdx);

        iIdx = g_arrWhosHadTankPersistent.FindString(szSteamId);
        if (iIdx != -1)
            g_arrWhosHadTankPersistent.Erase(iIdx);

        CPrintToChatAll("{red}[{default}Tank Control{red}] {green}%N{default} was added to the tank pool!", iTarget);
    }

    return Plugin_Handled;
}

/**
 * Removes specific player from tank pool.
 */
Action Cmd_RemoveTankPool(int iClient, int iArgs) {
    // Who are we targetting?
    char szArg[MAX_NAME_LENGTH];
    GetCmdArg(1, szArg, sizeof(szArg));
    // Try and find a matching player
    int iTarget = FindTarget(iClient, szArg);
    if (iTarget == -1)
        return Plugin_Handled;

    // Set the tank
    if (IsClientInGame(iTarget) && !IsFakeClient(iTarget)) {
        // Checking if on our desired team
        if (GetClientTeam(iTarget) != L4D2Team_Infected || TM_IsPlayerRespectating(iTarget)) {
            CPrintToChat(iClient, "{red}[{default}Tank Control{red}] {green}%N{default} is not in the infected team. Unable to remove from tank pool!", iTarget);
            return Plugin_Handled;
        }

        char szSteamId[64];
        GetClientAuthId(iTarget, AuthId_Steam2, szSteamId, sizeof(szSteamId));

        // Add player to list of who had tank
        int iIdx = g_arrWhosHadTank.FindString(szSteamId);
        if (iIdx == -1)
            g_arrWhosHadTank.PushString(szSteamId);

        iIdx = g_arrWhosHadTankPersistent.FindString(szSteamId);
        if (iIdx == -1)
            g_arrWhosHadTankPersistent.PushString(szSteamId);

        CPrintToChat(iClient, "{red}[{default}Tank Control{red}] {green}%N{default} was removed from the tank pool!", iTarget);
    }

    return Plugin_Handled;
}

// - Clients Commands - //

/**
 * Shows who is in the pool of possible tanks.
 */
Action Cmd_TankPool(int iClient, int iArgs) {
    // Create our pool of players to choose from
    ArrayList arrInfectedPool = new ArrayList(64);
    AddTeamSteamIdsToArray(arrInfectedPool, 3);
    // Remove players who've already had tank from the pool.
    RemoveSteamIdsFromArray(arrInfectedPool, g_arrWhosHadTank);
    // If the infected pool is empty, reset pool of players
    if (!arrInfectedPool.Length)
        AddTeamSteamIdsToArray(arrInfectedPool, 3);

    // If there is nobody on the infected team
    if (!arrInfectedPool.Length) {
        CPrintToChat(iClient, "{red}[{default}Tank Control{red}]{default} Infected team is empty!");
        delete arrInfectedPool;
        return Plugin_Handled;
    }

    int iTankClientId;
    char szSteamId[64];
    char szNames[MAX_NAME_LENGTH * 4 + 6]; // 4 names, 3 comma+space in between
    szNames[0] = '\0';
    for (int i = 0; i < arrInfectedPool.Length; i++) {
        arrInfectedPool.GetString(i, szSteamId, sizeof(szSteamId));
        iTankClientId = GetValidInfectedClientBySteamId(szSteamId);
        if (iTankClientId == -1)
            continue;
        if (!szNames[0]) {
            Format(szNames, sizeof(szNames), "%N", iTankClientId);
        } else {
            Format(szNames, sizeof(szNames), "%s, %N", szNames, iTankClientId);
        }
    }

    CPrintToChat(iClient, "{red}[{default}Tank Control{red}] {olive}Tank pool{default}: {red}%s", szNames);
    delete arrInfectedPool;
    return Plugin_Handled;
}

/**
 * Show tank and witch percents, current survivors percent position and who wiil become the tank if it's possible.
 */
Action Cmd_Boss(int iClient, int iArgs) {
    PrintBossPercents(iClient);
    PrintCurrentToClient(iClient);

    // Only output if we have a queued tank
    if (!g_szQueuedTankSteamId[0]) {
        return Plugin_Handled;
    }

    int iTankClientId = GetValidInfectedClientBySteamId(g_szQueuedTankSteamId);
    if (iTankClientId != -1 && g_bTankPercent) {
        if (g_bIsConfoglEnabled) {
            CPrintToChat(iClient, "{red}%N{default} will become the tank!", iTankClientId);
        } else if (GetClientTeam(iClient) == L4D2Team_Infected && !TM_IsPlayerRespectating(iClient)) {
            CPrintToChat(iClient, "{red}%N{default} will become the tank!", iTankClientId);
        }
    }

    return Plugin_Handled;
}

// - Pass tank and Tank Control vote -

Action Cmd_PassTank(int iClient, int iArgs) {
    if (!g_bTankPercent)
        return Plugin_Continue;

    if (g_bIsConfoglEnabled)
        return Plugin_Continue;

    if (TM_IsPlayerRespectating(iClient))
        return Plugin_Continue;

    if (GetClientTeam(iClient) == L4D2Team_Infected)
        PassTankMenu(iClient);

    return Plugin_Handled;
}

void PassTankMenu(int iClient) {
    Menu mMenu = new Menu(Select_PassTankMenu);
    mMenu.SetTitle("Select a player who will become the tank:\n");
    char szTmpSteamId[64];
    char szName[32];
    int iTankClientId = GetValidInfectedClientBySteamId(g_szQueuedTankSteamId);
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == L4D2Team_Infected && i != iTankClientId) {
            GetClientAuthId(i, AuthId_Steam2, szTmpSteamId, sizeof(szTmpSteamId));
            GetClientName(i, szName, sizeof(szName));
            mMenu.AddItem(szTmpSteamId, szName);
        }
    }
    mMenu.Display(iClient, MENU_TIME_FOREVER);
}

int Select_PassTankMenu(Menu mMenu, MenuAction maAction, int iClient, int iOption) {
    if (maAction == MenuAction_End)
        delete mMenu;

    if (maAction == MenuAction_Select) {
        char szTmpSteamId[64];
        mMenu.GetItem(iOption, szTmpSteamId, sizeof(szTmpSteamId));
        int iTarget = GetValidInfectedClientBySteamId(szTmpSteamId);
        if (iTarget > 0) {
            int iTankClientId = GetValidInfectedClientBySteamId(g_szQueuedTankSteamId);
            if (iClient != iTankClientId) {
                // prepare vote title
                char szVotePrint[128] = "";
                char szVoteTitle[128] = "";
                Format(szVotePrint, sizeof(szVotePrint), "giving tank control to {teamcolor}%N{default}.", iTarget);
                Format(szVoteTitle, sizeof(szVoteTitle), "Give tank to %N?", iTarget);

                g_SolarisVoteTankControl.SetPrint(szVotePrint, false)
                                        .SetTitle(szVoteTitle);

                // start vote
                bool bVoteStarted = g_SolarisVoteTankControl.Start(iClient);
                if (bVoteStarted) strcopy(g_szPassTankSteamId, sizeof(g_szPassTankSteamId), szTmpSteamId);
            } else {
                strcopy(g_szQueuedTankSteamId, sizeof(g_szQueuedTankSteamId), szTmpSteamId);
                OutputTankToAll();
            }
        } else if (iClient > 0) {
            CPrintToChat(iClient, "{red}[{default}Tank Control{red}]{default} This player isn't available anymore.");
        }
    }

    return 0;
}

void VoteCallback_PassTank() {
    int iTarget = GetValidInfectedClientBySteamId(g_szPassTankSteamId);
    if (iTarget > 0) {
        strcopy(g_szQueuedTankSteamId, sizeof(g_szQueuedTankSteamId), g_szPassTankSteamId);
        OutputTankToAll();
    }
}

// - Boss Flow Vote -
Action Cmd_BossVote(int iClient, int iArgs) {
    if (g_bTankPercent && !IsStaticTank() && g_bWitchPercent && !IsStaticWitch()) {
        if (iArgs < 2) {
            CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} Usage: {green}!voteboss{olive} <tank> <witch>.");
            CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} Example: {green}!voteboss{default} 70 50.");
            CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} Your setting will be {olive}Tank 70%% {default}and {olive}Witch 50%%.");
            return Plugin_Handled;
        }

        char szTankCmdArg[8];
        GetCmdArg(1, szTankCmdArg, sizeof(szTankCmdArg));

        char szWitchCmdArg[8];
        GetCmdArg(2, szWitchCmdArg, sizeof(szWitchCmdArg));

        if (!IsInteger(szTankCmdArg) && !IsInteger(szWitchCmdArg)) {
            CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} Tank and Witch flows are invalid!");
            return Plugin_Handled;
        } else if (!IsInteger(szTankCmdArg)) {
            CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} Tank flow is invalid!");
            return Plugin_Handled;
        } else if (!IsInteger(szWitchCmdArg)) {
            CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} Witch flow is invalid!");
            return Plugin_Handled;
        }

        float fTankCmdArg   = StringToFloat(szTankCmdArg);
        float fWitchCmdArg  = StringToFloat(szWitchCmdArg);
        bool  bTankDisable  = fTankCmdArg  == 0;
        bool  bWitchDisable = fWitchCmdArg == 0;
        float fTankFlow     = (fTankCmdArg / 100.0) + (g_fBossBuffer / L4D2Direct_GetMapMaxFlowDistance());
        float fWitchFlow    = fWitchCmdArg / 100.0;

        int iMaxTankFlow  = RoundToFloor((FindConVar("versus_boss_flow_max").FloatValue - (g_fBossBuffer / L4D2Direct_GetMapMaxFlowDistance())) * 100);
        int iMinTankFlow  = RoundToFloor((FindConVar("versus_boss_flow_min").FloatValue - (g_fBossBuffer / L4D2Direct_GetMapMaxFlowDistance())) * 100);
        int iMaxWitchFlow = RoundToFloor(FindConVar("versus_boss_flow_max").FloatValue * 100);
        int iMinWitchFlow = RoundToFloor(FindConVar("versus_boss_flow_min").FloatValue * 100);

        if (iMinTankFlow <= 0) iMinTankFlow = 1;
        if (fTankCmdArg != 0 && (fTankCmdArg > iMaxTankFlow || fTankCmdArg < iMinTankFlow)) {
            CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} Tank spawns can be changed {olive}only by using interval{default} from {green}%i%%{default} to {green}%i%%{default}!", iMinTankFlow, iMaxTankFlow);
            return Plugin_Handled;
        }
        if (fWitchCmdArg != 0 && (fWitchCmdArg > iMaxWitchFlow || fWitchCmdArg < iMinWitchFlow)) {
            CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} Witch spawns can be changed {olive}only by using interval{default} from {green}%i%%{default} to {green}%i%%{default}!", iMinWitchFlow, iMaxWitchFlow);
            return Plugin_Handled;
        }

        char szVotePrint[128];
        char szVoteTitle[128];
        if (fTankCmdArg != 0 && fWitchCmdArg != 0) {
            Format(szVotePrint, sizeof(szVotePrint), "setting tank spawn to {olive}%i%%%%{default}, witch spawn to {olive}%i%%%%{default}.", RoundToNearest(fTankCmdArg), RoundToNearest(fWitchCmdArg));
            Format(szVoteTitle, sizeof(szVoteTitle), "Set tank spawn to %i%%%%%%%%, witch spawn to %i%%%%%%%%?", RoundToNearest(fTankCmdArg), RoundToNearest(fWitchCmdArg));
        } else if (fTankCmdArg != 0 && fWitchCmdArg == 0) {
            Format(szVotePrint, sizeof(szVotePrint), "setting tank spawn to {olive}%i%%%%{default} and disabling witch.", RoundToNearest(fTankCmdArg));
            Format(szVoteTitle, sizeof(szVoteTitle), "Set tank spawn to %i%%%%%%%% and disable witch?", RoundToNearest(fTankCmdArg));
        } else if (fTankCmdArg == 0 && fWitchCmdArg != 0) {
            Format(szVotePrint, sizeof(szVotePrint), "disabling tank and setting witch spawn to {olive}%i%%%%{default}.", RoundToNearest(fWitchCmdArg));
            Format(szVoteTitle, sizeof(szVoteTitle), "Disable tank and set witch spawn to %i%%%%%%%%?", RoundToNearest(fWitchCmdArg));
        } else if (fTankCmdArg == 0 && fWitchCmdArg == 0) {
            Format(szVotePrint, sizeof(szVotePrint), "disabling tank and witch.");
            Format(szVoteTitle, sizeof(szVoteTitle), "Disable tank and witch?");
        }
        // prepare vote title
        g_SolarisVoteBoss.SetPrint(szVotePrint)
                         .SetTitle(szVoteTitle);
        // start vote
        bool bVoteStarted = g_SolarisVoteBoss.Start(iClient);
        if (bVoteStarted) {
            g_bTankDisable  = bTankDisable;
            g_bWitchDisable = bWitchDisable;
            g_fTankFlow     = fTankFlow;
            g_fWitchFlow    = fWitchFlow;
        }
    } else if (g_bTankPercent || (g_bTankPercent && g_bWitchPercent && IsStaticWitch())) {
        if (iArgs < 1) {
            CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} Usage: {green}!voteboss{olive} <tank>.");
            CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} Example: {green}!voteboss{default} 70.");
            CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} Your setting will be {olive}Tank 70%%.");
            return Plugin_Handled;
        }

        char szTankCmdArg[8];
        GetCmdArg(1, szTankCmdArg, sizeof(szTankCmdArg));

        if (!IsInteger(szTankCmdArg)) {
            CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} Tank flow is invalid!");
            return Plugin_Handled;
        }

        float fTankCmdArg  = StringToFloat(szTankCmdArg);
        bool  bTankDisable = fTankCmdArg  == 0;
        float fTankFlow    = (fTankCmdArg / 100.0) + (g_fBossBuffer / L4D2Direct_GetMapMaxFlowDistance());

        int iMaxTankFlow = RoundToFloor((FindConVar("versus_boss_flow_max").FloatValue - (g_fBossBuffer / L4D2Direct_GetMapMaxFlowDistance())) * 100);
        int iMinTankFlow = RoundToFloor((FindConVar("versus_boss_flow_min").FloatValue - (g_fBossBuffer / L4D2Direct_GetMapMaxFlowDistance())) * 100);

        if (iMinTankFlow <= 0) iMinTankFlow = 1;
        if (fTankCmdArg != 0 && (fTankCmdArg > iMaxTankFlow || fTankCmdArg < iMinTankFlow)) {
            CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} Tank spawns can be changed {olive}only by using interval{default} from {green}%i%%{default} to {green}%i%%{default}!", iMinTankFlow, iMaxTankFlow);
            return Plugin_Handled;
        }

        char szVotePrint[128];
        char szVoteTitle[128];
        if (fTankCmdArg != 0) {
            Format(szVotePrint, sizeof(szVotePrint), "setting tank spawn to {olive}%i%%%%{default}.", RoundToNearest(fTankCmdArg));
            Format(szVoteTitle, sizeof(szVoteTitle), "Set tank spawn to %i%%%%%%%%?", RoundToNearest(fTankCmdArg));
        } else {
            Format(szVotePrint, sizeof(szVotePrint), "disabling tank.");
            Format(szVoteTitle, sizeof(szVoteTitle), "Disable tank?");
        }
        // prepare vote title
        g_SolarisVoteBoss.SetPrint(szVotePrint)
                         .SetTitle(szVoteTitle);
        // start vote
        bool bVoteStarted = g_SolarisVoteBoss.Start(iClient);
        if (bVoteStarted) {
            g_bTankDisable  = bTankDisable;
            g_fTankFlow     = fTankFlow;
            g_bWitchDisable = true;
        }
    } else if (g_bWitchPercent || (g_bTankPercent && IsStaticTank() && g_bWitchPercent)) {
        if (iArgs < 1) {
            CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} Usage: {green}!voteboss{olive} <witch>.");
            CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} Example: {green}!voteboss{default} 50.");
            CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} Your setting will be {olive}Witch 50%%.");
            return Plugin_Handled;
        }

        char szWitchCmdArg[8];
        GetCmdArg(1, szWitchCmdArg, sizeof(szWitchCmdArg));

        if (!IsInteger(szWitchCmdArg)) {
            CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} Witch flow is invalid!");
            return Plugin_Handled;
        }

        float fWitchCmdArg  = StringToFloat(szWitchCmdArg);
        bool  bWitchDisable = fWitchCmdArg == 0;
        float fWitchFlow    = fWitchCmdArg / 100.0;

        int iMaxWitchFlow = RoundToFloor(FindConVar("versus_boss_flow_max").FloatValue * 100);
        int iMinWitchFlow = RoundToFloor(FindConVar("versus_boss_flow_min").FloatValue * 100);

        if (fWitchCmdArg != 0 && (fWitchCmdArg > iMaxWitchFlow || fWitchCmdArg < iMinWitchFlow)) {
            CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} Witch spawns can be changed {olive}only by using interval{default} from {green}%i%%{default} to {green}%i%%{default}!", iMinWitchFlow, iMaxWitchFlow);
            return Plugin_Handled;
        }

        char szVotePrint[128];
        char szVoteTitle[128];
        if (fWitchCmdArg != 0) {
            Format(szVotePrint, sizeof(szVotePrint), "setting witch spawn to {olive}%i%%%%{default}.", RoundToNearest(fWitchCmdArg));
            Format(szVoteTitle, sizeof(szVoteTitle), "Set witch spawn to %i%%%%%%%%?", RoundToNearest(fWitchCmdArg));
        } else {
            Format(szVotePrint, sizeof(szVotePrint), "disabling witch.");
            Format(szVoteTitle, sizeof(szVoteTitle), "Disable witch?");
        }
        // prepare vote title
        g_SolarisVoteBoss.SetPrint(szVotePrint)
                         .SetTitle(szVoteTitle);
        // start vote
        bool bVoteStarted = g_SolarisVoteBoss.Start(iClient);
        if (bVoteStarted) {
            g_bTankDisable  = true;
            g_bWitchDisable = bWitchDisable;
            g_fWitchFlow    = fWitchFlow;
        }
    }

    return Plugin_Handled;
}

void VoteCallback_BossVote() {
    SetTankSpawn(g_fTankFlow);
    SetWitchSpawn(g_fWitchFlow);
    CreateTimer(0.1, Timer_SaveBossFlows, _, TIMER_FLAG_NO_MAPCHANGE);
}

void SetTankSpawn(float fFlow) {
    for (int i = 0; i <= 1; i++) {
        if (!g_bTankDisable) {
            L4D2Direct_SetVSTankToSpawnThisRound(i, true);
            L4D2Direct_SetVSTankFlowPercent(i, fFlow);
        } else {
            L4D2Direct_SetVSTankToSpawnThisRound(i, false);
        }
    }
}

void SetWitchSpawn(float fFlow) {
    for (int i = 0; i <= 1; i++) {
        if (!g_bWitchDisable) {
            L4D2Direct_SetVSWitchToSpawnThisRound(i, true);
            L4D2Direct_SetVSWitchFlowPercent(i, fFlow);
        } else {
            L4D2Direct_SetVSWitchToSpawnThisRound(i, false);
        }
    }
}

// - Confogl Enabled? -
public void LGO_OnMatchModeLoaded() {
    g_bIsConfoglEnabled = true;
}

public void LGO_OnMatchModeUnloaded() {
    g_bIsConfoglEnabled = false;
}

/**
 *  When the tank disconnects, choose another one.
 */
public void L4D2_OnTankPassControl(int iOldTank, int iNewTank, int iPassCount) {
    /*
    * As the Player switches to AI on disconnect/team switch, we have to make sure we're only checking this if the old Tank was AI.
    * Then apply the previous' Tank's Frustration and Grace Period (if it still had Grace)
    * We'll also be keeping the same Tank pass, which resolves Tanks that dc on 1st pass resulting into the Tank instantly going to 2nd pass.
    */
    if (g_iTankFrustration != -1 && IsFakeClient(iOldTank)) {
        SetTankFrustration(iNewTank, g_iTankFrustration);
        CTimer_Start(GetFrustrationTimer(iNewTank), g_fTankGrace);
        L4D2Direct_SetTankPassedCount(L4D2Direct_GetTankPassedCount() - 1);
    }
}

public void OnTankFlowWasApplied() {
    g_iTankPercent = 0;
    if (L4D2Direct_GetVSTankToSpawnThisRound(InSecondHalfOfRound())) {
        g_iTankPercent = RoundToNearest(GetTankFlow(InSecondHalfOfRound()) * 100.0);
    }
}

public void OnWitchFlowWasApplied() {
    g_iWitchPercent = 0;
    if (L4D2Direct_GetVSWitchToSpawnThisRound(InSecondHalfOfRound())) {
        g_iWitchPercent = RoundToNearest(GetWitchFlow(InSecondHalfOfRound()) * 100.0);
    }
}

/**
 * When a new game starts, reset the tank pool.
 */
void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bIsRoundStarted        = true;
    g_bIsRoundLive           = false;
    g_iTankFrustration       = -1;
    g_szQueuedTankSteamId[0] = '\0';

    CreateTimer(10.0, Timer_RoundStart, _, TIMER_FLAG_NO_MAPCHANGE);
    if (!IsDKR()) CreateTimer(5.0, Timer_SaveBossFlows, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_RoundStart(Handle hTimer) {
    int iTeamAScore = L4D2Direct_GetVSCampaignScore(0);
    int iTeamBScore = L4D2Direct_GetVSCampaignScore(1);
    // If it's a new game, reset the tank pool
    if (iTeamAScore == 0 && iTeamBScore == 0) {
        g_arrWhosHadTank.Clear();
        g_arrWhosHadTankPersistent.Clear();
        Call_StartForward(g_fwdTankControlReset);
        Call_Finish();
    }
    return Plugin_Handled;
}

/**
 * Selects a player on the infected team from random who hasn't been
 * tank and gives it to them.
 */
void ChooseTank() {
    Action aResult;
    Call_StartForward(g_fwdChooseTank);
    Call_Finish(aResult);
    if (aResult == Plugin_Handled)
        return;

    // Create our pool of players to choose from
    ArrayList arrInfectedPool = new ArrayList(64);
    AddTeamSteamIdsToArray(arrInfectedPool, 3);

    // Remove players who've already had tank from the pool.
    RemoveSteamIdsFromArray(arrInfectedPool, g_arrWhosHadTank);

    // If the infected pool is empty, reset pool, and remove infected players from had tank pool
    if (!arrInfectedPool.Length) {
        AddTeamSteamIdsToArray(arrInfectedPool, 3);
        RemoveSteamIdsFromArray(g_arrWhosHadTank, arrInfectedPool); // g_arrWhosHadTankPersistent is not reset
    }

    // If no infected players, clear queued tank and return
    if (!arrInfectedPool.Length) {
        g_szQueuedTankSteamId[0] = '\0';
        delete arrInfectedPool;
        return;
    }

    // Select a random person to become the tank
    int iMaxIdx = arrInfectedPool.Length - 1;
    int iRndIdx = Math_GetRandomInt(0, iMaxIdx);
    arrInfectedPool.GetString(iRndIdx, g_szQueuedTankSteamId, sizeof(g_szQueuedTankSteamId));
    delete arrInfectedPool;
}

/**
 * Make sure we give the tank to our queued player.
 */
public Action L4D_OnTryOfferingTankBot(int iTankIdx, bool &bEnterStasis) {
    if (iTankIdx <= 0)
        return Plugin_Continue;

    // Reset the tank's frustration if need be
    if (!IsFakeClient(iTankIdx)) {
        PrintHintText(iTankIdx, "Rage Meter Refilled");
        for (int i = 1; i <= MaxClients; i++) {
            if (!IsClientInGame(i))
                continue;

            if (IsFakeClient(i))
                continue;

            if (GetClientTeam(i) != L4D2Team_Infected)
                continue;

            if (TM_IsPlayerRespectating(i))
                continue;

            CPrintToChat(i, "{red}[{default}Tank Control{red}] {green}%N{default}'s {olive}Rage Meter{red} Refilled", iTankIdx);
        }

        SetTankFrustration(iTankIdx, 100);
        int iTankPassCount = L4D2Direct_GetTankPassedCount() + 1;
        L4D2Direct_SetTankPassedCount(iTankPassCount);
        return Plugin_Handled;
    }

    // If we don't have a queued tank, choose one
    if (!g_szQueuedTankSteamId[0])
        ChooseTank();

    // Mark the player as having had tank
    if (g_szQueuedTankSteamId[0]) {
        SetTankTickets(g_szQueuedTankSteamId, 20000);
        int iIdx = g_arrWhosHadTank.FindString(g_szQueuedTankSteamId);

        if (iIdx == -1)
            g_arrWhosHadTank.PushString(g_szQueuedTankSteamId);

        iIdx = g_arrWhosHadTankPersistent.FindString(g_szQueuedTankSteamId);

        if (iIdx == -1)
            g_arrWhosHadTankPersistent.PushString(g_szQueuedTankSteamId);

        Call_StartForward(g_fwdTankGiven);
        Call_PushString(g_szQueuedTankSteamId);
        Call_Finish();
    }

    return Plugin_Continue;
}

/**
 * Sets the amount of tickets for a particular player, essentially giving them tank.
 */
void SetTankTickets(const char[] szSteamId, const int iTickets) {
    int iTankClientId = GetValidInfectedClientBySteamId(szSteamId);
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        if (GetClientTeam(i) != L4D2Team_Infected)
            continue;

        if (TM_IsPlayerRespectating(i))
            continue;

        L4D2Direct_SetTankTickets(i, (i == iTankClientId) ? iTickets : 0);
    }
}

/**
 * Output who will become tank
 */
void OutputTankToAll() {
    int iTankClientId = GetValidInfectedClientBySteamId(g_szQueuedTankSteamId);
    if (iTankClientId == -1 || !g_bTankPercent)
        return;

    if (g_bIsConfoglEnabled) {
        CPrintToChatAll("{red}%N{default} will become the tank!", iTankClientId);
    } else {
        for (int i = 1; i <= MaxClients; i++) {
            if (!IsClientInGame(i))
                continue;

            if (GetClientTeam(i) != L4D2Team_Infected)
                continue;

            if (TM_IsPlayerRespectating(i))
                continue;

            CPrintToChat(i, "{red}%N{default} will become the tank!", iTankClientId);
        }
    }
}

/**
 * Adds steam ids for a particular team to an array.
 *
 * @param Handle:arrSteamIds
 *     The array to modify.
 * @param iTeam
 *     The team which to return steam ids for.
 *
 * @noreturn
 */
void AddTeamSteamIdsToArray(ArrayList arrSteamIds, int iTeam) {
    char szSteamId[64];
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == iTeam) {
            GetClientAuthId(i, AuthId_Steam2, szSteamId, sizeof(szSteamId));
            arrSteamIds.PushString(szSteamId);
        }
    }
}

/**
 * Removes an array of steam ids from another array.
 *
 * @param Handle:arrSteamIds
 *     The array of steam ids to modify.
 * @ param Handle:arrSteamIdsToRemove
 *     The steam ids to remove.
 *
 * @noreturn
 */
void RemoveSteamIdsFromArray(ArrayList arrSteamIds, ArrayList arrSteamIdsToRemove) {
    int iIdx = -1;
    char szSteamId[64];
    for (int i = 0; i < arrSteamIdsToRemove.Length; i++) {
        arrSteamIdsToRemove.GetString(i, szSteamId, sizeof(szSteamId));
        iIdx = arrSteamIds.FindString(szSteamId);
        if (iIdx != -1) arrSteamIds.Erase(iIdx);
    }
}

/**
 * Retrieves a valid infected player's iClient iIndex by their steam id.
 *
 * @param const String:szSteamId[]
 *     The steam id to look for.
 *
 * @return
 *     The player's iClient iIndex.
 */
int GetValidInfectedClientBySteamId(const char[] szSteamId) {
    char szTmpSteamId[64];
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (GetClientTeam(i) != L4D2Team_Infected)
            continue;

        if (TM_IsPlayerRespectating(i))
            continue;

        GetClientAuthId(i, AuthId_Steam2, szTmpSteamId, sizeof(szTmpSteamId));
        if (strcmp(szSteamId, szTmpSteamId) == 0)
            return i;
    }

    return -1;
}

CountdownTimer GetFrustrationTimer(int iClient) {
    static int iFrustrationTimerOffs = -1;
    if (iFrustrationTimerOffs == -1)
        iFrustrationTimerOffs = FindSendPropInfo("CTerrorPlayer", "m_frustration") + 4;
    return view_as<CountdownTimer>(GetEntityAddress(iClient) + view_as<Address>(iFrustrationTimerOffs));
}

// - Boss Percents - //
Action Timer_SaveBossFlows(Handle hTimer) {
    if (InSecondHalfOfRound())
        return Plugin_Handled;

    g_iTankPercent  = 0;
    g_iWitchPercent = 0;

    if (L4D2Direct_GetVSTankToSpawnThisRound(0)) {
        g_iTankPercent = RoundToNearest(GetTankFlow(0) * 100.0);
    }

    if (L4D2Direct_GetVSWitchToSpawnThisRound(0)) {
        g_iWitchPercent = RoundToNearest(GetWitchFlow(0) * 100.0);
    }

    return Plugin_Handled;
}

void PrintBossPercents(int iClient) {
    if (g_bTankPercent) {
        if (g_iTankPercent) {
            CPrintToChat(iClient, "Tank: {red}%d%%", g_iTankPercent);
        } else {
            CPrintToChat(iClient, "Tank: {red}%s", IsStaticTank() ? "Static" : "None");
        }
    }
    if (g_bWitchPercent) {
        if (g_iWitchPercent) {
            CPrintToChat(iClient, "Witch: {red}%d%%", g_iWitchPercent);
        } else {
            CPrintToChat(iClient, "Witch: {red}%s", IsStaticWitch() ? "Static" : "None");
        }
    }
}

float GetTankFlow(int iRound) {
    float fTankPercent = L4D2Direct_GetVSTankFlowPercent(iRound) - (g_fBossBuffer / L4D2Direct_GetMapMaxFlowDistance());
    if (fTankPercent <= 0.00) fTankPercent = 0.01;
    return fTankPercent;
}

float GetWitchFlow(int iRound) {
    return L4D2Direct_GetVSWitchFlowPercent(iRound);
}

// - Current Survivors Percent Position - //

void PrintCurrentToClient(int iClient) {
    if (g_bTankPercent || g_bWitchPercent) {
        int iBossProximity = RoundToNearest(GetBossProximity() * 100.0);
        CPrintToChat(iClient, "Current: {red}%d%%", iBossProximity);
    }
}

float GetBossProximity() {
    float fProximity = GetMaxSurvivorCompletion() + (g_bDKR ? g_fBossBuffer : 0.0) / L4D2Direct_GetMapMaxFlowDistance();
    float fVar1;
    if (fProximity > 1.0) {
        fVar1 = 1.0;
    } else {
        fVar1 = fProximity;
    }
    return fVar1;
}

float GetMaxSurvivorCompletion() {
    float   fFlow = 0.0;
    float   fTmpFlow;
    float   fOrigin[3];
    Address pNavArea;
    int     iClient = 1;
    while (iClient <= MaxClients) {
        if (IsClientInGame(iClient) && GetClientTeam(iClient) == L4D2Team_Survivor) {
            GetClientAbsOrigin(iClient, fOrigin);
            pNavArea = L4D2Direct_GetTerrorNavArea(fOrigin, 120.0);
            if (pNavArea) {
                fTmpFlow = L4D2Direct_GetTerrorNavAreaFlow(pNavArea);
                float fVar2;
                if (fFlow > fTmpFlow) {
                    fVar2 = fFlow;
                } else {
                    fVar2 = fTmpFlow;
                }
                fFlow = fVar2;
            }
        }
        iClient++;
    }
    return fFlow / L4D2Direct_GetMapMaxFlowDistance();
}

// - Boss Percents for Dark Carnival Remix - //

int FindNumbers(char[] szTmp) {
    // Check to see if text contains '%' - Store the index if it does
    int iIdx = StrContains(szTmp, "%", false);
    // If the index isn't -1 (No '%' found) then find the percentage
    if (iIdx > -1) {
        char sBuffer[12];    // Where our percentage will be kept.
        // If the 3rd character before the '%' symbol is a number it's 100%.
        if (IsCharNumeric(szTmp[iIdx - 3]))
            return 100;
        // Check to see if the characters that are 1 and 2 characters before our '%' symbol are numbers
        if (IsCharNumeric(szTmp[iIdx - 2]) && IsCharNumeric(szTmp[iIdx - 1])) {
            // If both characters are numbers combine them into 1 string
            Format(sBuffer, sizeof(sBuffer), "%c%c", szTmp[iIdx - 2], szTmp[iIdx - 1]);
            // Convert our string to an int
            return StringToInt(sBuffer);
        }
    }

    // Couldn't find a percentage
    return 0;
}

// - Is Current Map Dark Carnival Remix? - //

bool IsDKR() {
    char szMap[64];
    GetCurrentMap(szMap, sizeof(szMap));
    if (strcmp(szMap, "dkr_m1_motel") == 0 || strcmp(szMap, "dkr_m2_carnival") == 0 || strcmp(szMap, "dkr_m3_tunneloflove") == 0 || strcmp(szMap, "dkr_m4_ferris") == 0 || strcmp(szMap, "dkr_m5_stadium") == 0)
        return true;
    return false;
}

bool IsInteger(const char[] szBuffer) {
    // negative check
    if (!IsCharNumeric(szBuffer[0]) && szBuffer[0] != '-')
        return false;
    int iLength = strlen(szBuffer);
    for (int i = 1; i < iLength; i++) {
        if (!IsCharNumeric(szBuffer[i]))
            return false;
    }
    return true;
}

bool IsStaticTank() {
    if (!g_bIsWitchAndTankifierAvailable)
        return false;
    return IsStaticTankMap();
}

bool IsStaticWitch() {
    if (!g_bIsWitchAndTankifierAvailable)
        return false;
    return IsStaticWitchMap();
}

int Math_GetRandomInt(int iMin, int iMax) {
    int iRnd = GetURandomInt();
    if (iRnd == 0) iRnd++;
    return RoundToCeil(float(iRnd) / (float(SIZE_OF_INT) / float(iMax - iMin + 1))) + iMin - 1;
}