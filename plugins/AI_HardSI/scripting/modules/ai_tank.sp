#if defined __AI_TANK__
    #endinput
#endif
#define __AI_TANK__

Action Tank_OnPlayerRunCmd(int iClient, int &iButtons) {
    if (!g_bTankBhop)
        return Plugin_Continue;

    if (GetEntityMoveType(iClient) == MOVETYPE_LADDER || GetEntProp(iClient, Prop_Data, "m_nWaterLevel") > 1 || (!GetEntProp(iClient, Prop_Send, "m_hasVisibleThreats") && !TargetSurvivor(iClient)))
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
        static float fCurTargetDist;
        static float fNearestSurDist;
        GetSurDistance(iClient, fCurTargetDist, fNearestSurDist);
        if (fCurTargetDist > 0.5 * g_fTankAttackRange && -1.0 < fNearestSurDist < 1500.0) {
            GetClientEyeAngles(iClient, vAng);
            return BunnyHop(iClient, iButtons, vAng);
        }
    } else {
        if (bModify[iClient] || fVal < GetEntPropFloat(iClient, Prop_Send, "m_flMaxspeed") + BOOST)
            return Plugin_Continue;

        static int iTarget;
        iTarget = g_iCurTarget[iClient]; // GetClientAimTarget(iClient, true);
        // if (!IsAliveSurvivor(iTarget)) iTarget = g_iCurTarget[iClient];

        if (!IsAliveSurvivor(iTarget))
            return Plugin_Continue;

        static float vPos[3];
        GetClientAbsOrigin(iClient, vPos);

        static float vTar[3];
        GetClientAbsOrigin(iTarget, vTar);

        fVal = GetVectorDistance(vPos, vTar);
        if (fVal < g_fTankAttackRange || fVal > 440.0)
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