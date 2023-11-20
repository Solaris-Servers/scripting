#if defined _readyup_command_included
    #endinput
#endif
#define _readyup_command_included

void ToggleCommandListeners(bool bHook) {
    static bool bHooked = false;
    if (bHooked && !bHook) {
        RemoveCommandListener(Vote_Callback, "Vote");
        bHooked = false;
    } else if (!bHooked && bHook) {
        AddCommandListener(Vote_Callback, "Vote");
        bHooked = true;
    }
}

// ========================
//  Ready Commands
// ========================
Action Cmd_Ready(int iClient, int iArgs) {
    if (g_bInReadyUp && IsPlayer(iClient)) {
        if (g_iReadyUpMode == ReadyMode_PlayerReady) {
            if (SetPlayerReady(iClient, true))
                PlayNotifySound(iClient);

            if (g_cvReadySecret.BoolValue)
                DoSecrets(iClient);

            if (CheckFullReady())
                InitiateLiveCountdown();

            return Plugin_Handled;
        } else if (g_iReadyUpMode == ReadyMode_TeamReady) {
            if (!TM_IsFinishedLoading()) {
                CPrintToChat(iClient, "{green}[{default}ReadyUp{green}]{default} Please wait for others. {olive}%ds{default} remaining!", TM_LoadingTimeRemaining());
                return Plugin_Handled;
            }

            if (SetTeamReady(GetClientTeam(iClient), true))
                PlayNotifySound(iClient);

            if (g_cvReadySecret.BoolValue)
                DoSecrets(iClient);

            if (CheckFullReady())
                InitiateLiveCountdown();

            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}

Action Cmd_Unready(int iClient, int iArgs) {
    if (g_iReadyUpMode == ReadyMode_PlayerReady || g_iReadyUpMode == ReadyMode_TeamReady) {
        if (g_bInReadyUp && iClient) {
            // Check if admin always allowed to do so
            AdminId id = GetUserAdmin(iClient);
            // Check for specific admin flag
            bool bHasFlag = (id != INVALID_ADMIN_ID && GetAdminFlag(id, Admin_Ban));
            if (g_bIsForceStart) {
                if (bHasFlag) {
                    CancelFullReady(iClient, eAdminAbort);
                    g_bIsForceStart = false;
                    return Plugin_Handled;
                }
            } else {
                if (IsPlayer(iClient)) {
                    if (g_iReadyUpMode == ReadyMode_PlayerReady) {
                        if (SetPlayerReady(iClient, false)) PlayNotifySound(iClient);
                    } else if (g_iReadyUpMode == ReadyMode_TeamReady) {
                        if (SetTeamReady(GetClientTeam(iClient), false)) PlayNotifySound(iClient);
                    }
                    CancelFullReady(iClient, eReadyStatus);
                    SetButtonTime(iClient);
                    return Plugin_Handled;
                } else if (bHasFlag) {
                    CancelFullReady(iClient, eAdminAbort);
                    g_bIsForceStart = false;
                    return Plugin_Handled;
                }
            }
        }
    }

    return Plugin_Continue;
}

Action Cmd_ToggleReady(int iClient, int iArgs) {
    if (!g_bInReadyUp)
        return Plugin_Continue;

    switch (g_iReadyUpMode) {
        case ReadyMode_PlayerReady: {
            return IsPlayerReady(iClient) ? Cmd_Unready(iClient, 0) : Cmd_Ready(iClient, 0);
        }
        case ReadyMode_TeamReady: {
            return IsTeamReady(GetClientTeam(iClient)) ? Cmd_Unready(iClient, 0) : Cmd_Ready(iClient, 0);
        }
    }
    return Plugin_Continue;
}

// ========================
//  Admin Commands
// ========================
Action Cmd_ForceStart(int iClient, int iArgs) {
    if (g_iReadyUpMode == ReadyMode_PlayerReady || g_iReadyUpMode == ReadyMode_TeamReady) {
        if (g_bIsForceStart)
            return Plugin_Continue;

        if (g_bInReadyUp) {
            // Check if admin always allowed to do so
            AdminId id = GetUserAdmin(iClient);
            // Check for specific admin flag
            if (id != INVALID_ADMIN_ID && GetAdminFlag(id, Admin_Ban)) {
                g_bIsForceStart = true;
                InitiateLiveCountdown();
                CPrintToChatAllEx(iClient, "{green}[{default}ReadyUp{green}] {olive}Game{default} start is {green}forced{default} by {olive}Admin{default} ({teamcolor}%N{default}).", iClient);
                return Plugin_Handled;
            }
        }
    }

    return Plugin_Continue;
}

// ========================
//  Player Commands
// ========================
Action Cmd_Hide(int iClient, int iArgs) {
    if (g_iReadyUpMode == ReadyMode_PlayerReady || g_iReadyUpMode == ReadyMode_TeamReady) {
        if (g_bInReadyUp) {
            SetPlayerHiddenPanel(iClient, true);
            CPrintToChat(iClient, "{green}[{default}ReadyUp{green}]{default} Panel is now {red}off{default}.");
            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}

Action Cmd_Show(int iClient, int iArgs) {
    if (g_iReadyUpMode == ReadyMode_PlayerReady || g_iReadyUpMode == ReadyMode_TeamReady) {
        if (g_bInReadyUp) {
            SetPlayerHiddenPanel(iClient, false);
            CPrintToChat(iClient, "{green}[{default}ReadyUp{green}]{default} Panel is now {blue}on{default}.");
            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}

Action Cmd_Return(int iClient, int iArgs) {
    if (g_iReadyUpMode == ReadyMode_PlayerReady || g_iReadyUpMode == ReadyMode_TeamReady) {
        if (g_bInReadyUp && iClient > 0 && GetClientTeam(iClient) == L4D2Team_Survivor) {
            ReturnPlayerToSaferoom(iClient, false);
            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}

// ========================
//  Footer Commands
// ========================
Action Cmd_AddCmd(int iArgs) {
    if (!iArgs)
        return Plugin_Handled;

    char szCmd[32];
    GetCmdArg(1, szCmd, sizeof(szCmd));
    AddToPanel(szCmd);
    return Plugin_Handled;
}

Action Cmd_ResetCmd(int iArgs) {
    ResetPanel();
    return Plugin_Continue;
}