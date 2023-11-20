#if defined __SERVER_CMDS__
    #endinput
#endif
#define __SERVER_CMDS__

void ServerCmds_OnModuleStart() {
    RegServerCmd("log",                  Cmd_ProtectLoggingChange);
    RegServerCmd("logaddress_del",       Cmd_ProtectForwardingChange);
    RegServerCmd("logaddress_delall",    Cmd_ProtectForwardingDelAllChange);

    RegServerCmd("hlx_sm_psay",          Cmd_PSay);
    RegServerCmd("hlx_sm_psay2",         Cmd_PSay2);
    RegServerCmd("hlx_sm_csay",          Cmd_CSay);
    RegServerCmd("hlx_sm_msay",          Cmd_MSay);
    RegServerCmd("hlx_sm_tsay",          Cmd_TSay);
    RegServerCmd("hlx_sm_hint",          Cmd_Hint);
    RegServerCmd("hlx_sm_browse",        Cmd_Browse);
    RegServerCmd("hlx_sm_redirect",      Cmd_Redirect);
    RegServerCmd("hlx_sm_player_action", Cmd_PlayerAction);
    RegServerCmd("hlx_sm_team_action",   Cmd_TeamAction);
    RegServerCmd("hlx_sm_world_action",  Cmd_WorldAction);
}

Action Cmd_ProtectLoggingChange(int iArgs) {
    char szProtectAddress[192];
    cvProtectAddress.GetString(szProtectAddress, sizeof(szProtectAddress));
    if (strcmp(szProtectAddress, "") != 0) {
        if (iArgs >= 1) {
            char szLogAction[192];
            GetCmdArg(1, szLogAction, sizeof(szLogAction));
            if (strcmp(szLogAction, "off") == 0 || strcmp(szLogAction, "0") == 0) {
                LogToGame("HLstatsX address protection active, logging reenabled!");
                ServerCommand("log 1");
            }
        }
    }
    return Plugin_Continue;
}

Action Cmd_ProtectForwardingChange(int iArgs) {
    char szProtectAddress[192];
    cvProtectAddress.GetString(szProtectAddress, sizeof(szProtectAddress));
    if (strcmp(szProtectAddress, "") != 0) {
        if (iArgs == 1) {
            char szLogAction[192];
            GetCmdArg(1, szLogAction, sizeof(szLogAction));
            if (strcmp(szLogAction, szProtectAddress) == 0) {
                char szLogCommand[192];
                Format(szLogCommand, sizeof(szLogCommand), "logaddress_add %s", szProtectAddress);
                LogToGame("HLstatsX address protection active, logaddress readded!");
                ServerCommand(szLogCommand);
            }
        } else if (iArgs > 1) {
            char szLogAction[192];
            for (int i = 1; i <= iArgs; i++) {
                char szTmpArg[192];
                GetCmdArg(i, szTmpArg, sizeof(szTmpArg));
                strcopy(szLogAction[strlen(szLogAction)], sizeof(szTmpArg), szTmpArg);
            }
            if (strcmp(szLogAction, szProtectAddress) == 0) {
                char szLogCommand[192];
                Format(szLogCommand, sizeof(szLogCommand), "logaddress_add %s", szProtectAddress);
                LogToGame("HLstatsX address protection active, logaddress readded!");
                ServerCommand(szLogCommand);
            }
        }
    }
    return Plugin_Continue;
}

Action Cmd_ProtectForwardingDelAllChange(int iArgs) {
    char szProtectAddress[192];
    cvProtectAddress.GetString(szProtectAddress, sizeof(szProtectAddress));
    if (strcmp(szProtectAddress, "") != 0) {
        char szLogCommand[192];
        Format(szLogCommand, sizeof(szLogCommand), "logaddress_add %s", szProtectAddress);
        LogToGame("HLstatsX address protection active, logaddress readded!");
        ServerCommand(szLogCommand);
    }
    return Plugin_Continue;
}

Action Cmd_PSay(int iArgs) {
    if (iArgs < 2) {
        PrintToServer("Usage: hlx_sm_psay <userid><colored><message> - sends private message");
        return Plugin_Handled;
    }
    char szUserId[32];
    GetCmdArg(1, szUserId, sizeof(szUserId));
    char szColoredParam[32];
    GetCmdArg(2, szColoredParam, sizeof(szColoredParam));
    int iParamIgnore = 0;
    if (strcmp(szColoredParam, "1") == 0) iParamIgnore = 1;
    if (strcmp(szColoredParam, "0") == 0) iParamIgnore = 1;
    char szClientMsg[192];
    int  iArgCount = GetCmdArgs();
    for (int i = (1 + iParamIgnore); i < iArgCount; i++) {
        char szTmpArg[192];
        GetCmdArg(i + 1, szTmpArg, sizeof(szTmpArg));
        if (i > (1 + iParamIgnore)) {
            if ((sizeof(szTmpArg) - strlen(szClientMsg) - 1) > strlen(szTmpArg)) {
                if (szTmpArg[0] == ',' || szTmpArg[0] == '}') {
                    strcopy(szClientMsg[strlen(szClientMsg)], sizeof(szTmpArg), szTmpArg);
                } else if (strlen(szClientMsg) && szClientMsg[strlen(szClientMsg) - 1] != '(' && szClientMsg[strlen(szClientMsg) - 1] != '{' && szClientMsg[strlen(szClientMsg) - 1] != ':' && szClientMsg[strlen(szClientMsg) - 1] != '\'' && szClientMsg[strlen(szClientMsg) - 1] != ',') {
                    if (strcmp(szTmpArg, ":") != 0 && strcmp(szTmpArg, ",") != 0 && strcmp(szTmpArg, "'") != 0)
                        szClientMsg[strlen(szClientMsg)] = ' ';
                    strcopy(szClientMsg[strlen(szClientMsg)], sizeof(szTmpArg), szTmpArg);
                } else {
                    strcopy(szClientMsg[strlen(szClientMsg)], sizeof(szTmpArg), szTmpArg);
                }
            }
        } else if (sizeof(szTmpArg) - strlen(szClientMsg) > strlen(szTmpArg)) {
            strcopy(szClientMsg[strlen(szClientMsg)], sizeof(szTmpArg), szTmpArg);
        }
    }
    int iClient = GetClientOfUserId(StringToInt(szUserId))
    if (iClient && !IsFakeClient(iClient) && IsClientInGame(iClient)) {
        char szDisplayMsg[192];
        Format(szDisplayMsg, sizeof(szDisplayMsg), "%s", szClientMsg);
    }
    return Plugin_Handled;
}

Action Cmd_PSay2(int iArgs) {
    if (iArgs < 2) {
        PrintToServer("Usage: hlx_sm_psay2 <userid><colored><message> - sends green colored private message");
        return Plugin_Handled;
    }
    char szUserId[32];
    GetCmdArg(1, szUserId, sizeof(szUserId));
    char szColoredParam[32];
    GetCmdArg(2, szColoredParam, sizeof(szColoredParam));
    int iParamIgnore = 0;
    if (strcmp(szColoredParam, "1") == 0) iParamIgnore = 1;
    if (strcmp(szColoredParam, "0") == 0) iParamIgnore = 1;
    char szClientMsg[192];
    int  iArgCount = GetCmdArgs();
    for (int i = (1 + iParamIgnore); i < iArgCount; i++) {
        char szTmpArg[192];
        GetCmdArg(i + 1, szTmpArg, sizeof(szTmpArg));
        if (i > (1 + iParamIgnore)) {
            if ((sizeof(szTmpArg) - strlen(szClientMsg) - 1) > strlen(szTmpArg)) {
                if (szTmpArg[0] == ',' || szTmpArg[0] == '}') {
                    strcopy(szClientMsg[strlen(szClientMsg)], sizeof(szTmpArg), szTmpArg);
                } else if (strlen(szClientMsg) && szClientMsg[strlen(szClientMsg) - 1] != '(' && szClientMsg[strlen(szClientMsg) - 1] != '{' && szClientMsg[strlen(szClientMsg) - 1] != ':' && szClientMsg[strlen(szClientMsg) - 1] != '\'' && szClientMsg[strlen(szClientMsg) - 1] != ',') {
                    if ((strcmp(szTmpArg, ":") != 0) && (strcmp(szTmpArg, ",") != 0) && (strcmp(szTmpArg, "'") != 0))
                        szClientMsg[strlen(szClientMsg)] = ' ';
                    strcopy(szClientMsg[strlen(szClientMsg)], sizeof(szTmpArg), szTmpArg);
                } else {
                    strcopy(szClientMsg[strlen(szClientMsg)], sizeof(szTmpArg), szTmpArg);
                }
            }
        } else if ((sizeof(szTmpArg) - strlen(szClientMsg)) > strlen(szTmpArg)) {
            strcopy(szClientMsg[strlen(szClientMsg)], sizeof(szTmpArg), szTmpArg);
        }
    }
    int iClient = GetClientOfUserId(StringToInt(szUserId))
    if (iClient && IsClientInGame(iClient) && !IsFakeClient(iClient)) {
        char szDisplayMsg[192];
        Format(szDisplayMsg, sizeof(szDisplayMsg), "%s", szClientMsg);
    }
    return Plugin_Handled;
}

Action Cmd_CSay(int iArgs) {
    if (iArgs < 1) {
        PrintToServer("Usage: hlx_sm_csay <message> - display center message");
        return Plugin_Handled;
    }
    char szDisplayMsg[192];
    int  iArgCount = GetCmdArgs();
    for (int i = 1; i <= iArgCount; i++) {
        char temp_argument[192];
        GetCmdArg(i, temp_argument, sizeof(temp_argument));
        if (i > 1) {
            if ((sizeof(temp_argument) - strlen(szDisplayMsg) - 1) > strlen(temp_argument)) {
                szDisplayMsg[strlen(szDisplayMsg)] = ' ';
                strcopy(szDisplayMsg[strlen(szDisplayMsg)], sizeof(temp_argument), temp_argument);
            }
        } else if ((sizeof(temp_argument) - strlen(szDisplayMsg)) > strlen(temp_argument)) {
            strcopy(szDisplayMsg[strlen(szDisplayMsg)], sizeof(temp_argument), temp_argument);
        }
    }
    if (strcmp(szDisplayMsg, "") != 0)
        PrintCenterTextAll(szDisplayMsg);
    return Plugin_Handled;
}

Action Cmd_MSay(int iArgs) {
    if (iArgs < 3) {
        PrintToServer("Usage: hlx_sm_msay <time><userid><message> - sends hud message");
        return Plugin_Handled;
    }
    if (CheckVoteDelay() != 0) return Plugin_Handled;
    char szDisplayTime[16];
    GetCmdArg(1, szDisplayTime, sizeof(szDisplayTime));
    char szUserId[32];
    GetCmdArg(2, szUserId, sizeof(szUserId));
    char szHandlerParam[32];
    GetCmdArg(3, szHandlerParam, sizeof(szHandlerParam));
    bool bNeedHandler = false;
    int  iParamIgnore = 0;
    if (strcmp(szHandlerParam, "1") == 0) {
        bNeedHandler = true;
        iParamIgnore = 1;
    }
    if (strcmp(szHandlerParam, "0") == 0) {
        bNeedHandler = true;
        iParamIgnore = 1;
    }
    char szClientMsg[1024];
    int  iArgCount = GetCmdArgs();
    for (int i = (3 + iParamIgnore); i <= iArgCount; i++) {
        char szTmpArg[1024];
        GetCmdArg(i, szTmpArg, sizeof(szTmpArg));
        if (i > (3 + iParamIgnore)) {
            if ((sizeof(szTmpArg) - strlen(szClientMsg) - 1) > strlen(szTmpArg)) {
                szClientMsg[strlen(szClientMsg)] = ' ';
                strcopy(szClientMsg[strlen(szClientMsg)], sizeof(szTmpArg), szTmpArg);
            }
        } else if ((sizeof(szTmpArg) - strlen(szClientMsg)) > strlen(szTmpArg)) {
            strcopy(szClientMsg[strlen(szClientMsg)], sizeof(szTmpArg), szTmpArg);
        }
    }
    int iTime = StringToInt(szDisplayTime);
    if (iTime <= 0) iTime = 10;
    int  iClient = GetClientOfUserId(StringToInt(szUserId))
    char szDisplayMsg[1024];
    strcopy(szDisplayMsg, sizeof(szDisplayMsg), szClientMsg);
    if (strcmp(szDisplayMsg, "") != 0 && iClient && IsClientInGame(iClient) && !IsFakeClient(iClient))
        Display_Menu(iClient, iTime, szDisplayMsg, bNeedHandler);
    return Plugin_Handled;
}

Action Cmd_TSay(int iArgs) {
    if (iArgs < 3) {
        PrintToServer("Usage: hlx_sm_tsay <time><userid><message> - sends hud message");
        return Plugin_Handled;
    }
    char szDisplayTime[16];
    GetCmdArg(1, szDisplayTime, sizeof(szDisplayTime));
    char szUserId[32];
    GetCmdArg(2, szUserId, sizeof(szUserId));
    char szClientMsg[192];
    int iArgCount = GetCmdArgs();
    for (int i = 2; i < iArgCount; i++) {
        char szTmpArg[192];
        GetCmdArg(i + 1, szTmpArg, sizeof(szTmpArg));
        if (i > 2) {
            if ((sizeof(szTmpArg) - strlen(szClientMsg) - 1) > strlen(szTmpArg)) {
                szClientMsg[strlen(szClientMsg)] = ' ';
                strcopy(szClientMsg[strlen(szClientMsg)], sizeof(szTmpArg), szTmpArg);
            }
        } else if ((sizeof(szTmpArg) - strlen(szClientMsg)) > strlen(szTmpArg)) {
            strcopy(szClientMsg[strlen(szClientMsg)], sizeof(szTmpArg), szTmpArg);
        }
    }
    int iClient = GetClientOfUserId(StringToInt(szUserId));
    if (strcmp(szClientMsg, "") != 0 && iClient && IsClientInGame(iClient) && !IsFakeClient(iClient)) {
        KeyValues kv = new KeyValues("msg");
        kv.SetString("title", szClientMsg);
        kv.SetNum("level", 1);
        kv.SetString("time", szDisplayTime);
        CreateDialog(iClient, kv, DialogType_Msg);
        delete kv;
    }
    return Plugin_Handled;
}

Action Cmd_Hint(int iArgs) {
    if (iArgs < 2) {
        PrintToServer("Usage: hlx_sm_hint <userid><message> - send hint message");
        return Plugin_Handled;
    }
    char szUserId[32];
    GetCmdArg(1, szUserId, sizeof(szUserId));
    char szClientMsg[192];
    int iArgCount = GetCmdArgs();
    for (int i = 1; i < iArgCount; i++) {
        char szTmpArg[192];
        GetCmdArg(i + 1, szTmpArg, sizeof(szTmpArg));
        if (i > 1) {
            if ((strlen(szTmpArg) - strlen(szClientMsg)) > strlen(szTmpArg)) {
                if (szTmpArg[0] == ')' || szTmpArg[0] == '}') {
                    strcopy(szClientMsg[strlen(szClientMsg)], (sizeof(szTmpArg) - 1), szTmpArg);
                } else if (strlen(szClientMsg) && szClientMsg[strlen(szClientMsg) - 1] != '(' && szClientMsg[strlen(szClientMsg) - 1] != '{' && szClientMsg[strlen(szClientMsg) - 1] != ':' && szClientMsg[strlen(szClientMsg) - 1] != '\'' && szClientMsg[strlen(szClientMsg) - 1] != ',') {
                    if ((strcmp(szTmpArg, ":") != 0) && (strcmp(szTmpArg, ",") != 0) && (strcmp(szTmpArg, "'") != 0))
                        szClientMsg[strlen(szClientMsg)] = ' ';
                    strcopy(szClientMsg[strlen(szClientMsg)], sizeof(szTmpArg), szTmpArg);
                } else {
                    strcopy(szClientMsg[strlen(szClientMsg)], sizeof(szTmpArg), szTmpArg);
                }
            }
        } else if ((sizeof(szTmpArg) - strlen(szClientMsg)) > strlen(szTmpArg)) {
            strcopy(szClientMsg[strlen(szClientMsg)], sizeof(szTmpArg), szTmpArg);
        }
    }
    int iClient = GetClientOfUserId(StringToInt(szUserId));
    if (strcmp(szClientMsg, "") != 0 && iClient && IsClientInGame(iClient) && !IsFakeClient(iClient))
        PrintHintText(iClient, szClientMsg);
    return Plugin_Handled;
}

Action Cmd_Browse(int iArgs) {
    if (iArgs < 2) {
        PrintToServer("Usage: hlx_sm_browse <userid><url> - open client ingame browser");
        return Plugin_Handled;
    }
    char szUserId[32];
    GetCmdArg(1, szUserId, sizeof(szUserId));
    char szClientUrl[192];
    char szArg[512];
    GetCmdArgString(szArg, sizeof(szArg));
    int iFindPos = StrContains(szArg, "http://", true);
    if (iFindPos == -1) {
        int argument_count = GetCmdArgs();
        for (int i = 1; i < argument_count; i++) {
            char szTmpArg[192];
            GetCmdArg(i + 1, szTmpArg, sizeof(szTmpArg));
            if ((sizeof(szTmpArg) - strlen(szClientUrl)) > strlen(szTmpArg))
                strcopy(szClientUrl[strlen(szClientUrl)], sizeof(szTmpArg), szTmpArg);
        }
    } else {
        strcopy(szClientUrl, sizeof(szClientUrl), szArg[iFindPos]);
        ReplaceString(szClientUrl, sizeof(szClientUrl), "\"", "");
    }
    int iClient = GetClientOfUserId(StringToInt(szUserId));
    if (strcmp(szClientUrl, "") != 0 && iClient && IsClientInGame(iClient) && !IsFakeClient(iClient))
        ShowMOTDPanel(iClient, "HLstatsX", szClientUrl, MOTDPANEL_TYPE_URL);
    return Plugin_Handled;
}

Action Cmd_Redirect(int iArgs) {
    if (iArgs < 3) {
        PrintToServer("Usage: hlx_sm_redirect <time><userid><address><reason> - asks player to be redirected to specified gameserver");
        return Plugin_Handled;
    }
    char szDisplayTime[16];
    GetCmdArg(1, szDisplayTime, sizeof(szDisplayTime));
    char szUserId[32];
    GetCmdArg(2, szUserId, sizeof(szUserId));
    int  iArgCount     = GetCmdArgs();
    int  iBreakAddress = iArgCount;
    char szServerAddress[192];
    for (int i = 2; i < iArgCount; i++) {
        char szTmpArg[192];
        GetCmdArg(i + 1, szTmpArg, sizeof(szTmpArg));
        if (strcmp(szTmpArg, ":") == 0) {
            iBreakAddress = i + 1;
        } else if (i == 3) {
            iBreakAddress = i - 1;
        }
        if (i <= iBreakAddress) {
            if ((sizeof(szTmpArg) - strlen(szServerAddress)) > strlen(szTmpArg))
                strcopy(szServerAddress[strlen(szServerAddress)], sizeof(szTmpArg), szTmpArg);
        }
    }
    char szRedirectReason[192];
    for (int i = iBreakAddress + 1; i < iArgCount; i++) {
        char szTmpArg[192];
        GetCmdArg(i + 1, szTmpArg, sizeof(szTmpArg));
        if ((sizeof(szTmpArg) - strlen(szRedirectReason)) > strlen(szTmpArg)) {
            szRedirectReason[strlen(szRedirectReason)] = ' ';
            strcopy(szRedirectReason[strlen(szRedirectReason)], sizeof(szTmpArg), szTmpArg);
        }
    }
    int iClient = GetClientOfUserId(StringToInt(szUserId));
    if (strcmp(szServerAddress, "") != 0 && iClient && IsClientInGame(iClient) && !IsFakeClient(iClient)) {
        KeyValues kv = new KeyValues("msg");
        kv.SetString("title", szRedirectReason);
        kv.SetNum("level", 1);
        kv.SetString("time", szDisplayTime);
        CreateDialog(iClient, kv, DialogType_Msg);
        delete kv;
        float fDisplayTime;
        fDisplayTime = StringToFloat(szDisplayTime);
        DisplayAskConnectBox(iClient, fDisplayTime, szServerAddress);
    }
    return Plugin_Handled;
}

Action Cmd_PlayerAction(int iArgs) {
    if (iArgs < 2) {
        PrintToServer("Usage: hlx_sm_player_action <userid><action> - trigger player action to be handled from HLstatsX");
        return Plugin_Handled;
    }
    char szUserId[32];
    GetCmdArg(1, szUserId, sizeof(szUserId));
    char iPlayerAction[192];
    GetCmdArg(2, iPlayerAction, sizeof(iPlayerAction));
    int iClient = GetClientOfUserId(StringToInt(szUserId));
    if (iClient) LogPlayerEvent(iClient, "triggered", iPlayerAction);
    return Plugin_Handled;
}

Action Cmd_TeamAction(int iArgs) {
    if (iArgs < 2) {
        PrintToServer("Usage: hlx_sm_player_action <team_name><action> - trigger team action to be handled from HLstatsX");
        return Plugin_Handled;
    }
    char szTeamName[64];
    GetCmdArg(1, szTeamName, sizeof(szTeamName));
    char szTeamAction[64];
    GetCmdArg(2, szTeamAction, sizeof(szTeamAction));
    LogToGame("Team \"%s\" triggered \"%s\"", szTeamName, szTeamAction);
    return Plugin_Handled;
}

Action Cmd_WorldAction(int iArgs) {
    if (iArgs < 1) {
        PrintToServer("Usage: hlx_sm_world_action <action> - trigger world action to be handled from HLstatsX");
        return Plugin_Handled;
    }
    char szWorldAction[64];
    GetCmdArg(1, szWorldAction, sizeof(szWorldAction));
    LogToGame("World triggered \"%s\"", szWorldAction);
    return Plugin_Handled;
}