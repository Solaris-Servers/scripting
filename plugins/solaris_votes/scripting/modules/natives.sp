#if defined __solaris_votes_natives_included
    #endinput
#endif
#define __solaris_votes_natives_included

APLRes Natives_AskPluginLoad2() {
    CreateNative("SolarisVote.Start",                     Native_SolarisVote_Start);
    CreateNative("SolarisVote.StartChangeAllTalkVote",    Native_SolarisVote_StartChangeAllTalkVote);
    CreateNative("SolarisVote.StartChangeChapterVote",    Native_SolarisVote_StartChangeChapterVote);
    CreateNative("SolarisVote.StartChangeDifficultyVote", Native_SolarisVote_StartChangeDifficultyVote);
    CreateNative("SolarisVote.StartChangeMissionVote",    Native_SolarisVote_StartChangeMissionVote);
    CreateNative("SolarisVote.StartKickVote",             Native_SolarisVote_StartKickVote);
    CreateNative("SolarisVote.StartRestartVote",          Native_SolarisVote_StartRestartVote);
    CreateNative("SolarisVote.StartReturnToLobbyVote",    Native_SolarisVote_StartReturnToLobbyVote);
    CreateNative("SolarisVote.OnSuccess",                 Native_SolarisVote_OnSuccess);
    CreateNative("SolarisVotes_GetCurrentVotingState",    Native_GetCurrentVotingState);
    CreateNative("SolarisVotes_IsVoteInProgress",         Native_IsVoteInProgress);
    CreateNative("SolarisVotes_IsClientInVotePool",       Native_IsClientInVotePool);
    return APLRes_Success;
}

any Native_SolarisVote_Start(Handle hPlugin, int iNumParams) {
    SolarisVote self = view_as<SolarisVote>(GetNativeCell(1));
    int iClient = GetNativeCell(2);
    return StartVote(iClient, self);
}

any Native_SolarisVote_StartChangeAllTalkVote(Handle hPlugin, int iNumParams) {
    SolarisVote self = view_as<SolarisVote>(GetNativeCell(1));
    int iClient = GetNativeCell(2);
    bool bEnabled = GetNativeCell(3);
    return StartChangeAllTalkVote(iClient, bEnabled, self);
}

any Native_SolarisVote_StartChangeChapterVote(Handle hPlugin, int iNumParams) {
    SolarisVote self = view_as<SolarisVote>(GetNativeCell(1));
    int iClient = GetNativeCell(2);
    char szChNum[128];
    GetNativeString(3, szChNum, sizeof(szChNum));
    return StartChangeChapterVote(iClient, szChNum, self);
}

any Native_SolarisVote_StartChangeDifficultyVote(Handle hPlugin, int iNumParams) {
    SolarisVote self = view_as<SolarisVote>(GetNativeCell(1));
    int iClient = GetNativeCell(2);
    char szDifficulty[128];
    GetNativeString(3, szDifficulty, sizeof(szDifficulty));
    return StartChangeDifficultyVote(iClient, szDifficulty, self);
}

any Native_SolarisVote_StartChangeMissionVote(Handle hPlugin, int iNumParams) {
    SolarisVote self = view_as<SolarisVote>(GetNativeCell(1));
    int iClient = GetNativeCell(2);
    char szCmpCode[128];
    GetNativeString(3, szCmpCode, sizeof(szCmpCode));
    return StartChangeMissionVote(iClient, szCmpCode, self);
}

any Native_SolarisVote_StartKickVote(Handle hPlugin, int iNumParams) {
    SolarisVote self = view_as<SolarisVote>(GetNativeCell(1));
    int iClient = GetNativeCell(2);
    int iTargetId = GetNativeCell(3);
    return StartKickVote(iClient, iTargetId, self);
}

any Native_SolarisVote_StartRestartVote(Handle hPlugin, int iNumParams) {
    SolarisVote self = view_as<SolarisVote>(GetNativeCell(1));
    int iClient = GetNativeCell(2);
    return StartRestartVote(iClient, self);
}

any Native_SolarisVote_StartReturnToLobbyVote(Handle hPlugin, int iNumParams) {
    SolarisVote self = view_as<SolarisVote>(GetNativeCell(1));
    int iClient = GetNativeCell(2);
    return StartReturnToLobbyVote(iClient, self);
}

any Native_SolarisVote_OnSuccess(Handle hPlugin, int iNumParams) {
    SolarisVote self = view_as<SolarisVote>(GetNativeCell(1));
    // VotePassedCallback Callback = view_as<VotePassedCallback>(GetNativeFunction(2));
    Function Callback = GetNativeFunction(2);
    PrivateForward fwd;
    self.GetValue("fwdPassedCb", fwd);
    if (fwd) delete fwd;
    fwd = new PrivateForward(ET_Ignore);
    fwd.AddFunction(hPlugin, Callback);
    self.SetValue("fwdPassedCb", fwd, true);
    return self;
}

any Native_GetCurrentVotingState(Handle hPlugin, int iNumParams) {
    return g_votingState;
}

any Native_IsVoteInProgress(Handle hPlugin, int iNumParams) {
    return g_votingState == Voting_InProgress;
}

any Native_IsClientInVotePool(Handle hPlugin, int iNumParams) {
    if (g_votingState != Voting_InProgress) return false;
    int client = GetNativeCell(1);
    for (int i = 0; i < sizeof(g_iClientsPool); i++) {
        if (g_iClientsPool[i] == client) return true;
    }
    return false;
}