#if defined _readyup_game_included
    #endinput
#endif
#define _readyup_game_included

Action Timer_RestartCountdowns(Handle hTimer, bool bStartOn) {
    RestartCountdowns(bStartOn);
    return Plugin_Stop;
}

void RestartCountdowns(bool bStartOn) {
    if (!g_bInReadyUp && !bStartOn)
        return;

    if (SDK_IsScavenge()) {
        RestartScvngSetupCountdown(bStartOn);
        ResetAccumulatedTime();
    } else {
        RestartVersusStartCountdown(bStartOn);
    }

    RestartMobCountdown(bStartOn);
}

void ResetAccumulatedTime() {
    static ConVar cvScavengeRoundInitialTime = null;
    if ((cvScavengeRoundInitialTime = FindConVar("scavenge_round_initial_time")) == null)
        return;

    L4D_NotifyNetworkStateChanged();
    GameRules_SetPropFloat("m_flAccumulatedTime", cvScavengeRoundInitialTime.FloatValue);
}

void RestartVersusStartCountdown(bool bStartOn) {
    static ConVar cv = null;
    if (cv == null) {
        if ((cv = FindConVar("versus_force_start_time")) == null)
            return;
    }

    L4D2_CTimerStart(L4D2CT_VersusStartTimer, bStartOn ? cv.FloatValue : 99999.9);
}

// TODO: Implement script override
static float GetRandomMobSpawnInterval() {
    static ConVar cvMinInterval, cvMaxInterval;

    static ConVar cvDifficulty;
    char szDifficulty[10] = "normal";

    if (L4D2_HasConfigurableDifficultySetting()) {
        if (cvDifficulty == null)
            cvDifficulty = FindConVar("z_difficulty");

        char szBuffer[10];
        cvDifficulty.GetString(szBuffer, sizeof(szBuffer));
        ST_StrToLower(szBuffer, szBuffer, sizeof(szBuffer));

        if (strcmp(szBuffer, "impossible") == 0)
            strcopy(szBuffer, sizeof(szBuffer), "expert");

        if (strcmp(szBuffer, szDifficulty) != 0) {
            strcopy(szDifficulty, sizeof(szDifficulty), szBuffer);
            cvMinInterval = null;
            cvMaxInterval = null;
        }
    }

    char szBuffer[64];

    if (cvMinInterval == null) {
        FormatEx(szBuffer, sizeof(szBuffer), "z_mob_spawn_min_interval_%s", szDifficulty);
        cvMinInterval = FindConVar(szBuffer);
        if (cvMinInterval == null) ThrowError("Missing ConVar \"z_mob_spawn_min_interval_%s\" for mob spawn interval!", szDifficulty);
    }

    if (cvMaxInterval == null) {
        FormatEx(szBuffer, sizeof(szBuffer), "z_mob_spawn_max_interval_%s", szDifficulty);
        cvMaxInterval = FindConVar(szBuffer);
        if (cvMaxInterval == null) ThrowError("Missing ConVar \"z_mob_spawn_max_interval_%s\" for mob spawn interval!", szDifficulty);
    }

    SetRandomSeed(GetTime());
    return GetRandomFloat(cvMinInterval.FloatValue, cvMaxInterval.FloatValue);
}

void RestartMobCountdown(bool bStartOn) {
    float fDuration = bStartOn ? GetRandomMobSpawnInterval() : 99999.9;
    L4D2_CTimerStart(L4D2CT_MobSpawnTimer, fDuration);
}

void RestartScvngSetupCountdown(bool bStartOn) {
    static ConVar cv = null;
    if (cv == null) {
        if ((cv = FindConVar("scavenge_round_setup_time")) == null)
            return;
    }
    CountdownTimer cTimer = L4D2Direct_GetScavengeRoundSetupTimer();
    if (cTimer == CTimer_Null)
        return;
    CTimer_Start(cTimer, bStartOn ? cv.FloatValue : 99999.9);
    ToggleCountdownPanel(bStartOn);
}

void ToggleCountdownPanel(bool bOnOff, int client = 0) {
    if (client > 0 && IsClientInGame(client)) {
        ShowVGUIPanel(client, "ready_countdown", _, bOnOff);
    } else {
        for (int i = 1; i <= MaxClients; i++) {
            if (!IsClientInGame(i))
                continue;

            if (IsFakeClient(i))
                continue;

            ShowVGUIPanel(i, "ready_countdown", _, bOnOff);
        }
    }
}

void ClearSurvivorProgress() {
    for (int i = 0; i < 4; i++) {
        GameRules_SetProp("m_iVersusDistancePerSurvivor", 0, _, i + 4 * GameRules_GetProp("m_bAreTeamsFlipped"));
    }
}

void SetAllowSpawns(bool bAllow) {
    g_cvDirectorNoSpecials.BoolValue = bAllow;
}