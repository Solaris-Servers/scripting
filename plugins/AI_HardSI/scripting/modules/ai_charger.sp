#if defined __AI_CHARGER__
    #endinput
#endif
#define __AI_CHARGER__

void Charger_OnStartCarryingVictim_Post(int iVictim, int iAttacker) {
    if (GetEntPropEnt(iAttacker, Prop_Send, "m_carryVictim") != -1) {
        DataPack dp = new DataPack();
        dp.WriteCell(GetClientUserId(iVictim));
        dp.WriteCell(GetClientUserId(iAttacker));
        RequestFrame(NextFrame_SetVelocity, dp);
    }
}

void NextFrame_SetVelocity(DataPack dp) {
    dp.Reset();
    int iVictim   = dp.ReadCell();
    int iAttacker = dp.ReadCell();
    delete dp;

    iVictim = GetClientOfUserId(iVictim);
    if (iVictim <= 0 || !IsClientInGame(iVictim))
        return;

    iAttacker = GetClientOfUserId(iAttacker);
    if (iAttacker <= 0 || !IsClientInGame(iAttacker))
        return;

    if (GetEntPropEnt(iAttacker, Prop_Send, "m_carryVictim") == -1)
        return;

    if (GetEntPropEnt(iAttacker, Prop_Send, "m_pummelVictim") != -1)
        return;

    float vVel[3];
    GetEntPropVector(iAttacker, Prop_Data, "m_vecVelocity", vVel);

    float fVel = GetVectorLength(vVel);
    if (vVel[2] <= 0.0)
        return;

    vVel[2] = 0.0;
    NormalizeVector(vVel, vVel);
    ScaleVector(vVel, fVel);

    TeleportEntity(iAttacker, NULL_VECTOR, NULL_VECTOR, vVel);
}

Action Charger_OnPlayerRunCmd(int iClient, int &iButtons) {
    static float fNearestSurDist;
    fNearestSurDist = NearestSurvivorDistance(iClient);

    if (fNearestSurDist > g_fChargeProximity && GetEntProp(iClient, Prop_Data, "m_iHealth") > g_iHealthThreshold) {
        if (!g_bShouldCharge[iClient])
            ResetAbilityTime(iClient, 0.1);
    } else {
        g_bShouldCharge[iClient] = true;
    }

    if (g_bShouldCharge[iClient] && CanCharge(iClient)) {
        static int iTarget;
        iTarget = GetClientAimTarget(iClient, false);
        if (IsAliveSurvivor(iTarget) && !Incapacitated(iTarget) && GetEntPropEnt(iTarget, Prop_Send, "m_carryAttacker") == -1) {
            static float vPos[3];
            GetClientAbsOrigin(iClient, vPos);

            static float vTar[3];
            GetClientAbsOrigin(iTarget, vTar);

            if (GetVectorDistance(vPos, vTar) < 100.0 && !EntHitWall(iClient, iTarget)) {
                iButtons |= IN_ATTACK;
                iButtons |= IN_ATTACK2;
                return Plugin_Changed;
            }
        }
    }

    if (!g_bChargerBhop || GetEntityMoveType(iClient) == MOVETYPE_LADDER || GetEntProp(iClient, Prop_Data, "m_nWaterLevel") > 1 || !GetEntProp(iClient, Prop_Send, "m_hasVisibleThreats"))
        return Plugin_Continue;

    static float vVel[3];
    GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", vVel);
    vVel[2] = 0.0;

    static float fVal;
    fVal = GetVectorLength(vVel);
    if (!CheckPlayerMove(iClient, fVal))
        return Plugin_Continue;

    static float vAng[3];
    static bool  bModify[MAXPLAYERS + 1];

    if (IsGrounded(iClient)) {
        bModify[iClient] = false;
        if (CurTargetDistance(iClient) > 100.0 && -1.0 < fNearestSurDist < 1500.0) {
            GetClientEyeAngles(iClient, vAng);
            return BunnyHop(iClient, iButtons, vAng);
        }
    } else {
        if (bModify[iClient] || fVal < GetEntPropFloat(iClient, Prop_Send, "m_flMaxspeed") + BOOST)
            return Plugin_Continue;

        if (IsCharging(iClient))
            return Plugin_Continue;

        static int iTarget;
        iTarget = GetClientAimTarget(iClient, false);
        if (!IsAliveSurvivor(iTarget))
            iTarget = g_iCurTarget[iClient];

        if (!IsAliveSurvivor(iTarget))
            return Plugin_Continue;


        static float vPos[3];
        GetClientAbsOrigin(iClient, vPos);

        static float vTar[3];
        GetClientAbsOrigin(iTarget, vTar);

        fVal = GetVectorDistance(vPos, vTar);
        if (fVal < 100.0 || fVal > 440.0)
            return Plugin_Continue;

        static float vEye1[3];
        GetClientEyePosition(iClient, vEye1);
        if (vEye1[2] < vTar[2])
            return Plugin_Continue;

        static float vEye2[3];
        GetClientEyePosition(iTarget, vEye2);
        if (vPos[2] > vEye2[2])
            return Plugin_Continue;

        vAng = vVel;
        vAng[2] = 0.0;
        NormalizeVector(vAng, vAng);

        static float vBuf[3];
        MakeVectorFromPoints(vPos, vTar, vBuf);
        vBuf[2] = 0.0;
        NormalizeVector(vBuf, vBuf);

        if (RadToDeg(ArcCosine(GetVectorDotProduct(vAng, vBuf))) < 90.0)
            return Plugin_Continue;

        if (VecHitWall(iClient, vPos, vTar))
            return Plugin_Continue;

        MakeVectorFromPoints(vPos, vEye2, vVel);
        TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, vVel);
        bModify[iClient] = true;
    }

    return Plugin_Continue;
}

float CurTargetDistance(int iClient) {
    if (!IsAliveSurvivor(g_iCurTarget[iClient]))
        return -1.0;

    static float vPos[3];
    GetClientAbsOrigin(iClient, vPos);

    static float vTar[3];
    GetClientAbsOrigin(g_iCurTarget[iClient], vTar);

    return GetVectorDistance(vPos, vTar);
}

bool IsCharging(int iClient) {
    static int iEnt;
    iEnt = GetEntPropEnt(iClient, Prop_Send, "m_customAbility");
    return iEnt > MaxClients && GetEntProp(iEnt, Prop_Send, "m_isCharging");
}

bool CanCharge(int iClient) {
    if (GetEntPropEnt(iClient, Prop_Send, "m_pummelVictim") > 0 || GetEntPropEnt(iClient, Prop_Send, "m_carryVictim") > 0)
        return false;

    static int iEnt;
    iEnt = GetEntPropEnt(iClient, Prop_Send, "m_customAbility");
    return iEnt > MaxClients && !GetEntProp(iEnt, Prop_Send, "m_isCharging") && GetEntPropFloat(iEnt, Prop_Send, "m_timestamp") < GetGameTime();
}

void ResetAbilityTime(int iClient, float fTime) {
    static int iEnt;
    iEnt = GetEntPropEnt(iClient, Prop_Send, "m_customAbility");
    if (iEnt > MaxClients) SetEntPropFloat(iEnt, Prop_Send, "m_timestamp", GetGameTime() + fTime);
}

void ChargerCharge(int iClient) {
    int iTarget = GetClientAimTarget(iClient, false); // iCurTarget[iClient];
    if (!IsAliveSurvivor(iTarget) || Incapacitated(iTarget) || IsPinned(iTarget, true) || EntHitWall(iClient, iTarget) || WithinViewAngle(iClient, iTarget, g_fAimOffsetSensitivityCharger))
        iTarget = GetClosestSurvivor(iClient, g_fChargeMaxSpeed, iTarget);

    if (!IsAliveSurvivor(iTarget))
        return;

    float vVel[3];
    GetEntPropVector(iClient, Prop_Data, "m_vecAbsVelocity", vVel);

    float fVel = GetVectorLength(vVel);
    fVel = fVel < g_fChargeStartSpeed ? g_fChargeStartSpeed : fVel;

    float vPos[3], vTar[3];
    GetClientAbsOrigin(iClient, vPos);
    GetClientAbsOrigin(iTarget, vTar);

    float fHeight = vTar[2] - vPos[2];
    if (fHeight >= 44.0) {
        vTar[2] += 44.0;
        fVel += FloatAbs(fHeight);
        vTar[2] += GetVectorDistance(vPos, vTar) / fVel * PLAYER_HEIGHT;
    }

    if (!IsGrounded(iClient)) fVel += g_fChargeMaxSpeed;

    MakeVectorFromPoints(vPos, vTar, vVel);

    float vAng[3];
    GetVectorAngles(vVel, vAng);
    NormalizeVector(vVel, vVel);
    ScaleVector(vVel, fVel);

    int iFlags = GetEntityFlags(iClient);
    SetEntityFlags(iClient, (iFlags & ~FL_FROZEN) & ~FL_ONGROUND);
    TeleportEntity(iClient, NULL_VECTOR, vAng, vVel);
    SetEntityFlags(iClient, iFlags);
}