#if defined __Stocks__
    #endinput
#endif
#define __Stocks__

/**
 * Returns true if specified bot is valid
 * @param   iBot            Bot
 * @return  bool
 */
stock bool IsSurvivorBotValid(int iBot) {
    if (IsClientInGame(iBot) && IsFakeClient(iBot) && !IsClientInKickQueue(iBot) && GetClientTeam(iBot) == TEAM_SURVIVORS && IsPlayerAlive(iBot))
        return true;
    return false;
}

/**
 * Returns true if specified client is idle
 * @param   iClient         Client
 * @return  bool
 */
stock bool IsClientIdle(int iClient) {
    char szNetClass[12];
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsSurvivorBotValid(i))
            continue;

        GetEntityNetClass(i, szNetClass, sizeof(szNetClass));
        if (strcmp(szNetClass, "SurvivorBot") == 0) {
            if (GetClientOfUserId(GetEntProp(i, Prop_Send, "m_humanSpectatorUserID")) == iClient)
                return true;
        }
    }
    return false;
}

/**
 * Returns true if confogl match mode enabled
 * @return  bool
 */
stock bool IsConfoglEnabled() {
    return g_bIsConfoglEnabled;
}

/**
 * Returns time when last message was sent by specified client
 * @param   iClient         Client
 * @return  float
 */
stock float GetLastMessageTime(int iClient) {
    return g_fLastMessage[iClient];
}

/**
 * Sets time when last message was sent by specified client
 * @return  void
 */
stock void SetLastMessageTime(int iClient) {
    g_fLastMessage[iClient] = GetEngineTime();
}

/**
 * Create say event
 * @return  void
 */
void CreateSayEvent(int iUserId, const char[] szMsg) {
    // Event
    Event eEvent = CreateEvent("player_say");
    if (eEvent != null) {
        eEvent.SetInt("userid", iUserId);
        eEvent.SetString("text", szMsg);
        eEvent.Fire();
    }
}