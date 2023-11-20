#if defined __CMDS_RATES__
    #endinput
#endif
#define __CMDS_RATES__

Action Cmd_Rates(int iClient, int iArgs) {
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
            CPrintToChat(iClient, "{green}[{default}FPS{green}]{default} List of approximate rate values:{blue}");
            bFound[L4D2Team_None] = true;
        }

        if (!bFound[L4D2Team_Spectator]) {
            CPrintToChat(iClient, " {green}[{olive}Spectators{green}]{blue}");
            bFound[L4D2Team_Spectator] = true;
        }

        CPrintToChat(iClient, "  {green}» {olive}%N{default}'s cmdrate: {green}%.0f{default}, updaterate: {green}%.0f{blue}", i, GetClientAvgPackets(i, NetFlow_Incoming), GetClientAvgPackets(i, NetFlow_Outgoing));
    }

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        if (GetClientTeam(i) != L4D2Team_Survivor)
            continue;

        if (!bFound[L4D2Team_None]) {
            CPrintToChat(iClient, "{green}[{default}FPS{green}]{default} List of approximate rate values:{blue}");
            bFound[L4D2Team_None] = true;
        }

        if (!bFound[L4D2Team_Survivor]) {
            CPrintToChat(iClient, " {green}[{blue}Survivors Team{green}]");
            bFound[L4D2Team_Survivor] = true;
        }

        CPrintToChat(iClient, "  {green}» {blue}%N{default}'s cmdrate: {green}%.0f{default}, updaterate: {green}%.0f", i, GetClientAvgPackets(i, NetFlow_Incoming), GetClientAvgPackets(i, NetFlow_Outgoing));
    }

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        if (GetClientTeam(i) != L4D2Team_Infected)
            continue;

        if (!bFound[L4D2Team_None]) {
            CPrintToChat(iClient, "{green}[{default}FPS{green}]{default} List of approximate rate values:{blue}");
            bFound[L4D2Team_None] = true;
        }

        if (!bFound[L4D2Team_Infected]) {
            CPrintToChat(iClient, " {green}[{red}Infected Team{green}]");
            bFound[L4D2Team_Infected] = true;
        }

        CPrintToChat(iClient, "  {green}» {red}%N{default}'s cmdrate: {green}%.0f{default}, updaterate: {green}%.0f", i, GetClientAvgPackets(i, NetFlow_Incoming), GetClientAvgPackets(i, NetFlow_Outgoing));
    }

    iPreviousTime[iClient] = iCurrentTime[iClient];
    return Plugin_Handled;
}