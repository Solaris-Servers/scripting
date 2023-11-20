#if defined __CMDS_LERPS__
    #endinput
#endif
#define __CMDS_LERPS__

Action Cmd_Lerps(int iClient, int iArgs) {
    iCurrentTime[iClient] = GetTime();
    if (iCurrentTime[iClient] - iPreviousTime[iClient] < ANTISPAM)
        return Plugin_Handled;

    static bool bFound[L4D2Team_Size - 1];
    for (int i = 0; i < L4D2Team_Size - 1; i++) {
        bFound[i] = false;
    }

    static char szSteamId[32];

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        if (GetClientTeam(i) != L4D2Team_Spectator)
            continue;

        if (!GetClientAuthId(i, AuthId_Steam2, szSteamId, sizeof(szSteamId)))
            continue;

        if (!bFound[L4D2Team_None]) {
            CPrintToChat(iClient, "{green}[{default}Lerp Monitor{green}]{default} List of players lerp settings:{blue}");
            bFound[L4D2Team_None] = true;
        }

        if (!bFound[L4D2Team_Spectator]) {
            CPrintToChat(iClient, " {green}[{olive}Spectators{green}]{blue}");
            bFound[L4D2Team_Spectator] = true;
        }

        CPrintToChat(iClient, "  {green}» {olive}%N {green}[{default}%s{green}]{default}: {green}%.01f", i, szSteamId, GetPlayerLerp(i));
    }

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        if (GetClientTeam(i) != L4D2Team_Survivor)
            continue;

        if (!GetClientAuthId(i, AuthId_Steam2, szSteamId, sizeof(szSteamId)))
            continue;

        if (!bFound[L4D2Team_None]) {
            CPrintToChat(iClient, "{green}[{default}Lerp Monitor{green}]{default} List of players lerp settings:{blue}");
            bFound[L4D2Team_None] = true;
        }

        if (!bFound[L4D2Team_Survivor]) {
            CPrintToChat(iClient, " {green}[{blue}Survivors Team{green}]");
            bFound[L4D2Team_Survivor] = true;
        }

        CPrintToChat(iClient, "  {green}» {blue}%N {green}[{default}%s{green}]{default}: {olive}%.01f", i, szSteamId, GetPlayerLerp(i));
    }

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        if (GetClientTeam(i) != L4D2Team_Infected)
            continue;

        if (!GetClientAuthId(i, AuthId_Steam2, szSteamId, sizeof(szSteamId)))
            continue;

        if (!bFound[L4D2Team_None]) {
            CPrintToChat(iClient, "{green}[{default}Lerp Monitor{green}]{default} List of players lerp settings:{blue}");
            bFound[L4D2Team_None] = true;
        }

        if (!bFound[L4D2Team_Infected]) {
            CPrintToChat(iClient, " {green}[{red}Infected Team{green}]");
            bFound[L4D2Team_Infected] = true;
        }

        CPrintToChat(iClient, "  {green}» {red}%N {green}[{default}%s{green}]{default}: {olive}%.01f", i, szSteamId, GetPlayerLerp(i));
    }

    iPreviousTime[iClient] = iCurrentTime[iClient];
    return Plugin_Handled;
}