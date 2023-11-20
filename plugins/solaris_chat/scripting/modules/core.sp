#if defined __Core__
    #endinput
#endif
#define __Core__

static const char szDefColor[16] = "{default}";
static const char szTeamTags[][] = {
    "",
    "(Spectator) ",
    "(Survivor) ",
    "(Infected) "
};

void Core_OnModuleStart() {
    AddCommandListener(Cmd_Say, "say");
    AddCommandListener(Cmd_Say, "say_team");
}

Action Cmd_Say(int iClient, const char[] szCmd, int iArgs) {
    // Get Client Message
    char szMsg[MAXLENGTH_MESSAGE];
    GetCmdArgString(szMsg, sizeof(szMsg));
    CRemoveTags(szMsg, sizeof(szMsg));
    TrimString(szMsg);
    StripQuotes(szMsg);

    // Server says...
    if (iClient == 0) {
        Action aAction = Forwards_OnConsoleChatMessage(szMsg);
        if (aAction == Plugin_Handled || aAction == Plugin_Stop) {
            return Plugin_Handled;
        }
        DataPack dp = new DataPack();
        dp.WriteString(szMsg);
        RequestFrame(NextFrame_OnServerSay, dp);
        return Plugin_Handled;
    }

    // Get Client Name
    char szName[MAXLENGTH_NAME];
    GetClientName(iClient, szName, sizeof(szName));
    CRemoveTags(szName, sizeof(szName));
    StripQuotes(szName);

    if (GetLastMessageTime(iClient) + ANTIFLOOD >= GetEngineTime())
        return Plugin_Handled;
    SetLastMessageTime(iClient);

    if (!IsConfoglEnabled() && SourceComms_GetClientGagType(iClient) > bNot) {
        return Plugin_Handled;
    }

    if (IsChatTrigger() && (szMsg[0] == '/' || (IsConfoglEnabled() && (szMsg[0] == '!' || szMsg[0] == '@')))) {
        return Plugin_Handled;
    }

    int iTeam = GetClientTeam(iClient);
    if (TM_IsPlayerRespectating(iClient)) iTeam = TEAM_SPECTATORS;
    if (IsClientIdle(iClient))            iTeam = TEAM_SURVIVORS;

    bool bTeamChat = strcmp(szCmd, "say_team") == 0;
    if (iTeam == TEAM_SPECTATORS) bTeamChat = GagSpec_OnChatMessage(iClient, bTeamChat);

    ArrayList aRecipients = new ArrayList();
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i)) {
            if (IsClientSourceTV(i))
                aRecipients.Push(GetClientUserId(i));
            continue;
        }

        switch (bTeamChat) {
            case true: {
                switch (iTeam) {
                    case TEAM_SPECTATORS: {
                        if (GetClientTeam(i) == TEAM_SPECTATORS || TM_IsPlayerRespectating(i)) {
                            aRecipients.Push(GetClientUserId(i));
                        }
                    }
                    case TEAM_SURVIVORS: {
                        if (GetClientTeam(i) == TEAM_SURVIVORS || IsClientIdle(i)) {
                            aRecipients.Push(GetClientUserId(i));
                        }
                    }
                    case TEAM_INFECTED: {
                        if (GetClientTeam(i) == TEAM_INFECTED && !TM_IsPlayerRespectating(i)) {
                            aRecipients.Push(GetClientUserId(i));
                        }
                    }
                }
            }
            case false: {
                aRecipients.Push(GetClientUserId(i));
            }
        }
    }

    char szTag      [16] = "";
    char szTagColor [16] = "{default}";
    char szNameColor[16] = "{teamcolor}";
    char szMsgColor [16] = "{default}";

    Specs_OnChatMessage(iTeam, aRecipients, bTeamChat);
    Vips_OnChatMessage(iClient, iArgs, szTagColor, szTag, szNameColor, szMsgColor, szMsg);
    SelfMute_OnChatMessage(iClient, aRecipients);
    AdminSentinel_OnChatMessage(aRecipients);

    CreateSayEvent(GetClientUserId(iClient), szMsg);
    Action aAction = Forwards_OnChatMessage(iClient, iArgs, iTeam, bTeamChat, aRecipients, szTagColor, szTag, szNameColor, szName, szMsgColor, szMsg);
    if (aAction == Plugin_Handled || aAction == Plugin_Stop) {
        delete aRecipients;
        return Plugin_Handled;
    }

    DataPack dp = new DataPack();
    dp.WriteCell(GetClientUserId(iClient));
    dp.WriteCell(iArgs);
    dp.WriteCell(bTeamChat);
    dp.WriteCell(iTeam);
    dp.WriteCell(aRecipients);
    dp.WriteString(szName);
    dp.WriteString(szMsg);
    dp.WriteString(szTag);
    dp.WriteString(szTagColor);
    dp.WriteString(szNameColor);
    dp.WriteString(szMsgColor);
    RequestFrame(NextFrame_OnPlayerSay, dp);

    return Plugin_Handled;
}

void NextFrame_OnServerSay(DataPack dp) {
    dp.Reset();

    // Get message
    static char szMsg[MAXLENGTH_MESSAGE];
    dp.ReadString(szMsg, sizeof(szMsg));
    delete dp;

    // Send message
    CPrintToChatAll("{green}<{olive}Server{green}>{default} : %s", szMsg);
    PrintToServer("<Server> : %s", szMsg);
    Forwards_OnConsoleChatMessagePost(szMsg);
    CreateSayEvent(0, szMsg);
}

void NextFrame_OnPlayerSay(DataPack dp) {
    dp.Reset();

    // Get client
    int iUserId = dp.ReadCell();
    int iClient = GetClientOfUserId(iUserId);

    // Get arguments
    int iArgs = dp.ReadCell();

    // Team chat or all chat?
    bool bTeamChat = dp.ReadCell();

    // Get team
    int iTeam = dp.ReadCell();

    // Get recipients
    ArrayList aRecipients = dp.ReadCell();

    // Get name
    static char szName[MAXLENGTH_NAME] = "";
    dp.ReadString(szName, sizeof(szName));

    // Get message
    static char szMsg[MAXLENGTH_MESSAGE];
    dp.ReadString(szMsg, sizeof(szMsg));

    // Get tag
    char szTag[16] = "";
    dp.ReadString(szTag, sizeof(szTag));

    // Get tag color
    char szTagColor[16] = "{default}";
    dp.ReadString(szTagColor, sizeof(szTagColor));

    // Get name color
    char szNameColor[16] = "{teamcolor}";
    dp.ReadString(szNameColor, sizeof(szNameColor));

    // Get message color
    char szMsgColor[16] = "{default}";
    dp.ReadString(szMsgColor, sizeof(szMsgColor));
    delete dp;

    if (iClient <= 0) {
        delete aRecipients;
        return;
    }

    // Send message
    int iRecipient;
    for (int i = 0; i < aRecipients.Length; i++) {
        iRecipient = GetClientOfUserId(aRecipients.Get(i));
        if (iRecipient <= 0)
            continue;

        CPrintToChatEx(iRecipient, iClient, "%s%s%s%s%s%s : %s%s", bTeamChat ? szTeamTags[iTeam] : szTeamTags[0], szTagColor, szTag, szNameColor, szName, szDefColor, szMsgColor, szMsg);
    }

    PrintToServer("%s%s : %s", bTeamChat ? szTeamTags[iTeam] : szTeamTags[0], szName, szMsg);
    Forwards_OnChatMessagePost(iClient, iArgs, iTeam, bTeamChat, aRecipients, szTagColor, szTag, szNameColor, szName, szMsgColor, szMsg);

    delete aRecipients;
}
