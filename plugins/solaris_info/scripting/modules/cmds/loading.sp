#if defined __CMDS_LOADING__
    #endinput
#endif
#define __CMDS_LOADING__

Action Cmd_LoadingTimes(int iClient, int iArgs) {
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
            CPrintToChat(iClient, "{green}[{default}Loading Times{green}]{default} List of loading times:{blue}");
            bFound[L4D2Team_None] = true;
        }

        if (!bFound[L4D2Team_Spectator]) {
            CPrintToChat(iClient, " {green}[{olive}Spectators{green}]{blue}");
            bFound[L4D2Team_Spectator] = true;
        }

        CPrintToChat(iClient, "  {green}» {olive}%N{default} loaded in {green}%.1f{default} seconds{blue}", i, GetPlayerLoadingTime(i));
    }

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        if (GetClientTeam(i) != L4D2Team_Survivor)
            continue;

        if (!bFound[L4D2Team_None]) {
            CPrintToChat(iClient, "{green}[{default}Loading Times{green}]{default} List of loading times:{blue}");
            bFound[L4D2Team_None] = true;
        }

        if (!bFound[L4D2Team_Survivor]) {
            CPrintToChat(iClient, " {green}[{blue}Survivors Team{green}]");
            bFound[L4D2Team_Survivor] = true;
        }

        CPrintToChat(iClient, "  {green}» {blue}%N{default} loaded in {green}%.1f{default} seconds", i, GetPlayerLoadingTime(i));
    }

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        if (GetClientTeam(i) != L4D2Team_Infected)
            continue;

        if (!bFound[L4D2Team_None]) {
            CPrintToChat(iClient, "{green}[{default}Loading Times{green}]{default} List of loading times:{blue}");
            bFound[L4D2Team_None] = true;
        }

        if (!bFound[L4D2Team_Infected]) {
            CPrintToChat(iClient, " {green}[{red}Infected Team{green}]");
            bFound[L4D2Team_Infected] = true;
        }

        CPrintToChat(iClient, "  {green}» {red}%N{default} loaded in {green}%.1f{default} seconds", i, GetPlayerLoadingTime(i));
    }

    iPreviousTime[iClient] = iCurrentTime[iClient];
    return Plugin_Handled;
}