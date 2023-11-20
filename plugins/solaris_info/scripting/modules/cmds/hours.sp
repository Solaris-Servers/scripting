#if defined __CMDS_HOURS__
    #endinput
#endif
#define __CMDS_HOURS__

Action Cmd_Hours(int iClient, int iArgs) {
    iCurrentTime[iClient] = GetTime();
    if (iCurrentTime[iClient] - iPreviousTime[iClient] < ANTISPAM)
        return Plugin_Handled;

    static bool bFound[L4D2Team_Size - 1];
    for (int i = 0; i < L4D2Team_Size - 1; i++) {
        bFound[i] = false;
    }

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        if (GetClientTeam(i) != L4D2Team_Spectator)
            continue;

        if (!bFound[L4D2Team_None]) {
            CPrintToChat(iClient, "{green}[{default}Hours{green}]{default} List of players play time:{blue}");
            bFound[L4D2Team_None] = true;
        }

        if (!bFound[L4D2Team_Spectator]) {
            CPrintToChat(iClient, " {green}[{olive}Spectators{green}]{blue}");
            bFound[L4D2Team_Spectator] = true;
        }

        CPrintToChat(iClient, "  {green}» {olive}%N{default}'s hours: {green}%.01f{blue}", i, GetPlayerHours(i));
    }

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        if (GetClientTeam(i) != L4D2Team_Survivor)
            continue;

        if (!bFound[L4D2Team_None]) {
            CPrintToChat(iClient, "{green}[{default}Hours{green}]{default} List of players play time:{blue}");
            bFound[L4D2Team_None] = true;
        }

        if (!bFound[L4D2Team_Survivor]) {
            CPrintToChat(iClient, " {green}[{blue}Survivors Team{green}]");
            bFound[L4D2Team_Survivor] = true;
        }

        CPrintToChat(iClient, "  {green}» {blue}%N{default}'s hours: {green}%.01f", i, GetPlayerHours(i));
    }

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        if (GetClientTeam(i) != L4D2Team_Infected)
            continue;

        if (!bFound[L4D2Team_None]) {
            CPrintToChat(iClient, "{green}[{default}Hours{green}]{default} List of players play time:{blue}");
            bFound[L4D2Team_None] = true;
        }

        if (!bFound[L4D2Team_Infected]) {
            CPrintToChat(iClient, " {green}[{red}Infected Team{green}]");
            bFound[L4D2Team_Infected] = true;
        }

        CPrintToChat(iClient, "  {green}» {red}%N{default}'s hours: {green}%.01f", i, GetPlayerHours(i));
    }

    iPreviousTime[iClient] = iCurrentTime[iClient];
    return Plugin_Handled;
}