#if defined _readyup_action_included
    #endinput
#endif
#define _readyup_action_included

#include "sound.sp"

static int    iReadyDelay;
static Handle hReadyCountdownTimer;

void InitiateReadyUp(bool bReal = true) {
    switch (g_iReadyUpMode) {
        case ReadyMode_None: {
            g_bInReadyUp         = true;
            g_bInLiveCountdown   = false;
            g_bIsForceStart      = false;
            hReadyCountdownTimer = null;

            SetAllowSpawns(g_cvReadyDisableSpawns.BoolValue);
            CreateTimer(0.3, Timer_RestartCountdowns, false, TIMER_FLAG_NO_MAPCHANGE);

            g_cvDirectorNoBosses.SetBool(true, .notify = false);
            g_cvInfiniteAmmo.SetBool(false, .notify = false);
            g_cvGod.SetBool(false, .notify = false);
            g_cvSurvivorBotStop.SetBool(false, .notify = false);
        }
        case ReadyMode_PlayerReady: {
            if (bReal) {
                UTIL_WrapperForward(g_fwdPreInitiate)
                for (int i = 1; i <= MaxClients; i++) {
                    SetPlayerReady(i, false);
                    SetButtonTime(i);
                }
                InitPanel();
                UpdatePanel();
            }
            g_bInReadyUp         = true;
            g_bInLiveCountdown   = false;
            g_bIsForceStart      = false;
            hReadyCountdownTimer = null;

            SetAllowSpawns(g_cvReadyDisableSpawns.BoolValue);
            CreateTimer(0.3, Timer_RestartCountdowns, false, TIMER_FLAG_NO_MAPCHANGE);

            g_cvDirectorNoBosses.SetBool(false, .notify = false);
            g_cvInfiniteAmmo.SetBool(true, .notify = false);
            g_cvGod.SetBool(true, .notify = false);
            g_cvSurvivorBotStop.SetBool(true, .notify = false);

            if (bReal) {
                ToggleCommandListeners(true);
                UTIL_WrapperForward(g_fwdInitiate);
            }
        }
        case ReadyMode_TeamReady: {
            if (bReal) {
                UTIL_WrapperForward(g_fwdPreInitiate);
                for (int i = L4D2Team_Survivor; i <= L4D2Team_Infected; i++) {
                    SetTeamReady(i, false);
                }
                InitPanel();
                UpdatePanel();
            }
            g_bInReadyUp         = true;
            g_bInLiveCountdown   = false;
            g_bIsForceStart      = false;
            hReadyCountdownTimer = null;

            SetAllowSpawns(g_cvReadyDisableSpawns.BoolValue);
            CreateTimer(0.3, Timer_RestartCountdowns, false, TIMER_FLAG_NO_MAPCHANGE);

            g_cvDirectorNoBosses.SetBool(false, .notify = false);
            g_cvInfiniteAmmo.SetBool(true, .notify = false);
            g_cvGod.SetBool(true, .notify = false);
            g_cvSurvivorBotStop.SetBool(true, .notify = false);

            if (bReal) {
                ToggleCommandListeners(true);
                UTIL_WrapperForward(g_fwdInitiate);
            }
        }
        case ReadyMode_Loading: {
            g_bInReadyUp         = true;
            g_bInLiveCountdown   = false;
            g_bIsForceStart      = false;
            hReadyCountdownTimer = null;

            SetAllowSpawns(g_cvReadyDisableSpawns.BoolValue);
            CreateTimer(0.3, Timer_RestartCountdowns, false, TIMER_FLAG_NO_MAPCHANGE);

            g_cvDirectorNoBosses.SetBool(true, .notify = false);
            g_cvInfiniteAmmo.SetBool(false, .notify = false);
            g_cvGod.SetBool(false, .notify = false);
            g_cvSurvivorBotStop.SetBool(false, .notify = false);
        }
    }
}

void InitiateLive(bool bReal = true) {
    if (bReal)
        UTIL_WrapperForward(g_fwdPreLive);

    g_bInReadyUp       = false;
    g_bInLiveCountdown = false;
    g_bIsForceStart    = false;
    SetTeamFrozen(L4D2Team_Survivor, false);
    g_cvDirectorNoSpecials.SetBool(false, .notify = false);
    g_cvDirectorNoBosses.SetBool(false, .notify = false);
    g_cvInfiniteAmmo.SetBool(false, .notify = false);
    g_cvGod.SetBool(false, .notify = false);
    g_cvSurvivorBotStop.SetBool(false, .notify = false);
    ToggleCommandListeners(false);

    if (bReal) {
        ClearSurvivorProgress();
        RestartCountdowns(true);
        UTIL_WrapperForward(g_fwdLive);
    }

    hReadyCountdownTimer = null;
}

void InitiateLiveCountdown() {
    if (hReadyCountdownTimer == null) {
        UTIL_WrapperForward(g_fwdPreCountdown);
        ReturnTeamToSaferoom(L4D2Team_Survivor);
        for (int i = 1; i <= MaxClients; i++) {
            if (!IsClientInGame(i))
                continue;

            if (IsFakeClient(i))
                continue;

            PrintHintText(i, "Going live!%s", IsPlayer(i) ? "\nSay !unready / Press F2 to cancel" : "");
        }

        g_bInLiveCountdown = true;
        iReadyDelay = g_cvReadyDelay.IntValue + g_cvReadyForceExtra.IntValue * view_as<int>(g_bIsForceStart);
        hReadyCountdownTimer = CreateTimer(1.0, Timer_ReadyCountdownDelay, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
        UTIL_WrapperForward(g_fwdCountdown);
    }
}

static Action Timer_ReadyCountdownDelay(Handle hTimer) {
    if (iReadyDelay == 0) {
        PrintHintTextToAll("Round is live!");
        InitiateLive(true);
        PlayLiveSound();
        hReadyCountdownTimer = null;
        return Plugin_Stop;
    }

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        PrintHintText(i, "Live in: %d%s", iReadyDelay, IsPlayer(i) ? "\nSay !unready / Press F2 to cancel" : "");
    }

    PlayCountdownSound();
    iReadyDelay--;
    return Plugin_Continue;
}

bool CheckFullReady() {
    int iSurvReadyCount = 0;
    int iInfReadyCount  = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (!IsPlayerReady(i))
            continue;

        switch (GetClientTeam(i)) {
            case L4D2Team_Survivor: iSurvReadyCount++;
            case L4D2Team_Infected: iInfReadyCount++;
        }
    }

    if (g_iReadyUpMode == ReadyMode_TeamReady) {
        if (!g_cvReadyUnbalancedStart.BoolValue) return (IsTeamReady(L4D2Team_Survivor)) && (IsTeamReady(L4D2Team_Infected));
        return (IsTeamReady(L4D2Team_Survivor) || GetTeamHumanCount(L4D2Team_Survivor) == 0) && (IsTeamReady(L4D2Team_Infected) || GetTeamHumanCount(L4D2Team_Infected) == 0);
    }

    int iSurvLimit = g_cvSurvivorLimit.IntValue;
    int iZombLimit = g_cvInfectedLimit.IntValue;
    if (g_cvReadyUnbalancedStart.BoolValue) {
        int iBaseLine = g_cvReadyUnbalancedMin.IntValue;
        if (iBaseLine > iSurvLimit)
            iBaseLine = iSurvLimit;

        if (iBaseLine > iZombLimit)
            iBaseLine = iZombLimit;

        int iSurvCount = GetTeamHumanCount(L4D2Team_Survivor);
        int iInfCount  = GetTeamHumanCount(L4D2Team_Infected);
        return (iBaseLine <= iSurvCount && iSurvCount <= iSurvReadyCount) && (iBaseLine <= iInfCount && iInfCount <= iInfReadyCount);
    }
    return (iSurvReadyCount + iInfReadyCount) >= iSurvLimit + iZombLimit;
}

void CancelFullReady(int iClient, DisruptType eType) {
    if (hReadyCountdownTimer != null) {
        delete hReadyCountdownTimer;
        InitiateReadyUp(false);
        SetTeamFrozen(L4D2Team_Survivor, g_cvReadySurvivorFreeze.BoolValue);
        if (eType == eTeamShuffle) // fix spectating
            SetClientFrozen(iClient, false);

        PrintHintTextToAll("Countdown Cancelled!");
        char szBuffer[256];
        switch (eType) {
            case eReadyStatus:      FormatEx(szBuffer, sizeof(szBuffer), "{green}[{default}ReadyUp{green}] {default}Countdown Cancelled! {olive}({teamcolor}%N {default}marked unready{olive}){default}.", iClient);
            case eTeamShuffle:      FormatEx(szBuffer, sizeof(szBuffer), "{green}[{default}ReadyUp{green}] {default}Countdown Cancelled! {olive}({teamcolor}%N {default}switched team{olive}){default}.", iClient);
            case ePlayerDisconnect: FormatEx(szBuffer, sizeof(szBuffer), "{green}[{default}ReadyUp{green}] {default}Countdown Cancelled! {olive}({teamcolor}%N {default}disconnected{olive}){default}.", iClient);
            case eAdminAbort:       FormatEx(szBuffer, sizeof(szBuffer), "{green}[{default}ReadyUp{green}] {default}Force Start Aborted! {olive}({teamcolor}%N {default}issued{olive}){default}.", iClient);
        }

        CPrintToChatAllEx(iClient, szBuffer);
        if (g_fwdCountdownCancelled.FunctionCount) {
            Call_StartForward(g_fwdCountdownCancelled);
            Call_PushCell(iClient);
            Call_PushString(szBuffer);
            Call_Finish();
        }
    }
}
