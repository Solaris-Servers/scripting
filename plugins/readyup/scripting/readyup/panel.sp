#if defined _readyup_panel_included
    #endinput
#endif
#define _readyup_panel_included

static Footer CmdFooter;
static int    iCurCmd;
static Handle hMenu;
static Handle hMenuCmd;
static const char szHintPhrase  [2][] = {"You are not ready.\nSay !ready / Press F1 to ready up.", "You are ready.\nSay !unready / Press F2 to unready."};
static const char szReadySymbol [2][] = {"☐ ", "☑ "};

void InitPanel() {
    if (hMenu != null)
        delete hMenu;

    if (hMenuCmd != null)
        delete hMenuCmd;

    iCurCmd = 0;

    if (CmdFooter == null) {
        CmdFooter = new Footer();
        CmdFooter.Add("!mix - Mix teams");
        CmdFooter.Add("!gagspec - Gag spectators");
        CmdFooter.Add("!kickspec - Kick spectators");
        CmdFooter.Add("!match - Load a config");
        CmdFooter.Add("!callvote - Start a vote");
    }

    hMenu    = CreateTimer(1.0, Timer_MenuRefresh, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    hMenuCmd = CreateTimer(4.0, Timer_MenuCmd,     _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

void ResetPanel() {
    if (CmdFooter == null)
        return;
    delete CmdFooter;
    iCurCmd = 0;
}

void AddToPanel(const char[] szCmd) {
    if (CmdFooter == null)
        CmdFooter = new Footer();
    CmdFooter.Add(szCmd);
}

int DummyHandler(Menu mMenu, MenuAction maAction, int iParam1, int iParam2) {
    /* Here goes nothing */
    return 1;
}

Action Timer_MenuRefresh(Handle hTimer) {
    if (g_bInReadyUp) {
        UpdatePanel();
        return Plugin_Continue;
    }

    hMenu = null
    return Plugin_Stop;
}

Action Timer_MenuCmd(Handle hTimer) {
    if (g_bInReadyUp) {
        if (CmdFooter == null) {
            hMenuCmd = null
            return Plugin_Stop;
        }

        if (CmdFooter.Length)
            iCurCmd = (iCurCmd + 1) % CmdFooter.Length;
        return Plugin_Continue;
    }

    hMenuCmd = null
    return Plugin_Stop;
}

void UpdatePanel() {
    Panel mPanel = new Panel();
    switch (g_iReadyUpMode) {
        case ReadyMode_PlayerReady: {
            PlayerReadyPanel(mPanel);
        }
        case ReadyMode_TeamReady: {
            TeamReadyPanel(mPanel);
        }
    }

    // Send Panel to clients
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i) && !IsClientSourceTV(i))
            continue;

        if (IsPlayerHiddenPanel(i))
            continue;

        if (SolarisVotes_IsVoteInProgress() && SolarisVotes_IsClientInVotePool(i))
            continue;

        switch (GetClientMenu(i)) {
            case MenuSource_External, MenuSource_Normal:
                continue;
        }

        mPanel.Send(i, DummyHandler, 1);
    }

    delete mPanel;
}

void PlayerReadyPanel(Panel mPanel) {
    char szInfo   [64];
    char szTeamBuf[64];
    char szNameBuf[MAX_NAME_LENGTH];

    // Server name
    char szServerNamer[64];
    FillServerNamer(szServerNamer);
    FormatEx(szInfo, sizeof(szInfo), "▸ Server: %s", szServerNamer);
    mPanel.DrawText(szInfo);

    // Config name
    char szCfgName[32];
    g_cvReadyCfgName.GetString(szCfgName, sizeof(szCfgName));
    FormatEx(szInfo, sizeof(szInfo), "▸ Config: %s", szCfgName);
    mPanel.DrawText(szInfo);

    // Server slots
    int iMaxPlayers = FindConVar("sv_maxplayers").IntValue;
    FormatEx(szInfo, sizeof(szInfo), "▸ Slots: %d/%d [!slots]", GetSeriousClientCount(), iMaxPlayers);
    mPanel.DrawText(szInfo);

    // Server tips
    FormatEx(szInfo, sizeof(szInfo), "▸ Tip: %s", CmdFooter.Get(iCurCmd));
    mPanel.DrawText(szInfo);

    mPanel.DrawText("‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒");

    // Survivors Buffer
    mPanel.DrawItem("Survivors");
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        if (TM_IsPlayerRespectating(i))
            continue;

        if (GetClientTeam(i) == L4D2Team_Survivor) {
            int iReady = view_as<int>(IsPlayerReady(i));
            if (IsClientTimingOut(i)) {
                SetPlayerReady(i, false);
                CancelFullReady(i, eReadyStatus);
            }

            if (!g_bInLiveCountdown)
                PrintHintText(i, "%s", szHintPhrase[iReady]);

            GetClientFixedName(i, szNameBuf, sizeof(szNameBuf));
            FormatEx(szTeamBuf, sizeof(szTeamBuf), " %s%s%s", szReadySymbol[iReady], szNameBuf, IsClientTimingOut(i) ? " [Crashed]" : IsPlayerAfk(i) ? " [AFK]" : "");
            mPanel.DrawText(szTeamBuf);
        }
    }

    // Empty slots in survivors team
    if (GetTeamHumanCount(L4D2Team_Survivor) < GetTeamMaxHumans(L4D2Team_Survivor)) {
        for (int i; i < (GetTeamMaxHumans(L4D2Team_Survivor) - GetTeamHumanCount(L4D2Team_Survivor)); i++) {
            mPanel.DrawText(" ☐");
        }
    }

    // Infected Buffer
    mPanel.DrawItem("Infected");
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        if (TM_IsPlayerRespectating(i))
            continue;

        if (GetClientTeam(i) == L4D2Team_Infected) {
            int iReady = IsPlayerReady(i);
            if (IsClientTimingOut(i)) {
                SetPlayerReady(i, false);
                CancelFullReady(i, eReadyStatus);
            }

            if (!g_bInLiveCountdown)
                PrintHintText(i, "%s", szHintPhrase[iReady]);

            GetClientFixedName(i, szNameBuf, sizeof(szNameBuf));
            FormatEx(szTeamBuf, sizeof(szTeamBuf), " %s%s%s", szReadySymbol[iReady], szNameBuf, IsClientTimingOut(i) ? " [Crashed]" : IsPlayerAfk(i) ? " [AFK]" : "");
            mPanel.DrawText(szTeamBuf);
        }
    }

    // Empty slots in infected team
    if (GetTeamHumanCount(L4D2Team_Infected) < GetTeamMaxHumans(L4D2Team_Infected)) {
        for (int i; i < (GetTeamMaxHumans(L4D2Team_Infected) - GetTeamHumanCount(L4D2Team_Infected)); i++) {
            mPanel.DrawText(" ☐");
        }
    }

    mPanel.DrawText("‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒");

    // Boss Buffer
    if (g_bIsBossPctAvailable) {
        char szBossBuffer[64];
        bool bTankFlow  = BossPercent_TankEnabled();
        bool bWitchFlow = BossPercent_WitchEnabled();
        if (bTankFlow && bWitchFlow) {
            if (BossPercent_TankPercent() && BossPercent_WitchPercent()) {
                FormatEx(szBossBuffer, sizeof(szBossBuffer), "Tank: %d%%, Witch: %d%%", BossPercent_TankPercent(), BossPercent_WitchPercent());
                mPanel.DrawText(szBossBuffer);
            } else if (BossPercent_TankPercent()) {
                FormatEx(szBossBuffer, sizeof(szBossBuffer), "Tank: %d%%, Witch: %s", BossPercent_TankPercent(), IsStaticWitch() ? "Static" : "None");
                mPanel.DrawText(szBossBuffer);
            } else if (BossPercent_WitchPercent()) {
                FormatEx(szBossBuffer, sizeof(szBossBuffer), "Tank: %s, Witch: %d%%", IsStaticTank() ? "Static" : "None", BossPercent_WitchPercent());
                mPanel.DrawText(szBossBuffer);
            } else {
                FormatEx(szBossBuffer, sizeof(szBossBuffer), "Tank: %s, Witch: %s", IsStaticTank() ? "Static" : "None", IsStaticWitch() ? "Static" : "None");
                mPanel.DrawText(szBossBuffer);
            }
        } else if (bTankFlow) {
            if (BossPercent_TankPercent()) {
                FormatEx(szBossBuffer, sizeof(szBossBuffer), "Tank: %d%%", BossPercent_TankPercent());
                mPanel.DrawText(szBossBuffer);
            } else {
                FormatEx(szBossBuffer, sizeof(szBossBuffer), "Tank: %s", IsStaticTank() ? "Static" : "None");
                mPanel.DrawText(szBossBuffer);
            }
        } else if (bWitchFlow) {
            if (BossPercent_WitchPercent()) {
                FormatEx(szBossBuffer, sizeof(szBossBuffer), "Witch: %d%%", BossPercent_WitchPercent());
                mPanel.DrawText(szBossBuffer);
            } else {
                FormatEx(szBossBuffer, sizeof(szBossBuffer), "Witch: %s", IsStaticWitch() ? "Static" : "None");
                mPanel.DrawText(szBossBuffer);
            }
        }
    }

    // Special Infected Spawn Buffer
    int iSpawns;
    int iSpawnCls[L4D2Infected_Size];

    for (int i = 1; i <= MaxClients && iSpawns < L4D2Infected_Size; i++) {
        if (!IsClientInGame(i))
            continue;

        if (GetClientTeam(i) != L4D2Team_Infected)
            continue;

        if (!IsPlayerAlive(i))
            continue;

        iSpawnCls[iSpawns] = GetInfectedClass(i);
        iSpawns++;
    }

    char szSpawnsBuffer[256];
    if (iSpawns > 0) {
        strcopy(szSpawnsBuffer, sizeof(szSpawnsBuffer), "SI: ");
        for (int i = 0; i < iSpawns; i++) {
            Format(szSpawnsBuffer, sizeof(szSpawnsBuffer), "%s%s%s", szSpawnsBuffer, i > 0 ? ", " : "", L4D2_InfectedNames[iSpawnCls[i]]);
        }
        mPanel.DrawText(szSpawnsBuffer);
    }
}

void TeamReadyPanel(Panel mPanel) {
    char szInfo[64];

    // Server name
    char szServerNamer[64];
    FillServerNamer(szServerNamer);
    FormatEx(szInfo, sizeof(szInfo), "%s", szServerNamer);
    mPanel.DrawText(szInfo);

    mPanel.DrawText("‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒");

    // Server slots
    int iMaxPlayers = FindConVar("sv_maxplayers").IntValue;
    FormatEx(szInfo, sizeof(szInfo), " Slots: %d/%d [!slots]", GetSeriousClientCount(), iMaxPlayers);
    mPanel.DrawText(szInfo);

    // Server tips
    FormatEx(szInfo, sizeof(szInfo), " Tip: %s", CmdFooter.Get(iCurCmd));
    mPanel.DrawText(szInfo);

    mPanel.DrawText("‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒");

    int iReady;
    if (g_cvReadyUnbalancedStart.BoolValue) {
        // Survivors Buffer
        if (GetTeamHumanCount(L4D2Team_Survivor) != 0) {
            iReady = IsTeamReady(L4D2Team_Survivor);
            FormatEx(szInfo, sizeof(szInfo), " %sSurvivors", szReadySymbol[iReady]);
            mPanel.DrawText(szInfo);
        }

        // Infected Buffer
        if (GetTeamHumanCount(L4D2Team_Infected) != 0) {
            iReady = IsTeamReady(L4D2Team_Infected);
            FormatEx(szInfo, sizeof(szInfo), " %sInfected", szReadySymbol[iReady]);
            mPanel.DrawText(szInfo);
        }

        // No players
        if (GetTeamHumanCount(L4D2Team_Survivor) == 0 && GetTeamHumanCount(L4D2Team_Infected) == 0) {
            mPanel.DrawText(" No player in any team!");
        }
    } else {
        // Survivors Buffer
        iReady = IsTeamReady(L4D2Team_Survivor);
        FormatEx(szInfo, sizeof(szInfo), " %sSurvivors", szReadySymbol[iReady]);
        mPanel.DrawText(szInfo);

        // Infected Buffer
        iReady = IsTeamReady(L4D2Team_Infected);
        FormatEx(szInfo, sizeof(szInfo), " %sInfected", szReadySymbol[iReady]);
        mPanel.DrawText(szInfo);
    }

    if (!TM_IsFinishedLoading()) {
        char szBuffer[256];
        if (TM_GetPlayersInLoad() > 0) FormatEx(szBuffer, sizeof(szBuffer), "%d player%s loading. Please wait!", TM_GetPlayersInLoad(), TM_GetPlayersInLoad() == 1 ? " is" : "s are");
        else                           FormatEx(szBuffer, sizeof(szBuffer), "Every player has loaded. Game begins!");
        for (int i = 1; i <= MaxClients; i++) {
            if (!IsClientInGame(i))
                continue;

            if (IsFakeClient(i))
                continue;

            if (!IsPlayer(i))
                continue;

            PrintHintText(i, szBuffer);
        }
    } else if (!g_bInLiveCountdown) {
        for (int i = 1; i <= MaxClients; i++) {
            if (!IsClientInGame(i))
                continue;

            if (IsFakeClient(i))
                continue;

            if (!IsPlayer(i))
                continue;

            PrintHintText(i, "%s", szHintPhrase[view_as<int>(IsTeamReady(GetClientTeam(i)))]);
        }
    }

    mPanel.DrawText("‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒");

    // Boss Buffer
    if (g_bIsBossPctAvailable) {
        char szBossBuffer[64];
        bool bTankFlow  = BossPercent_TankEnabled();
        bool bWitchFlow = BossPercent_WitchEnabled();
        if (bTankFlow && bWitchFlow) {
            if (BossPercent_TankPercent() && BossPercent_WitchPercent()) {
                FormatEx(szBossBuffer, sizeof(szBossBuffer), "Tank: %d%%, Witch: %d%%", BossPercent_TankPercent(), BossPercent_WitchPercent());
                mPanel.DrawText(szBossBuffer);
            } else if (BossPercent_TankPercent()) {
                FormatEx(szBossBuffer, sizeof(szBossBuffer), "Tank: %d%%, Witch: %s", BossPercent_TankPercent(), IsStaticWitch() ? "Static" : "None");
                mPanel.DrawText(szBossBuffer);
            } else if (BossPercent_WitchPercent()) {
                FormatEx(szBossBuffer, sizeof(szBossBuffer), "Tank: %s, Witch: %d%%", IsStaticTank() ? "Static" : "None", BossPercent_WitchPercent());
                mPanel.DrawText(szBossBuffer);
            } else {
                FormatEx(szBossBuffer, sizeof(szBossBuffer), "Tank: %s, Witch: %s", IsStaticTank() ? "Static" : "None", IsStaticWitch() ? "Static" : "None");
                mPanel.DrawText(szBossBuffer);
            }
        } else if (bTankFlow) {
            if (BossPercent_TankPercent()) {
                FormatEx(szBossBuffer, sizeof(szBossBuffer), "Tank: %d%%", BossPercent_TankPercent());
                mPanel.DrawText(szBossBuffer);
            } else {
                FormatEx(szBossBuffer, sizeof(szBossBuffer), "Tank: %s", IsStaticTank() ? "Static" : "None");
                mPanel.DrawText(szBossBuffer);
            }
        } else if (bWitchFlow) {
            if (BossPercent_WitchPercent()) {
                FormatEx(szBossBuffer, sizeof(szBossBuffer), "Witch: %d%%", BossPercent_WitchPercent());
                mPanel.DrawText(szBossBuffer);
            } else {
                FormatEx(szBossBuffer, sizeof(szBossBuffer), "Witch: %s", IsStaticWitch() ? "Static" : "None");
                mPanel.DrawText(szBossBuffer);
            }
        }
    }

    // Special Infected Spawn Buffer
    int iSpawns;
    int iSpawnCls[L4D2Infected_Size];

    for (int i = 1; i <= MaxClients && iSpawns < L4D2Infected_Size; i++) {
        if (!IsClientInGame(i))
            continue;

        if (GetClientTeam(i) != L4D2Team_Infected)
            continue;

        if (!IsPlayerAlive(i))
            continue;

        iSpawnCls[iSpawns] = GetInfectedClass(i);
        iSpawns++;
    }

    char szSpawnsBuffer[256];
    if (iSpawns > 0) {
        strcopy(szSpawnsBuffer, sizeof(szSpawnsBuffer), "SI: ");
        for (int i = 0; i < iSpawns; i++) {
            Format(szSpawnsBuffer, sizeof(szSpawnsBuffer), "%s%s%s", szSpawnsBuffer, i > 0 ? ", " : "", L4D2_InfectedNames[iSpawnCls[i]]);
        }

        mPanel.DrawText(szSpawnsBuffer);
    }
}

void PanelEnd() {
    hMenu    = null;
    hMenuCmd = null;
}