#if defined __SpecChat__
    #endinput
#endif
#define __SpecChat__

void Specs_OnChatMessage(int iTeam, ArrayList aRecipients, bool bTeamChat) {
    if (!IsConfoglEnabled())
        return;

    if (iTeam <= TEAM_SPECTATORS)
        return;

    if (!bTeamChat)
        return;

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        if ((ST_IsSpecClient(i) || TM_IsPlayerRespectating(i)) && aRecipients.FindValue(GetClientUserId(i)) == -1) {
            aRecipients.Push(GetClientUserId(i));
        }
    }
}