#if defined __AI_BOOMER__
    #endinput
#endif
#define __AI_BOOMER__

Action Boomer_OnPlayerRunCmd(int iClient, int &iButtons) {
    if (!g_bBoomerBhop)
        return Plugin_Continue;

    if (!IsGrounded(iClient) || GetEntityMoveType(iClient) == MOVETYPE_LADDER || GetEntProp(iClient, Prop_Data, "m_nWaterLevel") > 1 && (!GetEntProp(iClient, Prop_Send, "m_hasVisibleThreats") && !TargetSurvivor(iClient)))
        return Plugin_Continue;

    static float vVel[3];
    GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", vVel);

    vVel[2] = 0.0;
    if (!CheckPlayerMove(iClient, GetVectorLength(vVel)))
        return Plugin_Continue;

    static float fCurTargetDist;
    static float fNearestSurDist;
    GetSurDistance(iClient, fCurTargetDist, fNearestSurDist);

    if (fCurTargetDist > 0.50 * g_fVomitRange && -1.0 < fNearestSurDist < 1500.0) {
        static float vAng[3];
        GetClientEyeAngles(iClient, vAng);
        return BunnyHop(iClient, iButtons, vAng);
    }

    return Plugin_Continue;
}

void BoomerVomit(int iClient) {
    int iTarget = GetClientAimTarget(iClient, false); // g_iCurTarget[iClient];
    if (!IsAliveSurvivor(iTarget) || GetEntPropFloat(iTarget, Prop_Send, "m_itTimer", 1) != -1.0)
        iTarget = FindVomitTarget(iClient, g_fVomitRange + 2.0 * PLAYER_HEIGHT, iTarget);

    if (!IsAliveSurvivor(iTarget))
        return;

    float vPos[3], vTar[3], vVel[3];
    GetClientAbsOrigin(iClient, vPos);
    GetClientEyePosition(iTarget, vTar);
    MakeVectorFromPoints(vPos, vTar, vVel);

    float fVel = GetVectorLength(vVel);
    if (fVel < g_fVomitRange) fVel = 0.5 * g_fVomitRange;

    float fHeight = vTar[2] - vPos[2];
    if (fHeight > PLAYER_HEIGHT) fVel += GetVectorDistance(vPos, vTar) / fVel * PLAYER_HEIGHT;

    float vAng[3];
    GetVectorAngles(vVel, vAng);
    NormalizeVector(vVel, vVel);
    ScaleVector(vVel, fVel);

    int iFlags = GetEntityFlags(iClient);
    SetEntityFlags(iClient, (iFlags & ~FL_FROZEN) & ~FL_ONGROUND);
    TeleportEntity(iClient, NULL_VECTOR, vAng, vVel);
    SetEntityFlags(iClient, iFlags);
}

int FindVomitTarget(int iClient, float fRange, int iExclude = -1) {
    static int   i;
    static int   iNum;
    static float fDist;
    static float vPos[3];
    static float vTarget[3];
    static int   iClients[MAXPLAYERS + 1];

    iNum = 0;
    GetClientEyePosition(iClient, vPos);
    iNum = GetClientsInRange(vPos, RangeType_Visibility, iClients, MAXPLAYERS);

    if (!iNum) return iExclude;

    static ArrayList arrTargets;
    arrTargets = new ArrayList(2);
    for (i = 0; i < iNum; i++) {
        if (!iClients[i] || iClients[i] == iExclude)
            continue;

        if (GetClientTeam(iClients[i]) != L4D2Team_Survivor || !IsPlayerAlive(iClients[i]) || GetEntPropFloat(iClients[i], Prop_Send, "m_itTimer", 1) != -1.0)
            continue;

        GetClientAbsOrigin(iClients[i], vTarget);
        fDist = GetVectorDistance(vPos, vTarget);
        if (fDist < fRange) arrTargets.Set(arrTargets.Push(fDist), iClients[i], 1);
    }

    if (!arrTargets.Length) {
        delete arrTargets;
        return iExclude;
    }

    arrTargets.Sort(Sort_Ascending, Sort_Float);
    iNum = arrTargets.Get(0, 1);
    delete arrTargets;
    return iNum;
}