#if defined __solaris_votes_globals_included
    #endinput
#endif
#define __solaris_votes_globals_included

#include <solaris/votes/types>

// Team Numbers
#define TEAM_SPECTATE  1
#define TEAM_SURVIVORS 2
#define TEAM_INFECTED  3

// Admin Actions (Veto, Pass)
#define VETO 0
#define PASS 1

int g_iClientsPool     [MAXPLAYERS + 1];
int g_iVotesCountPerMap[MAXPLAYERS + 1];

char g_gmBase     [16] = "coop";
char g_szGameMode[128] = "coop";

int g_iCooldownExpiresIn = 0;
int g_iVoteDelay = 0;

bool g_bIsSurf           = false;
bool g_bIsGauntlet       = false;
bool g_bIsPracticogl     = false;
bool g_bHasRoundStarted  = false;
bool g_bIsSecondHalf     = false;
bool g_bIsInCaptains     = false;
bool g_bConfoglAvailable = false;

ConVar g_cvGamemode;
ConVar g_cvVoteDelay;
ConVar g_cvSurvivorLimit;
ConVar g_cvInfectedLimit;
ConVar g_cvVoteCommandDelay;  // How long after a vote passes until the action happens
ConVar g_cvVoteTimerDuration; // duration, in seconds, that players have to vote for a vote that has been called
ConVar g_cvVoteNotifyToChat;  // should vote manager notify

NativeVote  g_hActiveVote = null;
VotingState g_votingState = Voting_Allowed;
Handle      g_hTimerDelay = null;

StringMap g_smPlayersTemporarilyBanned;
StringMap g_smPlayersWithoutPassword;

SolarisVote g_voteInstance;

void Globals_OnPluginStart() {
    g_cvGamemode = FindConVar("mp_gamemode");
    g_cvGamemode.GetString(g_szGameMode, sizeof(g_szGameMode));
    g_cvGamemode.AddChangeHook(ConVarChange_Gamemode);

    g_cvVoteDelay = FindConVar("sm_vote_delay");
    g_iVoteDelay  = g_cvVoteDelay.IntValue;
    g_cvVoteDelay.AddChangeHook(ConVarChange_VoteDelay);

    g_cvVoteCommandDelay  = FindConVar("sv_vote_command_delay");  // how long after a vote passes until the action happens.
    g_cvVoteTimerDuration = FindConVar("sv_vote_timer_duration"); // time (in seconds) during which players have to vote.

    g_cvSurvivorLimit = FindConVar("survivor_limit");
    g_cvInfectedLimit = FindConVar("z_max_player_zombies");

    g_cvVoteNotifyToChat = CreateConVar(
    "sm_vote_notify_to_chat", "1", "Should user votes be notified to chat?  \
    0 = Votes won't be notified to chat; Choices won't be notified to chat. \
    1 = Votes will be notified to all players if 'PrintToAll' Vote Instance was not changed, otherwise, votes will be notified to pool and admins only; Choices will be notified to admins only. \
    2 = Votes will be notified to all players; Choices will be notified to all players.",
    FCVAR_NONE, true, 0.0, true, 2.0);

    HookEvent("round_start",           Event_RoundStart,         EventHookMode_PostNoCopy);
    HookEvent("player_left_safe_area", Event_PlayerLeftSafeArea, EventHookMode_PostNoCopy);
    HookEvent("survival_round_start",  Event_SurvivalRoundStart, EventHookMode_PostNoCopy);

    // arrays for OnClientPreConnect forward
    g_smPlayersTemporarilyBanned = new StringMap();
    g_smPlayersWithoutPassword   = new StringMap();
}

void Globals_OnAllPluginsLoaded() {
    g_bConfoglAvailable = LibraryExists("confogl");
}

void Globals_OnLibraryAdded(const char[] szName) {
    if (strcmp(szName, "confogl") != 0) return;
    g_bConfoglAvailable = true;
}

void Globals_OnLibraryRemoved(const char[] szName) {
    if (strcmp(szName, "confogl") != 0) return;
    g_bConfoglAvailable = false;
}

void Globals_OnConfigsExecuted() {
    if (g_bConfoglAvailable && LGO_IsMatchModeLoaded() && FindConVar("l4d_ready_cfg_name") != null) {
        char szReadyCfgName[64];
        FindConVar("l4d_ready_cfg_name").GetString(szReadyCfgName, sizeof(szReadyCfgName));
        g_bIsSurf       = StrContains(szReadyCfgName, "Dead Air Surf", false) != -1 || StrContains(szReadyCfgName, "Vertigo", false) != -1 || StrContains(szReadyCfgName, "Dead Hotel", false) != -1;
        g_bIsGauntlet   = StrContains(szReadyCfgName, "Gauntlet",      false) != -1;
        g_bIsPracticogl = StrContains(szReadyCfgName, "Practiceogl",   false) != -1;
    } else {
        g_bIsSurf       = false;
        g_bIsGauntlet   = false;
        g_bIsPracticogl = false;
    }
}

void Globals_OnMapStart() {
    if (g_hActiveVote != null) delete g_hActiveVote;
    if (g_hTimerDelay != null) delete g_hTimerDelay;
    // reset vote state each map
    g_votingState        = Voting_Allowed;
    g_iCooldownExpiresIn = 0;
    g_bHasRoundStarted   = false;
    g_bIsSecondHalf      = InSecondHalfOfRound();
    // reset voting counters
    for (int i = 0; i <= MaxClients; i++) {
        g_iVotesCountPerMap[i] = 0;
    }
}

void Globals_OnMapEnd() {
    if (g_hActiveVote != null) delete g_hActiveVote;
    if (g_hTimerDelay != null) delete g_hTimerDelay;
    // reset vote state each map
    g_votingState        = Voting_Allowed;
    g_iCooldownExpiresIn = 0;
    g_bHasRoundStarted   = false;
    g_bIsSecondHalf      = InSecondHalfOfRound();
    // reset voting counters
    for (int i = 0; i <= MaxClients; i++) {
        g_iVotesCountPerMap[i] = 0;
    }
}

void Globals_OnClientConnected(int iClient) {
    g_iVotesCountPerMap[iClient] = 0;
}

void Globals_OnClientDisconnect(int iClient) {
    g_iVotesCountPerMap[iClient] = 0;
}

void Event_RoundStart(Event evt, const char[] szEvtName, bool bDontBroadcast) {
    g_bHasRoundStarted = false;
    g_bIsSecondHalf    = InSecondHalfOfRound();
}

void Event_PlayerLeftSafeArea(Event evt, const char[] szEvtName, bool bDontBroadcast) {
    if (SDK_IsSurvival())   return;
    if (g_bHasRoundStarted) return;
    g_bHasRoundStarted = true;
    HandleVoteEnd();
}

void Event_SurvivalRoundStart(Event evt, const char[] szEvtName, bool bDontBroadcast) {
    if (g_bHasRoundStarted) return;
    g_bHasRoundStarted = true;
    HandleVoteEnd();
}

void Globals_OnRoundIsLive() {
    g_bHasRoundStarted = true;
    HandleVoteEnd();
}

void Globals_OnMixStarted() {
    g_bIsInCaptains = true;
}

void Globals_OnMixStopped() {
    g_bIsInCaptains = false;
}

void HandleVoteEnd() {
    if (SDK_IsVersus() || SDK_IsCoop() || SDK_IsScavenge() || SDK_IsRealism()) {
        if (!NativeVotes_IsVoteInProgress()) return;
        if (!g_voteInstance.BeforeRoundOnly) return;
        NativeVotes_Cancel();
    }
}

void ConVarChange_Gamemode(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    cv.GetString(g_szGameMode, sizeof(g_szGameMode));
    SDK_GetGameModeBase(g_gmBase, sizeof(g_gmBase));
}

void ConVarChange_VoteDelay(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iVoteDelay = cv.IntValue;
    if (g_hTimerDelay != null) {
        g_iCooldownExpiresIn -= StringToInt(szOldVal);
        g_iCooldownExpiresIn += StringToInt(szNewVal);
        if (g_iCooldownExpiresIn <= 0) {
            delete g_hTimerDelay;
            AllowVoting();
        }
    }
}

stock bool InSecondHalfOfRound() {
    return GameRules_GetProp("m_bInSecondHalfOfRound") >= 1;
}

stock int GetTeamHumanCount(int iTeam) {
    int iHumans = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))        continue;
        if (IsFakeClient(i))           continue;
        if (iTeam == TEAM_SPECTATE) {
            if (GetClientTeam(i) == iTeam || TM_IsPlayerRespectating(i)) {
                iHumans++;
            }
        } else {
            if (GetClientTeam(i) == iTeam && !TM_IsPlayerRespectating(i)) {
                iHumans++;
            }
        }
    }
    return iHumans;
}