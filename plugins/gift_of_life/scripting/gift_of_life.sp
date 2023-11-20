#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <colors>

#define PI 3.1415927
#define CHANGE 25
#define CIRCLE_PIECES 16
#define WITCHES_NUM 1
#define MAX_ATTEMPTS 3

Handle g_hGiftTouchHook;
Handle g_hSpawnGiftSDK;

ConVar g_cvGiftOfLife;
int    g_iGiftOfLife;

ConVar g_cvGiftWitchChance;
float  g_fGiftWitchChance;

ConVar g_cvGiftStuffEnabled;
bool   g_bGiftStuffEnabled;

ConVar g_cvGiftWitchSpawnRadius;
int    g_iGiftWitchSpawnRadius;

public Plugin myinfo = {
    name        = "Gift of Life!",
    description = "Gifts either give hp or spawn a witch! Admins can !spawngift to create one.",
    author      = "PP(R)TH: Dr. Gregory House, epilimic, purpletreefactory",
    version     = "1.0",
    url         = "nope.avi"
};

public void OnPluginStart() {
    PrepSDK();

    g_cvGiftOfLife = CreateConVar(
    "gift_of_life", "5",
    "Amount of perm health to gain for picking up a holiday gift!");
    g_iGiftOfLife = g_cvGiftOfLife.IntValue;
    g_cvGiftOfLife.AddChangeHook(ConVarChanged);

    g_cvGiftWitchChance = CreateConVar(
    "gift_witch_chance", "0.25",
    "Chance of a witch spawning instead of gaining health.");
    g_fGiftWitchChance = g_cvGiftWitchChance.FloatValue;
    g_cvGiftWitchChance.AddChangeHook(ConVarChanged);
    
    g_cvGiftStuffEnabled = CreateConVar(
    "gift_stuff_enabled", "1",
    "Enable giving health with gifts.");
    g_bGiftStuffEnabled = g_cvGiftStuffEnabled.BoolValue;
    g_cvGiftStuffEnabled.AddChangeHook(ConVarChanged);
    
    g_cvGiftWitchSpawnRadius = CreateConVar(
    "gift_witch_spawnradius", "100",
    "Radius of the circle in which the witch will spawn.");
    g_iGiftWitchSpawnRadius = g_cvGiftWitchSpawnRadius.IntValue;
    g_cvGiftWitchSpawnRadius.AddChangeHook(ConVarChanged);

    RegAdminCmd("sm_spawngift", Cmd_SpawnGift, ADMFLAG_KICK, "Spawn a gift!");
}

void PrepSDK() {
    GameData gmConf = new GameData("l4d2_giftstuff");
    if (!gmConf) SetFailState("Couldn't load gamedata. Exiting.");

    int iOffs = gmConf.GetOffset("MyTouch");
    g_hGiftTouchHook = DHookCreate(iOffs, HookType_Entity, ReturnType_Int, ThisPointer_Ignore, OnGiftTouched);
    DHookAddParam(g_hGiftTouchHook, HookParamType_CBaseEntity);

    StartPrepSDKCall(SDKCall_Static);
    PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, "SpawnGift");
    PrepSDKCall_AddParameter(SDKType_Vector,       SDKPass_ByRef);
    PrepSDKCall_AddParameter(SDKType_QAngle,       SDKPass_ByRef);
    PrepSDKCall_AddParameter(SDKType_QAngle,       SDKPass_ByRef);
    PrepSDKCall_AddParameter(SDKType_Vector,       SDKPass_ByRef);
    PrepSDKCall_AddParameter(SDKType_CBasePlayer,  SDKPass_Pointer);
    PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
    g_hSpawnGiftSDK = EndPrepSDKCall();
}

public void OnEntityCreated(int iEnt, const char[] szClsName) {
    if (strcmp(szClsName, "holiday_gift") != 0) return;
    DHookEntity(g_hGiftTouchHook, true, iEnt);
}

public MRESReturn OnGiftTouched(int iEnt, Handle hParams, Handle hReturn) {
    if (!g_bGiftStuffEnabled) return MRES_Ignored;
    int iClient = DHookGetParam(hParams, 1);
    if (!IsFakeClient(iClient) && GetClientTeam(iClient) == 2) {
        ArrayList arrPotentialPositions = new ArrayList(1, 0);

        float fRnd            = GetURandomFloat();
        float fPieceSize      = PI * 2.0 / CIRCLE_PIECES;
        float fCirclePos      = GetRandomFloat(0.0, fPieceSize);
        float fRadiusModifier = 1.25;
        int   iLackingWitches = WITCHES_NUM - arrPotentialPositions.Length;

        float vPos[3];
        GetClientAbsOrigin(iClient, vPos);
        
        float vGoal[3];
        vGoal[2] = vPos[2] + CHANGE;

        int iAddedWitches;
        if (fRnd <= g_fGiftWitchChance) {
            int k;
            while (k < MAX_ATTEMPTS) {
                int i;
                while (i < CIRCLE_PIECES) {
                    vGoal[0] = vPos[0] + Sine(fCirclePos)   * g_iGiftWitchSpawnRadius;
                    vGoal[1] = vPos[1] + Cosine(fCirclePos) * g_iGiftWitchSpawnRadius;
                    if (IsValidWitchArea(vGoal, vPos, iClient))
                        arrPotentialPositions.Push(fCirclePos);
                    i++;
                    fCirclePos += fPieceSize;
                }

                iLackingWitches = WITCHES_NUM - arrPotentialPositions.Length;
                fRadiusModifier = 1.25;
                int l;
                while (l < iLackingWitches) {
                    int j;
                    while (arrPotentialPositions.Length > j) {
                        fCirclePos = arrPotentialPositions.Get(j, 0, false);
                        vGoal[0] = vPos[0] + Sine(fCirclePos)   * g_iGiftWitchSpawnRadius * fRadiusModifier;
                        vGoal[1] = vPos[1] + Cosine(fCirclePos) * g_iGiftWitchSpawnRadius * fRadiusModifier;
                        vGoal[2] = vPos[2] + CHANGE;
                        if (IsValidWitchArea(vGoal, vPos, iClient)) {
                            vGoal[2] -= FindOffset(vGoal);
                            int iTmpEnt = CreateEntityByName("witch", -1);
                            DispatchKeyValueVector(iTmpEnt, "origin", vGoal);
                            DispatchSpawn(iTmpEnt);
                            iAddedWitches++;
                            l++;
                            fRadiusModifier += 0.25;
                        }
                        j++;
                    }
                    l++;
                    fRadiusModifier += 0.25;
                }
                if (!(iLackingWitches - iAddedWitches < 1)) {
                    arrPotentialPositions.Clear();
                    fCirclePos = GetRandomFloat(0.0, fPieceSize);
                    k++;
                }
                int n;
                while (WITCHES_NUM - iAddedWitches > n) {
                    if (arrPotentialPositions.Length > 0) {
                        int iRnd = GetRandomInt(0, arrPotentialPositions.Length + -1);
                        fCirclePos = arrPotentialPositions.Get(iRnd, 0, false);
                        arrPotentialPositions.Erase(iRnd);
                        vGoal[0] = vPos[0] + Sine(fCirclePos) * g_iGiftWitchSpawnRadius;
                        vGoal[1] = vPos[1] + Cosine(fCirclePos) * g_iGiftWitchSpawnRadius;
                        vGoal[2] = vPos[2] + CHANGE;
                        vGoal[2] -= FindOffset(vGoal);
                        int iTmpEnt = CreateEntityByName("witch", -1);
                        DispatchKeyValueVector(iTmpEnt, "origin", vGoal);
                        DispatchSpawn(iTmpEnt);
                    }

                    n++;
                }
            }
            int j;
            while (WITCHES_NUM - iAddedWitches > j) {
                if (arrPotentialPositions.Length > 0) {
                    int iRnd = GetRandomInt(0, arrPotentialPositions.Length + -1);
                    fCirclePos = arrPotentialPositions.Get(iRnd, 0, false);
                    arrPotentialPositions.Erase(iRnd);
                    vGoal[0] = vPos[0] + Sine(fCirclePos) * g_iGiftWitchSpawnRadius;
                    vGoal[1] = vPos[1] + Cosine(fCirclePos) * g_iGiftWitchSpawnRadius;
                    vGoal[2] = vPos[2] + CHANGE;
                    vGoal[2] -= FindOffset(vGoal);
                    int iTmpEnt = CreateEntityByName("witch", -1);
                    DispatchKeyValueVector(iTmpEnt, "origin", vGoal);
                    DispatchSpawn(iTmpEnt);
                }
                j++;
            }
        } else {
            GiveLife(iClient);
        }
    }
    return MRES_Ignored;
}

void GiveLife(int iClient) {
    int iHealth = g_iGiftOfLife + GetSurvivorPermHealth(iClient);
    SetSurvivorPermHealth(iClient, iHealth);
}

int GetSurvivorPermHealth(int iClient) {
    return GetEntProp(iClient, Prop_Send, "m_iHealth");
}

void SetSurvivorPermHealth(int iClient, int iHealth) {
    SetEntProp(iClient, Prop_Send, "m_iHealth", iHealth);
}

Action Cmd_SpawnGift(int iClient, int iArgs) {
    float vPos[3];
    GetClientAbsOrigin(iClient, vPos);
    vPos[1] += 150.0;
    float vRot[3] = {0.0, ...};
    float vAng[3] = {0.0, ...};
    float vVel[3] = {0.0, ...};
    SpawnGift(vPos, vAng, vRot, vVel, iClient);
    return Plugin_Handled;
}

void SpawnGift(float vPos[3], float vAng[3], float vRot[3], float vVel[3], int iClient) {
    int iGift = SDKCall(g_hSpawnGiftSDK, vPos, vAng, vRot, vVel, iClient);
    if (iGift) DHookEntity(g_hGiftTouchHook, true, iGift);
}

void ConVarChanged(ConVar cv, char[] szOldVal, char[] szNewVal) {
    g_iGiftOfLife       = g_cvGiftOfLife.IntValue;
    g_fGiftWitchChance  = g_cvGiftWitchChance.FloatValue;
    g_bGiftStuffEnabled = g_cvGiftStuffEnabled.BoolValue;
    g_iGiftWitchSpawnRadius = g_cvGiftWitchSpawnRadius.IntValue;
}

float FindOffset(float vPos[3]) {
    float vAng[3] = {0.0, ...};
    //fAngle[0] = "\x00\x00�B";
    float vGroundPos[3];
    Handle hTrace = TR_TraceRayEx(vPos, vAng, 33570827, RayType_Infinite);
    if (TR_DidHit(hTrace)) {
        TR_GetEndPosition(vGroundPos, hTrace);
        float fDistance = GetVectorDistance(vPos, vGroundPos, false);
        delete hTrace;
        return fDistance - 10.0;
    }
    delete hTrace;
    return 0.0;
}

bool FilterPlayers(int iEnt, int iMask, any iData) {
    return iEnt > MaxClients && iEnt <= GetEntityCount();
}

bool IsValidWitchArea(float vPos[3], float vSurvPos[3], int iClient) {
    float vTmpPos[3] = {0.0, ...};
    vTmpPos[0] = vPos[0];
    vTmpPos[1] = vPos[1];
    vTmpPos[2] = vPos[2];

    float vTmpPos2[3] = {0.0, ...};
    vTmpPos2[0] = vPos[0];
    vTmpPos2[1] = vPos[1];
    vTmpPos2[2] = vPos[2];

    if (!IsValidWitchPoint(vTmpPos))
        return false;

    vTmpPos[0] = vTmpPos[0] - 13.0;
    vTmpPos[1] += 13.0;
    if (!IsValidWitchPoint(vTmpPos))
        return false;

    vTmpPos[0] = vTmpPos[0] + 26.0;
    if (!IsValidWitchPoint(vTmpPos))
        return false;

    vTmpPos[1] -= 26.0;
    if (!IsValidWitchPoint(vTmpPos))
        return false;

    vTmpPos[0] = vTmpPos[0] - 26.0;
    if (!IsValidWitchPoint(vTmpPos))
        return false;

    float vSurvEyeAng[3] = {0.0, ...};
    vSurvEyeAng[0] = vSurvPos[0];
    vSurvEyeAng[1] = vSurvPos[1];
    vSurvEyeAng[2] = vSurvPos[2] + 72.0;

    Handle hTrace = TR_TraceRayFilterEx(vSurvEyeAng, vPos, 33570827, RayType_EndPoint, FilterPlayers, iClient);
    if (TR_DidHit(hTrace)) {
        delete hTrace;
        return false;
    }

    vTmpPos2[0] = vTmpPos2[0] + 13.0;
    vTmpPos2[1] += 13.0;
    vTmpPos2[2] -= 5.0;
    vTmpPos [2] -= 5.0;
    hTrace = TR_TraceRayEx(vTmpPos, vTmpPos2, 33570827, RayType_EndPoint);
    if (TR_DidHit(hTrace)) {
        delete hTrace;
        return false;
    }

    vTmpPos2[0] = vTmpPos2[0] - 26.0;
    vTmpPos[0]  = vTmpPos[0] + 26.0;
    hTrace       = TR_TraceRayEx(vTmpPos, vTmpPos2, 33570827, RayType_EndPoint);
    if (TR_DidHit(hTrace)) {
        delete hTrace;
        return false;
    }

    delete hTrace;
    return true;
}

bool IsValidWitchPoint(float vPos[3]) {
    float vAng[3] = {0.0, ...};
    float vGroundPos[3];
    Handle hTrace = TR_TraceRayEx(vPos, vAng, 33570827, RayType_Infinite);
    if (TR_DidHit(hTrace)) {
        TR_GetEndPosition(vGroundPos, hTrace);
        float fDistance = GetVectorDistance(vPos, vGroundPos, false);
        if (fDistance < 10.0) {
            delete hTrace;
            return false;
        }
    }
    delete hTrace;
    return true;
}