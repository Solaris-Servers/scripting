#if defined __GHOST_TANK_MODULE__
    #endinput
#endif
#define __GHOST_TANK_MODULE__

#define ZOMBIECLASS_TANK 8

#define INCAPHEALTH            300
#define THROWRANGE             99999999.0
#define FIREIMMUNITY_TIME      5.0
#define SPECHUD_UPDATEINTERVAL 0.5

int GT_iTankClient;

bool GT_bTankIsInPlay;
bool GT_bTankHasFireImmunity;
bool GT_bFinaleVehicleIncoming;

ConVar GT_cvEnabled;
ConVar GT_cvRemoveEscapeTank;

Handle GT_hTankDeathTimer;

int GT_iPasses;

// Disable Tank Hordes items
bool   GT_bHordesDisabled;
ConVar GT_cvDisableTankHordes;

void GT_OnModuleStart() {
    GT_cvEnabled = CreateConVarEx(
    "boss_tank", "1", "Tank can't be prelight, frozen and ghost until player takes over, punch fix, and no rock throw for AI tank while waiting for player",
    FCVAR_NONE, true, 0.0, true, 1.0);

    GT_cvRemoveEscapeTank = CreateConVarEx(
    "remove_escape_tank", "1", "Remove tanks that spawn as the rescue vehicle is incoming on finales.",
    FCVAR_NONE, true, 0.0, true, 1.0);

    GT_cvDisableTankHordes = CreateConVarEx(
    "disable_tank_hordes", "0", "Disable natural hordes while tanks are in play",
    FCVAR_NONE, true, 0.0, true, 1.0);

    HookEvent("tank_spawn",              GT_Event_TankSpawn);
    HookEvent("player_death",            GT_Event_TankKilled);
    HookEvent("player_hurt",             GT_Event_TankOnFire);
    HookEvent("round_start",             GT_Event_RoundStart);
    HookEvent("item_pickup",             GT_Event_ItemPickup);
    HookEvent("player_incapacitated",    GT_Event_PlayerIncap);
    HookEvent("finale_vehicle_incoming", GT_Event_FinaleVehicleIncoming);
    HookEvent("finale_vehicle_ready",    GT_Event_FinaleVehicleIncoming);
}

Action GT_OnTankSpawn_Forward() {
    if (IsPluginEnabled() && GT_cvRemoveEscapeTank.BoolValue && GT_bFinaleVehicleIncoming)
        return Plugin_Handled;

    return Plugin_Continue;
}

Action GT_OnSpawnMob_Forward(int &iAmount) {
    // quick fix. needs normalize_hordes 1
    if (IsPluginEnabled()) {
        if (IsDebugEnabled())
            LogMessage("[GT] SpawnMob(%d), HordesDisabled: %d TimerDuration: %f Minimum: %f Remaining: %f", iAmount,
                                                                                                            GT_bHordesDisabled,
                                                                                                            L4D2_CTimerGetCountdownDuration(L4D2CT_MobSpawnTimer),
                                                                                                            FindConVar("z_mob_spawn_min_interval_normal").FloatValue,
                                                                                                            L4D2_CTimerGetRemainingTime(L4D2CT_MobSpawnTimer));
        if (GT_bHordesDisabled) {
            static ConVar cvMobSpawnIntervalMin;
            static ConVar cvMobSpawnIntervalMax;
            static ConVar cvMobSpawnSizeMin;
            static ConVar cvMobSpawnSizeMax;
            if (cvMobSpawnIntervalMin == null) cvMobSpawnIntervalMin = FindConVar("z_mob_spawn_min_interval_normal");
            if (cvMobSpawnIntervalMax == null) cvMobSpawnIntervalMax = FindConVar("z_mob_spawn_max_interval_normal");
            if (cvMobSpawnSizeMin == null)     cvMobSpawnSizeMin     = FindConVar("z_mob_spawn_min_size");
            if (cvMobSpawnSizeMax == null)     cvMobSpawnSizeMax     = FindConVar("z_mob_spawn_max_size");

            int iMinSize = cvMobSpawnSizeMin.IntValue;
            int iMaxSize = cvMobSpawnSizeMax.IntValue;
            if (iAmount < iMinSize || iAmount > iMaxSize)
                return Plugin_Continue;

            if (!L4D2_CTimerIsElapsed(L4D2CT_MobSpawnTimer))
                return Plugin_Continue;

            float fDuration = L4D2_CTimerGetCountdownDuration(L4D2CT_MobSpawnTimer);
            if (fDuration < cvMobSpawnIntervalMin.FloatValue || fDuration > cvMobSpawnIntervalMax.FloatValue)
                return Plugin_Continue;

            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}

// Disable stasis when we're using GhostTank
Action GT_OnTryOfferingTankBot(bool &bEnterStasis) {
    GT_iPasses++;
    if (IsPluginEnabled()) {
        if (GT_cvEnabled.BoolValue)
            bEnterStasis = false;
        if (GT_cvRemoveEscapeTank.BoolValue && GT_bFinaleVehicleIncoming)
            return Plugin_Handled;
    }

    return Plugin_Continue;
}

void GT_Event_FinaleVehicleIncoming(Event eEvent, const char[] szName, bool bDontBroadcast) {
    GT_bFinaleVehicleIncoming = true;
    if (GT_bTankIsInPlay && IsClientInGame(GT_iTankClient) && IsFakeClient(GT_iTankClient)) {
        KickClient(GT_iTankClient);
        GT_Reset();
    }
}

void GT_Event_ItemPickup(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!GT_bTankIsInPlay)
        return;

    char szItem[64];
    eEvent.GetString("item", szItem, sizeof(szItem));
    if (strcmp(szItem, "tank_claw") == 0) {
        GT_iTankClient = GetClientOfUserId(eEvent.GetInt("userid"));
        if (GT_hTankDeathTimer != null) {
            KillTimer(GT_hTankDeathTimer);
            GT_hTankDeathTimer = null;
        }
    }
}

void DisableNaturalHordes() {
    // 0x7fff = 16 bit signed max value. Over 9 hours.
    GT_bHordesDisabled = true;
}

void EnableNaturalHordes() {
    GT_bHordesDisabled = false;
}

void GT_Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    GT_bFinaleVehicleIncoming = false;
    GT_Reset();
}

void GT_Event_TankKilled(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!GT_bTankIsInPlay)
        return;

    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient != GT_iTankClient)
        return;

    GT_hTankDeathTimer = CreateTimer(1.0, GT_Timer_TankKilled, _, TIMER_FLAG_NO_MAPCHANGE);
}

void GT_Event_TankSpawn(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    GT_iTankClient = iClient;
    if (GT_bTankIsInPlay)
        return;

    GT_bTankIsInPlay = true;
    if (GT_cvDisableTankHordes.BoolValue)
        DisableNaturalHordes();

    if (!IsPluginEnabled() || !GT_cvEnabled.BoolValue)
        return;

    float fFireImmunityTime = FIREIMMUNITY_TIME;
    float fSelectionTime    = FindConVar("director_tank_lottery_selection_time").FloatValue;
    if (IsFakeClient(iClient)) {
        GT_PauseTank();
        CreateTimer(fSelectionTime, GT_Timer_ResumeTank, _, TIMER_FLAG_NO_MAPCHANGE);
        fFireImmunityTime += fSelectionTime;
    }

    CreateTimer(fFireImmunityTime, GT_Timer_FireImmunity, _, TIMER_FLAG_NO_MAPCHANGE);
}

void GT_Event_TankOnFire(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!GT_bTankIsInPlay || !GT_bTankHasFireImmunity || !IsPluginEnabled() || !GT_cvEnabled.BoolValue)
        return;

    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (GT_iTankClient != iClient || !IsValidClient(iClient))
        return;

    int iDmgType = eEvent.GetInt("type");
    if (iDmgType != 8)
        return;

    ExtinguishEntity(iClient);
    int iCurHealth = GetClientHealth(iClient);
    int iDmgDone   = eEvent.GetInt("dmg_health");
    SetEntityHealth(iClient, (iCurHealth + iDmgDone));
}

void GT_Event_PlayerIncap(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!GT_bTankIsInPlay || !IsPluginEnabled() || !GT_cvEnabled.BoolValue)
        return;

    char szWeapon[16];
    eEvent.GetString("weapon", szWeapon, sizeof(szWeapon));
    if (strcmp(szWeapon, "tank_claw") != 0)
        return;

    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (!IsValidClient(iClient))
        return;

    SetEntProp(iClient, Prop_Send, "m_isIncapacitated", 0);
    SetEntityHealth(iClient, 1);
    CreateTimer(0.4, GT_Timer_PlayerIncap, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
}

Action GT_Timer_PlayerIncap(Handle hTimer, any iUserId) {
    int iClient = GetClientOfUserId(iUserId);
    if (!IsValidEntity(iClient) || !IsValidClient(iClient))
        return Plugin_Stop;

    SetEntProp(iClient, Prop_Send, "m_isIncapacitated", 1);
    SetEntityHealth(iClient, INCAPHEALTH);
    return Plugin_Stop;
}

Action GT_Timer_ResumeTank(Handle hTimer) {
    GT_ResumeTank();
    return Plugin_Stop;
}

Action GT_Timer_FireImmunity(Handle hTimer) {
    GT_bTankHasFireImmunity = false;
    return Plugin_Stop;
}

void GT_PauseTank() {
    FindConVar("tank_throw_allow_range").SetFloat(THROWRANGE);
    if (!IsValidEntity(GT_iTankClient))
        return;

    SetEntityMoveType(GT_iTankClient, MOVETYPE_NONE);
    SetEntProp(GT_iTankClient, Prop_Send, "m_isGhost", 1, 1);
}

void GT_ResumeTank() {
    FindConVar("tank_throw_allow_range").RestoreDefault();
    if (!IsValidEntity(GT_iTankClient))
        return;

    SetEntityMoveType(GT_iTankClient, MOVETYPE_CUSTOM);
    SetEntProp(GT_iTankClient, Prop_Send, "m_isGhost", 0, 1);
}

void GT_Reset() {
    GT_iPasses = 0;
    GT_hTankDeathTimer = null;

    if (GT_bHordesDisabled)
        EnableNaturalHordes();

    GT_bTankIsInPlay        = false;
    GT_bTankHasFireImmunity = true;
}

Action GT_Timer_TankKilled(Handle hTimer) {
    GT_Reset();
    return Plugin_Stop;
}

bool IsValidClient(int iClient) {
    if (iClient <= 0 || iClient > MaxClients)
        return false;

    if (!IsClientInGame(iClient))
        return false;

    return true;
}