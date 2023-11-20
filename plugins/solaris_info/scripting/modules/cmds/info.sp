#if defined __CMDS_INFO__
    #endinput
#endif
#define __CMDS_INFO__

Action Cmd_Info(int iClient, int iArgs) {
    iCurrentTime[iClient] = GetTime();
    if (iCurrentTime[iClient] - iPreviousTime[iClient] < ANTISPAM)
        return Plugin_Handled;

    if (iClient <= 0)
        return Plugin_Handled;

    if (iArgs == 0) {
        CreateMenuInfo(iClient);
        return Plugin_Handled;
    }

    static char szBuffer[64];
    GetCmdArg(1, szBuffer, sizeof(szBuffer));

    char  szTargetName[MAX_TARGET_LENGTH];
    int[] iTargetList = new int[MaxClients + 1];
    int   iTargetCount;
    bool  bTnIsMl;

    if ((iTargetCount = ProcessTargetString(szBuffer, iClient, iTargetList, MaxClients + 1, COMMAND_FILTER_NO_IMMUNITY|COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_NO_MULTI, szTargetName, sizeof(szTargetName), bTnIsMl)) <= 0) {
        CPrintToChat(iClient, "{green}[{default}!{green}]{default} Couldn't find a player!");
        return Plugin_Handled;
    }

    for (int i = 0; i < iTargetCount; i++) {
        int iTarget = iTargetList[i];
        if (iTarget <= 0)
            continue;

        if (iTarget > MaxClients)
            continue;

        ShowInfo(iClient, GetClientUserId(iTarget));
    }

    iPreviousTime[iClient] = iCurrentTime[iClient];
    return Plugin_Handled;
}

void ShowInfo(int iClient, int iTargetUserId) {
    int iTarget = GetClientOfUserId(iTargetUserId);
    if (iTarget <= 0)
        return;

    static char szCountry[3];
    GetPlayerCountry(iTarget, szCountry, sizeof(szCountry));

    static char szCity[45];
    GetPlayerCity(iTarget, szCity, sizeof(szCity));

    static char szRank[8];
    IntToString(PlayerRank(iTarget), szRank, sizeof(szRank));

    CPrintToChatEx(iClient, iTarget, "{teamcolor} ");
    CPrintToChatEx(iClient, iTarget, " {green}[{teamcolor}%N{default}'s info{green}]{default}:", iTarget);
    CPrintToChatEx(iClient, iTarget, "  Rank: {olive}#%s{teamcolor}", PlayerRank(iTarget) > 0 ? szRank : "N/A");
    CPrintToChatEx(iClient, iTarget, "  Country: {olive}%s{default}, City: {olive}%s{teamcolor}", szCountry, szCity);
    CPrintToChatEx(iClient, iTarget, "  Hours: {olive}%.01f{default}, Lerp: {olive}%.01f{teamcolor}", GetPlayerHours(iTarget), GetPlayerLerp(iTarget));
    CPrintToChatEx(iClient, iTarget, "  CmdRate: {olive}%.01f{default}; UpdateRate {olive}%.01f{teamcolor}", GetClientAvgPackets(iTarget, NetFlow_Incoming), GetClientAvgPackets(iTarget, NetFlow_Outgoing));
    CPrintToChatEx(iClient, iTarget, "{teamcolor} ");
}

void CreateMenuInfo(int iClient) {
    Menu mMenu = new Menu(Menu_ListOfPlayers);

    char szName[MAX_NAME_LENGTH];
    char szUserId[64];

    mMenu.SetTitle("Select a player:");

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        FormatEx(szUserId, sizeof(szUserId), "%i", GetClientUserId(i));

        if (!GetClientName(i, szName, sizeof(szName)))
            continue;

        mMenu.AddItem(szUserId, szName);
    }

    mMenu.Display(iClient, MENU_TIME_FOREVER);
}

int Menu_ListOfPlayers(Menu mMenu, MenuAction maAction, int iClient, int iParam2) {
    switch (maAction) {
        case MenuAction_Select: {
            char szUserId[64];
            if (mMenu.GetItem(iParam2, szUserId, sizeof(szUserId)))
                ShowInfo(iClient, StringToInt(szUserId));
        }
        case MenuAction_End: {
            delete mMenu;
        }
    }

    return 0;
}