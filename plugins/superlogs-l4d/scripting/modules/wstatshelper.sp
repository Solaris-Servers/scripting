#if defined __WStatsHelpter__
    #endinput
#endif
#define __WStatsHelpter__

#define HITGROUP_GENERIC   0
#define HITGROUP_HEAD      1
#define HITGROUP_CHEST     2
#define HITGROUP_STOMACH   3
#define HITGROUP_LEFTARM   4
#define HITGROUP_RIGHTARM  5
#define HITGROUP_LEFTLEG   6
#define HITGROUP_RIGHTLEG  7

#define LOG_HIT_OFFSET     7

#define LOG_HIT_SHOTS      0
#define LOG_HIT_HITS       1
#define LOG_HIT_KILLS      2
#define LOG_HIT_HEADSHOTS  3
#define LOG_HIT_TEAMKILLS  4
#define LOG_HIT_DAMAGE     5
#define LOG_HIT_DEATHS     6
#define LOG_HIT_GENERIC    7
#define LOG_HIT_HEAD       8
#define LOG_HIT_CHEST      9
#define LOG_HIT_STOMACH    10
#define LOG_HIT_LEFTARM    11
#define LOG_HIT_RIGHTARM   12
#define LOG_HIT_LEFTLEG    13
#define LOG_HIT_RIGHTLEG   14

StringMap g_smWeaponTrie;

void CreatePopulateWeaponTrie() {
    // Create a Trie
    g_smWeaponTrie = new StringMap();
    // Initial populate
    for (int i = 0; i < sizeof(g_szWeaponList); i++) {
        if (g_szWeaponList[i][0] == 0) {
            // some games have a couple blanks as place holders (so array indexes match with weapon ids)
            char szRandomKey[6];
            Format(szRandomKey, sizeof(szRandomKey), "%c%c%c%c%c%c", GetURandomInt(), GetURandomInt(), GetURandomInt(), GetURandomInt(), GetURandomInt(), GetURandomInt());
            g_smWeaponTrie.SetValue(szRandomKey, i);
            continue;
        }
        g_smWeaponTrie.SetValue(g_szWeaponList[i], i);
    }
}

void DumpPlayerStats(int iClient) {
    if (IsClientInGame(iClient)) {
        char szPlayerAuthId[64];
        if (!GetClientAuthId(iClient, AuthId_Steam2, szPlayerAuthId, sizeof(szPlayerAuthId))) {
            strcopy(szPlayerAuthId, sizeof(szPlayerAuthId), "UNKNOWN");
        }
        int iPlayerTeamIndex = GetClientTeam(iClient);
        int iPlayerUserId    = GetClientUserId(iClient);
        int IsLogged;
        for (int i = 0; i < sizeof(g_szWeaponList); i++) {
            if (g_iWeaponStats[iClient][i][LOG_HIT_SHOTS] > 0) {
                LogToGame("\"%N<%d><%s><%s>\" triggered \"weaponstats\" (weapon \"%s\") (shots \"%d\") (hits \"%d\") (kills \"%d\") (headshots \"%d\") (tks \"%d\") (damage \"%d\") (deaths \"%d\")", iClient, iPlayerUserId, szPlayerAuthId, g_szTeamList[iPlayerTeamIndex], g_szWeaponList[i], g_iWeaponStats[iClient][i][LOG_HIT_SHOTS], g_iWeaponStats[iClient][i][LOG_HIT_HITS], g_iWeaponStats[iClient][i][LOG_HIT_KILLS], g_iWeaponStats[iClient][i][LOG_HIT_HEADSHOTS], g_iWeaponStats[iClient][i][LOG_HIT_TEAMKILLS], g_iWeaponStats[iClient][i][LOG_HIT_DAMAGE], g_iWeaponStats[iClient][i][LOG_HIT_DEATHS]);
                LogToGame("\"%N<%d><%s><%s>\" triggered \"weaponstats2\" (weapon \"%s\") (head \"%d\") (chest \"%d\") (stomach \"%d\") (leftarm \"%d\") (rightarm \"%d\") (leftleg \"%d\") (rightleg \"%d\")", iClient, iPlayerUserId, szPlayerAuthId, g_szTeamList[iPlayerTeamIndex], g_szWeaponList[i], g_iWeaponStats[iClient][i][LOG_HIT_HEAD], g_iWeaponStats[iClient][i][LOG_HIT_CHEST], g_iWeaponStats[iClient][i][LOG_HIT_STOMACH], g_iWeaponStats[iClient][i][LOG_HIT_LEFTARM], g_iWeaponStats[iClient][i][LOG_HIT_RIGHTARM], g_iWeaponStats[iClient][i][LOG_HIT_LEFTLEG], g_iWeaponStats[iClient][i][LOG_HIT_RIGHTLEG]);
                IsLogged++;
            }
        }
        if (IsLogged > 0) {
            ResetPlayerStats(iClient);
        }
    }
}

void ResetPlayerStats(int iClient) {
    for (int i = 0; i < sizeof(g_szWeaponList); i++) {
        g_iWeaponStats[iClient][i][LOG_HIT_SHOTS]     = 0;
        g_iWeaponStats[iClient][i][LOG_HIT_HITS]      = 0;
        g_iWeaponStats[iClient][i][LOG_HIT_KILLS]     = 0;
        g_iWeaponStats[iClient][i][LOG_HIT_HEADSHOTS] = 0;
        g_iWeaponStats[iClient][i][LOG_HIT_TEAMKILLS] = 0;
        g_iWeaponStats[iClient][i][LOG_HIT_DAMAGE]    = 0;
        g_iWeaponStats[iClient][i][LOG_HIT_DEATHS]    = 0;
        g_iWeaponStats[iClient][i][LOG_HIT_GENERIC]   = 0;
        g_iWeaponStats[iClient][i][LOG_HIT_HEAD]      = 0;
        g_iWeaponStats[iClient][i][LOG_HIT_CHEST]     = 0;
        g_iWeaponStats[iClient][i][LOG_HIT_STOMACH]   = 0;
        g_iWeaponStats[iClient][i][LOG_HIT_LEFTARM]   = 0;
        g_iWeaponStats[iClient][i][LOG_HIT_RIGHTARM]  = 0;
        g_iWeaponStats[iClient][i][LOG_HIT_LEFTLEG]   = 0;
        g_iWeaponStats[iClient][i][LOG_HIT_RIGHTLEG]  = 0;
    }
}

stock int GetWeaponIndex(const char[] szWeaponName) {
    int iIdx = -1;
    g_smWeaponTrie.GetValue(szWeaponName, iIdx);
    return iIdx;
}

void WstatsDumpAll() {
    for (int i = 1; i <= MaxClients; i++) {
        DumpPlayerStats(i);
    }
}

void OnPlayerDisconnect(int iClient) {
    if (iClient > 0 && IsClientInGame(iClient)) {
        DumpPlayerStats(iClient);
        ResetPlayerStats(iClient);
    }
}