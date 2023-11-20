#if defined _skill_detect_tracking_included
    #endinput
#endif
#define _skill_detect_tracking_included

public void OnMapEnd() {
    for (int i = 1; i <= MaxClients; i++) {
        g_hBoomerShoveTimer[i] = null;
    }
}

public void OnClientPutInServer(int iClient) {
    ResetHunter(iClient);
}

public void OnClientDisconnect(int iClient) {
    ResetHunter(iClient);
}

public void L4D_OnEnterGhostState(int iClient) {
    ResetHunter(iClient);
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_smRocks.Clear();
    g_iRocksBeingThrownCount = 0;

    for (int i = 1; i <= MaxClients; i++) {
        ResetHunter(i);
        g_bIsHopping[i] = false;

        for (int j = 1; j <= MaxClients; j++) {
            g_fVictimLastShove[i][j] = 0.0;
        }
    }
}

void Event_PlayerHurt(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iVictim   = GetClientOfUserId(eEvent.GetInt("userid"));
    int iAttacker = GetClientOfUserId(eEvent.GetInt("attacker"));
    int zClass;

    int iDmg     = eEvent.GetInt("dmg_health");
    int iDmgType = eEvent.GetInt("type");

    if (IsValidInfected(iVictim)) {
        zClass        = GetEntProp(iVictim, Prop_Send, "m_zombieClass");
        int iHealth   = eEvent.GetInt("health");
        int iHitGroup = eEvent.GetInt("hitgroup");

        if (iDmg == 0)
            return;

        switch (zClass) {
            case L4D2Infected_Hunter: {
                if (IsValidSurvivor(iAttacker)) {
                    static bool bIsPouncing;
                    bIsPouncing = view_as<bool>(GetEntProp(iVictim, Prop_Send, "m_isAttemptingToPounce") || g_fHunterTracePouncing[iVictim] != 0.0 && (GetGameTime() - g_fHunterTracePouncing[iVictim]) < 0.001);

                    if (iDmgType & DMG_BULLET || iDmgType & DMG_BUCKSHOT) {
                        if (iDmg > g_iHunterHealth[iVictim])
                            iDmg = g_iHunterHealth[iVictim]; // fix fake damage

                        g_iDmgDealt[iVictim][iAttacker] += iDmg;

                        if (!g_bShotCounted[iVictim][iAttacker]) {
                            g_iShotsDealt [iVictim][iAttacker]++;
                            g_bShotCounted[iVictim][iAttacker] = true;
                        }

                        if (iHealth == 0 && bIsPouncing) {
                            char szWeapon[32];
                            eEvent.GetString("weapon", szWeapon, sizeof(szWeapon));

                            WeaponType eWeaponType;
                            g_smWeapons.GetValue(szWeapon, eWeaponType);

                            // headshot with bullet based weapon (only single shots) -- only snipers
                            if (eWeaponType == WPTYPE_SNIPER && iHitGroup == HITGROUP_HEAD) {
                                HandleSkeet(iAttacker, iVictim, g_iDmgDealt[iVictim][iAttacker], g_iShotsDealt[iVictim][iAttacker], false, false, true);
                            } else {
                                int iAssisters[4][4];
                                int iAssisterCount;

                                for (int i = 1; i <= MaxClients; i++) {
                                    if (i == iAttacker)
                                        continue;

                                    if (g_iDmgDealt[iVictim][i] > 0 && IsClientInGame(i)) {
                                        iAssisters[iAssisterCount][0] = i;
                                        iAssisters[iAssisterCount][1] = g_iDmgDealt[iVictim][i];
                                        iAssisterCount++;
                                    }
                                }

                                HandleSkeet(iAttacker, iVictim, g_iDmgDealt[iVictim][iAttacker], g_iShotsDealt[iVictim][iAttacker], iAssisterCount ? true : false);
                            }
                        }
                    } else if (iDmgType & DMG_SLASH || iDmgType & DMG_CLUB) {
                        if (iHealth == 0 && bIsPouncing) {
                            HandleSkeet(iAttacker, iVictim, g_iDmgDealt[iVictim][iAttacker], g_iShotsDealt[iVictim][iAttacker], false, true);
                        }
                    }
                }

                // store health for next damage it takes
                if (iHealth > 0)
                    g_iHunterHealth[iVictim] = iHealth;
                else
                    ResetHunter(iVictim);
            }
            case L4D2Infected_Charger: {
                if (IsValidSurvivor(iAttacker)) {
                    // check for levels
                    if (iHealth == 0 && (iDmgType & DMG_CLUB || iDmgType & DMG_SLASH)) {
                        int iAbilityEnt = GetEntPropEnt(iVictim, Prop_Send, "m_customAbility");
                        if (IsValidEntity(iAbilityEnt) && GetEntProp(iAbilityEnt, Prop_Send, "m_isCharging")) {
                            if (iDmg > g_iChargerHealth[iVictim])
                                iDmg = g_iChargerHealth[iVictim]; // fix fake damage

                            // charger was killed, was it a full level?
                            if (iHitGroup == HITGROUP_HEAD) {
                                HandleLevel(iAttacker, iVictim);
                            } else {
                                HandleLevelHurt(iAttacker, iVictim, iDmg);
                            }
                        }
                    }
                }

                // store health for next damage it takes
                if (iHealth > 0)
                    g_iChargerHealth[iVictim] = iHealth;
            }
            case L4D2Infected_Smoker: {
                if (!IsValidSurvivor(iAttacker))
                    return;

                g_iSmokerVictimDamage[iVictim] += iDmg;
            }
        }
    } else if (IsValidInfected(iAttacker)) {
        zClass = GetEntProp(iAttacker, Prop_Send, "m_zombieClass");

        switch (zClass) {
            case L4D2Infected_Hunter: {
                // a hunter pounce landing is DMG_CRUSH
                if (iDmgType & DMG_CRUSH)
                    g_iPounceDamage[iAttacker] = iDmg;
            }
        }
    }

    // check for deathcharge flags
    if (IsValidSurvivor(iVictim)) {
        // debug
        if (iDmgType & DMG_DROWN || iDmgType & DMG_FALL)
            g_iVictimMapDmg[iVictim] += iDmg;

        if (iDmgType & DMG_DROWN && iDmg >= MIN_DC_TRIGGER_DMG) {
            g_iVictimFlags[iVictim] = g_iVictimFlags[iVictim] | VICFLG_HURTLOTS;
        } else if (iDmgType & DMG_FALL && iDmg >= MIN_DC_FALL_DMG) {
            g_iVictimFlags[iVictim] = g_iVictimFlags[iVictim] | VICFLG_HURTLOTS;
        }
    }
}

void Event_PlayerSpawn(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (!IsValidInfected(iClient))
        return;

    int zClass = GetEntProp(iClient, Prop_Send, "m_zombieClass");

    g_fSpawnTime[iClient]    = GetGameTime();
    g_fPinTime  [iClient][0] = 0.0;
    g_fPinTime  [iClient][1] = 0.0;

    switch (zClass) {
        case L4D2Infected_Boomer: {
            g_bBoomerHitSomebody[iClient] = false;
            g_iBoomerGotShoved  [iClient] = 0;
            g_iBoomerKiller     [iClient] = 0;
            g_iBoomerShover     [iClient] = 0;

            if (g_hBoomerShoveTimer[iClient] != null) {
                KillTimer(g_hBoomerShoveTimer[iClient]);
                g_hBoomerShoveTimer[iClient] = null;
            }
        }
        case L4D2Infected_Smoker: {
            g_bSmokerClearCheck  [iClient] = false;
            g_iSmokerVictim      [iClient] = 0;
            g_iSmokerVictimDamage[iClient] = 0;
        }
        case L4D2Infected_Hunter: {
            SDKHook(iClient, SDKHook_TraceAttack, TraceAttack_Hunter);

            g_vPouncePosition[iClient][0] = 0.0;
            g_vPouncePosition[iClient][1] = 0.0;
            g_vPouncePosition[iClient][2] = 0.0;

            g_iHunterHealth[iClient] = GetClientHealth(iClient);
        }
        case L4D2Infected_Charger: {
            SDKHook(iClient, SDKHook_TraceAttack, TraceAttack_Charger);
            g_iChargerHealth[iClient] = GetClientHealth(iClient);
        }
    }
}

// player about to get incapped
void Event_IncapStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient    = GetClientOfUserId(eEvent.GetInt("userid"));
    int iAttackEnt = eEvent.GetInt("attackerentid");
    int iDmgType   = eEvent.GetInt("type");

    char szClsName[24];
    OEC  eClasNameOEC;

    if (IsValidEntity(iAttackEnt)) {
        GetEdictClassname(iAttackEnt, szClsName, sizeof(szClsName));
        if (g_smEntityCreated.GetValue(szClsName, eClasNameOEC))
            g_iVictimFlags[iClient] = g_iVictimFlags[iClient] | VICFLG_TRIGGER;
    }

    float fFlow = L4D2Direct_GetFlowDistance(iClient);

    // drown is damage type
    if (iDmgType & DMG_DROWN)
        g_iVictimFlags[iClient] = g_iVictimFlags[iClient] | VICFLG_DROWN;

    if (fFlow < WEIRD_FLOW_THRESH)
        g_iVictimFlags[iClient] = g_iVictimFlags[iClient] | VICFLG_WEIRDFLOW;
}

// trace attacks on hunters
Action TraceAttack_Hunter(int iVictim, int &iAttacker, int &iInflictor, float &fDmg, int &iDmgType, int &iAmmoType, int iHitBox, int iHitGroup) {
    // track pinning
    g_iSpecialVictim[iVictim] = GetEntPropEnt(iVictim, Prop_Send, "m_pounceVictim");

    if (!IsValidSurvivor(iAttacker) || !IsValidEdict(iInflictor))
        return Plugin_Continue;

    // track flight
    if (GetEntProp(iVictim, Prop_Send, "m_isAttemptingToPounce")) {
        g_fHunterTracePouncing[iVictim] = GetGameTime();
    } else {
        g_fHunterTracePouncing[iVictim] = 0.0;
    }

    return Plugin_Continue;
}

Action TraceAttack_Charger(int iVictim, int &iAttacker, int &iInflictor, float &fDmg, int &iDmgType, int &iAmmoType, int iHitBox, int iHitGroup) {
    // track pinning
    int iVictimA = GetEntPropEnt(iVictim, Prop_Send, "m_carryVictim");

    if (iVictimA != -1) {
        g_iSpecialVictim[iVictim] = iVictimA;
    } else {
        g_iSpecialVictim[iVictim] = GetEntPropEnt(iVictim, Prop_Send, "m_pummelVictim");
    }

    return Plugin_Continue;
}

void Event_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iVictim   = GetClientOfUserId(eEvent.GetInt("userid"));
    int iAttacker = GetClientOfUserId(eEvent.GetInt("attacker"));

    if (eEvent.GetBool("headshot"))
        HandleHeadShot(iAttacker, iVictim);

    if (IsValidInfected(iVictim)) {
        int zClass = GetEntProp(iVictim, Prop_Send, "m_zombieClass");

        switch (zClass) {
            case L4D2Infected_Smoker: {
                if (!IsValidSurvivor(iAttacker))
                    return;

                if (g_bSmokerClearCheck[iVictim] && g_iSmokerVictim[iVictim] == iAttacker && g_iSmokerVictimDamage[iVictim] >= g_cvSelfClearThresh.IntValue) {
                    HandleSmokerSelfClear(iAttacker, iVictim);
                } else {
                    g_bSmokerClearCheck[iVictim] = false;
                    g_iSmokerVictim    [iVictim] = 0;
                }
            }
            case L4D2Infected_Boomer: {
                if (!IsValidSurvivor(iAttacker))
                    return;

                g_iBoomerKiller[iVictim] = iAttacker;
                DataPack dp;
                CreateDataTimer(0.2, Timer_BoomerKilledCheck, dp, TIMER_FLAG_NO_MAPCHANGE);
                dp.WriteCell(GetClientUserId(iVictim));
                dp.WriteCell(iVictim);
            }
            case L4D2Infected_Hunter: {
                ResetHunter(iVictim);
                if (g_iSpecialVictim[iVictim] > 0)
                    HandleClear(iAttacker, iVictim, g_iSpecialVictim[iVictim], L4D2Infected_Hunter, (GetGameTime() - g_fPinTime[iVictim][0]), -1.0);
            }
            case L4D2Infected_Jockey: {
                // check whether it was a clear
                if (g_iSpecialVictim[iVictim] > 0)
                    HandleClear(iAttacker, iVictim, g_iSpecialVictim[iVictim], L4D2Infected_Jockey, (GetGameTime() - g_fPinTime[iVictim][0]), -1.0);
            }
            case L4D2Infected_Charger: {
                // is it someone carrying a survivor (that might be DC'd)?
                // switch charge victim to 'impact' check (reset checktime)
                if (IsValidClientInGame(g_iChargeVictim[iVictim]))
                    g_fChargeTime[g_iChargeVictim[iVictim]] = GetGameTime();

                // check whether it was a clear
                if (g_iSpecialVictim[iVictim] > 0)
                    HandleClear(iAttacker, iVictim, g_iSpecialVictim[iVictim], L4D2Infected_Charger, (g_fPinTime[iVictim][1] > 0.0) ? (GetGameTime() - g_fPinTime[iVictim][1]) : -1.0, (GetGameTime() - g_fPinTime[iVictim][0]));
            }
        }
    } else if (IsValidSurvivor(iVictim)) {
        int iDmgType = eEvent.GetInt("type");
        if (iDmgType & DMG_FALL) {
            g_iVictimFlags[iVictim] = g_iVictimFlags[iVictim] | VICFLG_FALL;
        } else if (IsValidInfected(iAttacker) && iAttacker != g_iVictimCharger[iVictim]) {
            // if something other than the charger killed them, remember (not a DC)
            g_iVictimFlags[iVictim] = g_iVictimFlags[iVictim] | VICFLG_KILLEDBYOTHER;
        }
    }
}

Action Timer_BoomerKilledCheck(Handle hTimer, DataPack dp) {
    dp.Reset();
    int iUserId = dp.ReadCell();
    int iVictim = dp.ReadCell();

    float[] fBoomerKillTime = new float[MaxClients + 1];
    fBoomerKillTime[iVictim] = GetGameTime() - g_fSpawnTime[iVictim];

    if (GetClientOfUserId(iUserId) != iVictim || g_bBoomerHitSomebody[iVictim]) {
        g_iBoomerKiller[iVictim] = 0;
        fBoomerKillTime[iVictim] = 0.0;
        return Plugin_Stop;
    }

    if (iVictim <= 0 || !IsClientInGame(iVictim)) {
        g_iBoomerKiller[iVictim] = 0;
        fBoomerKillTime[iVictim] = 0.0;
        return Plugin_Stop;
    }

    int iAttacker = g_iBoomerKiller[iVictim];
    if (iAttacker <= 0 || !IsClientInGame(iAttacker)) {
        g_iBoomerKiller[iVictim] = 0;
        fBoomerKillTime[iVictim] = 0.0;
        return Plugin_Stop;
    }

    int   iShover     = g_iBoomerShover[iVictim];
    float fTimeAlive  = fBoomerKillTime[iVictim];
    int   iShoveCount = g_iBoomerGotShoved[iVictim];

    if (IsValidSurvivor(iShover)) {
        HandlePop(iAttacker, iVictim, iShover, iShoveCount, fTimeAlive);
    } else {
        HandlePop(iAttacker, iVictim, -1, iShoveCount, fTimeAlive);
    }

    g_iBoomerKiller[iVictim] = 0;
    fBoomerKillTime[iVictim] = 0.0;
    return Plugin_Stop;
}

void Event_PlayerShoved(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iVictim   = GetClientOfUserId(eEvent.GetInt("userid"));
    int iAttacker = GetClientOfUserId(eEvent.GetInt("attacker"));

    if (!IsValidSurvivor(iAttacker) || !IsValidInfected(iVictim))
        return;

    // check for boomers and clears
    int zClass = GetEntProp(iVictim, Prop_Send, "m_zombieClass");
    switch (zClass) {
        case L4D2Infected_Boomer: {
            if (g_hBoomerShoveTimer[iVictim] != null) {
                KillTimer(g_hBoomerShoveTimer[iVictim]);
                if (!g_iBoomerShover[iVictim] || !IsClientInGame(g_iBoomerShover[iVictim]))
                    g_iBoomerShover[iVictim] = iAttacker;
            } else {
                g_iBoomerShover[iVictim] = iAttacker;
            }
            g_hBoomerShoveTimer[iVictim] = CreateTimer(4.0, Timer_BoomerShoved, iVictim, TIMER_FLAG_NO_MAPCHANGE);
            g_iBoomerGotShoved[iVictim]++;
        }
        case L4D2Infected_Hunter: {
            if (GetEntPropEnt(iVictim, Prop_Send, "m_pounceVictim") > 0)
                HandleClear(iAttacker, iVictim, GetEntPropEnt(iVictim, Prop_Send, "m_pounceVictim"), L4D2Infected_Hunter, (GetGameTime() - g_fPinTime[iVictim][0]), -1.0, true);
        }
        case L4D2Infected_Jockey: {
            if (GetEntPropEnt(iVictim, Prop_Send, "m_jockeyVictim") > 0)
                HandleClear(iAttacker, iVictim, GetEntPropEnt(iVictim, Prop_Send, "m_jockeyVictim"), L4D2Infected_Jockey, (GetGameTime() - g_fPinTime[iVictim][0]), -1.0, true);
        }
    }

    if (g_fVictimLastShove[iVictim][iAttacker] == 0.0 || (GetGameTime() - g_fVictimLastShove[iVictim][iAttacker]) >= SHOVE_TIME) {
        if (GetEntProp(iVictim, Prop_Send, "m_isAttemptingToPounce"))
            HandleDeadstop(iAttacker, iVictim);
        g_fVictimLastShove[iVictim][iAttacker] = GetGameTime();
    }

    // check for shove on smoker by pull victim
    if (g_iSmokerVictim[iVictim] == iAttacker)
        g_bSmokerShoved[iVictim] = true;
}

Action Timer_BoomerShoved(Handle hTimer, int iVictim) {
    g_hBoomerShoveTimer[iVictim] = null;
    g_iBoomerShover    [iVictim] = 0;
    return Plugin_Stop;
}

void Event_LungePounce(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    int iVictim = GetClientOfUserId(eEvent.GetInt("victim"));

    g_fPinTime[iClient][0] = GetGameTime();

    // check if it was a DP
    // ignore if no real pounce start pos
    if (g_vPouncePosition[iClient][0] == 0.0 && g_vPouncePosition[iClient][1] == 0.0 && g_vPouncePosition[iClient][2] == 0.0)
        return;

    float vEndPos[3];
    GetClientAbsOrigin(iClient, vEndPos);

    float fHeight = g_vPouncePosition[iClient][2] - vEndPos[2];

    // from pounceannounce:
    // distance supplied isn't the actual 2d vector distance needed for damage calculation. See more about it at
    // http://forums.alliedmods.net/showthread.php?t=93207

    float fMin    = g_cvMinPounceDistance.FloatValue;
    float fMax    = g_cvMaxPounceDistance.FloatValue;
    float fMaxDmg = g_cvMaxPounceDamage.FloatValue;

    // calculate 2d distance between previous position and pounce position
    int iDistance = RoundToNearest(GetVectorDistance(g_vPouncePosition[iClient], vEndPos));

    // get damage using hunter damage formula
    // check if this is accurate, seems to differ from actual damage done!
    float fDamage = (((float(iDistance) - fMin) / (fMax - fMin)) * fMaxDmg) + 1.0;

    // apply bounds
    if (fDamage < 0.0) {
        fDamage = 0.0;
    } else if (fDamage > fMaxDmg + 1.0) {
        fDamage = fMaxDmg + 1.0;
    }

    DataPack dp;
    CreateDataTimer(0.05, Timer_HunterDP, dp, TIMER_FLAG_NO_MAPCHANGE);
    dp.WriteCell(iClient);
    dp.WriteCell(iVictim);
    dp.WriteFloat(fDamage);
    dp.WriteFloat(fHeight);
}

Action Timer_HunterDP(Handle hTimer, DataPack dp) {
    ResetPack(dp);
    int   iClient = dp.ReadCell();
    int   iVictim = dp.ReadCell();
    float fDamage = dp.ReadFloat();
    float fHeight = dp.ReadFloat();

    HandleHunterDP(iClient, iVictim, g_iPounceDamage[iClient], fDamage, fHeight);
    return Plugin_Continue;
}

void Event_PlayerJumped(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));

    if (IsValidInfected(iClient)) {
        int zClass = GetEntProp(iClient, Prop_Send, "m_zombieClass");
        if (zClass != L4D2Infected_Jockey)
            return;

        // where did jockey jump from?
        GetClientAbsOrigin(iClient, g_vPouncePosition[iClient]);
    } else if (IsValidSurvivor(iClient)) {
        // could be the start or part of a hopping streak
        float vVel[3];
        GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", vVel);
        vVel[2] = 0.0; // safeguard

        float fLengthNew;
        float fLengthOld;
        fLengthNew = GetVectorLength(vVel);

        g_bHopCheck[iClient] = false;

        if (!g_bIsHopping[iClient]) {
            if (fLengthNew >= g_cvBHopMinInitSpeed.FloatValue) {
                // starting potential hop streak
                g_fHopTopVelocity[iClient] = fLengthNew;
                g_bIsHopping[iClient]      = true;
                g_iHops[iClient]           = 0;
            }
        } else {
            // check for hopping streak
            fLengthOld = GetVectorLength(g_fLastHop[iClient]);

            // if they picked up speed, count it as a hop, otherwise, we're done hopping
            if (fLengthNew - fLengthOld > HOP_ACCEL_THRESH || fLengthNew >= g_cvBHopContSpeed.FloatValue) {
                g_iHops[iClient]++;

                // this should always be the case...
                if (fLengthNew > g_fHopTopVelocity[iClient])
                    g_fHopTopVelocity[iClient] = fLengthNew;
            } else {
                g_bIsHopping[iClient] = false;

                if (g_iHops[iClient]) {
                    HandleBHopStreak(iClient, g_iHops[iClient], g_fHopTopVelocity[iClient]);
                    g_iHops[iClient] = 0;
                }
            }
        }

        g_fLastHop[iClient][0] = vVel[0];
        g_fLastHop[iClient][1] = vVel[1];
        g_fLastHop[iClient][2] = vVel[2];

        if (g_iHops[iClient] != 0)
            CreateTimer(HOP_CHECK_TIME, Timer_CheckHop, iClient, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE); // check when the player returns to the ground
    }
}

Action Timer_CheckHop(Handle hTimer, any iClient) {
    // player back to ground = end of hop (streak)?
    if (!IsValidClientInGame(iClient) || !IsPlayerAlive(iClient)) {
        // streak stopped by dying / teamswitch / disconnect?
        return Plugin_Stop;
    } else if (GetEntityFlags(iClient) & FL_ONGROUND) {
        float vVel[3];
        GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", vVel);
        vVel[2] = 0.0; // safeguard
        g_bHopCheck[iClient] = true;
        CreateTimer(HOPEND_CHECK_TIME, Timer_CheckHopStreak, iClient, TIMER_FLAG_NO_MAPCHANGE);
        return Plugin_Stop;
    }

    return Plugin_Continue;
}

Action Timer_CheckHopStreak(Handle hTimer, any iClient) {
    if (!IsValidClientInGame(iClient) || !IsPlayerAlive(iClient))
        return Plugin_Continue;

    // check if we have any sort of hop streak, and report
    if (g_bHopCheck[iClient] && g_iHops[iClient]) {
        HandleBHopStreak(iClient, g_iHops[iClient], g_fHopTopVelocity[iClient]);
        g_bIsHopping     [iClient] = false;
        g_iHops          [iClient] = 0;
        g_fHopTopVelocity[iClient] = 0.0;
    }

    g_bHopCheck[iClient] = false;
    return Plugin_Continue;
}

void Event_PlayerJumpApex(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));

    if (g_bIsHopping[iClient]) {
        float vVel[3];
        GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", vVel);
        vVel[2] = 0.0;

        float fLength = GetVectorLength(vVel);
        if (fLength > g_fHopTopVelocity[iClient])
            g_fHopTopVelocity[iClient] = fLength;
    }
}

void Event_JockeyRide(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    int iVictim = GetClientOfUserId(eEvent.GetInt("victim"));

    if (!IsValidInfected(iClient) || !IsValidSurvivor(iVictim))
        return;

    g_fPinTime[iClient][0] = GetGameTime();
}

void Event_AbilityUse(Event eEvent, const char[] szName, bool bDontBroadcast) {
    // track hunters pouncing
    int  iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    char szAbilityName[64];
    eEvent.GetString("ability", szAbilityName, sizeof(szAbilityName));

    if (!IsValidClientInGame(iClient))
        return;

    Ability eAbility;
    if (!g_smAbility.GetValue(szAbilityName, eAbility))
        return;

    switch (eAbility) {
        case ABL_HUNTERLUNGE: {
            // hunter started a pounce
            GetClientAbsOrigin(iClient, g_vPouncePosition[iClient]);
        }
        case ABL_ROCKTHROW: {
            // tank throws rock
            g_iTankRockClient[g_iRocksBeingThrownCount] = iClient;
            // safeguard
            if (g_iRocksBeingThrownCount < MAXPLAYERS + 1)
                g_iRocksBeingThrownCount++;
        }
    }
}

// charger carrying
void Event_ChargeCarryStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    int iVictim = GetClientOfUserId(eEvent.GetInt("victim"));

    if (!IsValidInfected(iClient))
        return;

    g_fChargeTime[iClient]    = GetGameTime();
    g_fPinTime   [iClient][0] = g_fChargeTime[iClient];
    g_fPinTime   [iClient][1] = 0.0;

    if (!IsValidSurvivor(iVictim))
        return;

    g_iChargeVictim [iClient] = iVictim;                    // store who we're carrying (as long as this is set, it's not considered an impact charge flight)
    g_iVictimCharger[iVictim] = iClient;                    // store who's charging whom
    g_iVictimFlags  [iVictim] = VICFLG_CARRIED;             // reset flags for checking later - we know only this now
    g_fChargeTime   [iVictim] = g_fChargeTime[iClient];
    g_iVictimMapDmg [iVictim] = 0;

    GetClientAbsOrigin(iVictim, g_fChargeVictimPos[iVictim]);

    CreateTimer(CHARGE_CHECK_TIME, Timer_ChargeCheck, iVictim, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

void Event_ChargeImpact(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    int iVictim = GetClientOfUserId(eEvent.GetInt("victim"));

    if (!IsValidInfected(iClient) || !IsValidSurvivor(iVictim))
        return;

    // remember how many people the charger bumped into, and who, and where they were
    GetClientAbsOrigin(iVictim, g_fChargeVictimPos[iVictim]);

    g_iVictimCharger[iVictim] = iClient;           // store who we've bumped up
    g_iVictimFlags  [iVictim] = 0;                // reset flags for checking later
    g_fChargeTime   [iVictim] = GetGameTime();    // store time per victim, for impacts
    g_iVictimMapDmg [iVictim] = 0;

    CreateTimer(CHARGE_CHECK_TIME, Timer_ChargeCheck, iVictim, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

void Event_ChargePummelStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));

    if (!IsValidInfected(iClient))
        return;

    g_fPinTime[iClient][1] = GetGameTime();
}

void Event_ChargeCarryEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));

    if (iClient <= 0 || iClient > MaxClients)
        return;

    g_fPinTime[iClient][1] = GetGameTime();

    // delay so we can check whether charger died 'mid carry'
    CreateTimer(0.1, Timer_ChargeCarryEnd, iClient, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_ChargeCarryEnd(Handle hTimer, any iClient) {
    // set charge time to 0 to avoid deathcharge timer continuing
    g_iChargeVictim[iClient] = 0;    // unset this so the repeated timer knows to stop for an ongroundcheck
    return Plugin_Continue;
}

Action Timer_ChargeCheck(Handle hTimer, any iClient) {
    // if something went wrong with the survivor or it was too long ago, forget about it
    if (!IsValidSurvivor(iClient) || !g_iVictimCharger[iClient] || g_fChargeTime[iClient] == 0.0 || (GetGameTime() - g_fChargeTime[iClient]) > MAX_CHARGE_TIME)
        return Plugin_Stop;

    // we're done checking if either the victim reached the ground, or died
    if (!IsPlayerAlive(iClient)) {
        // player died (this was .. probably.. a death charge)
        g_iVictimFlags[iClient] = g_iVictimFlags[iClient] | VICFLG_AIRDEATH;

        // check conditions now
        CreateTimer(0.0, Timer_DeathChargeCheck, iClient, TIMER_FLAG_NO_MAPCHANGE);
        return Plugin_Stop;
    } else if (GetEntityFlags(iClient) & FL_ONGROUND && g_iChargeVictim[g_iVictimCharger[iClient]] != iClient) {
        // survivor reached the ground and didn't die (yet)
        // the client-check condition checks whether the survivor is still being carried by the charger
        //      (in which case it doesn't matter that they're on the ground)

        // check conditions with small delay (to see if they still die soon)
        CreateTimer(CHARGE_END_CHECK, Timer_DeathChargeCheck, iClient, TIMER_FLAG_NO_MAPCHANGE);
        return Plugin_Stop;
    }

    return Plugin_Continue;
}

Action Timer_DeathChargeCheck(Handle hTimer, any iClient) {
    if (!IsValidClientInGame(iClient))
        return Plugin_Continue;

    int iFlags = g_iVictimFlags[iClient];

    if (!IsPlayerAlive(iClient)) {
        float vPos[3];
        GetClientAbsOrigin(iClient, vPos);

        /*
            it's a deathcharge when:
                the survivor is dead AND
                    they drowned/fell AND took enough damage or died in mid-air
                    AND not killed by someone else
                    OR is in an unreachable spot AND dropped at least X height
                    OR took plenty of map damage

            old.. need?
                fHeight > g_cvDeathChargeHeight.FloatValue
        */

        float fHeight = g_fChargeVictimPos[iClient][2] - vPos[2];
        if (((iFlags & VICFLG_DROWN || iFlags & VICFLG_FALL) && (iFlags & VICFLG_HURTLOTS || iFlags & VICFLG_AIRDEATH) || (iFlags & VICFLG_WEIRDFLOW && fHeight >= MIN_FLOWDROPHEIGHT) || g_iVictimMapDmg[iClient] >= MIN_DC_TRIGGER_DMG) && !(iFlags & VICFLG_KILLEDBYOTHER))
            HandleDeathCharge(g_iVictimCharger[iClient], iClient, fHeight, GetVectorDistance(g_fChargeVictimPos[iClient], vPos, false), view_as<bool>(iFlags & VICFLG_CARRIED));
    } else if ((iFlags & VICFLG_WEIRDFLOW || g_iVictimMapDmg[iClient] >= MIN_DC_RECHECK_DMG) && !(iFlags & VICFLG_WEIRDFLOWDONE)) {
        // could be incapped and dying more slowly
        // flag only gets set on preincap, so don't need to check for incap
        g_iVictimFlags[iClient] = g_iVictimFlags[iClient] | VICFLG_WEIRDFLOWDONE;
        CreateTimer(CHARGE_END_RECHECK, Timer_DeathChargeCheck, iClient, TIMER_FLAG_NO_MAPCHANGE);
    }

    return Plugin_Continue;
}

void ResetHunter(int iClient) {
    for (int i = 1; i <= MaxClients; i++) {
        g_iDmgDealt  [iClient][i] = 0;
        g_iShotsDealt[iClient][i] = 0;
    }
}

// entity creation
public void OnEntityCreated(int iEnt, const char[] szClsName) {
    if (iEnt <= 0 || !IsValidEntity(iEnt) || !IsValidEdict(iEnt))
        return;

    // track infected so damage on them counts as hits
    OEC eClsName;
    if (!g_smEntityCreated.GetValue(szClsName, eClsName))
        return;

    switch (eClsName) {
        case OEC_TANKROCK: {
            char szRockKey[10];
            FormatEx(szRockKey, sizeof(szRockKey), "%x", iEnt);

            // store which tank is throwing what rock
            int iTank = ShiftTankThrower();
            g_smRocks.SetValue(szRockKey, iTank, true);
            SDKHook(iEnt, SDKHook_OnTakeDamageAlivePost, TakeDamageAlivePost_Rock);
        }
    }
}

// entity destruction
public void OnEntityDestroyed(int iEnt) {
    char szKey[10];
    FormatEx(szKey, sizeof(szKey), "%x", iEnt);

    int iTank;
    if (!g_smRocks.GetValue(szKey, iTank))
        return;

    g_smRocks.Remove(szKey);
}

void TakeDamageAlivePost_Rock(int iVictim, int iAttacker, int iInflictor, float fDmg, int iDmgType, int iWeapon, const float vDmgForce[3], const float vDmgPos[3]) {
    if (GetEntProp(iVictim, Prop_Data, "m_iHealth") > 0)
        return;

    if (!IsValidClientInGame(iAttacker))
        return;

    char szRockKey[10];
    FormatEx(szRockKey, sizeof(szRockKey), "%x", iVictim);

    int iTank
    if (!g_smRocks.GetValue(szRockKey, iTank))
        return;

    HandleRockSkeeted(iAttacker, iTank);
}

// boomer got somebody
void Event_PlayerBoomed(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int  iAttacker = GetClientOfUserId(eEvent.GetInt("attacker"));
    bool bByBoom   = eEvent.GetBool("by_boomer");

    if (!g_bBoomerHitSomebody[iAttacker]) {
        if (IsValidSurvivor(g_iBoomerKiller[iAttacker]) && IsValidInfected(iAttacker) && IsValidSurvivor(g_iBoomerShover[iAttacker]))
            HandlePopEarly(g_iBoomerKiller[iAttacker], iAttacker, g_iBoomerShover[iAttacker]);
    }

    if (bByBoom && IsValidInfected(iAttacker)) {
        g_bBoomerHitSomebody[iAttacker] = true;

        // check if it was vomit spray
        bool bByExplosion = eEvent.GetBool("exploded");
        if (!bByExplosion) {
            // count amount of booms
            if (!g_iBoomerVomitHits[iAttacker])
                // check for boom count later
                CreateTimer(VOMIT_DURATION_TIME, Timer_BoomVomitCheck, iAttacker, TIMER_FLAG_NO_MAPCHANGE);
            g_iBoomerVomitHits[iAttacker]++;
        }
    }
}

// check how many booms landed
Action Timer_BoomVomitCheck(Handle hTimer, any iClient) {
    HandleVomitLanded(iClient, g_iBoomerVomitHits[iClient]);
    g_iBoomerVomitHits[iClient] = 0;
    return Plugin_Continue;
}

// smoker tongue cutting & self clears
void Event_TonguePullStopped(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iAttacker = GetClientOfUserId(eEvent.GetInt("userid"));
    int iVictim   = GetClientOfUserId(eEvent.GetInt("victim"));
    int iSmoker   = GetClientOfUserId(eEvent.GetInt("smoker"));
    int iReason   = eEvent.GetInt("release_type");

    if (!IsValidSurvivor(iAttacker) || !IsValidInfected(iSmoker))
        return;

    // clear check - if the smoker itself was not shoved, handle the clear
    HandleClear(iAttacker, iSmoker, iVictim, L4D2Infected_Smoker, (g_fPinTime[iSmoker][1] > 0.0) ? (GetGameTime() - g_fPinTime[iSmoker][1]) : -1.0, (GetGameTime() - g_fPinTime[iSmoker][0]), view_as<bool>(iReason != CUT_SLASH && iReason != CUT_KILL));

    if (iAttacker != iVictim)
        return;

    if (iReason == CUT_KILL) {
        g_bSmokerClearCheck[iSmoker] = true;
    } else if (g_bSmokerShoved[iSmoker]) {
        HandleSmokerSelfClear(iAttacker, iSmoker, true);
    } else if (iReason == CUT_SLASH) {
        // check weapon
        char szWeapon[32];
        GetClientWeapon(iAttacker, szWeapon, sizeof(szWeapon));

        // this doesn't count the chainsaw, but that's no-skill anyway
        if (strcmp(szWeapon, "weapon_melee", false) == 0)
            HandleTongueCut(iAttacker, iSmoker);
    }
}

void Event_TongueGrab(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iAttacker = GetClientOfUserId(eEvent.GetInt("userid"));
    int iVictim   = GetClientOfUserId(eEvent.GetInt("victim"));

    if (IsValidInfected(iAttacker) && IsValidSurvivor(iVictim)) {
        // new pull, clean damage
        g_bSmokerClearCheck  [iAttacker]    = false;
        g_bSmokerShoved      [iAttacker]    = false;
        g_iSmokerVictim      [iAttacker]    = iVictim;
        g_iSmokerVictimDamage[iAttacker]    = 0;
        g_fPinTime           [iAttacker][0] = GetGameTime();
        g_fPinTime           [iAttacker][1] = 0.0;
    }
}

void Event_ChokeStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iAttacker = GetClientOfUserId(eEvent.GetInt("userid"));
    if (g_fPinTime[iAttacker][0] == 0.0)
        g_fPinTime[iAttacker][0] = GetGameTime();
    g_fPinTime[iAttacker][1] = GetGameTime();
}

void Event_ChokeStop(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iAttacker = GetClientOfUserId(eEvent.GetInt("userid"));
    int iVictim   = GetClientOfUserId(eEvent.GetInt("victim"));
    int iSmoker   = GetClientOfUserId(eEvent.GetInt("smoker"));
    int iReason   = eEvent.GetInt("release_type");

    if (!IsValidSurvivor(iAttacker) || !IsValidInfected(iSmoker))
        return;

    // if the smoker itself was not shoved, handle the clear
    HandleClear(iAttacker, iSmoker, iVictim, L4D2Infected_Smoker, (g_fPinTime[iSmoker][1] > 0.0) ? (GetGameTime() - g_fPinTime[iSmoker][1]) : -1.0, (GetGameTime() - g_fPinTime[iSmoker][0]), view_as<bool>(iReason != CUT_SLASH && iReason != CUT_KILL));
}

// car alarm handling
void Event_TriggeredCarAlarm(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));

    if (!IsValidSurvivor(iClient))
        return;

    HandleCarAlarmTriggered(iClient);
}

void Event_WeaponFire(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    for (int i = 1; i <= MaxClients; i++) {
        g_bShotCounted[i][iClient] = false;
    }
}