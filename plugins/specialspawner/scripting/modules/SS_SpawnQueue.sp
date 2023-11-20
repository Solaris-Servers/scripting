#if defined _Spawn_Queue_Included
    #endinput
#endif
#define _Spawn_Queue_Included

int iSpawnCounts[L4D2Infected_Size];

void GenerateSpawnQueue() {
    if (CountSpecialInfectedBots() >= cvSILimit.IntValue)
        return;

    static int iNumAllowedSI;
    iNumAllowedSI = cvSILimit.IntValue - CountSpecialInfectedBots();

    static int iSize;
    iSize = cvSpawnSize.IntValue;

    if (cvSpawnSize.IntValue > iNumAllowedSI)
        iSize = iNumAllowedSI;

    // refresh current SI counts
    SpecialInfectedCount();

    // Initialise spawn queue
    static int iIdx;
    // Generate and execute the spawn queue
    for (int i = 1; i <= iSize; i++) {
        iIdx = GenerateIndex(false);

        if (iIdx == -1)
            break;

        CreateTimer((0.1 * i), Timer_ExecuteSpawnQueue, iIdx, TIMER_FLAG_NO_MAPCHANGE);
    }
}

Action Timer_ExecuteSpawnQueue(Handle hTimer, int iIdx) {
    static float vPos[3];
    if (L4D_GetRandomPZSpawnPosition(GetRandomSurvivor(), iIdx, 5, vPos))
        L4D2_SpawnSpecial(iIdx, vPos, NULL_VECTOR);
    return Plugin_Stop;
}

int GenerateIndex(bool bReset = false) {
    static int i = L4D2Infected_Smoker;

    if (bReset) {
        i = L4D2Infected_Smoker;
        return -1;
    }

    static int iIdx = -1;
    iIdx = -1;

    for (; i <= L4D2Infected_Charger; i++) {
        if (iSpawnCounts[i] >= cvSpawnLimits[i].IntValue)
            continue;

        iSpawnCounts[i]++;
        iIdx = i;
        break;
    }

    if (i >= L4D2Infected_Charger)
        i = L4D2Infected_Smoker;

    return iIdx;
}

void SpecialInfectedCount() {
    static int iCls;
    for (int i = L4D2Infected_Smoker; i <= L4D2Infected_Charger; i++) {
        iSpawnCounts[i] = 0;
    }

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (!IsFakeClient(i))
            continue;

        if (GetClientTeam(i) != 3)
            continue;

        if (!IsPlayerAlive(i))
            continue;

        iCls = GetInfectedClass(i);
        switch (iCls) {
            case 1, 2, 3, 4, 5, 6: {
                iSpawnCounts[iCls]++;
            }
        }
    }
}

int CountSpecialInfectedBots() {
    int iCount = 0;
    for (int i = 1; i < MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (!IsFakeClient(i))
            continue;

        if (GetClientTeam(i) != 3)
            continue;

        if (!IsPlayerAlive(i))
            continue;

        iCount++;
    }

    return iCount;
}