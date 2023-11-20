#if defined __Events__
    #endinput
#endif
#define __Events__

void InitEvents() {
    HookEvent("round_start", Event_RoundStart);
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!g_cvEnabled.BoolValue)
        return;
    GetMeleeClasses();
    CreateTimer(1.0, Timer_SpawnMelee, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_SpawnMelee(Handle hTimer) {
    int iClient = GetInGameClient();

    if (iClient == -1) {
        CreateTimer(1.0, Timer_SpawnMelee, _, TIMER_FLAG_NO_MAPCHANGE);
        return Plugin_Stop;
    }

    float vSpawnPos[3];
    float vSpawnAng[3];
    GetClientAbsOrigin(iClient, vSpawnPos);
    vSpawnPos[2] += 20;
    vSpawnAng[0]  = 90.0;

    if (!g_cvWeaponRandom.BoolValue) {
        SpawnCustomList(vSpawnPos, vSpawnAng);
        return Plugin_Stop;
    }

    int i = 0;
    while (i < g_cvWeaponRandomAmount.IntValue) {
        int iRandomMelee = GetRandomInt(0, eWeaponMeleeSize - 1);
        if (SDK_IsVersus() && InSecondHalfOfRound())
            iRandomMelee = g_iMeleeRandomSpawn[i];
        SpawnMelee(g_szMeleeClass[iRandomMelee], vSpawnPos, vSpawnAng);
        if (SDK_IsVersus() && !InSecondHalfOfRound())
            g_iMeleeRandomSpawn[i] = iRandomMelee;
        i++;
    }

    return Plugin_Stop;
}