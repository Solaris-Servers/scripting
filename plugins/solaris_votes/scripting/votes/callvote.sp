#if defined __solaris_votes_callvote_included
    #endinput
#endif
#define __solaris_votes_callvote_included

#include <left4dhooks>
#include <l4d2_source_keyvalues>

/** Variables **/

SolarisVote voteLobby;
SolarisVote voteKick;
SolarisVote voteChapter;
SolarisVote voteDifficulty;
SolarisVote voteMission;
SolarisVote voteRestart;
SolarisVote voteAllTalk;

ConVar cvAlltalk;
ConVar cvDifficulty;

bool bShouldRestoreScore;

char szKickTargetIdentity[64];
char szChangeMapOrMissionTo[64];
char szChangeDifficultyTo[16];

int iKickTargetUserId;
int iVersusScores[2];

#include "callvote/menu.sp"

void CallVote_OnPluginStart() {
    MenuInit();
    voteLobby      = (new SolarisVote()).SetPrint("returning to lobby.")
                                        .OnSuccess(VoteCallback_ReturnToLobby);
    voteKick       = (new SolarisVote()).OnSuccess(VoteCallback_KickVote);
    voteChapter    = (new SolarisVote()).AllowOnPracticogl()
                                        .RestrictToGamemodes(GM_SCAV | GM_SURVIVAL)
                                        .OnSuccess(VoteCallback_ChangeChapterVote);
    voteDifficulty = (new SolarisVote()).RestrictFromSurf()
                                        .RestrictFromGauntlet()
                                        .RestrictToGamemodes(GM_COOP | GM_REALISM | GM_HOLDOUT | GM_DASH | GM_SHOOTZONES)
                                        .OnSuccess(VoteCallback_ChangeDifficultyVote);
    voteMission    = (new SolarisVote()).RestrictFromSurf()
                                        .RestrictToGamemodes(GM_VERSUS | GM_COOP | GM_REALISM)
                                        .OnSuccess(VoteCallback_ChangeMissionVote);
    voteRestart    = (new SolarisVote()).SetPrint("restarting the game.")
                                        .RestrictFromSurf()
                                        .RestrictToGamemodes(GM_VERSUS | GM_COOP | GM_SURVIVAL | GM_REALISM | GM_HOLDOUT | GM_DASH | GM_SHOOTZONES)
                                        .OnSuccess(VoteCallback_RestartGameVote);
    voteAllTalk    = (new SolarisVote()).RestrictToGamemodes(GM_VERSUS | GM_SCAV)
                                        .OnSuccess(VoteCallback_ChangeAllTalkVote);

    cvAlltalk    = FindConVar("sv_alltalk");
    cvDifficulty = FindConVar("z_difficulty");

    RegConsoleCmd("sm_votekick", Cmd_VoteKick);
    RegConsoleCmd("sm_vk",       Cmd_VoteKick);

    RegConsoleCmd("sm_callvote", Cmd_CallVote);
    AddCommandListener(CommandListener_CallVote, "callvote");
}

void CallVote_OnMapStart() {
    if (bShouldRestoreScore) {
        GameRules_SetProp("m_iCampaignScore", iVersusScores[0], 4, 0, true);
        GameRules_SetProp("m_iCampaignScore", iVersusScores[1], 4, 1, true);
        L4D2Direct_SetVSCampaignScore(0, iVersusScores[0]);
        L4D2Direct_SetVSCampaignScore(1, iVersusScores[1]);
    } else {
        iVersusScores[0] = L4D2Direct_GetVSCampaignScore(0);
        iVersusScores[1] = L4D2Direct_GetVSCampaignScore(1);
    }
    bShouldRestoreScore = false;
}

Action Cmd_CallVote(int iClient, int iArgs) {
    if (iClient <= 0 || !IsClientInGame(iClient))
        return Plugin_Handled;

    if (iArgs == 0) {
        CreateVoteManagerMenu(iClient);
        return Plugin_Handled;
    }

    char szCVType[32];
    GetCmdArg(1, szCVType, sizeof(szCVType));

    if (strcmp(szCVType, "ReturnToLobby", false) == 0) {
        ReturnToLobbyVote(iClient);
        return Plugin_Handled;
    }

    if (strcmp(szCVType, "Kick", false) == 0) {
        if (iArgs < 2) {
            CreateVoteKickMenu(iClient);
            return Plugin_Handled;
        }

        char szCVArg[128];
        GetCmdArg(2, szCVArg, sizeof(szCVArg));
        KickVote(iClient, szCVArg);
        return Plugin_Handled;
    }

    if (strcmp(szCVType, "ChangeChapter", false) == 0) {
        if (iArgs < 2) {
            CreateChangeChapterMenu(iClient);
            return Plugin_Handled;
        }

        char szCVArg[128];
        GetCmdArg(2, szCVArg, sizeof(szCVArg));
        ChangeChapterVote(iClient, szCVArg, true);
        return Plugin_Handled;
    }

    if (strcmp(szCVType, "ChangeDifficulty", false) == 0) {
        if (iArgs < 2) {
            CreateChangeDifficultyMenu(iClient);
            return Plugin_Handled;
        }

        char szCVArg[128];
        GetCmdArg(2, szCVArg, sizeof(szCVArg));
        ChangeDifficultyVote(iClient, szCVArg);
        return Plugin_Handled;
    }

    if (strcmp(szCVType, "ChangeMission", false) == 0) {
        if (iArgs < 2) {
            CreateChangeMissionMenu(iClient);
            return Plugin_Handled;
        }

        char szCVArg[128];
        GetCmdArg(2, szCVArg, sizeof(szCVArg));
        ChangeMissionVote(iClient, szCVArg);
        return Plugin_Handled;
    }

    if (strcmp(szCVType, "RestartGame", false) == 0) {
        RestartGameVote(iClient);
        return Plugin_Handled;
    }

    if (strcmp(szCVType, "ChangeAllTalk", false) == 0) {
        ChangeAllTalkVote(iClient);
        return Plugin_Handled;
    }

    return Plugin_Handled;
}

Action CommandListener_CallVote(int iClient, const char[] szCommand, int iArgs) {
    return Cmd_CallVote(iClient, iArgs);
}

// Return to lobby
Action ReturnToLobbyVote(int iClient) {
    voteLobby.StartReturnToLobbyVote(iClient);
    return Plugin_Handled;
}

void VoteCallback_ReturnToLobby() {
    StartMessageAll("DisconnectToLobby", USERMSG_RELIABLE);
    EndMessage();
}

// Kick vote
Action KickVote(int iClient, const char[] szKickUserId) {
    int iTargetUserId = StringToInt(szKickUserId);
    int iTargetClient = GetClientOfUserId(iTargetUserId);
    if (iTargetClient <= 0 || !IsClientInGame(iTargetClient) || IsFakeClient(iTargetClient))
        return Plugin_Handled;

    if (iTargetClient == iClient)
        return Plugin_Handled;

    if (ST_IsAntiKickClient(iTargetClient)) {
        CPrintToChatEx(iTargetClient, iClient, "{teamcolor}%N{default} tried to kick {olive}You", iClient);
        CPrintToChatEx(iClient, iTargetClient, "{olive}You{default} cannot kick {teamcolor}%N{default}. This player is {green}PRIVILEGED{default}!", iTargetClient);
        return Plugin_Handled;
    }

    int iCallerTeam = GetClientTeam(iClient);
    int iTargetTeam = GetClientTeam(iTargetClient);
    if (iTargetTeam > TEAM_SPECTATE && iTargetTeam != iCallerTeam)
        return Plugin_Handled;

    if (iTargetTeam != TEAM_SPECTATE && GetTeamHumanCount(iTargetTeam) < 3 && g_cvSurvivorLimit.IntValue != 2 && g_cvInfectedLimit.IntValue != 2) {
        CPrintToChatEx(iClient, iTargetClient, "{olive}You{default} cannot kick {teamcolor}%N{default}. Not enough players {teamcolor}in your team{default}!", iTargetClient);
        return Plugin_Handled;
    }

    char szKickTargetID[64];
    GetClientAuthId(iTargetClient, AuthId_Steam2, szKickTargetID, sizeof(szKickTargetID), true);

    // allow for cross-team vote when kicking spec
    if (iTargetTeam == iCallerTeam)
        voteKick.ForInitiatorTeam();
    else
        voteKick.ForAllPlayers();

    char szVotePrint[128];
    FormatEx(szVotePrint, sizeof(szVotePrint), "kicking {olive}%N{default}.", iTargetClient);

    bool bVoteStarted = voteKick.SetPrint(szVotePrint)
                                .StartKickVote(iClient, iTargetClient);

    if (bVoteStarted) {
        iKickTargetUserId = iTargetUserId;
        strcopy(szKickTargetIdentity, sizeof(szKickTargetIdentity), szKickTargetID);
    }

    return Plugin_Handled;
}

void VoteCallback_KickVote() {
    int iTargetClient = GetClientOfUserId(iKickTargetUserId);
    ST_KickClient(iTargetClient, "You have been voted off.");
    BanIdentity(szKickTargetIdentity, 1, BANFLAG_AUTHID, "You have been voted off.");
    g_smPlayersTemporarilyBanned.SetValue(szKickTargetIdentity, GetTime() + 300, true);
    iKickTargetUserId    = 0;
    szKickTargetIdentity = "";
}

// Change chapter
Action ChangeChapterVote(int iClient, const char[] szMapName, bool bCheckValidity = true) {
    if (bCheckValidity && !IsValidMap(szMapName))
        return Plugin_Handled;

    if (TM_IsReserved())
        return Plugin_Handled;

    char szGmBaseUpper[16];
    ST_StrToUpper(g_gmBase, szGmBaseUpper, sizeof(szGmBaseUpper));

    char szMapNameUpper[16];
    ST_StrToUpper(szMapName, szMapNameUpper, sizeof(szMapNameUpper));
    SplitString(szMapNameUpper, "_", szMapNameUpper, sizeof(szMapNameUpper));

    char szUIChaptername[64];
    FormatEx(szUIChaptername, sizeof(szUIChaptername), "#L4D360UI_LevelName_%s_%s", szGmBaseUpper, szMapNameUpper);

    char szVotePrint[128];
    FormatEx(szVotePrint, sizeof(szVotePrint), "changing chapter to {olive}%t{default}.", szUIChaptername[1]);

    bool bVoteStarted = voteChapter.SetPrint(szVotePrint)
                                   .StartChangeChapterVote(iClient, szUIChaptername);

    if (bVoteStarted)
        strcopy(szChangeMapOrMissionTo, sizeof(szChangeMapOrMissionTo), szMapName);

    return Plugin_Handled;
}

void VoteCallback_ChangeChapterVote() {
    L4D2_ChangeLevel(szChangeMapOrMissionTo);
    szChangeMapOrMissionTo = "";
}

// Change difficulty
Action ChangeDifficultyVote(int iClient, char[] szDifficulty) {
    if (strcmp(szDifficulty, "Easy",       false) != 0 &&
        strcmp(szDifficulty, "Normal",     false) != 0 &&
        strcmp(szDifficulty, "Hard",       false) != 0 &&
        strcmp(szDifficulty, "Impossible", false) != 0)
        return Plugin_Handled;

    ST_StrCapitalizeFirstAndLowerRest(szDifficulty, szDifficulty, 16);

    char szCur[16];
    cvDifficulty.GetString(szCur, sizeof(szCur));
    if (strcmp(szDifficulty, szCur, false) == 0)
        return Plugin_Handled;

    char szUIString[32];
    FormatEx(szUIString, sizeof(szUIString), "#L4D360UI_Difficulty_%s", szDifficulty);

    char szVotePrint[128];
    FormatEx(szVotePrint, sizeof(szVotePrint), "changing difficulty to {olive}%t{default}.", szUIString[1]);

    bool bVoteStarted = voteDifficulty.SetPrint(szVotePrint)
                                      .StartChangeDifficultyVote(iClient, szUIString);

    if (bVoteStarted)
        strcopy(szChangeDifficultyTo, sizeof(szChangeDifficultyTo), szDifficulty);

    return Plugin_Handled;
}

void VoteCallback_ChangeDifficultyVote() {
    cvDifficulty.SetString(szChangeDifficultyTo);
    szChangeDifficultyTo = "";
}

// Change mission
Action ChangeMissionVote(int iClient, const char[] szVoteMission) {
    if (StrContains(szVoteMission, "L4D2C", false) == -1)
        return Plugin_Handled;

    if (TM_IsReserved())
        return Plugin_Handled;

    // reads from string that looks like "L4D2C12" only the campaign number after "L4D2C" part ("12")
    char szMissionNum[4];
    strcopy(szMissionNum, sizeof(szMissionNum), szVoteMission[5]);

    int iMissionNum = 0;
    iMissionNum = StringToInt(szMissionNum);

    if (iMissionNum <= 0 || iMissionNum > 14) {
        return Plugin_Handled;
    }

    // prepare arguments and initiate the vote
    char szMissionName[32];
    FormatEx(szMissionName, sizeof(szMissionName), "#L4D360UI_CampaignTitle_C%i", iMissionNum);

    char szVotePrint[128];
    FormatEx(szVotePrint, sizeof(szVotePrint), "changing campaign to {olive}%t{default}.", szMissionName[1]);

    bool bVoteStarted = voteMission.SetPrint(szVotePrint)
                                   .StartChangeMissionVote(iClient, szMissionName);

    if (bVoteStarted)
        strcopy(szChangeMapOrMissionTo, sizeof(szChangeMapOrMissionTo), szVoteMission);

    return Plugin_Handled;
}

void VoteCallback_ChangeMissionVote() {
    L4D2_ChangeMission(szChangeMapOrMissionTo);
    szChangeMapOrMissionTo = "";
}

// Restart game
Action RestartGameVote(int iClient) {
    bool bVoteStarted = voteRestart.SetRequiredVotes(SDK_HasPlayerInfected() ? RV_MAJORITY : RV_MORETHANHALF)
                                   .StartRestartVote(iClient);

    if (bVoteStarted)
        GetCurrentMap(szChangeMapOrMissionTo, sizeof(szChangeMapOrMissionTo));

    return Plugin_Handled;
}

void VoteCallback_RestartGameVote() {
    if (SDK_HasPlayerInfected()) {
        bShouldRestoreScore = true;
        L4D2_ChangeLevel(szChangeMapOrMissionTo);
        szChangeMapOrMissionTo = "";
        return;
    }

    FindConVar("mp_restartgame").SetInt(1);
}

// Change alltalk
Action ChangeAllTalkVote(int iClient) {
    char szVotePrint[32];
    FormatEx(szVotePrint, sizeof(szVotePrint), "turning all talk %s.", !cvAlltalk.BoolValue ? "on" : "off");

    voteAllTalk.SetPrint(szVotePrint)
               .SetRequiredVotes(!cvAlltalk.BoolValue ? RV_MAJORITY : RV_HALF)
               .StartChangeAllTalkVote(iClient, !cvAlltalk.BoolValue);

    return Plugin_Handled;
}

void VoteCallback_ChangeAllTalkVote() {
    cvAlltalk.SetBool(!cvAlltalk.BoolValue);
}

// Some Stuff
bool IsValidMap(const char[] szBuffer) {
    int iDummy;
    static char szSubName[256], szMap[256], szKey[256];
    SourceKeyValues kvDummy;
    SourceKeyValues kvMissions = kvDummy.GetAllMissions();
    for (SourceKeyValues kvSub = kvMissions.GetFirstTrueSubKey(); !kvSub.IsNull(); kvSub = kvSub.GetNextTrueSubKey()) {
        kvSub.GetName(szSubName, sizeof(szSubName));
        if (smExcludeMissions.GetValue(szSubName, iDummy))
            continue;

        FormatEx(szKey, sizeof(szKey), "modes/%s", g_szGameMode);
        if (kvSub.FindKey(szKey).IsNull())
            continue;

        if (!kvSub.GetInt("builtin"))
            continue;

        FormatEx(szKey, sizeof(szKey), "%s/modes/%s", szSubName, g_szGameMode);
        SourceKeyValues kvChapters = kvMissions.FindKey(szKey);
        if (kvChapters.IsNull())
            continue;

        for (SourceKeyValues kvSub2 = kvChapters.GetFirstTrueSubKey(); !kvSub2.IsNull(); kvSub2 = kvSub2.GetNextTrueSubKey()) {
            kvSub2.GetString("Map", szMap, sizeof(szMap), "N/A");
            if (strcmp(szBuffer, szMap) == 0)
                return true;
        }
    }

    return false;
}

Action CallVote_OnClientPreConnect(const char[] szSteamId, char szRejectReason[255]) {
    int iUnbanTime;
    if (g_smPlayersTemporarilyBanned.GetValue(szSteamId, iUnbanTime)) {
        int iCurrentTime = GetTime();
        if (iCurrentTime < iUnbanTime) {
            FormatEx(szRejectReason, sizeof(szRejectReason), "You are banned for %d second%s", iUnbanTime - iCurrentTime, iUnbanTime - iCurrentTime > 1 ? "s" : "");
            return Plugin_Stop;
        }

        g_smPlayersTemporarilyBanned.Remove(szSteamId);
    }

    return Plugin_Continue;
}