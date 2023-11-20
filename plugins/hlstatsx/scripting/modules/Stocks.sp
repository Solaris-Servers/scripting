#if defined __STOCKS__
    #endinput
#endif
#define __STOCKS__

char szTeamList[16][64];

static const char szBlockedCommands[][] = {
    "rank",
    "skill",
    "points",
    "place",
    "session",
    "kpd",
    "kdratio",
    "top10",
    "top5",
    "hlx_hideranking",
};

stock void LogPlayerEvent(int iClient, const char[] szVerb, const char[] szPlayerEvent, bool bDisplayLocation = false) {
    if (iClient) {
        char szPlayerName[32];
        if (!GetClientName(iClient, szPlayerName, sizeof(szPlayerName)))
            strcopy(szPlayerName, sizeof(szPlayerName), "UNKNOWN");
        char szPlayerAuthId[32];
        if (!GetClientAuthId(iClient, AuthId_Steam2, szPlayerAuthId, sizeof(szPlayerAuthId)))
            strcopy(szPlayerAuthId, sizeof(szPlayerAuthId), "UNKNOWN");
        int  iTeam = GetClientTeam(iClient);
        char szPlayerTeam[64];
        szPlayerTeam = szTeamList[iTeam];
        int iUserId = GetClientUserId(iClient);
        if (bDisplayLocation) {
            float vOrigin[3];
            GetClientAbsOrigin(iClient, vOrigin);
            LogToGame("\"%s<%d><%s><%s>\" %s \"%s\" (position \"%d %d %d\")", szPlayerName, iUserId, szPlayerAuthId, szPlayerTeam, szVerb, szPlayerEvent, RoundFloat(vOrigin[0]), RoundFloat(vOrigin[1]), RoundFloat(vOrigin[2]));
        } else {
            LogToGame("\"%s<%d><%s><%s>\" %s \"%s\"", szPlayerName, iUserId, szPlayerAuthId, szPlayerTeam, szVerb, szPlayerEvent);
        }
    }
}

// not used yet
stock void LogAdminEvent(int iClient, const char[] szAdminEvt) {
    if (iClient) {
        char szPlayerName[32];
        if (!GetClientName(iClient, szPlayerName, sizeof(szPlayerName)))
            strcopy(szPlayerName, sizeof(szPlayerName), "UNKNOWN");
        char szPlayerAuthId[32];
        if (!GetClientAuthId(iClient, AuthId_Steam2, szPlayerAuthId, sizeof(szPlayerAuthId)))
            strcopy(szPlayerAuthId, sizeof(szPlayerAuthId), "UNKNOWN");
        int  iTeam = GetClientTeam(iClient);
        char szPlayerTeam[64];
        szPlayerTeam = szTeamList[iTeam];
        LogToGame("[SOURCEMOD]: \"%s<%s><%s>\" %s \"%s\"", szPlayerName, szPlayerAuthId, szPlayerTeam, "executed", szAdminEvt);
    } else {
        LogToGame("[SOURCEMOD]: \"<SERVER>\" %s \"%s\"", "executed", szAdminEvt);
    }
}

stock void MakePlayerCommand(int iClient, char szCmd[192]) {
    if (iClient) LogPlayerEvent(iClient, "say", szCmd);
}

stock bool IsCommandBlocked(const char[] szCmd) {
    for (int i = 0; i < sizeof(szBlockedCommands); i++) {
        if (strcmp(szCmd, szBlockedCommands[i]) == 0)
            return true;
    }
    return false;
}

stock void Display_Menu(int iClient, int iTime, char szFullMsg[1024], bool bNeedHandler = false) {
    char szMsg[1024];
    int  iOffs = 0;
    for (int i = 1; i < strlen(szFullMsg); i++) {
        if (szFullMsg[i - 1] == 92 && szFullMsg[i] == 110) {
            char szBuffer[1024];
            strcopy(szBuffer, (i - iOffs), szFullMsg[iOffs]);
            if (strlen(szMsg) == 0) {
                strcopy(szMsg[strlen(szMsg)], strlen(szBuffer) + 1, szBuffer);
            } else {
                szMsg[strlen(szMsg)] = 10;
                strcopy(szMsg[strlen(szMsg)], strlen(szBuffer) + 1, szBuffer);
            }
            i++;
            iOffs = i;
        }
    }
    if (bNeedHandler) InternalShowMenu(iClient, szMsg, iTime, (1 << 0)|(1 << 1)|(1 << 2)|(1 << 3)|(1 << 4)|(1 << 5)|(1 << 6)|(1 << 7)|(1 << 8)|(1 << 9), InternalMenuHandler);
    else              InternalShowMenu(iClient, szMsg, iTime);
}

stock int InternalMenuHandler(Menu mMenu, MenuAction maAction, int iClient, int iParam) {
    if (IsClientInGame(iClient)) {
        if (maAction == MenuAction_Select) {
            char szPlayerEvt[192];
            IntToString(iParam, szPlayerEvt, sizeof(szPlayerEvt));
            LogPlayerEvent(iClient, "selected", szPlayerEvt);
        } else if (maAction == MenuAction_Cancel) {
            char szPlayerEvt[192] = "cancel";
            LogPlayerEvent(iClient, "selected", szPlayerEvt);
        }
    }
    return 0;
}

// Call this on map start to cache team names in szTeamList
stock void GetTeams() {
    int iMaxTeamsCount = GetTeamCount();
    for (int i = 0; (i < iMaxTeamsCount); i++) {
        char szTeamName[64];
        GetTeamName(i, szTeamName, sizeof(szTeamName));
        if (strcmp(szTeamName, "") == 0) continue;
        szTeamList[i] = szTeamName;
    }
}