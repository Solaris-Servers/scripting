#if defined __solaris_votes_password_included
    #endinput
#endif
#define __solaris_votes_password_included

ConVar cvPasswordEnabled;
ConVar cvPasswordBuffer;

SolarisVote votePasswordSet;
SolarisVote votePasswordRM;

bool bPasswordEnabled;

char szListOfChar[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
char szSetPassword[9];
char szPassword[9];
char szServerIp[32];

int iPwdLen      = sizeof(szSetPassword) - 1;
int iAlphabetLen = sizeof(szListOfChar)  - 1;
int iServerPort;

void Password_OnPluginStart() {
    votePasswordSet = (new SolarisVote()).OnSuccess(VoteCallback_Password_Set);

    votePasswordRM  = (new SolarisVote()).SetPrint("removing the password.")
                                         .SetTitle("Remove the password?")
                                         .SetSuccessMessage("Password was removed")
                                         .OnSuccess(VoteCallback_Password_Remove);

    cvPasswordEnabled = CreateConVar(
    "sm_server_password_set", "0",
    "Is Password Set?",
    FCVAR_PROTECTED|FCVAR_UNLOGGED|FCVAR_DONTRECORD, true, 0.0, true, 1.0);
    bPasswordEnabled = cvPasswordEnabled.BoolValue;
    cvPasswordEnabled.AddChangeHook(ConVarChanged);

    cvPasswordBuffer = CreateConVar(
    "sm_server_password", "",
    "Server Password",
    FCVAR_PROTECTED|FCVAR_UNLOGGED|FCVAR_DONTRECORD);
    cvPasswordBuffer.GetString(szPassword, sizeof(szPassword));
    cvPasswordBuffer.AddChangeHook(ConVarChanged);

    RegConsoleCmd("sm_cw",       Cmd_GeneratePassword);
    RegConsoleCmd("sm_pub",      Cmd_RemovePassword);
    RegConsoleCmd("sm_password", Cmd_ShowPassword);
    RegConsoleCmd("sm_pw",       Cmd_ShowPassword);
}

void Password_OnPluginEnd() {
    cvPasswordEnabled.SetBool(false);
    cvPasswordBuffer.SetString("");
}

void ConVarChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    bPasswordEnabled = cvPasswordEnabled.BoolValue;
    cvPasswordBuffer.GetString(szPassword, sizeof(szPassword));
}

void Password_OnConfigsExecuted() {
    GetIp();
}

Action Cmd_GeneratePassword(int iClient, int iArgs) {
    if (iClient <= 0 || !IsClientInGame(iClient))
        return Plugin_Handled;

    // prepare vote title
    char szVotePrint[32];
    FormatEx(szVotePrint, sizeof(szVotePrint), bPasswordEnabled ? "setting a new password." : "setting a password.");

    char szVoteTitle[32];
    FormatEx(szVoteTitle, sizeof(szVoteTitle), bPasswordEnabled ? "Set a new password?" : "Set a password?");

    char szVotePassed[32];
    FormatEx(szVotePassed, sizeof(szVotePassed), bPasswordEnabled ? "Password was changed" : "Password was set");

    // start vote
    votePasswordSet.SetPrint(szVotePrint)
                   .SetTitle(szVoteTitle)
                   .SetSuccessMessage(szVotePassed)
                   .Start(iClient);

    return Plugin_Handled;
}

void VoteCallback_Password_Set() {
    char szSteamId[32];
    for (int i = 0; i < iPwdLen; i++) {
        szSetPassword[i] = szListOfChar[GetRandomInt(0, iAlphabetLen - 1)];
    }

    cvPasswordEnabled.SetBool(true);
    cvPasswordBuffer.SetString(szSetPassword);
    g_smPlayersWithoutPassword.Clear();

    for (int cl = 1; cl <= MaxClients; cl++) {
        if (!IsClientInGame(cl))
            continue;

        if (!GetClientAuthId(cl, AuthId_Engine, szSteamId, sizeof(szSteamId), false))
            continue;

        g_smPlayersWithoutPassword.SetValue(szSteamId, true);
    }

    CPrintToChatAll("{blue}[{default}Password{blue}]{default} Server password was set. Type {olive}!pw{default} to see {green}password{default}.");
}

Action Cmd_RemovePassword(int iClient, int iArgs) {
    if (iClient <= 0 || !IsClientInGame(iClient))
        return Plugin_Handled;

    if (!bPasswordEnabled) {
        CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} Password isn't set.");
        return Plugin_Handled;
    }

    // start vote
    votePasswordRM.Start(iClient);
    return Plugin_Handled;
}

void VoteCallback_Password_Remove() {
    cvPasswordEnabled.SetBool(false);
    cvPasswordBuffer.SetString("");
}

Action Cmd_ShowPassword(int iClient, int iArgs) {
    if (iClient <= 0 || !IsClientInGame(iClient))
        return Plugin_Handled;

    if (bPasswordEnabled)
        CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Password{teamcolor}]{default} Server password: {olive}%s", szPassword);
    else
        CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Password{teamcolor}]{default} Server password: {olive}Disabled");

    return Plugin_Handled;
}

Action Password_OnClientPreConnect(const char[] szPw, const char[] szSteamId, char szRejectReason[255]) {
    bool bNoopVal;
    if (bPasswordEnabled && !g_smPlayersWithoutPassword.GetValue(szSteamId, bNoopVal) && strcmp(szPassword, szPw) != 0) {
        FormatEx(szRejectReason, sizeof(szRejectReason), "You need the correct password in order to join the server. \nType 'connect %s:%i; password <current_password>' in console to join the server.", szServerIp, iServerPort);
        return Plugin_Stop;
    }
    return Plugin_Continue;
}

void GetIp() {
    int arrIpAddress[4];
    SteamWorks_GetPublicIP(arrIpAddress);

    if (!arrIpAddress[0] && !arrIpAddress[1] && !arrIpAddress[2] && !arrIpAddress[3]) {
        DataPack dp = new DataPack();
        dp.WriteFunction(GetIp);
        CreateTimer(1.0, Timer_CallSingleFunction, dp);
        return;
    }

    FormatEx(szServerIp, sizeof(szServerIp), "%d.%d.%d.%d", arrIpAddress[0], arrIpAddress[1], arrIpAddress[2], arrIpAddress[3]);
    iServerPort = FindConVar("hostport").IntValue;
}

Action Timer_CallSingleFunction(Handle hTimer, DataPack dp) {
    dp.Reset();
    Call_StartFunction(INVALID_HANDLE, dp.ReadFunction());
    Call_Finish();
    delete dp;
    return Plugin_Stop;
}