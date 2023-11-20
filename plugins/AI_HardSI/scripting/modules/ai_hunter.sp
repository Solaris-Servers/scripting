#if defined __AI_HUNTER__
    #endinput
#endif
#define __AI_HUNTER__

bool  bHasQueuedLunge[MAXPLAYERS + 1];
float fCanLungeTime  [MAXPLAYERS + 1];

void Hunter_RoundEnd() {
    for (int i = 1; i <= MaxClients; i++) {
        fCanLungeTime[i] = 0.0;
    }
}

void Hunter_PlayerSpawn(int iClient) {
    fCanLungeTime  [iClient] = 0.0;
    bHasQueuedLunge[iClient] = false;
}

Action Hunter_OnPlayerRunCmd(int iClient, int &iButtons) {
    static int iFlags;
    iFlags = GetEntityFlags(iClient);
    if (iFlags & FL_ONGROUND == 0 || iFlags & FL_DUCKING == 0 || !GetEntProp(iClient, Prop_Send, "m_hasVisibleThreats"))
        return Plugin_Continue;

    iButtons &= ~IN_ATTACK2;

    if (NearestSurvivorDistance(iClient) > g_fFastPounceProximity)
        return Plugin_Changed;

    iButtons &= ~IN_ATTACK;
    if (!bHasQueuedLunge[iClient]) {
        bHasQueuedLunge[iClient] = true;
        fCanLungeTime[iClient] = GetGameTime() + g_fLungeInterval;
    } else if (fCanLungeTime[iClient] < GetGameTime()) {
        iButtons |= IN_ATTACK;
        bHasQueuedLunge[iClient] = false;
    }

    return Plugin_Changed;
}

void HunterPounce(int iClient) {
    static int iEnt;
    static float vPos[3];
    GetClientAbsOrigin(iClient, vPos);
    if (g_fWallDetectionDistance > 0.0 && HitWall(iClient, vPos)) {
        iEnt = GetEntPropEnt(iClient, Prop_Send, "m_customAbility");
        AngleLunge(iEnt, Math_GetRandomInt(0, 1) ? 45.0 : 315.0);
    } else {
        if (WithinViewAngle(iClient, -1, g_fAimOffsetSensitivityHunter) && NearestSurvivorDistance(iClient) > g_fStraightPounceProximity) {
            iEnt = GetEntPropEnt(iClient, Prop_Send, "m_customAbility");
            AngleLunge(iEnt, GaussianRNG(g_fPounceAngleMean, g_fPounceAngleStd));
            LimitLungeVerticality(iEnt);
        }
    }
}

bool HitWall(int iClient, float vStart[3]) {
    vStart[2] += OBSTACLE_HEIGHT;
    static float vAng[3];
    static float vEnd[3];
    GetClientEyeAngles(iClient, vAng);
    GetAngleVectors(vAng, vAng, NULL_VECTOR, NULL_VECTOR);
    NormalizeVector(vAng, vAng);
    vEnd = vAng;
    ScaleVector(vEnd, g_fWallDetectionDistance);
    AddVectors(vStart, vEnd, vEnd);

    static Handle hTrace;
    hTrace = TR_TraceHullFilterEx(vStart, vEnd, view_as<float>({-16.0, -16.0, 0.0}), view_as<float>({16.0, 16.0, 33.0}), MASK_PLAYERSOLID_BRUSHONLY, TraceEntityFilter);
    if (TR_DidHit(hTrace)) {
        static float vPlane[3];
        TR_GetPlaneNormal(hTrace, vPlane);
        if (RadToDeg(ArcCosine(GetVectorDotProduct(vAng, vPlane))) > 165.0) {
            delete hTrace;
            return true;
        }
    }

    delete hTrace;
    return false;
}

float GetPlayerAimOffset(int iClient, int iTarget) {
    static float vAng[3];
    GetClientEyeAngles(iTarget, vAng);

    vAng[0] = vAng[2] = 0.0;
    GetAngleVectors(vAng, vAng, NULL_VECTOR, NULL_VECTOR);
    NormalizeVector(vAng, vAng);

    static float vPos[3];
    GetClientAbsOrigin(iClient, vPos);

    static float vDir[3];
    GetClientAbsOrigin(iTarget, vDir);

    vPos[2] = vDir[2] = 0.0;
    MakeVectorFromPoints(vDir, vPos, vDir);
    NormalizeVector(vDir, vDir);

    return RadToDeg(ArcCosine(GetVectorDotProduct(vAng, vDir)));
}

void AngleLunge(int iEnt, float fTurnAngle) {
    static float vLunge[3];
    GetEntPropVector(iEnt, Prop_Send, "m_queuedLunge", vLunge);
    fTurnAngle = DegToRad(fTurnAngle);

    static float vForcedLunge[3];
    vForcedLunge[0] = vLunge[0] * Cosine(fTurnAngle) - vLunge[1] * Sine(fTurnAngle);
    vForcedLunge[1] = vLunge[0] * Sine(fTurnAngle) + vLunge[1] * Cosine(fTurnAngle);
    vForcedLunge[2] = vLunge[2];

    SetEntPropVector(iEnt, Prop_Send, "m_queuedLunge", vForcedLunge);
}

void LimitLungeVerticality(int iEnt) {
    static float vLunge[3];
    GetEntPropVector(iEnt, Prop_Send, "m_queuedLunge", vLunge);

    static float fVertAngle;
    fVertAngle = DegToRad(g_fPounceVerticalAngle);

    static float vFlatLunge[3];
    vFlatLunge[1] = vLunge[1] * Cosine(fVertAngle) - vLunge[2] * Sine(fVertAngle);
    vFlatLunge[2] = vLunge[1] * Sine(fVertAngle) + vLunge[2] * Cosine(fVertAngle);
    vFlatLunge[0] = vLunge[0] * Cosine(fVertAngle) + vLunge[2] * Sine(fVertAngle);
    vFlatLunge[2] = vLunge[0] * -Sine(fVertAngle) + vLunge[2] * Cosine(fVertAngle);

    SetEntPropVector(iEnt, Prop_Send, "m_queuedLunge", vFlatLunge);
}