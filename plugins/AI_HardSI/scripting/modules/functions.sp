#if defined __FUNCTIONS__
    #endinput
#endif
#define __FUNCTIONS__

void GetSurDistance(int iClient, float &fCurTargetDist, float &fNearestSurDist) {
    static float vPos[3];
    GetClientAbsOrigin(iClient, vPos);

    static float vTar[3];
    if (!IsAliveSurvivor(g_iCurTarget[iClient]))
        fCurTargetDist = -1.0;
    else {
        GetClientAbsOrigin(g_iCurTarget[iClient], vTar);
        fCurTargetDist = GetVectorDistance(vPos, vTar);
    }

    static int   i;
    static float fDist;

    fNearestSurDist = -1.0;
    GetClientAbsOrigin(iClient, vPos);
    for (i = 1; i <= MaxClients; i++) {
        if (i != iClient && IsClientInGame(i) && GetClientTeam(i) == L4D2Team_Survivor && IsPlayerAlive(i)) {
            GetClientAbsOrigin(i, vTar);
            fDist = GetVectorDistance(vPos, vTar);
            if (fNearestSurDist == -1.0 || fDist < fNearestSurDist)
                fNearestSurDist = fDist;
        }
    }
}

bool VecHitWall(int iClient, float vPos[3], float vTar[3]) {
    vPos[2] += 10.0;
    vTar[2] += 10.0;
    MakeVectorFromPoints(vPos, vTar, vTar);

    static float fDist;
    fDist = GetVectorLength(vTar);
    NormalizeVector(vTar, vTar);
    ScaleVector(vTar, fDist);
    AddVectors(vPos, vTar, vTar);

    static float vMins[3];
    GetClientMins(iClient, vMins);

    static float vMaxs[3];
    GetClientMaxs(iClient, vMaxs);

    vMins[2] += 10.0;
    vMaxs[2] -= 10.0;

    static bool   bHit;
    static Handle hTrace;
    hTrace = TR_TraceHullFilterEx(vPos, vTar, vMins, vMaxs, MASK_PLAYERSOLID, TraceEntityFilter);
    bHit = TR_DidHit(hTrace);
    delete hTrace;
    return bHit;
}

bool CheckPlayerMove(int iClient, float fVel) {
    return fVel > 0.9 * GetEntPropFloat(iClient, Prop_Send, "m_flMaxspeed") > 0.0;
}

Action BunnyHop(int iClient, int &iButtons, const float vAng[3]) {
    float vVec[3];
    if (iButtons & IN_FORWARD && !(iButtons & IN_BACK)) {
        GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
        NormalizeVector(vVec, vVec);
        ScaleVector(vVec, BOOST * 2.0);
        float vVel[3];
        GetEntPropVector(iClient, Prop_Data, "m_vecAbsVelocity", vVel);
        AddVectors(vVel, vVec, vVel);
        if (CheckHopVel(iClient, vAng, vVel)) {
            iButtons |= IN_DUCK;
            iButtons |= IN_JUMP;
            TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, vVel);
            return Plugin_Changed;
        }
    } else if (iButtons & IN_BACK && !(iButtons & IN_FORWARD)) {
        GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
        NormalizeVector(vVec, vVec);
        ScaleVector(vVec, -BOOST);
        float vVel[3];
        GetEntPropVector(iClient, Prop_Data, "m_vecAbsVelocity", vVel);
        AddVectors(vVel, vVec, vVel);
        if (CheckHopVel(iClient, vAng, vVel)) {
            iButtons |= IN_DUCK;
            iButtons |= IN_JUMP;
            TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, vVel);
            return Plugin_Changed;
        }
    }

    if (iButtons & IN_MOVERIGHT && !(iButtons & IN_MOVELEFT)) {
        GetAngleVectors(vAng, NULL_VECTOR, vVec, NULL_VECTOR);
        NormalizeVector(vVec, vVec);
        ScaleVector(vVec, BOOST);
        float vVel[3];
        GetEntPropVector(iClient, Prop_Data, "m_vecAbsVelocity", vVel);
        AddVectors(vVel, vVec, vVel);
        if (CheckHopVel(iClient, vAng, vVel)) {
            iButtons |= IN_DUCK;
            iButtons |= IN_JUMP;
            TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, vVel);
            return Plugin_Changed;
        }
    }
    else if (iButtons & IN_MOVELEFT && !(iButtons & IN_MOVERIGHT)) {
        GetAngleVectors(vAng, NULL_VECTOR, vVec, NULL_VECTOR);
        NormalizeVector(vVec, vVec);
        ScaleVector(vVec, -BOOST);
        float vVel[3];
        GetEntPropVector(iClient, Prop_Data, "m_vecAbsVelocity", vVel);
        AddVectors(vVel, vVec, vVel);
        if (CheckHopVel(iClient, vAng, vVel)) {
            iButtons |= IN_DUCK;
            iButtons |= IN_JUMP;
            TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, vVel);
            return Plugin_Changed;
        }
    }

    return Plugin_Continue;
}

bool CheckHopVel(int iClient, const float vAng[3], const float vVel[3]) {
    static float vMins[3];
    GetClientMins(iClient, vMins);

    static float vMaxs[3];
    GetClientMaxs(iClient, vMaxs);

    static float vPos[3];
    GetClientAbsOrigin(iClient, vPos);

    static float vEnd[3];
    NormalizeVector(vVel, vEnd);

    float fVel = GetVectorLength(vVel);
    ScaleVector(vEnd, fVel + FloatAbs(vMaxs[0] - vMins[0]) + 3.0);
    AddVectors(vPos, vEnd, vEnd);

    static bool   bHit;
    static Handle hTrace;

    static float  vVec  [3];
    static float  vNor  [3];
    static float  vPlane[3];

    bHit = false;
    vPos[2] += 10.0;
    vEnd[2] += 10.0;

    hTrace = TR_TraceHullFilterEx(vPos, vEnd, vMins, vMaxs, MASK_PLAYERSOLID, TraceEntityFilter);
    if (TR_DidHit(hTrace)) {
        bHit = true;
        TR_GetEndPosition(vVec, hTrace);

        NormalizeVector(vVel, vNor);
        TR_GetPlaneNormal(hTrace, vPlane);
        if (RadToDeg(ArcCosine(GetVectorDotProduct(vNor, vPlane))) > 165.0) {
            delete hTrace;
            return false;
        }

        vNor[1] = vAng[1];
        vNor[0] = vNor[2] = 0.0;
        GetAngleVectors(vNor, vNor, NULL_VECTOR, NULL_VECTOR);
        NormalizeVector(vNor, vNor);
        if (RadToDeg(ArcCosine(GetVectorDotProduct(vNor, vPlane))) > 165.0) {
            delete hTrace;
            return false;
        }
    }
    else {
        vNor[1] = vAng[1];
        vNor[0] = vNor[2] = 0.0;
        GetAngleVectors(vNor, vNor, NULL_VECTOR, NULL_VECTOR);
        NormalizeVector(vNor, vNor);
        vPlane = vNor;
        ScaleVector(vPlane, 128.0);
        AddVectors(vPos, vPlane, vPlane);
        delete hTrace;
        hTrace = TR_TraceHullFilterEx(vPos, vPlane, view_as<float>({-16.0, -16.0, 0.0}), view_as<float>({16.0, 16.0, 33.0}), MASK_PLAYERSOLID, TraceWallFilter, iClient);
        if (TR_DidHit(hTrace)) {
            TR_GetPlaneNormal(hTrace, vPlane);
            if (RadToDeg(ArcCosine(GetVectorDotProduct(vNor, vPlane))) > 165.0) {
                delete hTrace;
                return false;
            }
        }
        delete hTrace;
    }
    delete hTrace;

    if (!bHit) vVec = vEnd;

    static float vDown[3];
    vDown[0] = vVec[0];
    vDown[1] = vVec[1];
    vDown[2] = vVec[2] - 100000.0;

    hTrace = TR_TraceHullFilterEx(vVec, vDown, vMins, vMaxs, MASK_PLAYERSOLID, TraceSelfFilter, iClient);
    if (!TR_DidHit(hTrace)) {
        delete hTrace;
        return false;
    }

    TR_GetEndPosition(vEnd, hTrace);
    delete hTrace;
    return vVec[2] - vEnd[2] < 104.0;
}

bool TraceWallFilter(int iEnt, int iMask, any aData) {
    if (iEnt != aData) {
        static char szCls[5];
        GetEdictClassname(iEnt, szCls, sizeof szCls);
        return szCls[3] != 'e' && szCls[3] != 'c';
    }

    return false;
}

bool TraceEntityFilter(int iEnt, int iMask) {
    if (!iEnt || iEnt > MaxClients) {
        static char szCls[5];
        GetEdictClassname(iEnt, szCls, sizeof szCls);
        return szCls[3] != 'e' && szCls[3] != 'c';
    }

    return false;
}

bool TraceSelfFilter(int iEnt, int iMask, any aData) {
    return iEnt != aData;
}

// credits = "AtomicStryker"
bool IsVisibleTo(const float vPos[3], const float vTarget[3]) {
    static float vLookAt[3];
    MakeVectorFromPoints(vPos, vTarget, vLookAt);
    GetVectorAngles(vLookAt, vLookAt);

    static Handle hTrace;
    hTrace = TR_TraceRayFilterEx(vPos, vLookAt, MASK_VISIBLE, RayType_Infinite, TraceEntityFilter);

    static bool bVisible;
    bVisible = false;
    if (TR_DidHit(hTrace)) {
        static float vStart[3];
        TR_GetEndPosition(vStart, hTrace);
        if ((GetVectorDistance(vPos, vStart, false) + 25.0) >= GetVectorDistance(vPos, vTarget))
            bVisible = true;
    }

    delete hTrace;
    return bVisible;
}

bool WithinViewAngle(int iClient, int iTarget = -1, float fOffsetThreshold) {
    if (iTarget == -1) {
        iTarget = GetClientAimTarget(iClient);
        if (!IsAliveSurvivor(iTarget))
            return true;
    }

    static float vSrc[3];
    GetClientEyePosition(iTarget, vSrc);

    static float vTar[3];
    GetClientEyePosition(iClient, vTar);

    static float vAng[3];
    if (IsVisibleTo(vSrc, vTar)) {
        GetClientEyeAngles(iTarget, vAng);
        return PointWithinViewAngle(vSrc, vTar, vAng, GetFOVDotProduct(fOffsetThreshold));
    }

    return false;
}

float NearestSurvivorDistance(int iClient) {
    static int   i;
    static float vPos[3];
    static float vTar[3];
    static float fDist;
    static float fMinDist;

    fMinDist = -1.0;
    GetClientAbsOrigin(iClient, vPos);
    for (i = 1; i <= MaxClients; i++) {
        if (i != iClient && IsClientInGame(i) && GetClientTeam(i) == L4D2Team_Survivor && IsPlayerAlive(i)) {
            GetClientAbsOrigin(i, vTar);
            fDist = GetVectorDistance(vPos, vTar);
            if (fMinDist == -1.0 || fDist < fMinDist)
                fMinDist = fDist;
        }
    }

    return fMinDist;
}

int GetClosestSurvivor(int iClient, float fRange, int iExclude = -1) {
    static int   i;
    static int   iNum;
    static int   iIdx;
    static float fDist;
    static float vAng[3];
    static float vSrc[3];
    static float vTar[3];
    static int   iClients[MAXPLAYERS + 1];

    iNum = 0;
    GetClientEyePosition(iClient, vSrc);
    iNum = GetClientsInRange(vSrc, RangeType_Visibility, iClients, MAXPLAYERS);

    if (!iNum) return iExclude;

    static ArrayList arrTargets;
    arrTargets = new ArrayList(3);
    float fFov = GetFOVDotProduct(g_fAimOffsetSensitivityCharger);
    for (i = 0; i < iNum; i++) {
        if (!iClients[i] || iClients[i] == iExclude)
            continue;

        if (GetClientTeam(iClients[i]) != L4D2Team_Survivor || !IsPlayerAlive(iClients[i]) || Incapacitated(iClients[i]) || IsPinned(iClients[i], true) || EntHitWall(iClient, iClients[i]))
            continue;

        GetClientEyePosition(iClients[i], vTar);
        fDist = GetVectorDistance(vSrc, vTar);
        if (fDist < fRange) {
            iIdx = arrTargets.Push(fDist);
            arrTargets.Set(iIdx, iClients[i], 1);

            GetClientEyeAngles(iClients[i], vAng);
            arrTargets.Set(iIdx, !PointWithinViewAngle(vTar, vSrc, vAng, fFov) ? 0 : 1, 2);
        }
    }

    if (!arrTargets.Length) {
        delete arrTargets;
        return iExclude;
    }

    arrTargets.Sort(Sort_Ascending, Sort_Float);
    iIdx = arrTargets.FindValue(0, 2);
    i = arrTargets.Get(iIdx != -1 && arrTargets.Get(iIdx, 0) < 0.5 * fRange ? iIdx : 0, 1);

    delete arrTargets;
    return i;
}

bool EntHitWall(int iClient, int iTarget) {
    static float vPos[3];
    GetClientAbsOrigin(iClient, vPos);

    static float vTar[3];
    GetClientAbsOrigin(iTarget, vTar);

    vPos[2] += 10.0;
    vTar[2] += 10.0;

    MakeVectorFromPoints(vPos, vTar, vTar);
    static float fDist;
    fDist = GetVectorLength(vTar);
    NormalizeVector(vTar, vTar);
    ScaleVector(vTar, fDist);
    AddVectors(vPos, vTar, vTar);

    static float vMins[3];
    GetClientMins(iClient, vMins);

    static float vMaxs[3];
    GetClientMaxs(iClient, vMaxs);

    vMins[2] += fDist > 49.0 ? 10.0 : 44.0;
    vMaxs[2] -= 10.0;

    static bool   bHit;
    static Handle hTrace;
    hTrace = TR_TraceHullFilterEx(vPos, vTar, vMins, vMaxs, MASK_PLAYERSOLID, TraceEntityFilter);
    bHit = TR_DidHit(hTrace);
    delete hTrace;
    return bHit;
}

bool IsPinned(int iClient, bool bExclude = false) {
    if (GetEntPropEnt(iClient, Prop_Send, "m_tongueOwner") > 0 && !bExclude)
        return true;
    if (GetEntPropEnt(iClient, Prop_Send, "m_pounceAttacker") > 0)
        return true;
    if (GetEntPropEnt(iClient, Prop_Send, "m_jockeyAttacker") > 0 && !bExclude)
        return true;
    if (GetEntPropEnt(iClient, Prop_Send, "m_carryAttacker") > 0)
        return true;
    if (GetEntPropEnt(iClient, Prop_Send, "m_pummelAttacker") > 0)
        return true;
    return false;
}

/**
 * Thanks to Newteee:
 * Random number generator fit to a bellcurve. Function to generate Gaussian Random Number fit to a bellcurve with a specified mean and std
 * Uses Polar Form of the Box-Muller transformation
*/
float GaussianRNG(float fMean, float fStd) {
    static float x1;
    static float x2;
    static float w;

    do {
        x1 = 2.0 * Math_GetRandomFloat(0.0, 1.0) - 1.0;
        x2 = 2.0 * Math_GetRandomFloat(0.0, 1.0) - 1.0;
        w = Pow(x1, 2.0) + Pow(x2, 2.0);
    } while (w >= 1.0);

    static const float e = 2.71828;
    w = SquareRoot(-2.0 * (Logarithm(w, e) / w));

    static float y1;
    static float y2;
    y1 = x1 * w;
    y2 = x2 * w;

    static float z1;
    static float z2;
    z1 = y1 * fStd + fMean;
    z2 = y2 * fStd - fMean;

    return Math_GetRandomFloat(0.0, 1.0) < 0.5 ? z1 : z2;
}

float Math_GetRandomFloat(float fMin, float fMax) {
    return (GetURandomFloat() * (fMax  - fMin)) + fMin;
}

// https://github.com/bcserv/smlib/blob/transitional_syntax/scripting/include/smlib/math.inc
/**
 * Returns a random, uniform Integer number in the specified (inclusive) range.
 * This is safe to use multiple times in a function.
 * The seed is set automatically for each plugin.
 * Rewritten by MatthiasVance, thanks.
 *
 * @param iMin          Min value used as lower border
 * @param iMax          Max value used as upper border
 * @return              Random Integer number between min and max
 */
int Math_GetRandomInt(int iMin, int iMax) {
    int iRnd = GetURandomInt();
    if (iRnd == 0) iRnd++;
    return RoundToCeil(float(iRnd) / (float(SIZE_OF_INT) / float(iMax - iMin + 1))) + iMin - 1;
}

// https://github.com/nosoop/stocksoup
/**
 * Checks if a point is in the field of view of an object.  Supports up to 180 degree FOV.
 * I forgot how the dot product stuff works.
 *
 * Direct port of the function of the same name from the Source SDK:
 * https://github.com/ValveSoftware/source-sdk-2013/blob/beaae8ac45a2f322a792404092d4482065bef7ef/sp/src/public/mathlib/vector.h#L461-L477
 *
 * @param vSrcPosition      Source position of the view.
 * @param vTargetPosition   Point to check if within view angle.
 * @param vLookDirection    The direction to look towards.  Note that this must be a forward
 *                          angle vector.
 * @param fCosHalfFOV       The width of the forward view cone as a dot product result. For
 *                          subclasses of CBaseCombatCharacter, you can use the
 *                          `m_flFieldOfView` data property.  To manually calculate for a
 *                          desired FOV, use `GetFOVDotProduct(angle)` from math.inc.
 * @return                  True if the point is within view from the source position at the
 *                          specified FOV.
 */
bool PointWithinViewAngle(const float vSrcPosition[3], const float vTargetPosition[3], const float vLookDirection[3], float fCosHalfFOV) {
    static float vDelta[3];
    SubtractVectors(vTargetPosition, vSrcPosition, vDelta);

    static float fCosDiff;
    fCosDiff = GetVectorDotProduct(vLookDirection, vDelta);

    if (fCosDiff < 0.0) return false;
    // a/sqrt(b) > c  == a^2 > b * c ^2
    return fCosDiff * fCosDiff >= GetVectorLength(vDelta, true) * fCosHalfFOV * fCosHalfFOV;
}

/**
 * Calculates the width of the forward view cone as a dot product result from the given angle.
 * This manually calculates the value of CBaseCombatCharacter's `m_flFieldOfView` data property.
 *
 * For reference: https://github.com/ValveSoftware/source-sdk-2013/blob/master/sp/src/game/server/hl2/npc_bullseye.cpp#L151
 *
 * @param fAng      The FOV value in degree
 * @return          Width of the forward view cone as a dot product result
 */
float GetFOVDotProduct(float fAng) {
    return Cosine(DegToRad(fAng) / 2.0);
}

// Stocks
stock bool Incapacitated(int iClient) {
    return view_as<bool>(GetEntProp(iClient, Prop_Send, "m_isIncapacitated"));
}

stock bool IsBeingWatched(int iClient, float fOffsetThreshold) {
    static int iTarget;
    iTarget = GetClientAimTarget(iClient);
    return !IsAliveSurvivor(iTarget) || GetPlayerAimOffset(iClient, iTarget) <= fOffsetThreshold;
}

stock bool TargetSurvivor(int iClient) {
    return IsAliveSurvivor(GetClientAimTarget(iClient, true));
}

stock bool IsGrounded(int iClient) {
    return GetEntPropEnt(iClient, Prop_Send, "m_hGroundEntity") != -1;
}

stock bool IsAliveSurvivor(int iClient) {
    return iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient) && GetClientTeam(iClient) == L4D2Team_Survivor && IsPlayerAlive(iClient);
}