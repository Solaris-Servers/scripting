#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <solaris/stocks>

#define MAX_TELEPORT_RANGE 200.0

ConVar g_cvStuckTolerance;

public void OnPluginStart() {
    g_cvStuckTolerance = FindConVar("sv_player_stuck_tolerance");
    g_cvStuckTolerance.SetInt(999999);
    g_cvStuckTolerance.AddChangeHook(CvChg_StuckTolerance);

    CreateTimer(1.0, Teleport_Callback, _, TIMER_REPEAT);
}

public void OnPluginEnd() {
    g_cvStuckTolerance.RemoveChangeHook(CvChg_StuckTolerance);
    g_cvStuckTolerance.RestoreDefault();
}

void CvChg_StuckTolerance(ConVar cv, const char[] szOldVal, const char[] szNewVal){
    g_cvStuckTolerance.SetInt(999999);
}

Action Teleport_Callback(Handle hTimer) {
    static int iAttempt[MAXPLAYERS + 1];

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i) || !IsSafeToTeleport(i)) {
            iAttempt[i] = 0;
            continue;
        }

        if (!EntityStuckLast(i) || !IsPlayerStuck(i)) {
            iAttempt[i] = 0;
            continue;
        }

        if (iAttempt[i] >= 3) {
            SDK_WarpToValidPosition(i);
            iAttempt[i] = 0;
            continue;
        }

        FixPlayerPosition(i);
        iAttempt[i]++;
    }

    return Plugin_Continue;
}

void FixPlayerPosition(int iClient) {
    float fPosZ   = -50.0;
    float fRadius = 0.0;
    while (fPosZ <= MAX_TELEPORT_RANGE && !TryFixPosition(iClient, fRadius, fPosZ)) {
        fRadius += 2.0;
        fPosZ   += 2.0;
    }
}

bool TryFixPosition(int iClient, float fRadius, float fPosZ) {
    float vOrigin[3];
    GetClientAbsOrigin(iClient, vOrigin);

    float vAng[3];
    GetClientEyeAngles(iClient, vAng);

    float vPos[3];
    vPos[2] = vOrigin[2] + fPosZ;

    float fAngDegree = -180.0;
    while (fAngDegree < 180.0) {
        vPos[0] = vOrigin[0] + fRadius * Cosine(fAngDegree * FLOAT_PI / 180.0);
        vPos[1] = vOrigin[1] + fRadius * Sine(fAngDegree * FLOAT_PI / 180.0);

        TeleportEntity(iClient, vPos, vAng, NULL_VECTOR);

        if (!IsPlayerStuck(iClient) && GetDistanceToFloor(iClient) <= 240.0)
            return true;

        fAngDegree += 10.0;
    }

    TeleportEntity(iClient, vOrigin, vAng, NULL_VECTOR);
    return false;
}

float GetDistanceToFloor(int iClient) {
    static const float vDownToFloor[3] = {90.0, 0.0, 0.0};

    float vOrigin[3];
    GetClientEyePosition(iClient, vOrigin);

    Handle hTrace = TR_TraceRayFilterEx(vOrigin, vDownToFloor, MASK_PLAYERSOLID, RayType_Infinite, TraceEntityFilterSolid);
    if (TR_DidHit(hTrace)) {
        float vFloorPoint[3];
        TR_GetEndPosition(vFloorPoint, hTrace);
        delete hTrace;
        return (vOrigin[2] - vFloorPoint[2]);
    }

    delete hTrace;
    return 999999.0;
}

bool IsPlayerStuck(int iClient) {
    float vMin[3];
    GetEntPropVector(iClient, Prop_Send, "m_vecMins", vMin);

    float vMax[3];
    GetEntPropVector(iClient, Prop_Send, "m_vecMaxs", vMax);

    float vOrigin[3];
    GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", vOrigin);

    Handle hTrace = TR_TraceHullFilterEx(vOrigin, vOrigin, vMin, vMax, MASK_PLAYERSOLID, TraceEntityFilterSolid);
    bool bHit = TR_DidHit(hTrace);
    delete hTrace;
    return bHit;
}

bool TraceEntityFilterSolid(int iEnt, int iMask) {
    if (iEnt > 0 && iEnt <= MaxClients)
        return false;

    int iCollisionType;
    if (iEnt >= 0 && IsValidEdict(iEnt) && IsValidEntity(iEnt))
        iCollisionType = GetEntProp(iEnt, Prop_Send, "m_CollisionGroup");

    if (iCollisionType == 1 || iCollisionType == 5 || iCollisionType == 11)
        return false;

    return true;
}

bool IsSafeToTeleport(int iClient) {
    if (!IsPlayerAlive(iClient))
        return false;

    if (GetEntProp(iClient, Prop_Send, "m_jockeyAttacker") > 0)
        return false;

    if (GetEntProp(iClient, Prop_Send, "m_jockeyVictim") > 0)
        return false;

    if (GetEntProp(iClient, Prop_Send, "m_pounceAttacker") > 0)
        return false;

    if (GetEntProp(iClient, Prop_Send, "m_pounceVictim") > 0)
        return false;

    if (GetEntProp(iClient, Prop_Send, "m_carryAttacker") > 0)
        return false;

    if (GetEntProp(iClient, Prop_Send, "m_carryVictim") > 0)
        return false;

    if (GetEntProp(iClient, Prop_Send, "m_pummelAttacker") > 0)
        return false;

    if (GetEntProp(iClient, Prop_Send, "m_pummelVictim") > 0)
        return false;

    if (GetEntProp(iClient, Prop_Send, "m_isHangingFromLedge") == 1)
        return false;

    if (GetEntProp(iClient, Prop_Send, "m_isIncapacitated") == 1)
        return false;

    return true;
}

int EntityStuckLast(int iEntity) {
    return GetEntProp(iEntity, Prop_Data, "m_StuckLast");
}