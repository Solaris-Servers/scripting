#if defined __Stocks__
    #endinput
#endif
#define __Stocks__

stock int GetInGameClient() {
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))    continue;
        if (GetClientTeam(i) != 2) continue;
        if (IsFakeClient(i))       continue;
        return i;
    }
    return -1;
}

stock bool InSecondHalfOfRound() {
    return view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"));
}