#if defined __FUNCTIONS__
    #endinput
#endif
#define __FUNCTIONS__

void ToggleBreakableForklifts(bool bPatch = false, float fTime) {
    CreateTimer(fTime, Timer_TogglePatch, bPatch, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_TogglePatch(Handle hTimer, bool bPatch) {
    int iForkLift = -1;

    while ((iForkLift = FindEntityByClassname(iForkLift, "prop_physics")) != -1) {
        char szModelName[PLATFORM_MAX_PATH];
        GetEntPropString(iForkLift, Prop_Data, "m_ModelName", szModelName, sizeof(szModelName));
        ReplaceString(szModelName, sizeof(szModelName), "\\", "/", false);

        if (StrEqual(szModelName, "models/props/cs_assault/forklift.mdl", false)) {
            SetEntProp(iForkLift, Prop_Data, "m_iMinHealthDmg", bPatch ? 0 : 400);
            SetEntProp(iForkLift, Prop_Data, "m_takedamage",    bPatch ? 1 : 3);
        }
    }

    return Plugin_Stop;
}

bool ProcessSpecialHittables(int iVictim, int &iAttacker, int &iInflictor, float &fDmg) {
    char szModelName[PLATFORM_MAX_PATH];
    GetEntityModel(iInflictor, szModelName, sizeof(szModelName));

    // Special Overkill section
    if (StrContains(szModelName, "brickpallets_break", false) != -1) { // [0]
        if (g_fSpecialOverkill[iVictim][0] - GetGameTime() > 0)
            return true;
        g_fSpecialOverkill[iVictim][0] = GetGameTime() + fOverHitInterval;
        fDmg = 13.0;
        iAttacker = FindTankClient(-1);
    } else if (StrContains(szModelName, "boat_smash_break", false) != -1) { // [1]
        if (g_fSpecialOverkill[iVictim][1] - GetGameTime() > 0)
            return true;
        g_fSpecialOverkill[iVictim][1] = GetGameTime() + fOverHitInterval;
        fDmg = 23.0;
        iAttacker = FindTankClient(-1);
    } else if (StrContains(szModelName, "concretepiller01_dm01", false) != -1) { // [2]
        if (g_fSpecialOverkill[iVictim][2] - GetGameTime() > 0)
            return true;
        g_fSpecialOverkill[iVictim][2] = GetGameTime() + fOverHitInterval;
        fDmg = 8.0;
        iAttacker = FindTankClient(-1);
    }

    return false;
}

bool GetHittableDamage(int iEnt, float &fDmg) {
    char szModelName[PLATFORM_MAX_PATH];
    GetEntityModel(iEnt, szModelName, sizeof(szModelName));

    if (StrContains(szModelName, "cara_", false) != -1  || StrContains(szModelName, "taxi_", false) != -1  || StrContains(szModelName, "police_car", false) != -1 || StrContains(szModelName, "utility_truck", false) != -1) {
        fDmg = fCarStandingDamage;
    } else if (StrContains(szModelName, "dumpster", false) != -1) {
        fDmg = fDumpsterStandingDamage;
    } else if (strcmp(szModelName, "models/props/cs_assault/forklift.mdl", false) == 0) {
        fDmg = fForkliftStandingDamage;
    } else if (StrContains(szModelName, "forklift_brokenlift", false) != -1) {
        fDmg = fBrokenForkliftStandingDamage;
    } else if (strcmp(szModelName, "models/props_vehicles/airport_baggage_cart2.mdl", false) == 0) {
        fDmg = fBaggageStandingDamage;
    } else if (strcmp(szModelName, "models/props_unique/haybails_single.mdl", false) == 0) {
        fDmg = fHaybaleStandingDamage;
    } else if (strcmp(szModelName, "models/props_foliage/swamp_fallentree01_bare.mdl", false) == 0) {
        fDmg = fLogStandingDamage;
    } else if (strcmp(szModelName, "models/props_foliage/tree_trunk_fallen.mdl", false) == 0) {
        fDmg = fBHLogStandingDamage;
    } else if (strcmp(szModelName, "models/props_fairgrounds/bumpercar.mdl", false) == 0) {
        fDmg = fBumperCarStandingDamage;
    } else if (strcmp(szModelName, "models/props/cs_assault/handtruck.mdl", false) == 0) {
        fDmg = fHandtruckStandingDamage;
    } else if (strcmp(szModelName, "models/props_vehicles/generatortrailer01.mdl", false) == 0) {
        fDmg = fGeneratorTrailerStandingDamage;
    } else if (strcmp(szModelName, "models/props/cs_militia/militiarock01.mdl", false) == 0) {
        fDmg = fMilitiaRockStandingDamage;
    } else if (strcmp(szModelName, "models/props_interiors/sofa_chair02.mdl", false) == 0) {
        char szTargetName[128];
        GetEntPropString(iEnt, Prop_Data, "m_iName", szTargetName, sizeof(szTargetName));
        if (strcmp(szTargetName, "hittable_chair_l4d1", false) == 0)
            fDmg = fSofaChairStandingDamage;
    } else if (strcmp(szModelName, "models/props_vehicles/van.mdl", false) == 0) {
        fDmg = fVanDamage;
    } else if (StrContains(szModelName, "atlas_break_ball.mdl", false) != -1) {
        fDmg = fAtlasBallDamage;
    } else if (StrContains(szModelName, "ibeam_breakable01", false) != -1) {
        fDmg = fIBeamDamage;
    } else if (strcmp(szModelName, "models/props_diescraper/statue_break_ball.mdl", false) == 0) {
        fDmg = fDiescraperBallDamage;
    } else if (strcmp(szModelName, "models/sblitz/field_equipment_cart.mdl", false) == 0) {
        fDmg = fBaggageStandingDamage;
    } else {
        return false;
    }

    return true;
}

void GetEntityModel(int iEnt, char[] szBuffer, int iLen) {
    GetEntPropString(iEnt, Prop_Data, "m_ModelName", szBuffer, iLen);
    ReplaceString(szBuffer, iLen, "\\", "/", false);
}

void InvalidatePhysOverhitTimer(int iClient) {
    static int iPhysOverhitTimerOffs = -1;
    if (iPhysOverhitTimerOffs == -1)
        iPhysOverhitTimerOffs = FindSendPropInfo("CTerrorPlayer", "m_knockdownTimer") + 32;
    SetEntDataFloat(iClient, iPhysOverhitTimerOffs + 8, -1.0);
}