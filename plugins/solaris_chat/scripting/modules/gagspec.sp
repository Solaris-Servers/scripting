#if defined __GagSpec__
    #endinput
#endif
#define __GagSpec__

#include <solaris/votes>
#include <solaris/team_manager>
#include <solaris/stocks>

/** Variables **/
SolarisVote VoteGagspec;
bool        bIsGaggingSpectators;

void GagSpec_OnModuleStart() {
    RegConsoleCmd("sm_gagspec", Cmd_GagSpec);
}

void GagSpec_OnAllPluginsLoaded() {
    VoteGagspec = (new SolarisVote()).OnSuccess(VoteCallback_GagSpec);
}

Action Cmd_GagSpec(int iClient, int iArgs) {
    // prepare vote title
    char szVotePrint [32] = "";
    char szVoteTitle [32] = "";
    char szVotePassed[32] = "";
    if (!bIsGaggingSpectators) {
        Format(szVotePrint,  sizeof(szVotePrint),  "gagging spectators.");
        Format(szVoteTitle,  sizeof(szVoteTitle),  "Gag spectators?");
        Format(szVotePassed, sizeof(szVotePassed), "Spectators were gagged");
    } else {
        Format(szVotePrint,  sizeof(szVotePrint),  "ungagging spectators.");
        Format(szVoteTitle,  sizeof(szVoteTitle),  "Ungag spectators?");
        Format(szVotePassed, sizeof(szVotePassed), "Spectators were ungagged");
    }
    // start vote
    VoteGagspec.SetPrint(szVotePrint)
               .SetTitle(szVoteTitle)
               .SetSuccessMessage(szVotePassed)
               .Start(iClient);
    return Plugin_Handled;
}

void VoteCallback_GagSpec() {
    bIsGaggingSpectators = !bIsGaggingSpectators;
}

bool GagSpec_OnChatMessage(int iClient, bool bTeamChat) {
    if (bIsGaggingSpectators && !ST_IsAdminClient(iClient))
        bTeamChat = true;
    return bTeamChat;
}