#if defined _Spawn_Timers_Included
    #endinput
#endif
#define _Spawn_Timers_Included

ConVar cvSpawnTimeMin;
ConVar cvSpawnTimeMax;
ConVar cvGracePeriod;

float fCurrentTime;
float fNextTime;

void SpawnTimers_OnModuleStart() {
    // Timer
    cvSpawnTimeMin = CreateConVar(
    "ss_time_min", "15.0",
    "The minimum auto spawn time (seconds) for infected",
    FCVAR_NONE, true, 0.0, false, 0.0);

    cvSpawnTimeMax = CreateConVar(
    "ss_time_max", "20.0",
    "The maximum auto spawn time (seconds) for infected",
    FCVAR_NONE, true, 1.0, false, 0.0);

    // Grace period
    cvGracePeriod = CreateConVar(
    "ss_grace_period", "7",
    "Grace period(sec) per incapped survivor/during tank",
    FCVAR_NONE, true, 0.0, false, 0.0);

    CreateTimer(1.0, Timer_SpawnInfectedAuto, _, TIMER_REPEAT);
}

/***********************************************************************************************************************************************************************************

                                                                       SPAWN TIMER

***********************************************************************************************************************************************************************************/
Action Timer_SpawnInfectedAuto(Handle hTimer) {
    if (!g_bIsRoundLive)
        return Plugin_Continue;

    fCurrentTime = GetGameTime();

    if (fCurrentTime < fNextTime)
        return Plugin_Continue;

    static float fInterval;
    fInterval = Math_GetRandomFloat(cvSpawnTimeMin.FloatValue, cvSpawnTimeMax.FloatValue);

    static float fGracePeriod;
    fGracePeriod = GetGracePeriod();

    fNextTime = fCurrentTime + fInterval + fGracePeriod;
    GenerateSpawnQueue();
    return Plugin_Continue;
}

/***********************************************************************************************************************************************************************************

                                                                        UTILITY

***********************************************************************************************************************************************************************************/

void SetCurrentTime() {
    fCurrentTime = GetGameTime();

    static float fInterval;
    fInterval = Math_GetRandomFloat(cvSpawnTimeMin.FloatValue, cvSpawnTimeMax.FloatValue);
    fNextTime = fCurrentTime + fInterval;
}

stock float GetGracePeriod() {
    static int iIncappedSurvs;
    iIncappedSurvs = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsSurvivor(i))
            continue;

        if (!IsIncapacitated(i))
            continue;

        if (IsSurvivorAttacked(i))
            continue;

        iIncappedSurvs++;
    }

    static float fGracePeriod;
    fGracePeriod = 0.0;
    fGracePeriod = iIncappedSurvs * cvGracePeriod.FloatValue;

    if (L4D2_IsTankInPlay())
        fGracePeriod += cvGracePeriod.FloatValue;

    return fGracePeriod;
}

stock float Math_GetRandomFloat(float fMin, float fMax) {
    return (GetURandomFloat() * (fMax  - fMin)) + fMin;
}