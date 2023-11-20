#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>
#include <l4d2_lagcomp_manager>

#define GAMEDATA "l4d2_lagcomp_manager"

#define MAX_ENTITY_NAME_SIZE 64

ConVar
    g_hSvUnlag;

Address
    g_pLagCompensation;

Handle
    g_hLagCompAddEntity,
    g_hLagCompRemoveEntity,
    g_hStartLagComp,
    g_hFinishLagComp;

GlobalForward
    g_fwdWantsLagCompensationOnEntity;

int g_iCUserCmdSize = -1;

public Plugin myinfo = {
    name        = "L4D2 Lag Compensation Manager",
    author      = "ProdigySim, A1m`, Forgetest",
    description = "Provides lag compensation for entities in left 4 dead 2 (required enable sv_unlag).",
    version     = "1.3",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    if (GetEngineVersion() == Engine_Left4Dead2) {
        CreateNative("L4D2_LagComp_StartLagCompensation",   Native_StartLagCompensation);
        CreateNative("L4D2_LagComp_FinishLagCompensation",  Native_FinishLagCompensation);
        CreateNative("L4D2_LagComp_AddAdditionalEntity",    Native_AddAdditionalEntity);
        CreateNative("L4D2_LagComp_RemoveAdditionalEntity", Native_RemoveAdditionalEntity);

        /* forward Action L4D2_LagComp_OnWantsLagCompensationOnEntity(int client, int entity, bool &result, int buttons, int impulse); */
        g_fwdWantsLagCompensationOnEntity = new GlobalForward(
        "L4D2_LagComp_OnWantsLagCompensationOnEntity",
        ET_Event, Param_Cell, Param_Cell, Param_CellByRef, Param_Cell, Param_Cell);

        RegPluginLibrary("l4d2_lagcomp_manager");
        return APLRes_Success;
    }

    strcopy(szError, iErrMax, "Plugin supports L4D2 only.");
    return APLRes_SilentFailure;
}

any Native_StartLagCompensation(Handle hPlugin, int iNumParams) {
    int iPlayer = GetNativeCell(1);
    LagCompensationType lagCompensationType = GetNativeCell(2);

    float vPos[3];
    GetNativeArray(3, vPos, sizeof(vPos));

    float vAng[3];
    GetNativeArray(4, vAng, sizeof(vAng));

    float fWeaponRange = GetNativeCell(5);

    if (!LagComp_StartLagCompensation(iPlayer, lagCompensationType, vPos, vAng, fWeaponRange))
        ThrowNativeError(SP_ERROR_NATIVE, "CLagCompensationManager::StartLagCompensation with NULL CUserCmd!!!");

    return 1;
}

any Native_FinishLagCompensation(Handle hPlugin, int iNumParams) {
    int iPlayer = GetNativeCell(1);
    LagComp_FinishLagCompensation(iPlayer);
    return 1;
}

any Native_AddAdditionalEntity(Handle hPlugin, int iNumParams) {
    int iEnt = GetNativeCell(1);
    LagComp_AddAdditionalEntity(iEnt);
    return 1;
}

any Native_RemoveAdditionalEntity(Handle hPlugin, int iNumParams) {
    int iEnt = GetNativeCell(1);
    LagComp_RemoveAdditionalEntity(iEnt);
    return 1;
}

public void OnPluginStart() {
    GameData gmConf = LoadGameConfigFile(GAMEDATA);
    if (!gmConf) SetFailState("Gamedata '%s.txt' missing or corrupt.", GAMEDATA);

    g_pLagCompensation = gmConf.GetAddress("lagcompensation");

    StartPrepSDKCall(SDKCall_Raw);
    PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, "CLagCompensationManager_AddAdditionalEntity");
    PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
    g_hLagCompAddEntity = EndPrepSDKCall();

    StartPrepSDKCall(SDKCall_Raw);
    PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, "CLagCompensationManager_RemoveAdditionalEntity");
    PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
    g_hLagCompRemoveEntity = EndPrepSDKCall();

    StartPrepSDKCall(SDKCall_Raw);
    PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, "CLagCompensationManager_StartLagCompensation");
    PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
    PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef);
    PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
    g_hStartLagComp = EndPrepSDKCall();

    StartPrepSDKCall(SDKCall_Raw);
    PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, "CLagCompensationManager_FinishLagCompensation");
    PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
    g_hFinishLagComp = EndPrepSDKCall();

    if (g_pLagCompensation == Address_Null || g_hLagCompAddEntity == null || g_hLagCompRemoveEntity == null || g_hStartLagComp == null || g_hFinishLagComp == null)
        SetFailState("Failed to find LagComp addresses: 0x%08x, %08x, %08x, %08x, %08x", g_pLagCompensation, g_hLagCompAddEntity, g_hLagCompRemoveEntity, g_hStartLagComp, g_hFinishLagComp);

    g_iCUserCmdSize = gmConf.GetOffset("sizeof(CUserCmd)");
    if (g_iCUserCmdSize == -1) SetFailState("Missing offset \"sizeof(CUserCmd)\"");

    DynamicDetour hDetour = DynamicDetour.FromConf(gmConf, "CTerrorPlayer::WantsLagCompensationOnEntity");
    if (!hDetour) SetFailState("Missing detour setup \"CTerrorPlayer::WantsLagCompensationOnEntity\"");

    if (!hDetour.Enable(Hook_Post, DTR__CTerrorPlayer__WantsLagCompensationOnEntity_Post))
        SetFailState("Failed to detour \"CTerrorPlayer::WantsLagCompensationOnEntity\"");

    delete hDetour;
    delete gmConf;

    g_hSvUnlag = FindConVar("sv_unlag");
    g_hSvUnlag.AddChangeHook(CvChg_Unlag);
}

public void OnConfigsExecuted() {
    CheckCvar();
}

void CvChg_Unlag(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    CheckCvar();
}

void CheckCvar() {
    if (g_hSvUnlag.BoolValue)
        return;

    PrintToServer("[%s] This plugin can only work with 'sv_unlag' cvar enabled!", GAMEDATA);
    LogError("This plugin can only work with 'sv_unlag' cvar enabled!");
}

MRESReturn DTR__CTerrorPlayer__WantsLagCompensationOnEntity_Post(int iClient, DHookReturn hReturn, DHookParam hParams) {
	if (g_fwdWantsLagCompensationOnEntity.FunctionCount == 0)
		return MRES_Ignored;

	int  iEnt     = hParams.Get(1);
	bool bResult  = hReturn.Value != 0;
	int  iButtons = hParams.GetObjectVar(2, 36, ObjectValueType_Int);
	int  iImpulse = hParams.GetObjectVar(2, 40, ObjectValueType_Int) & 0x000000FF;

	Action aRet = Plugin_Continue;
	Call_StartForward(g_fwdWantsLagCompensationOnEntity);
	Call_PushCell(iClient);
	Call_PushCell(iEnt);
	Call_PushCellRef(bResult);
	Call_PushCell(iButtons);
	Call_PushCell(iImpulse);
	Call_Finish(aRet);

	if (aRet == Plugin_Handled) {
		hReturn.Value = bResult ? 1 : 0;
		return MRES_Override;
	}

	return MRES_Ignored;
}

public void OnEntityCreated(int iEnt, const char[] szClsName) {
    if (szClsName[0] != 't')
        return;

    if (strcmp(szClsName, "tank_rock") == 0)
        LagComp_AddAdditionalEntity(iEnt);
}

public void OnEntityDestroyed(int iEnt) {
    if (!IsRock(iEnt))
        return;

    LagComp_RemoveAdditionalEntity(iEnt);
}

void LagComp_AddAdditionalEntity(int iEnt) {
    SDKCall(g_hLagCompAddEntity, g_pLagCompensation, iEnt);
}

void LagComp_RemoveAdditionalEntity(int iEnt) {
    SDKCall(g_hLagCompRemoveEntity, g_pLagCompensation, iEnt);
}

bool LagComp_StartLagCompensation(int iPlayer, LagCompensationType lagCompensationType, const float vPos[3] = NULL_VECTOR, const float vAng[3] = NULL_VECTOR, float fWeaponRange = 0.0 ) {
    if (GetPlayerCurrentCommand(iPlayer) == Address_Null)
        return false;

    static float vOrigin[3];

    if (IsNullVector(vPos)) {
        vOrigin = view_as<float>({0.0, 0.0, 0.0});
    } else {
        vOrigin = vPos;
    }

    static float vAngle[3];

    if (IsNullVector(vAng)) {
        vAngle = view_as<float>({0.0, 0.0, 0.0});
    } else {
        vAngle = vAng;
    }

    SDKCall(g_hStartLagComp, g_pLagCompensation, iPlayer, lagCompensationType, vOrigin, vAngle, fWeaponRange);
    return true;
}

void LagComp_FinishLagCompensation(int iPlayer) {
    SDKCall(g_hFinishLagComp, g_pLagCompensation, iPlayer);
}

Address GetPlayerCurrentCommand(int iPlayer) {
    static int iCurrentCommandOffs = -1;
    if (iCurrentCommandOffs == -1)
        iCurrentCommandOffs = FindDataMapInfo(iPlayer, "m_hViewModel")
                                                                    + 4*2             /* CHandle<CBaseViewModel> * MAX_VIEWMODELS */
                                                                    + g_iCUserCmdSize /* m_LastCmd */;

    return view_as<Address>(GetEntData(iPlayer, iCurrentCommandOffs, 4));
}

bool IsRock(int iEnt) {
    if (!IsValidEntity(iEnt))
        return false;

    char szClsName[MAX_ENTITY_NAME_SIZE];
    GetEntityClassname(iEnt, szClsName, sizeof(szClsName));
    return (strcmp(szClsName, "tank_rock") == 0);
}