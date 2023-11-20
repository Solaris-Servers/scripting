#if defined __FINALESPAWN_MODULE__
    #endinput
#endif
#define __FINALESPAWN_MODULE__

#define STATE_SPAWNREADY 0
#define STATE_TOOCLOSE   256
#define SPAWN_RANGE      150

bool   FS_bIsFinale;
bool   FS_bEnabled;
ConVar FS_cvEnabled;

void FS_OnModuleStart() {
    FS_cvEnabled = CreateConVarEx(
    "reduce_finalespawnrange", "1",
    "Adjust the spawn range on finales for infected, to normal spawning range",
    FCVAR_NONE, true, 0.0, true, 1.0);
    FS_bEnabled = FS_cvEnabled.BoolValue;
    FS_cvEnabled.AddChangeHook(FS_ConVarChange);
    HookEvent("round_end",    FS_Event_Round,       EventHookMode_PostNoCopy);
    HookEvent("round_start",  FS_Event_Round,       EventHookMode_PostNoCopy);
    HookEvent("finale_start", FS_Event_FinaleStart, EventHookMode_PostNoCopy);
}

void FS_Event_Round(Event eEvent, const char[] szName, bool bDontBroadcast) {
    FS_bIsFinale = false;
}

void FS_Event_FinaleStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    FS_bIsFinale = true;
}

void FS_ConVarChange(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    FS_bEnabled = FS_cvEnabled.BoolValue;
}

public void OnClientPostAdminCheck(int iClient) {
    SDKHook(iClient, SDKHook_PreThinkPost, HookCallback);
}

void HookCallback(int iClient) {
    if (!FS_bEnabled || !IsPluginEnabled)
        return;

    if (!FS_bIsFinale)
        return;

    if (GetClientTeam(iClient) != TEAM_INFECTED)
        return;

    if (GetEntProp(iClient, Prop_Send, "m_isGhost", 1) != 1)
        return;

    if (GetEntProp(iClient, Prop_Send, "m_ghostSpawnState") == STATE_TOOCLOSE) {
        if (!TooClose(iClient))
            SetEntProp(iClient, Prop_Send, "m_ghostSpawnState", STATE_SPAWNREADY);
    }
}

bool TooClose(int iClient) {
    float vInfLocation[3];
    GetClientAbsOrigin(iClient, vInfLocation);

    float vSurvLocation[3];
    float vVec[3];
    for (int i = 0; i < 4; i++) {
        int iIdx = GetSurvivorIndex(i);
        if (iIdx == 0)
            continue;

        if (!IsClientInGame(iIdx))
            continue;

        if (!IsPlayerAlive(iIdx))
            continue;

        GetClientAbsOrigin(iIdx, vSurvLocation);
        MakeVectorFromPoints(vInfLocation, vSurvLocation, vVec);
        if (GetVectorLength(vVec) <= SPAWN_RANGE)
            return true;
    }

    return false;
}