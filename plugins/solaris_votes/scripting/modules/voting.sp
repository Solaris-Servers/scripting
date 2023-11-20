#if defined __solaris_votes_voting_included
    #endinput
#endif
#define __solaris_votes_voting_included

void Voting_OnPluginStart() {
    RegConsoleCmd("sm_veto", Cmd_VetoVote);
    RegConsoleCmd("sm_pass", Cmd_PassVote);
}

bool _PreVote(int iClient) {
    VotePermission vp = GetVoteStartPermission(iClient);
    if (vp != VotePermission_Allowed) {
        PrintRefusalToClient(iClient, vp);
        return false;
    }
    PutVotingInProgress();
    return true;
}

bool StartVote(int iClient, SolarisVote instance) {
    g_voteInstance = instance;
    if (!_PreVote(iClient))
        return false;
    g_iVotesCountPerMap[iClient]++;
    char szVoteTitle[256], szVotePassedMsg[128];
    g_voteInstance.GetTitle(szVoteTitle, sizeof(szVoteTitle));
    g_voteInstance.GetSuccessMessage(szVotePassedMsg, sizeof(szVotePassedMsg));
    g_hActiveVote = new NativeVote(Handler_VoteAction, NativeVotesType_Custom_YesNo, NATIVEVOTES_ACTIONS_DEFAULT | MenuAction_Select);
    g_hActiveVote.SetTitle(szVoteTitle);
    g_hActiveVote.Initiator = iClient;
    g_hActiveVote.VoteResultCallback = Handler_VoteResult;
    DisplayVote(iClient);
    return true;
}

void DisplayVote(int iClient) {
    if (g_hActiveVote == null)
        return;

    int iPoolClientCount = 0;

    for (int i = 0; i < sizeof(g_iClientsPool); i++) {
        g_iClientsPool[i] = 0;
    }
    
    if (g_voteInstance.Pool != POOL_ALL_NON_SPEC) {
        iPoolClientCount = CreateTeamOnlyPool(g_iClientsPool, GetClientTeam(iClient));
    } else {
        iPoolClientCount = CreatePlayersOnlyPool(g_iClientsPool);
    }

    char szVotePrint[256];
    g_voteInstance.GetPrint(szVotePrint, sizeof(szVotePrint));
    NotifyVoteToChat(iClient, szVotePrint);
    g_hActiveVote.DisplayVote(g_iClientsPool, iPoolClientCount, g_cvVoteTimerDuration.IntValue);
}

public int Handler_VoteAction(NativeVote hVote, MenuAction maAction, int iParam1, int iParam2) {
    switch(maAction) {
        case MenuAction_Select: {
            NotifyChoiceToChat(iParam1, iParam2);
        }
        case MenuAction_End: {
            CreateTimer(3.0, PutVotingInCooldown, _, TIMER_FLAG_NO_MAPCHANGE);
            hVote.Close();
            g_hActiveVote = null;
        }
        case MenuAction_VoteCancel: {
            hVote.DisplayFail();
        }
    }
    return 0;
}

/**
 * Vote result handler
 *
 * @param   hVote           NativeVote of vote being voted on
 * @param   iVoteCount      Count of clients voted Yes/No
 * @param   iClientCount    Count of total clients eligible to participate in a vote
 * @param   iClients        An array of client indicies elibible to participate in a vote
 * @param   iVotes          An array of vote decisions made by clients
 * @param   iItemCount      Number of unique items that were selected
 * @param   iItems          An array of vote item indexes
 * @param   iItemVotes      An array of vote vote count
 * @return  int             Result of the vote
 */
public int Handler_VoteResult(NativeVote hVote, int iVoteCount, int iClientCount, const int[] iClients, const int[] iVotes, int iItemCount, const int[] iItems, const int[] iItemVotes) {
    /** - - -
        if not enough players, reject a vote!
                                         - - - **/
    if (g_voteInstance.RequiredPlayers != 0) {
        int iNumPlayers;
        for (int cl = 1; cl <= MaxClients; cl++) {
            if (!IsClientInGame(cl) || IsFakeClient(cl)) {
                continue;
            }
            if (g_voteInstance.Pool == POOL_ALL_NON_SPEC && (GetClientTeam(cl) == TEAM_SPECTATE || TM_IsPlayerRespectating(cl))) {
                continue;
            } else if (g_voteInstance.Pool == POOL_SURVIVORS && (GetClientTeam(cl) != TEAM_SURVIVORS || TM_IsPlayerRespectating(cl))) {
                continue;
            } else if (g_voteInstance.Pool == POOL_INFECTED && (GetClientTeam(cl) != TEAM_INFECTED || TM_IsPlayerRespectating(cl))) {
                continue;
            } else if (g_voteInstance.Pool == POOL_SPECTATORS && (GetClientTeam(cl) != TEAM_SPECTATE && !TM_IsPlayerRespectating(cl))) {
                continue;
            }
            for (int i = 0; i < sizeof(g_iClientsPool); i++) {
                if (g_iClientsPool[i] == cl) {
                    iNumPlayers++;
                }
            }
        }
        if (iNumPlayers < g_voteInstance.RequiredPlayers) {
            hVote.DisplayFail();
            return 0;
        }
    }
    /** - - -
        summarize choices
                     - - - **/
    int iYesVotes = 0;
    int iNoVotes  = 0;
    int arr_iYesVoteByTeam[4] = {0, 0, 0};
    int arr_iNoVotesByTeam[4] = {0, 0, 0};
    int arr_iClientCountByTeam[4] = {0, 0, 0};
    for (int i = 0; i < iClientCount; i++) {
        arr_iClientCountByTeam[GetClientTeam(iClients[i])]++;
        if (iVotes[i] == NATIVEVOTES_VOTE_YES) {
            iYesVotes++;
            arr_iYesVoteByTeam[GetClientTeam(iClients[i])]++;
        }
        if (iVotes[i] == NATIVEVOTES_VOTE_NO)  {
            iNoVotes++;
            arr_iNoVotesByTeam[GetClientTeam(iClients[i])]++;
        }
    }
    /** - - -
        vote result
               - - - **/
    bool bPassed = false;
    if (g_voteInstance.RequiredVotesFlags == RV_DEFAULT && iYesVotes > iNoVotes) {
        bPassed = true;
    } else if (g_voteInstance.RequiredVotesFlags == RV_HALF && iYesVotes >= iNoVotes) {
        bPassed = true;
    } else if (g_voteInstance.RequiredVotesFlags == RV_MORETHANHALF && iYesVotes > (iClientCount / 2)){
        bPassed = true;
    } else if (g_voteInstance.RequiredVotesFlags == RV_MAJORITY) {
        if (GetTeamHumanCount(TEAM_SURVIVORS) > 0 && GetTeamHumanCount(TEAM_INFECTED) > 0) {
            if (arr_iYesVoteByTeam[TEAM_SURVIVORS] > (arr_iClientCountByTeam[TEAM_SURVIVORS] / 2) &&
                arr_iYesVoteByTeam[TEAM_INFECTED]  > (arr_iClientCountByTeam[TEAM_INFECTED]  / 2))
                bPassed = true;
        } else if (GetTeamHumanCount(TEAM_SURVIVORS) > 0 && GetTeamHumanCount(TEAM_INFECTED) == 0) {
            if (arr_iYesVoteByTeam[TEAM_SURVIVORS] > (arr_iClientCountByTeam[TEAM_SURVIVORS] / 2))
                bPassed = true;
        } else if (GetTeamHumanCount(TEAM_SURVIVORS) == 0 && GetTeamHumanCount(TEAM_INFECTED) > 0) {
            if (arr_iYesVoteByTeam[TEAM_INFECTED] > (arr_iClientCountByTeam[TEAM_INFECTED] / 2))
                bPassed = true;
        }
    }
    if (bPassed) {
        char szVotePassedMsg[128];
        g_voteInstance.GetSuccessMessage(szVotePassedMsg, sizeof(szVotePassedMsg));
        if (strlen(szVotePassedMsg) > 0) {
            // custom pass message
            hVote.DisplayPassCustom(szVotePassedMsg);
        } else {
            // default or pre-determined pass message
            char szVoteDetails[128];
            hVote.GetDetails(szVoteDetails, sizeof(szVoteDetails));
            hVote.DisplayPass(szVoteDetails);
        }
        // execute vote success callback
        CreateTimer(g_cvVoteCommandDelay.FloatValue, Timer_ExecuteVoteCallback, _, TIMER_FLAG_NO_MAPCHANGE);
    } else {
        hVote.DisplayFail();
    }
    return 0;
}

Action Timer_ExecuteVoteCallback(Handle hTimer) {
    PrivateForward fwd;
    g_voteInstance.GetValue("fwdPassedCb", fwd);
    Call_StartForward(fwd);
    Call_Finish();
    return Plugin_Stop;
}

/**
 * Check if vote can be initiated by the client
 *
 * @param   iClient         Client index
 * @param   iVoteFlags=0    Vote settings flags bitmask
 * @return  VotePermission  Permission. Only VotePermission_Allowed will indicate ability to start a vote
 */
VotePermission GetVoteStartPermission(int iClient) {
    if (g_voteInstance.GamemodeFlags != GM_DEFAULT) {
        bool bGameModeAllowed = false;
        if (g_voteInstance.GamemodeFlags & GM_VERSUS && SDK_IsVersus())
            bGameModeAllowed = true;
        if (g_voteInstance.GamemodeFlags & GM_COOP && SDK_IsCoop())
            bGameModeAllowed = true;
        if (g_voteInstance.GamemodeFlags & GM_SCAV && SDK_IsScavenge())
            bGameModeAllowed = true;
        if (g_voteInstance.GamemodeFlags & GM_SURVIVAL && SDK_IsSurvival())
            bGameModeAllowed = true;
        if (g_voteInstance.GamemodeFlags & GM_REALISM && SDK_IsRealism())
            bGameModeAllowed = true;
        if (g_voteInstance.GamemodeFlags & GM_HOLDOUT && strcmp(g_gmBase, "holdout", false) == 0)
            bGameModeAllowed = true;
        if (g_voteInstance.GamemodeFlags & GM_DASH && strcmp(g_gmBase, "dash", false) == 0)
            bGameModeAllowed = true;
        if (g_voteInstance.GamemodeFlags & GM_SHOOTZONES && strcmp(g_gmBase, "shootzones", false) == 0)
            bGameModeAllowed = true;
        if (g_voteInstance.AllowedOnPracticogl && g_bIsPracticogl)
            bGameModeAllowed = true;
        if (!bGameModeAllowed)
            return VotePermission_GMDisallowed;
    }

    if (!TM_IsFinishedLoading())                                return VotePermission_InLoading;
    if (g_votingState == Voting_InProgress)                     return VotePermission_InProgress;
    if (g_votingState == Voting_InCooldown)                     return VotePermission_InCooldown;
    if (g_bIsInCaptains)                                        return VotePermission_CaptainsModeActive;
    if (g_voteInstance.FirstHalfOnly && g_bIsSecondHalf)        return VotePermission_NotInFirstHalf;
    if (g_voteInstance.BeforeRoundOnly && g_bHasRoundStarted)   return VotePermission_RoundStarted;
    if (g_voteInstance.RestrictedFromSurf && g_bIsSurf)         return VotePermission_RestrictedFromSurf;
    if (g_voteInstance.RestrictedFromGauntlet && g_bIsGauntlet) return VotePermission_RestrictedFromGauntlet;
    if (!IsClientInGame(iClient))                               return VotePermission_NotInGame;
    if (IsFakeClient(iClient))                                  return VotePermission_FakeClient;
    if (ST_IsSpecClient(iClient))                               return VotePermission_Spectator;
    if (TM_IsPlayerRespectating(iClient))                       return VotePermission_Spectator;
    if (NativeVotes_IsVoteInProgress())                         return VotePermission_NVNotAllowed;

    int iClientTeam = GetClientTeam(iClient);
    if (g_voteInstance.Pool == POOL_SPECTATORS && (iClientTeam != TEAM_SPECTATE && !TM_IsPlayerRespectating(iClient)))
        return VotePermission_NotInPool;
    if (g_voteInstance.Pool == POOL_SURVIVORS && (iClientTeam != TEAM_SURVIVORS || TM_IsPlayerRespectating(iClient)))
        return VotePermission_NotInPool;
    if (g_voteInstance.Pool == POOL_INFECTED && (iClientTeam != TEAM_INFECTED || TM_IsPlayerRespectating(iClient)))
        return VotePermission_NotInPool;

    if (g_voteInstance.RequiredPlayers != 0) {
        int iNumPlayers;
        for (int cl = 1; cl <= MaxClients; cl++) {
            if (!IsClientInGame(cl) || IsFakeClient(cl))
                continue;
            if (g_voteInstance.Pool == POOL_ALL_NON_SPEC && (GetClientTeam(cl) == TEAM_SPECTATE || TM_IsPlayerRespectating(cl))) {
                continue;
            } else if (g_voteInstance.Pool == POOL_INITIATOR_TEAM && (GetClientTeam(cl) != iClientTeam || TM_IsPlayerRespectating(cl))) {
                continue;
            } else if (g_voteInstance.Pool == POOL_SURVIVORS && (GetClientTeam(cl) != TEAM_SURVIVORS || TM_IsPlayerRespectating(cl))) {
                continue;
            } else if (g_voteInstance.Pool == POOL_INFECTED && (GetClientTeam(cl) != TEAM_INFECTED || TM_IsPlayerRespectating(cl))) {
                continue;
            } else if (g_voteInstance.Pool == POOL_SPECTATORS && (GetClientTeam(cl) != TEAM_SPECTATE && !TM_IsPlayerRespectating(cl))) {
                continue;
            }
            iNumPlayers++;
        }
        if (iNumPlayers < g_voteInstance.RequiredPlayers)
            return VotePermission_NotEnoughPlayers;
    }
    return VotePermission_Allowed;
}

/**
 * Put voting in progress
 *
 * @noreturn
 */
void PutVotingInProgress() {
    g_votingState = Voting_InProgress;
    g_voteInstance.HasStarted = true;
}

/**
 * Start voting cooldown for the length of the duration of the active vote
 *
 * @noreturn
 */
Action PutVotingInCooldown(Handle hTimer) {
    g_votingState             = Voting_InCooldown;
    g_voteInstance.HasStarted = false;
    g_iCooldownExpiresIn      = g_iVoteDelay;
    AllowVotingAfterDelay();
    for (int i = 0; i < sizeof(g_iClientsPool); i++) {
        g_iClientsPool[i] = 0;
    }
    return Plugin_Stop;
}

/**
 * Starts a Timer to reset VoteState and allow voting
 *
 * @noreturn
 */
void AllowVotingAfterDelay() {
    if (g_votingState != Voting_Allowed) {
        g_hTimerDelay = CreateTimer(1.0, Timer_AllowVoting, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    }
}

/**
 * Timer Callback. Resets VoteState allowing to create new votes.
 *
 * @param   hTimer          Timer Handle
 * @noreturn
 */
Action Timer_AllowVoting(Handle hTimer) {
    g_iCooldownExpiresIn--;
    if (g_iCooldownExpiresIn > 0)
        return Plugin_Continue;
    AllowVoting();
    return Plugin_Stop;
}

/**
 * Resets VoteState allowing to create new votes.
 *
 * @noreturn
 */
void AllowVoting() {
    g_votingState  = Voting_Allowed;
    g_voteInstance = null;
    g_hTimerDelay  = null;
    g_iCooldownExpiresIn = 0;
    for (int i = 0; i < sizeof(g_iClientsPool); i++) {
        g_iClientsPool[i] = 0;
    }
}

/**
 * Veto vote
 */
Action Cmd_VetoVote(int iClient, int iArgs) {
    VetoVote(iClient);
    return Plugin_Handled;
}

void VetoVote(int iClient) {
    if (ST_IsAdminClient(iClient) && NativeVotes_IsVoteInProgress()) {
        char szVotePrint[256];
        g_voteInstance.GetPrint(szVotePrint, sizeof(szVotePrint));
        NotifyPassVetoToChat(iClient, VETO, szVotePrint);
        NativeVotes_Cancel();
    }
}

/**
 * Pass vote
 */
Action Cmd_PassVote(int iClient, int iArgs) {
    PassVote(iClient);
    return Plugin_Handled;
}

void PassVote(int iClient) {
    if (ST_IsAdminClient(iClient) && NativeVotes_IsVoteInProgress()) {
        char szVotePrint[256];
        g_voteInstance.GetPrint(szVotePrint, sizeof(szVotePrint));
        NotifyPassVetoToChat(iClient, PASS, szVotePrint);
        NativeVotes_Pass();
    }
}

/**
 * Print admin action
 */
void NotifyPassVetoToChat(int iClient, int iAction, const char[] szBuffer) {
    int iPrintType = g_cvVoteNotifyToChat.IntValue;
    if (iPrintType <= 0)
        return;
    if (iPrintType == 2) {
        CPrintToChatAllEx(iClient, "{teamcolor}%N{default} has %s a vote for %s", iClient, (iAction == VETO ? "vetoed" : "passed"), szBuffer);
    } else if (iPrintType == 1) {
        for (int cl = 1; cl <= MaxClients; cl++) {
            if (!IsClientInGame(cl))
                continue;
            if (ST_IsAdminClient(cl) || (IsFakeClient(cl) && IsClientSourceTV(cl))) {
                CPrintToChatEx(cl, iClient, "{teamcolor}%N{default} has %s a vote for %s", iClient, (iAction == VETO ? "vetoed" : "passed"), szBuffer);
            }
        }
    }
}

/**
 * Print the vote type
 */
void NotifyVoteToChat(int iClient, const char[] szBuffer) {
    int iPrintType = g_cvVoteNotifyToChat.IntValue;

    if (iPrintType <= 0)
        return;

    if (iPrintType == 2 || g_voteInstance.PrintToAll) {
        CPrintToChatAllEx(iClient, "{teamcolor}%N{default} has started a vote for %s", iClient, szBuffer);
    } else if (iPrintType == 1) {
        bool bPrint = false;

        for (int cl = 1; cl <= MaxClients; cl++) {
            if (!IsClientInGame(cl))
                continue;

            bPrint = (ST_IsAdminClient(cl) || (IsFakeClient(cl) && IsClientSourceTV(cl)));

            for (int i = 0; i < sizeof(g_iClientsPool); i++) {
                if (g_iClientsPool[i] == cl)
                    bPrint = true;
            }

            if (bPrint) CPrintToChatEx(cl, iClient, "{teamcolor}%N{default} has started a vote for %s", iClient, szBuffer);

            bPrint = false;
        }
    }
}

/**
 * Print the choice
 */
void NotifyChoiceToChat(int iClient, int iChoice) {
    if (g_cvVoteNotifyToChat.IntValue <= 0)
        return;
    
    bool bAdmOnly = g_cvVoteNotifyToChat.IntValue == 1;
    if (!bAdmOnly) {
        if (iChoice == NATIVEVOTES_VOTE_YES) CPrintToChatAllEx(iClient, "{teamcolor}%N{default} has voted for {olive}Yes", iClient);
        if (iChoice == NATIVEVOTES_VOTE_NO)  CPrintToChatAllEx(iClient, "{teamcolor}%N{default} has voted for {olive}No",  iClient);
    } else {
        for (int cl = 1; cl <= MaxClients; cl++) {
            if (!IsClientInGame(cl))
                continue;
            if (ST_IsAdminClient(cl) || (IsFakeClient(cl) && IsClientSourceTV(cl))) {
                if (iChoice == NATIVEVOTES_VOTE_YES) CPrintToChatEx(cl, iClient, "{teamcolor}%N{default} has voted for {olive}Yes", iClient);
                if (iChoice == NATIVEVOTES_VOTE_NO)  CPrintToChatEx(cl, iClient, "{teamcolor}%N{default} has voted for {olive}No",  iClient);
            }
        }
    }
}

/**
 * Print the refusual reason
 */
void PrintRefusalToClient(int iClient, VotePermission vp) {
    switch (vp) {
        case VotePermission_InLoading:
            CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} Please wait for others. {olive}%is{default} remaining!", TM_LoadingTimeRemaining());
        case VotePermission_NVNotAllowed, VotePermission_InProgress:
            CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} Please wait for current vote to finish before calling another vote.");
        case VotePermission_InCooldown: {
            char szTimeLeft[16];
            if (g_iCooldownExpiresIn > 0)
                FormatEx(szTimeLeft, sizeof(szTimeLeft), "%is ", g_iCooldownExpiresIn);
            CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} Please wait {green}%s{default}before calling another vote.", szTimeLeft);
        }
        case VotePermission_CaptainsModeActive:
            CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} Please wait for the end of picking teams.");
        case VotePermission_Spectator:
            CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} Spectators are not allowed to call this vote.");
        case VotePermission_NotInFirstHalf:
            CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} This vote can be only started in first half of the round.");
        case VotePermission_RoundStarted:
            CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} This vote can be only started before the start of the game.");
        case VotePermission_NotEnoughPlayers:
            CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} Not enough players to start the vote.");
    }
}

/**
 * Vote flavors by issue type (predefined text)
 */
bool StartChangeAllTalkVote(int iClient, bool bEnable, SolarisVote instance) {
    g_voteInstance = instance;
    if (!_PreVote(iClient))
        return false;
    g_hActiveVote = new NativeVote(Handler_VoteAction, bEnable ? NativeVotesType_AlltalkOn : NativeVotesType_AlltalkOff, NATIVEVOTES_ACTIONS_DEFAULT | MenuAction_Select);
    g_hActiveVote.Initiator = iClient;
    g_hActiveVote.VoteResultCallback = Handler_VoteResult;
    DisplayVote(iClient);
    return true;
}

bool StartChangeChapterVote(int iClient, const char[] szChNum, SolarisVote instance) {
    g_voteInstance = instance;
    if (!_PreVote(iClient))
        return false;
    g_hActiveVote = new NativeVote(Handler_VoteAction, NativeVotesType_ChgLevel, NATIVEVOTES_ACTIONS_DEFAULT | MenuAction_Select);
    g_hActiveVote.Initiator = iClient;
    g_hActiveVote.SetDetails(szChNum);
    g_hActiveVote.VoteResultCallback = Handler_VoteResult;
    DisplayVote(iClient);
    return true;
}

bool StartChangeDifficultyVote(int iClient, const char[] szDifficulty, SolarisVote instance) {
    g_voteInstance = instance;
    if (!_PreVote(iClient))
        return false;
    g_hActiveVote = new NativeVote(Handler_VoteAction, NativeVotesType_ChgDifficulty, NATIVEVOTES_ACTIONS_DEFAULT | MenuAction_Select);
    g_hActiveVote.Initiator = iClient;
    g_hActiveVote.SetDetails(szDifficulty);
    g_hActiveVote.VoteResultCallback = Handler_VoteResult;
    DisplayVote(iClient);
    return true;
}

bool StartChangeMissionVote(int iClient, const char[] szCmpCode, SolarisVote instance) {
    g_voteInstance = instance;
    if (!_PreVote(iClient))
        return false;
    g_hActiveVote = new NativeVote(Handler_VoteAction, NativeVotesType_ChgCampaign, NATIVEVOTES_ACTIONS_DEFAULT | MenuAction_Select);
    g_hActiveVote.Initiator = iClient;
    g_hActiveVote.SetDetails(szCmpCode);
    g_hActiveVote.VoteResultCallback = Handler_VoteResult;
    DisplayVote(iClient);
    return true;
}

bool StartKickVote(int iClient, int iTargetClient, SolarisVote instance) {
    g_voteInstance = instance;
    if (!_PreVote(iClient))
        return false;
    g_hActiveVote = new NativeVote(Handler_VoteAction, NativeVotesType_Kick, NATIVEVOTES_ACTIONS_DEFAULT | MenuAction_Select);
    g_hActiveVote.Initiator = iClient;
    g_hActiveVote.SetTarget(iTargetClient);
    g_hActiveVote.VoteResultCallback = Handler_VoteResult;
    DisplayVote(iClient);
    return true;
}

bool StartRestartVote(int iClient, SolarisVote instance) {
    g_voteInstance = instance;
    if (!_PreVote(iClient))
        return false;
    g_hActiveVote = new NativeVote(Handler_VoteAction, NativeVotesType_Restart, NATIVEVOTES_ACTIONS_DEFAULT | MenuAction_Select);
    g_hActiveVote.Initiator = iClient;
    g_hActiveVote.VoteResultCallback = Handler_VoteResult;
    DisplayVote(iClient);
    return true;
}

bool StartReturnToLobbyVote(int iClient, SolarisVote instance) {
    g_voteInstance = instance;
    if (!_PreVote(iClient))
        return false;
    g_hActiveVote = new NativeVote(Handler_VoteAction, NativeVotesType_ReturnToLobby, NATIVEVOTES_ACTIONS_DEFAULT | MenuAction_Select);
    g_hActiveVote.Initiator = iClient;
    g_hActiveVote.VoteResultCallback = Handler_VoteResult;
    DisplayVote(iClient);
    return true;
}