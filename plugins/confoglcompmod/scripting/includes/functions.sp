#if defined __FUNCTIONS__
    #endinput
#endif
#define __FUNCTIONS__

#define CVAR_PREFIX  "confogl_"
#define CVAR_FLAGS   FCVAR_NONE
#define CVAR_PRIVATE FCVAR_DONTRECORD|FCVAR_PROTECTED

bool bIsPluginEnabled = false;

ConVar CreateConVarEx(const char[] szName, const char[] szDefaultValue, const char[] szDescription = "", int iFlags = 0, bool bHasMin = false, float fMin = 0.0, bool bHasMax = false, float fMax = 0.0) {
    char szBuffer[128];
    ConVar cv;
    Format(szBuffer, sizeof(szBuffer), "%s%s", CVAR_PREFIX, szName);
    iFlags = iFlags | CVAR_FLAGS;
    cv = CreateConVar(szBuffer, szDefaultValue, szDescription, iFlags, bHasMin, fMin, bHasMax, fMax);
    return cv;
}

ConVar FindConVarEx(const char[] szName) {
    char szBuffer[128];
    Format(szBuffer, sizeof(szBuffer), "%s%s", CVAR_PREFIX, szName);
    return FindConVar(szBuffer);
}

bool IsPluginEnabled(bool bSetStatus = false, bool bStatus = false) {
    if (bSetStatus)
        bIsPluginEnabled = bStatus;
    return bIsPluginEnabled;
}

stock int GetSurvivorPermanentHealth(int iClient) {
    return GetEntProp(iClient, Prop_Send, "m_iHealth");
}

stock int GetSurvivorTempHealth(int iClient) {
    int iTmpHp = RoundToCeil(GetEntPropFloat(iClient, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(iClient, Prop_Send, "m_healthBufferTime")) * FindConVar("pain_pills_decay_rate").FloatValue)) - 1;
    return iTmpHp > 0 ? iTmpHp : 0;
}

stock int GetSurvivorIncapCount(int iClient) {
    return GetEntProp(iClient, Prop_Send, "m_currentReviveCount");
}

stock bool IsSurvivor(int iClient) {
    return IsClientInGame(iClient) && GetClientTeam(iClient) == 2;
}

stock int InSecondHalfOfRound() {
    return GameRules_GetProp("m_bInSecondHalfOfRound");
}

stock void ZeroVector(float fVec[3]) {
    fVec = NULL_VECTOR;
}

stock void AddToVector(float fTo[3], float fFrom[3]) {
    fTo[0] += fFrom[0];
    fTo[1] += fFrom[1];
    fTo[2] += fFrom[2];
}

stock void CopyVector(float fTo[3], float fFrom[3]) {
    fTo = fFrom;
}

stock int GetURandomIntRange(int iMin, int iMax) {
    return RoundToNearest((GetURandomFloat() * (iMax - iMin)) + iMin);
}

/**
 * Finds the first occurrence of a pattern in another string.
 *
 * @param szStr         String to search in.
 * @param szPattern     String pattern to search for
 * @param bReverse      False (default) to search forward, true to search
 *                      backward.
 * @return              The index of the first character of the first
 *                      occurrence of the pattern in the string, or -1 if the
 *                      character was not found.
 */
stock int FindPatternInString(const char[] szStr, const char[] szPattern, bool bReverse = false) {
    int len = strlen(szPattern);
    int c   = szPattern[0];
    int i;
    while (i < len && (i = FindCharInString(szStr[i], c, bReverse)) != -1) {
        if (strncmp(szStr[i], szPattern, len))
            return i;
    }
    return -1;
}

/**
 * Counts the number of occurences of pattern in another string.
 *
 * @param szStr         String to search in.
 * @param szPattern     String pattern to search for
 * @param bOverlap      False (default) to count only non-overlapping
 *                      occurences, true to count matches within other
 *                      occurences.
 * @return              The number of occurences of the pattern in the string
 */
stock int CountPatternsInString(const char[] szStr, const char[] szPattern, bool bOverlap = false) {
    int off;
    int i;
    int delta;
    int cnt;
    int len = strlen(szStr);
    delta = bOverlap ? strlen(szPattern) : 1;
    while (i < len && (off = FindPatternInString(szStr[i], szPattern)) != -1) {
        cnt++;
        i += off + delta;
    }
    return cnt;
}

/**
 * Counts the number of occurences of pattern in another string.
 *
 * @param szStr         String to search in.
 * @param c             Character to search for.
 * @return              The number of occurences of the pattern in the string
 */
stock int CountCharsInString(const char[] szStr, int c) {
    int off;
    int i;
    int cnt;
    int len = strlen(szStr);
    while (i < len && (off = FindCharInString(szStr[i], c)) != -1) {
        cnt++;
        i += off + 1;
    }
    return cnt;
}