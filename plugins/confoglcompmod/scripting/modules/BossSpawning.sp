#if defined __BOSS_SPAWNING_MODULE__
    #endinput
#endif
#define __BOSS_SPAWNING_MODULE__

#define MAX_BOSSES 5
#define NULL_VELOCITY view_as<float>({0.0, 0.0, 0.0})

char  BS_szMap[64];

int   BS_iTankCount [2];
int   BS_iWitchCount[2];

bool  BS_bEnabled;
bool  BS_bDeleteWitches;
bool  BS_bFinaleStarted;

float BS_vTankSpawn [MAX_BOSSES][2][3];
float BS_vWitchSpawn[MAX_BOSSES][2][3];

ConVar BS_cvEnabled;

void BS_OnModuleStart() {
    BS_cvEnabled = CreateConVarEx(
    "lock_boss_spawns", "1",
    "Enables forcing same coordinates for tank and witch spawns",
    FCVAR_NONE, true, 0.0, true, 1.0);
    BS_bEnabled = BS_cvEnabled.BoolValue;
    BS_cvEnabled.AddChangeHook(BS_ConVarChange);
    HookEvent("round_end",    BS_Event_RoundEnd,    EventHookMode_PostNoCopy);
    HookEvent("finale_start", BS_Event_FinaleStart, EventHookMode_PostNoCopy);
}

void BS_OnMapStart() {
    BS_bFinaleStarted = false;
    GetCurrentMap(BS_szMap, sizeof(BS_szMap));
    for (int i = 0; i <= 1; i++) {
        BS_iTankCount [i] = 0;
        BS_iWitchCount[i] = 0;
    }
}

void BS_Event_RoundEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    BS_bDeleteWitches = true;
    CreateTimer(5.0, BS_Timer_RoundEnd);
}

Action BS_Timer_RoundEnd(Handle hTimer) {
    BS_bDeleteWitches = false;
    return Plugin_Stop;
}

void BS_Event_FinaleStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    BS_bFinaleStarted = true;
}

void BS_ConVarChange(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    BS_bEnabled = BS_cvEnabled.BoolValue;
}

void BS_OnSpawnTank_Post(int iClient, const float vPos[3], const float vAng[3]) {
    if (!BS_bEnabled)
        return;

    if (!IsPluginEnabled())
        return;

    // Don't touch tanks on finale events
    if (BS_bFinaleStarted)
        return;

    // Don't track tank spawns on c5m5 or tank can spawn behind other team.
    if (strcmp(BS_szMap, "c5m5_bridge") == 0)
        return;

    // fix stuck tank spawns, ex c1m1
    if (GetMapValueInt("tank_z_fix"))
        FixZDistance(iClient);

    // If we reach MAX_BOSSES, we don't have any room to store their locations
    if (BS_iTankCount[InSecondHalfOfRound()] >= MAX_BOSSES)
        return;

    if (!InSecondHalfOfRound()) {
        BS_vTankSpawn[BS_iTankCount[0]][0] = vPos;
        BS_vTankSpawn[BS_iTankCount[0]][1] = vAng;
        BS_iTankCount[0]++;
    } else if (InSecondHalfOfRound() && BS_iTankCount[0] > BS_iTankCount[1]) {
        TeleportEntity(iClient, BS_vTankSpawn[BS_iTankCount[1]][0], BS_vTankSpawn[BS_iTankCount[1]][1], NULL_VELOCITY);
        BS_iTankCount[1]++;
    }
}

Action BS_OnSpawnWitch() {
    if (!BS_bEnabled)
        return Plugin_Continue;

    if (!IsPluginEnabled())
        return Plugin_Continue;

    if (BS_bDeleteWitches)
        return Plugin_Handled; // Used to delete round2 extra witches, which spawn on round start instead of by flow

    return Plugin_Continue;
}

void BS_OnSpawnWitch_Post(int iEntity, const float vPos[3], const float vAng[3]) {
    if (!BS_bEnabled)
        return;

    if (!IsPluginEnabled())
        return;

    // Can't track more witches if our witch array is full
    if (BS_iWitchCount[InSecondHalfOfRound()] >= MAX_BOSSES)
        return;

    if (!InSecondHalfOfRound()) {
        // If it's the first round, track our witch.
        BS_vWitchSpawn[BS_iWitchCount[0]][0] = vPos;
        BS_vWitchSpawn[BS_iWitchCount[0]][1] = vAng;
        BS_iWitchCount[0]++;
    } else if (InSecondHalfOfRound() && BS_iWitchCount[0] > BS_iWitchCount[1]) {
        // Until we have found the same number of witches as from round1, teleport them to round1 locations
        TeleportEntity(iEntity, BS_vWitchSpawn[BS_iWitchCount[1]][0], BS_vWitchSpawn[BS_iWitchCount[1]][1], NULL_VELOCITY);
        BS_iWitchCount[1]++;
    }
}

void FixZDistance(int iClient) {
    float vTankLocation[3];
    float vTempSurvivorLocation[3];
    int   iIdx;
    GetClientAbsOrigin(iClient, vTankLocation);
    for (int i = 0; i < NUM_OF_SURVIVORS; i++) {
        float fDistance = GetMapValueFloat("max_tank_z", 99999999999999.9);
        iIdx = GetSurvivorIndex(i);
        if (iIdx == 0)
            continue;

        if (!IsValidEntity(iIdx))
            continue;

        GetClientAbsOrigin(iIdx, vTempSurvivorLocation);
        if (FloatAbs(vTempSurvivorLocation[2] - vTankLocation[2]) > fDistance) {
            float vWarpToLocation[3];
            GetMapValueVector("tank_warpto", vWarpToLocation);
            if (!GetVectorLength(vWarpToLocation, true)) {
                LogMessage("[BS] tank_warpto missing from mapinfo.txt");
                return;
            }

            TeleportEntity(iClient, vWarpToLocation, NULL_VECTOR, NULL_VELOCITY);
        }
    }
}