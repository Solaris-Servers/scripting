#if defined __RANK__
    #endinput
#endif
#define __RANK__

Database HlStatsX_CE;

bool AskPluginLoad2_Rank() {
    if (!SQL_CheckConfig("hlstats"))
        return false;
    return true;
}

void OnModuleStart_Rank() {
    SQL_TConnect(OnDatabaseConnected, "hlstats");
}

void OnDatabaseConnected(Handle hOwner, Handle hHndl, const char[] szError, any iData) {
    if (hHndl == null) {
        SetFailState("[HLStatsX:CE] Couldn't connect to the database \"hlstats\"");
        return;
    }

    HlStatsX_CE = view_as<Database>(hHndl);
    PrintToServer("[HLStatsX:CE] Database connected");

    char szAuth[32];
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        if (!GetClientAuthId(i, AuthId_Steam2, szAuth, sizeof(szAuth)))
            continue;

        RequestRank(i, szAuth);
    }
}

void OnClientConnected_Rank(int iClient) {
    PlayerRank(iClient, true, 0);
}

void OnClientAuthorized_Rank(int iClient, const char[] szAuth) {
    RequestRank(iClient, szAuth);
}

void OnClientDisconnect_Rank(int iClient) {
    PlayerRank(iClient, true, 0);
}

void RequestRank(int iClient, const char[] szAuth) {
    static char szQuery[1024];
    FormatEx(szQuery, sizeof(szQuery), "SELECT COUNT(*) AS rank FROM hlstats_Players WHERE hlstats_Players.game='l4d2' AND hideranking=0 AND skill>(SELECT skill from hlstats_Players WHERE uId=MID('%s', 9) AND hideranking=0) - 1", szAuth);
    SQL_TQuery(HlStatsX_CE, SQL_GetRankCallback, szQuery, GetClientUserId(iClient));
}

void SQL_GetRankCallback(Handle hOwner, Handle hHndl, const char[] szError, int iUserId) {
    if (hHndl == null) {
        StatsCallback(iUserId, 0);
        return;
    }

    if (SQL_FetchRow(hHndl)) {
        StatsCallback(iUserId, SQL_FetchInt(hHndl, 0));
        return;
    }

    StatsCallback(iUserId, 0);
}

void StatsCallback(int iUserId, int iRank) {
    int iClient = GetClientOfUserId(iUserId);
    if (iClient) PlayerRank(iClient, true, iRank);
}

int PlayerRank(int iClient, bool bSet = false, int iVal = 0) {
    static int iPlayerRank[MAXPLAYERS + 1];

    if (bSet)
        iPlayerRank[iClient] = iVal;

    return iPlayerRank[iClient];
}