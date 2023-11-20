#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <collisionhook>
#include <sourcescramble>
#include <dhooks>

#define GAMEDATA_FILE               "l4d2_tongue_block_fix"

#define KEY_ONUPDATEEXTENDINGSTATE  "CTongue::OnUpdateExtendingState"
#define KEY_UPDATETONGUETARGET      "CTongue::UpdateTongueTarget"
#define KEY_ISTARGETVISIBLE         "TongueTargetScan<CTerrorPlayer>::IsTargetVisible"
#define KEY_SETPASSENTITY           "CTraceFilterSimple::SetPassEntity"

#define PATCH_ARG                   "__AddEntityToIgnore_argpatch"
#define PATCH_PASSENT               "__TraceFilterTongue_passentpatch"
#define PATCH_DUMMY                 "__AddEntityToIgnore_dummypatch"
#define PATCH_COOP_DUMMY            "__AddEntityToIgnore_noncompetitive_dummypatch"

DynamicDetour g_hDetour;

int g_iTipFlag;
int g_iFlyFlag;

enum {
    TIP_GENERIC = (1 << 0),
    TIP_TANK    = (1 << 1),
};

enum {
    FLY_GENERIC  = (1 << 0),
    FLY_TANK     = (1 << 1),
    FLY_SURVIVOR = (1 << 2),
};

public Plugin myinfo =  {
    name        = "[L4D2] Tongue Block Fix",
    author      = "Forgetest",
    description = "Fix infected teammate blocking tongue chasing.",
    version     = "1.4",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    if (GetEngineVersion() != Engine_Left4Dead2) {
        strcopy(szError, iErrMax, "Plugin supports Left 4 Dead 2 only.");
        return APLRes_SilentFailure;
    }

    return APLRes_Success;
}

public void OnPluginStart() {
    InitGameData();

    ConVar cv = CreateConVar(
    "tongue_tip_through_teammate", "0",
    "Whether smoker can shoot his tongue through his teammates. 1 = Through generic SIs, 2 = Through Tank, 3 = All, 0 = Disabled",
    FCVAR_SPONLY, true, 0.0, true, 3.0);
    CvarChg_TipThroughTeammate(cv, "", "");
    cv.AddChangeHook(CvarChg_TipThroughTeammate);

    cv = CreateConVar(
    "tongue_fly_through_teammate", "5",
    "Whether tongue can go through his teammates once shot. 1 = Through generic SIs, 2 = Through Tank, 4 = Through Survivors, 7 = All, 0 = Disabled",
    FCVAR_SPONLY, true, 0.0, true, 7.0);
    CvarChg_FlyThroughTeammate(cv, "", "");
    cv.AddChangeHook(CvarChg_FlyThroughTeammate);
}

void InitGameData() {
    GameData gmConf = new GameData(GAMEDATA_FILE);
    if (!gmConf) SetFailState("Missing gamedata \""...GAMEDATA_FILE..."\"");

    Address pfnSetPassEntity = gmConf.GetAddress(KEY_SETPASSENTITY);
    if (pfnSetPassEntity == Address_Null)
        SetFailState("Failed to get address of \""...KEY_SETPASSENTITY..."\"");

    CreateEnabledPatch(gmConf, KEY_ONUPDATEEXTENDINGSTATE...PATCH_ARG);
    CreateEnabledPatch(gmConf, KEY_ONUPDATEEXTENDINGSTATE...PATCH_PASSENT);

    MemoryPatch mPatch = CreateEnabledPatch(gmConf, KEY_ONUPDATEEXTENDINGSTATE...PATCH_DUMMY);
    PatchNearJump(0xE8, mPatch.Address, pfnSetPassEntity);

    mPatch = CreateEnabledPatch(gmConf, KEY_ONUPDATEEXTENDINGSTATE...PATCH_COOP_DUMMY);
    PatchNearJump(0xE8, mPatch.Address, pfnSetPassEntity);

    g_hDetour = DynamicDetour.FromConf(gmConf, KEY_UPDATETONGUETARGET);
    if (!g_hDetour) SetFailState("Missing detour setup \""...KEY_UPDATETONGUETARGET..."\"");

    delete gmConf;
}

void CvarChg_TipThroughTeammate(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iTipFlag = cv.IntValue;
    ToggleDetour(g_iTipFlag > 0);
}

void CvarChg_FlyThroughTeammate(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iFlyFlag = cv.IntValue;
}

void ToggleDetour(bool bEnable) {
    static bool bEnabled = false;
    if (bEnable && !bEnabled) {
        if (!g_hDetour.Enable(Hook_Pre, DTR_OnUpdateTongueTarget))
            SetFailState("Failed to pre-detour \""...KEY_UPDATETONGUETARGET..."\"");
        if (!g_hDetour.Enable(Hook_Post, DTR_OnUpdateTongueTarget_Post))
            SetFailState("Failed to post-detour \""...KEY_UPDATETONGUETARGET..."\"");
        bEnabled = true;
    } else if (!bEnable && bEnabled) {
        if (!g_hDetour.Disable(Hook_Pre, DTR_OnUpdateTongueTarget))
            SetFailState("Failed to remove pre-detour \""...KEY_UPDATETONGUETARGET..."\"");
        if (!g_hDetour.Disable(Hook_Post, DTR_OnUpdateTongueTarget_Post))
            SetFailState("Failed to remove post-detour \""...KEY_UPDATETONGUETARGET..."\"");
        bEnabled = false;
    }
}

bool g_bUpdateTongueTarget = false;
MRESReturn DTR_OnUpdateTongueTarget(int pThis) {
    g_bUpdateTongueTarget = true;
    return MRES_Ignored;
}

MRESReturn DTR_OnUpdateTongueTarget_Post(int pThis) {
    g_bUpdateTongueTarget = false;
    return MRES_Ignored;
}

public Action CH_PassFilter(int iTouch, int iPass, bool &bResult) {
    if (iTouch <= 0 || iTouch > MaxClients || !IsClientInGame(iTouch))
        return Plugin_Continue;

    if (!g_bUpdateTongueTarget) {
        if (iPass <= MaxClients)
            return Plugin_Continue;

        static char szCls[64];
        if (!GetEdictClassname(iPass, szCls, sizeof(szCls)))
            return Plugin_Continue;

        if (strcmp(szCls, "ability_tongue") != 0)
            return Plugin_Continue;

        if (iTouch == GetEntPropEnt(iPass, Prop_Send, "m_owner")) // probably won't happen
            return Plugin_Continue;

        if (GetClientTeam(iTouch) == 3) {
            if (GetEntProp(iTouch, Prop_Send, "m_zombieClass") == 8) {
                if (~g_iFlyFlag & FLY_TANK)
                    return Plugin_Continue;
            } else if (~g_iFlyFlag & FLY_GENERIC) {
                return Plugin_Continue;
            }
        } else {
            if (~g_iFlyFlag & FLY_SURVIVOR)
                return Plugin_Continue;
        }
    } else {
        if (iPass <= 0 || iPass > MaxClients)
            return Plugin_Continue;

        if (!IsClientInGame(iPass))
            return Plugin_Continue;

        if (GetClientTeam(iTouch) != 3)
            return Plugin_Continue;

        if (GetClientTeam(iPass) != 3 || GetEntProp(iPass, Prop_Send, "m_zombieClass") != 1)
            return Plugin_Continue;

        if (GetEntProp(iTouch, Prop_Send, "m_zombieClass") == 8) {
            if (~g_iTipFlag & TIP_TANK)
                return Plugin_Continue;
        } else if (~g_iTipFlag & TIP_GENERIC) {
            return Plugin_Continue;
        }
    }

    bResult = false;
    return Plugin_Handled;
}

MemoryPatch CreateEnabledPatch(GameData gmConf, const char[] szName) {
    MemoryPatch mPatch = MemoryPatch.CreateFromConf(gmConf, szName);
    if (!mPatch.Enable()) SetFailState("Failed to patch \"%s\"", szName);
    return mPatch;
}

void PatchNearJump(int iInstruction, Address pSrc, Address pDest) {
    StoreToAddress(pSrc, iInstruction, NumberType_Int8);
    StoreToAddress(pSrc + view_as<Address>(1), view_as<int>(pDest - pSrc) - 5, NumberType_Int32);
}