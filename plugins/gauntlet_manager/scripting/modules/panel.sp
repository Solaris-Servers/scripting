#if defined __PANEL__
    #endinput
#endif
#define __PANEL__

Handle hMenuRefreshTimer;

void OnMapEnd_Panel() {
    hMenuRefreshTimer = null;
}

void InitInfo() {
    if (hMenuRefreshTimer != null) {
        KillTimer(hMenuRefreshTimer);
        hMenuRefreshTimer = null;
    }

    hMenuRefreshTimer = CreateTimer(1.0, Timer_MenuRefresh, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_MenuRefresh(Handle hTimer) {
    if (IsRoundLive()) {
        hMenuRefreshTimer = null;
        return Plugin_Stop;
    }

    UpdatePanel();
    return Plugin_Continue;
}

void UpdatePanel() {
    Panel mPanel = new Panel();

    char szGameInfo[64];
    FormatEx(szGameInfo, sizeof(szGameInfo), "▸ Gauntlet :: Player mode %d [!playermode]", FindConVar("survivor_limit").IntValue);
    mPanel.DrawText(szGameInfo);

    mPanel.DrawText(" ");

    char szSIIntervals[32];
    if (FindConVar("ss_time_min").FloatValue == FindConVar("ss_time_max").FloatValue) {
        FormatEx(szSIIntervals, sizeof(szSIIntervals), "%.1fs", FindConVar("ss_time_min").FloatValue);
    } else {
        FormatEx(szSIIntervals, sizeof(szSIIntervals), "%.1fs - %.1fs", FindConVar("ss_time_min").FloatValue, FindConVar("ss_time_max").FloatValue);
    }

    char szSettings[64];
    FormatEx(szSettings, sizeof(szSettings), "SI spawn limits [!limit]:", FindConVar("ss_smoker_limit").IntValue, FindConVar("ss_boomer_limit").IntValue, FindConVar("ss_hunter_limit").IntValue);
    mPanel.DrawText(szSettings);

    FormatEx(szSettings, sizeof(szSettings), "Smoker: %d - Boomer: %d - Hunter: %d", FindConVar("ss_smoker_limit").IntValue, FindConVar("ss_boomer_limit").IntValue, FindConVar("ss_hunter_limit").IntValue);
    mPanel.DrawText(szSettings);

    FormatEx(szSettings, sizeof(szSettings), "Spitter: %d - Jockey: %d - Charger: %d", FindConVar("ss_spitter_limit").IntValue, FindConVar("ss_jockey_limit").IntValue, FindConVar("ss_charger_limit").IntValue);
    mPanel.DrawText(szSettings);

    mPanel.DrawText(" ");

    FormatEx(szSettings, sizeof(szSettings), "Hunter Deadstops: %s [!deadstops]", DeadstopsAllowed() ? "Enabled" : "Disabled");
    mPanel.DrawText(szSettings);

    FormatEx(szSettings, sizeof(szSettings), "SI spawn interval: %s [!timer]", szSIIntervals);
    mPanel.DrawText(szSettings);

    if (SDK_IsCoop()) {
        FormatEx(szSettings, sizeof(szSettings), "Tank spawn: %s [!toggletank]", FindConVar("flow_tank_enable").BoolValue ? "Enabled" : "Disabled");
        mPanel.DrawText(szSettings);

        FormatEx(szSettings, sizeof(szSettings), "Witch spawn: %s [!togglewitch]", FindConVar("flow_witch_enable").BoolValue ? "Enabled" : "Disabled");
        mPanel.DrawText(szSettings);
    }

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        if (SolarisVotes_IsVoteInProgress() && SolarisVotes_IsClientInVotePool(i))
            continue;

        switch (GetClientMenu(i)) {
            case MenuSource_External, MenuSource_Normal: {
                continue;
            }
        }

        mPanel.Send(i, DummyHandler, 1);
    }

    delete mPanel;
}

int DummyHandler(Menu mMenu, MenuAction maAction, int iClient, int iParam2) {
    /* Here goes nothing*/
    return 0;
}