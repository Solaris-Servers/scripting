#if defined _Spawn_Quantities_Included
    #endinput
#endif
#define _Spawn_Quantities_Included

#define UNINITIALISED -1

// Settings upon load
ConVar cvSILimitCap;
ConVar cvSILimit;
ConVar cvSpawnSize;

ConVar cvSpawnLimits[L4D2Infected_Size];
int     iSpawnLimits[L4D2Infected_Size] = {UNINITIALISED, ...};

// Customised settings; cache
int iSpecialLimit = UNINITIALISED;
int iSpawnSize    = UNINITIALISED;

void SpawnQuantities_OnModuleStart() {
    // Server SI max (marked FCVAR_CHEAT; admin only)
    cvSILimitCap = CreateConVar(
    "ss_server_si_limit", "10",
    "The max amount of special infected at once",
    FCVAR_CHEAT, true, 1.0, true, 10.0);

    // Spawn limits
    cvSILimit = CreateConVar(
    "ss_si_limit", "8",
    "The max amount of special infected at once",
    FCVAR_NONE, true, 1.0, true, 10.0);

    cvSpawnSize = CreateConVar(
    "ss_spawn_size", "3",
    "The amount of special infected spawned at each spawn interval",
    FCVAR_NONE, true, 1.0, true, 10.0);

    for (int i = L4D2Infected_Smoker; i <= L4D2Infected_Charger; i++) {
        static char szInfected[16];
        ST_StrToLower(L4D2_InfectedNames[i], szInfected, sizeof(szInfected));

        static char szConVar[32];
        FormatEx(szConVar, sizeof(szConVar), "ss_%s_limit", szInfected);

        static char szDescription[256];
        FormatEx(szDescription, sizeof(szDescription), "The max amount of %ss present at once", szInfected);

        cvSpawnLimits[i] = CreateConVar(
        szConVar, "1", szDescription,
        FCVAR_NONE, true, 0.0, true, 14.0);
    }

    LoadCacheSpawnLimits();
}


/***********************************************************************************************************************************************************************************

                                                                       LIMIT UTILITY

***********************************************************************************************************************************************************************************/
void LoadCacheSpawnLimits() {
    if (iSpecialLimit != UNINITIALISED) {
        cvSILimit.SetInt(iSpecialLimit);
        iSpecialLimit = UNINITIALISED;
    }

    if (iSpawnSize != UNINITIALISED) {
        cvSpawnSize.SetInt(iSpawnSize);
        iSpawnSize = UNINITIALISED;
    }

    for (int i = L4D2Infected_Smoker; i <= L4D2Infected_Charger; i++) {
        if (iSpawnLimits[i] == UNINITIALISED)
            continue;

        cvSpawnLimits[i].SetInt(iSpawnLimits[i]);
        iSpawnLimits[i] = UNINITIALISED;
    }
}