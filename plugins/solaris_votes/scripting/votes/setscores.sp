#if defined __solaris_votes_setscores_included
    #endinput
#endif
#define __solaris_votes_setscores_included

#include <solaris/stocks>

/** Variables **/
SolarisVote voteScores;

int iSurvivorScore;
int iInfectedScore;

void Scores_OnPluginStart() {
    voteScores = (new SolarisVote()).RestrictToGamemodes(GM_VERSUS)
                                    .SetRequiredVotes(RV_MORETHANHALF)
                                    .RestrictToFirstHalf()
                                    .RestrictToBeforeRoundStart()
                                    .OnSuccess(VoteCallback_Scores_Set);

    RegConsoleCmd("sm_setscores", Cmd_SetScores);
}

Action Cmd_SetScores(int iClient, int iArgs) {
    if (iClient <= 0)
        return Plugin_Handled;

    if (!IsClientInGame(iClient))
        return Plugin_Handled;

    if (!SDK_IsVersus())
        return Plugin_Continue;

    if (iArgs < 2) {
        CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} Usage: {olive}!setscores{default} <{olive}survivor score{default}> <{olive}infected score{default}>.");
        return Plugin_Handled;
    }

    char szScoresArg[16];

    GetCmdArg(1, szScoresArg, sizeof(szScoresArg));
    int iTmpSurvivorScore = StringToInt(szScoresArg);

    GetCmdArg(2, szScoresArg, sizeof(szScoresArg));
    int iTmpInfectedScore = StringToInt(szScoresArg);

    // prepare vote title
    char szVotePrint[128];
    FormatEx(szVotePrint, sizeof(szVotePrint), "setting scores to {olive}%i{default} - {green}%i{default}.", iTmpSurvivorScore, iTmpInfectedScore);

    char szVoteTitle[64];
    FormatEx(szVoteTitle, sizeof(szVoteTitle), "Set scores to %i - %i?", iTmpSurvivorScore, iTmpInfectedScore);

    char szVotePassed[64];
    FormatEx(szVotePassed, sizeof(szVotePassed), "Scores were changed to %i - %i", iTmpSurvivorScore, iTmpInfectedScore);

    // start vote
    bool bVoteStarted = voteScores.SetPrint(szVotePrint)
                                  .SetTitle(szVoteTitle)
                                  .SetSuccessMessage(szVotePassed)
                                  .Start(iClient);

    if (bVoteStarted) {
        iSurvivorScore = iTmpSurvivorScore;
        iInfectedScore = iTmpInfectedScore;
    }

    return Plugin_Handled;
}

void VoteCallback_Scores_Set() {
    // Determine which teams are which
    bool bFlipped = view_as<bool>(GameRules_GetProp("m_bAreTeamsFlipped"));
    SDK_SetCampaignScores(bFlipped ? iInfectedScore : iSurvivorScore, bFlipped ? iSurvivorScore : iInfectedScore); // visible scores

    int iSurvivorTeamIndex = bFlipped ? 1 : 0;
    L4D2Direct_SetVSCampaignScore(iSurvivorTeamIndex, iSurvivorScore); // real scores

    int iInfectedTeamIndex = bFlipped ? 0 : 1;
    L4D2Direct_SetVSCampaignScore(iInfectedTeamIndex, iInfectedScore); // real scores
}