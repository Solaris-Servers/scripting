#if defined __L4DOWNTOWNFORWARDS_MODULE__
    #endinput
#endif
#define __L4DOWNTOWNFORWARDS_MODULE__

public Action L4D_OnSpawnTank(const float vPos[3], const float vAng[3]) {
    if (GT_OnTankSpawn_Forward() == Plugin_Handled)
        return Plugin_Handled;
    return Plugin_Continue;
}

public void L4D_OnSpawnTank_Post(int iClient, const float vPos[3], const float vAng[3]) {
    BS_OnSpawnTank_Post(iClient, vPos, vAng);
}

public Action L4D_OnSpawnWitch(const float vPos[3], const float vAng[3]) {
    if (BS_OnSpawnWitch() == Plugin_Handled)
        return Plugin_Handled;
    return Plugin_Continue;
}

public void L4D_OnSpawnWitch_Post(int iEntity, const float vPos[3], const float vAng[3]) {
    BS_OnSpawnWitch_Post(iEntity, vPos, vAng);
}

public void L4D2_OnSpawnWitchBride_Post(int iEntity, const float vPos[3], const float vAng[3]) {
    BS_OnSpawnWitch_Post(iEntity, vPos, vAng);
}

public Action L4D_OnSpawnMob(int &iAmount) {
    if (GT_OnSpawnMob_Forward(iAmount) == Plugin_Handled)
        return Plugin_Handled;
    return Plugin_Continue;
}

public Action L4D_OnTryOfferingTankBot(int iTank, bool &bEnterStasis) {
    if (GT_OnTryOfferingTankBot(bEnterStasis) == Plugin_Handled)
        return Plugin_Handled;
    return Plugin_Continue;
}

public Action L4D_OnGetMissionVSBossSpawning(float &fSpawnPosMin, float &fSpawnPosMax, float &fTankChance, float &fWitchChance) {
    if (UB_OnGetMissionVSBossSpawning() == Plugin_Handled)
        return Plugin_Handled;
    return Plugin_Continue;
}

public Action L4D_OnGetScriptValueInt(const char[] szKey, int &iRetVal) {
    if (UB_OnGetScriptValueInt(szKey, iRetVal) == Plugin_Handled)
        return Plugin_Handled;
    return Plugin_Continue;
}

public void L4D_OnFirstSurvivorLeftSafeArea_Post(int iClient) {
    if (IsPluginEnabled())
        CreateTimer(0.1, Timer_OFSLA_ForceMobSpawn, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_OFSLA_ForceMobSpawn(Handle hTimer) {
    // Workaround to make tank horde blocking always work
    // Makes the first horde always start 100s after survivors leave saferoom
    static ConVar MobSpawnTimeMin;
    if (MobSpawnTimeMin == null) MobSpawnTimeMin = FindConVar("z_mob_spawn_min_interval_normal");
    static ConVar MobSpawnTimeMax;
    if (MobSpawnTimeMax == null) MobSpawnTimeMax = FindConVar("z_mob_spawn_max_interval_normal");
    L4D2_CTimerStart(L4D2CT_MobSpawnTimer, GetRandomFloat((MobSpawnTimeMin.FloatValue, MobSpawnTimeMax.FloatValue)));
    return Plugin_Stop;
}