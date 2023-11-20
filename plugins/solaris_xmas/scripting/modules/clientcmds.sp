#if defined __CLIENT_CMDS__
    #endinput
#endif
#define __CLIENT_CMDS__

SolarisVote voteToggleSnow;

void ClientCmds_OnModuleStart() {
    RegConsoleCmd("sm_jingle",     Cmd_Jingle,     "Starts a christmas jingle.");
    RegConsoleCmd("sm_unjingle",   Cmd_Unjingle,   "Stops music clientside.");
    RegConsoleCmd("sm_nosnow",     Cmd_ToggleSnow, "Calls a vote to toggle snow.");
    RegConsoleCmd("sm_togglesnow", Cmd_ToggleSnow, "Calls a vote to toggle snow.");

    voteToggleSnow = (new SolarisVote()).OnSuccess(Callback_ToggleSnow)
                                        .SetRequiredVotes(RV_HALF);
}

// Plugin Commands
Action Cmd_Jingle(int iClient, int iArgs) {
    if (iClient <= 0)
        return Plugin_Handled;

    if (!IsClientInGame(iClient))
        return Plugin_Handled;

    if (!AllowJingle())
        return Plugin_Handled;

    AllowJingle(true, false);
    EmitSoundToAll("music/flu/jukebox/all_i_want_for_xmas.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
    CPrintToChatAll("{green}»{default} Happy Holidays! Music will stop when round goes live. You can use !unjingle to stop it locally any time.");
    return Plugin_Handled;
}

Action Cmd_Unjingle(int iClient, int iArgs) {
    StopSound(iClient, SNDCHAN_AUTO, "music/flu/jukebox/all_i_want_for_xmas.wav");
    return Plugin_Handled;
}

Action Cmd_ToggleSnow(int iClient, int iArgs) {
    if (iClient <= 0)
        return Plugin_Handled;

    if (!IsClientInGame(iClient))
        return Plugin_Handled;

    char szPrint[32];
    FormatEx(szPrint, sizeof(szPrint), "%s", IsSnowAllowed() ? "disabling snow" : "enabling snow");

    char szTitle[32];
    FormatEx(szTitle, sizeof(szTitle), "%s", IsSnowAllowed() ? "Disable snow?" : "Enable snow?");

    char szSuccessMessage[32];
    FormatEx(szSuccessMessage, sizeof(szSuccessMessage), "%s", IsSnowAllowed() ? "Snow has been disabled" : "Snow has been enabled");

    voteToggleSnow.SetPrint(szPrint)
                  .SetTitle(szTitle)
                  .SetSuccessMessage(szSuccessMessage)
                  .Start(iClient);

    return Plugin_Handled;
}

void Callback_ToggleSnow() {
    IsSnowAllowed(true, !IsSnowAllowed());
    CPrintToChatAll("{green}» {blue}Snow has been %s!", IsSnowAllowed() ? "enabled" : "disabled");
    MakeSnow();
}