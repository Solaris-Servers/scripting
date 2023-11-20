#if defined __STOCKS__
    #endinput
#endif
#define __STOCKS__

bool IsPvP(bool bSet = false, bool bVal = false) {
    static bool bIsPvP = false;

    if (bSet)
        bIsPvP = bVal;

    return bIsPvP;
}

bool IsSnowAllowed(bool bSet = false, bool bVal = false) {
    static bool bSnow = false;

    if (bSet)
        bSnow = bVal;

    return bSnow;
}

bool AllowJingle(bool bSet = false, bool bVal = false) {
    static bool bJingle = false;

    if (bSet)
        bJingle = bVal;

    return bJingle;
}

bool GetLookPosFilter(int iEnt, int iMask, any iClient) {
    return iClient != iEnt;
}

bool IsSurvivor(int iClient) {
    return IsClientInGame(iClient) && GetClientTeam(iClient) == 2;
}

void SetEntNoGlow(int iEnt) {
    SetEntProp(iEnt, Prop_Send, "m_nGlowRange", 0);
    SetEntProp(iEnt, Prop_Send, "m_iGlowType", 0);
    SetEntProp(iEnt, Prop_Send, "m_glowColorOverride", 0);
    AcceptEntityInput(iEnt, "StopGlowing");
}

void SetEntGlow(int iEnt, int iColor) {
    // Set outline glow color
    SetEntProp(iEnt, Prop_Send, "m_nGlowRange", 250);
    SetEntProp(iEnt, Prop_Send, "m_iGlowType", 3);
    SetEntProp(iEnt, Prop_Send, "m_glowColorOverride", iColor);
    AcceptEntityInput(iEnt, "StartGlowing");
}

int GetRealCountPlayers() {
    int iClients = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        iClients++;
    }

    return iClients;
}

int GetColor() {
    char szColorCvar[64];
    g_cvXmasGiftGlow.GetString(szColorCvar, sizeof(szColorCvar));

    char szColorStr[3][4];
    ExplodeString(szColorCvar, " ", szColorStr, 3, 4);

    int iColor;
    iColor = StringToInt(szColorStr[0]);
    iColor += 256 * StringToInt(szColorStr[1]);
    iColor += 65536 * StringToInt(szColorStr[2]);
    return iColor;
}

bool IsHoliday() {
    static const char szHolidayBuffer[][] = {
        "01.12", "02.12", "03.12", "04.12",
        "05.12", "06.12", "07.12", "08.12",
        "09.12", "10.12", "11.12", "12.12",
        "13.12", "14.12", "15.12", "16.12",
        "17.12", "18.12", "19.12", "20.12",
        "21.12", "22.12", "23.12", "24.12",
        "25.12", "26.12", "27.12", "28.12",
        "29.12", "30.12", "31.12", "01.01",
        "02.01", "03.01", "04.01", "05.01"
    };

    char szTime[64];
    FormatTime(szTime, sizeof(szTime), "%d.%m", GetTime());

    for (int i = 0; i < sizeof(szHolidayBuffer); i++) {
        if (strcmp(szTime, szHolidayBuffer[i]) == 0)
            return true;
    }

    return false;
}

/**
 * Checks if 2 values match
 *
 * @param szFirstVal  First value
 * @param szSecondVal Second value
 * @param bIsRegex    True if val1 should be treated as a regex pattern, false if not
 * @return            True if match, false otherwise
 *
 */
bool EntPropsMatch(const char[] szFirstVal, const char[] szSecondVal, bool bIsRegex) {
    return bIsRegex ? SimpleRegexMatch(szSecondVal, szFirstVal) > 0 : strcmp(szFirstVal, szSecondVal) == 0;
}

bool FormatRegex(char[] szPattern, int iLen) {
    if (szPattern[0] == '/' && szPattern[iLen - 1] == '/') {
        strcopy(szPattern, iLen - 1, szPattern[1]);
        return true;
    }
    return false;
}