#if defined __LogHelper__
    #endinput
#endif
#define __LogHelper__

#define LOGHELPER_VERSION 5

char g_szTeamList[16][64];

// Call this on map start to cache team names in g_szTeamList
stock void GetTeams() {
    int iMaxTeamsCount = GetTeamCount();
    for (int i = 0; (i < iMaxTeamsCount); i++) {
        char szTeamName[64];
        GetTeamName(i, szTeamName, sizeof(szTeamName));
        if (strcmp(szTeamName, "") == 0) continue;
        g_szTeamList[i] = szTeamName;
    }
}

stock void LogPlayerEvent(int iClient, const char[] szVerb, const char[] szEvent, bool bDisplayLocation = false, const char[] szProperties = "") {
    if (IsValidPlayer(iClient)) {
        char szPlayerAuthId[32];
        if (!GetClientAuthId(iClient, AuthId_Engine, szPlayerAuthId, sizeof(szPlayerAuthId), false))
            strcopy(szPlayerAuthId, sizeof(szPlayerAuthId), "UNKNOWN");
        if (bDisplayLocation) {
            float vPlayerOrigin[3];
            GetClientAbsOrigin(iClient, vPlayerOrigin);
            LogToGame("\"%N<%d><%s><%s>\" %s \"%s\"%s (position \"%d %d %d\")", iClient, GetClientUserId(iClient), szPlayerAuthId, g_szTeamList[GetClientTeam(iClient)], szVerb, szEvent, szProperties, RoundFloat(vPlayerOrigin[0]), RoundFloat(vPlayerOrigin[1]), RoundFloat(vPlayerOrigin[2]));
        } else {
            LogToGame("\"%N<%d><%s><%s>\" %s \"%s\"%s", iClient, GetClientUserId(iClient), szPlayerAuthId, g_szTeamList[GetClientTeam(iClient)], szVerb, szEvent, szProperties);
        }
    }
}

stock void LogPlayerToPlayerEvent(int iClient, int iVictim, const char[] szVerb, const char[] szEvent, bool bDisplayLocation = false, const char[] szProperties = "") {
    if (IsValidPlayer(iClient) && IsValidPlayer(iVictim)) {
        char szPlayerAuthId[32];
        if (!GetClientAuthId(iClient, AuthId_Engine, szPlayerAuthId, sizeof(szPlayerAuthId), false)) {
            strcopy(szPlayerAuthId, sizeof(szPlayerAuthId), "UNKNOWN");
        }
        char szVictimAuthid[32];
        if (!GetClientAuthId(iVictim, AuthId_Engine, szVictimAuthid, sizeof(szVictimAuthid), false)) {
            strcopy(szVictimAuthid, sizeof(szVictimAuthid), "UNKNOWN");
        }
        if (bDisplayLocation) {
            float vPlayerOrigin[3];
            GetClientAbsOrigin(iClient, vPlayerOrigin);
            float vVictimOrigin[3];
            GetClientAbsOrigin(iVictim, vVictimOrigin);
            LogToGame("\"%N<%d><%s><%s>\" %s \"%s\" against \"%N<%d><%s><%s>\"%s (position \"%d %d %d\") (victim_position \"%d %d %d\")", iClient, GetClientUserId(iClient), szPlayerAuthId, g_szTeamList[GetClientTeam(iClient)], szVerb, szEvent, iVictim, GetClientUserId(iVictim), szVictimAuthid, g_szTeamList[GetClientTeam(iVictim)], szProperties, RoundFloat(vPlayerOrigin[0]), RoundFloat(vPlayerOrigin[1]), RoundFloat(vPlayerOrigin[2]), RoundFloat(vVictimOrigin[0]), RoundFloat(vVictimOrigin[1]), RoundFloat(vVictimOrigin[2]));
        } else {
            LogToGame("\"%N<%d><%s><%s>\" %s \"%s\" against \"%N<%d><%s><%s>\"%s", iClient, GetClientUserId(iClient), szPlayerAuthId, g_szTeamList[GetClientTeam(iClient)], szVerb, szEvent, iVictim, GetClientUserId(iVictim), szVictimAuthid, g_szTeamList[GetClientTeam(iVictim)], szProperties);
        }
    }
}

stock void LogKill(int iAttacker, int iVictim, const char[] szWeapon, bool bDisplayLocation = false, const char[] szProperties = "") {
    if (IsValidPlayer(iAttacker) && IsValidPlayer(iVictim)) {
        char szAttackerAuthId[32];
        if (!GetClientAuthId(iAttacker, AuthId_Engine, szAttackerAuthId, sizeof(szAttackerAuthId), false)) {
            strcopy(szAttackerAuthId, sizeof(szAttackerAuthId), "UNKNOWN");
        }
        char szVictimAuthid[32];
        if (!GetClientAuthId(iVictim, AuthId_Engine, szVictimAuthid, sizeof(szVictimAuthid), false)) {
            strcopy(szVictimAuthid, sizeof(szVictimAuthid), "UNKNOWN");
        }
        if (bDisplayLocation) {
            float vAttackerOrigin[3];
            GetClientAbsOrigin(iAttacker, vAttackerOrigin);
            float vVictimOrigin[3];
            GetClientAbsOrigin(iVictim, vVictimOrigin);
            LogToGame("\"%N<%d><%s><%s>\" killed \"%N<%d><%s><%s>\" with \"%s\"%s (attacker_position \"%d %d %d\") (victim_position \"%d %d %d\")", iAttacker, GetClientUserId(iAttacker), szAttackerAuthId, g_szTeamList[GetClientTeam(iAttacker)], iVictim, GetClientUserId(iVictim), szVictimAuthid, g_szTeamList[GetClientTeam(iVictim)], szWeapon, szProperties, RoundFloat(vAttackerOrigin[0]), RoundFloat(vAttackerOrigin[1]), RoundFloat(vAttackerOrigin[2]), RoundFloat(vVictimOrigin[0]), RoundFloat(vVictimOrigin[1]), RoundFloat(vVictimOrigin[2]));
        } else {
            LogToGame("\"%N<%d><%s><%s>\" killed \"%N<%d><%s><%s>\" with \"%s\"%s", iAttacker, GetClientUserId(iAttacker), szAttackerAuthId, g_szTeamList[GetClientTeam(iAttacker)], iVictim, GetClientUserId(iVictim), szVictimAuthid, g_szTeamList[GetClientTeam(iVictim)], szWeapon, szProperties);
        }
    }
}

stock void LogSuicide(int iVictim, const char[] szWeapon, bool bDisplayLocation = false, const char[] szProperties = "") {
    if (IsValidPlayer(iVictim)) {
        char szVictimAuthid[32];
        if (!GetClientAuthId(iVictim, AuthId_Engine, szVictimAuthid, sizeof(szVictimAuthid), false)) {
            strcopy(szVictimAuthid, sizeof(szVictimAuthid), "UNKNOWN");
        }
        if (bDisplayLocation) {
            float vVictimOrigin[3];
            GetClientAbsOrigin(iVictim, vVictimOrigin);
            LogToGame("\"%N<%d><%s><%s>\" committed suicide with \"%s\"%s (victim_position \"%d %d %d\")", iVictim, GetClientUserId(iVictim), szVictimAuthid, g_szTeamList[GetClientTeam(iVictim)], szWeapon, szProperties, RoundFloat(vVictimOrigin[0]), RoundFloat(vVictimOrigin[1]), RoundFloat(vVictimOrigin[2]));
        } else {
            LogToGame("\"%N<%d><%s><%s>\" committed suicide with \"%s\"%s", iVictim, GetClientUserId(iVictim), szVictimAuthid, g_szTeamList[GetClientTeam(iVictim)], szWeapon, szProperties);
        }
    }
}

// For Psychostats "KTRAJ" kill trajectory log lines
stock void LogPSKillTraj(int iAttacker, int iVictim, const char[] szWeapon) {
    if (IsValidPlayer(iAttacker) && IsValidPlayer(iVictim)) {
        char szAttackerAuthId[32];
        if (!GetClientAuthId(iAttacker, AuthId_Engine, szAttackerAuthId, sizeof(szAttackerAuthId), false)) {
            strcopy(szAttackerAuthId, sizeof(szAttackerAuthId), "UNKNOWN");
        }
        char szVictimAuthid[32];
        if (!GetClientAuthId(iVictim, AuthId_Engine, szVictimAuthid, sizeof(szVictimAuthid), false)) {
            strcopy(szVictimAuthid, sizeof(szVictimAuthid), "UNKNOWN");
        }
        float vAttackerOrigin[3];
        GetClientAbsOrigin(iAttacker, vAttackerOrigin);
        float vVictimOrigin[3];
        GetClientAbsOrigin(iVictim, vVictimOrigin);
        LogToGame("[KTRAJ] \"%N<%d><%s><%s>\" killed \"%N<%d><%s><%s>\" with \"%s\" (attacker_position \"%d %d %d\") (victim_position \"%d %d %d\")", iAttacker, GetClientUserId(iAttacker), szAttackerAuthId, g_szTeamList[GetClientTeam(iAttacker)], iVictim, GetClientUserId(iVictim), szVictimAuthid, g_szTeamList[GetClientTeam(iVictim)], szWeapon, RoundFloat(vAttackerOrigin[0]), RoundFloat(vAttackerOrigin[1]), RoundFloat(vAttackerOrigin[2]), RoundFloat(vVictimOrigin[0]), RoundFloat(vVictimOrigin[1]), RoundFloat(vVictimOrigin[2]));
    }
}

// Verb should always be "triggered" for this.
stock void LogTeamEvent(int iTeam, const char[] szVerb, const char[] szEvent, const char[] szProperties = "") {
    if (iTeam > -1) {
        LogToGame("Team \"%s\" %s \"%s\"%s", g_szTeamList[iTeam], szVerb, szEvent, szProperties);
    }
}

stock void LogKillLoc(int iAttacker, int iVictim) {
    if (iAttacker > 0 && iVictim > 0) {
        float vAttackerOrigin[3];
        GetClientAbsOrigin(iAttacker, vAttackerOrigin);
        float vVictimOrigin[3];
        GetClientAbsOrigin(iVictim, vVictimOrigin);
        LogToGame("World triggered \"killlocation\" (attacker_position \"%d %d %d\") (victim_position \"%d %d %d\")", RoundFloat(vAttackerOrigin[0]), RoundFloat(vAttackerOrigin[1]), RoundFloat(vAttackerOrigin[2]), RoundFloat(vVictimOrigin[0]), RoundFloat(vVictimOrigin[1]), RoundFloat(vVictimOrigin[2]));
    }
}

stock void LogTeamChange(int iClient, int iNewTeam, const char[] szProperties = "") {
    if (IsValidPlayer(iClient)) {
        char szPlayerAuthId[32];
        if (!GetClientAuthId(iClient, AuthId_Engine, szPlayerAuthId, sizeof(szPlayerAuthId), false)) {
            strcopy(szPlayerAuthId, sizeof(szPlayerAuthId), "UNKNOWN");
        }
        LogToGame("\"%N<%d><%s><%s>\" joined team \"%s\"%s", iClient, GetClientUserId(iClient), szPlayerAuthId, g_szTeamList[GetClientTeam(iClient)], g_szTeamList[iNewTeam], szProperties);
    }
}

stock void LogRoleChange(int iClient, const char[] szRole, const char[] szProperties = "") {
    if (IsValidPlayer(iClient)) {
        char szPlayerAuthId[32];
        if (!GetClientAuthId(iClient, AuthId_Engine, szPlayerAuthId, sizeof(szPlayerAuthId), false)) {
            strcopy(szPlayerAuthId, sizeof(szPlayerAuthId), "UNKNOWN");
        }
        LogToGame("\"%N<%d><%s><%s>\" changed role to \"%s\"%s", iClient, GetClientUserId(iClient), szPlayerAuthId, g_szTeamList[GetClientTeam(iClient)], szRole, szProperties);
    }
}

stock void LogMapLoad() {
    char szMap[64];
    GetCurrentMap(szMap, sizeof(szMap));
    LogToGame("Loading map \"%s\"", szMap);
}

stock void LogGameMode(const char[] szGm) {
    LogToGame("Current GameMode \"%s\"", szGm);
}

stock void LogMatchConfig(const char[] szCfgName) {
    LogToGame("Current MatchMode \"%s\"", szCfgName);
}

stock bool IsValidPlayer(int iClient) {
    if (iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient)) {
        return true;
    }
    return false;
}