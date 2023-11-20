#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2util/stocks>
#include <l4d2util/weapons>

#undef REQUIRE_PLUGIN
#include <l4d2_lagcomp_manager>
#define REQUIRE_PLUGIN

#define ENTITY_MAX_NAME_LENGTH  64

ConVar g_cvSqRange;
float  g_fSqRange;

ConVar g_cvLOSClear;
bool   g_bLOSClear;

ConVar g_cvLagComp;
bool   g_bLagComp;

bool  g_bLateLoad;
bool  g_bLagCompAvailable;
int   g_iPasser = -1;

public Plugin myinfo = {
    name        = "Easier Pill Passer",
    author      = "CanadaRox, A1m`, Forgetest",
    description = "Lets players pass pills and adrenaline with +reload when they are holding one of those items",
    version     = "1.6.1",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    if (GetEngineVersion() != Engine_Left4Dead2) {
        strcopy(szError, iErrMax, "Plugin supports L4D2 only");
        return APLRes_SilentFailure;
    }

    g_bLateLoad = bLate;
    return APLRes_Success;
}

public void OnPluginStart() {
    g_cvSqRange = CreateConVar(
    "pill_passer_range", "274.0",
    "Max distance to transfer pills between players.",
    FCVAR_CHEAT, true, 0.0, false, 0.0);
    float fVal = g_cvSqRange.FloatValue;
    g_fSqRange = fVal * fVal;
    g_cvSqRange.AddChangeHook(CvChg_Range);

    g_cvLOSClear = CreateConVar(
    "pill_passer_los_clear", "0",
    "Whether to require LOS clear when passing pills.",
    FCVAR_CHEAT, true, 0.0, true, 1.0);
    g_bLOSClear = g_cvLOSClear.BoolValue;
    g_cvLOSClear.AddChangeHook(CvChg_LOSClear);

    g_cvLagComp = CreateConVar(
    "pill_passer_lag_compensate", "1",
    "Whether to enable lag compensation when passing pills.",
    FCVAR_CHEAT, true, 0.0, true, 1.0);
    g_bLagComp = g_cvLagComp.BoolValue;
    g_cvLagComp.AddChangeHook(CvChg_LagComp);

    if (g_bLateLoad) {
        for (int i = 1; i <= MaxClients; ++i) {
            if (!IsClientInGame(i))
                continue;

            OnClientPutInServer(i);
        }
    }
}

public void OnAllPluginsLoaded() {
    g_bLagCompAvailable = LibraryExists("l4d2_lagcomp_manager");
}

public void OnLibraryAdded(const char[] szName) {
    if (strcmp(szName, "l4d2_lagcomp_manager") == 0)
        g_bLagCompAvailable = true;
}

public void OnLibraryRemoved(const char[] szName) {
    if (strcmp(szName, "l4d2_lagcomp_manager") == 0)
        g_bLagCompAvailable = false;
}

void CvChg_Range(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    float fVal = g_cvSqRange.FloatValue;
    g_fSqRange = fVal * fVal;
}

void CvChg_LOSClear(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bLOSClear = g_cvLOSClear.BoolValue;
}

void CvChg_LagComp(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bLagComp = g_cvLagComp.BoolValue;
}

public Action L4D2_LagComp_OnWantsLagCompensationOnEntity(int iClient, int iEnt, bool &bResult, int iButtons, int iImpulse) {
    if (iClient != g_iPasser)
        return Plugin_Continue;

    if (iEnt <= 0 || iEnt > MaxClients || !IsClientInGame(iEnt))
        return Plugin_Continue;

    if (GetClientTeam(iEnt) != 2)
        return Plugin_Continue;

    if (!IsPlayerAlive(iEnt))
        return Plugin_Continue;

    bResult = true;
    return Plugin_Handled;
}

public void OnClientPutInServer(int iClient) {
    if (IsFakeClient(iClient))
        return;

    SDKHook(iClient, SDKHook_PostThinkPost, SDK_OnPostThink_Post);
}

void SDK_OnPostThink_Post(int iClient) {
    int iButtons = GetClientButtons(iClient);
    if (iButtons & IN_RELOAD && !(iButtons & IN_USE)) {
        char szWeaponName[ENTITY_MAX_NAME_LENGTH];
        GetClientWeapon(iClient, szWeaponName, sizeof(szWeaponName));

        int iWeapId = WeaponNameToId(szWeaponName);
        if (iWeapId == WEPID_PAIN_PILLS || iWeapId == WEPID_ADRENALINE) {
            if (g_bLagCompAvailable && g_bLagComp) {
                g_iPasser = iClient; // better detection in "WantsLagCompensationOnEntity"
                L4D2_LagComp_StartLagCompensation(iClient, LAG_COMPENSATE_BOUNDS);
            }

            int iTarget = -1;
            if (g_bLOSClear) {
                iTarget = GetClientAimTargetLOS(iClient, true);
            } else {
                iTarget = GetClientAimTarget(iClient, true);
            }

            if (iTarget > 0 && GetClientTeam(iTarget) == L4D2Team_Survivor && !IsPlayerIncap(iTarget)) {
                int iTargetWeaponIdx = GetPlayerWeaponSlot(iTarget, L4D2WeaponSlot_LightHealthItem);
                if (iTargetWeaponIdx == -1) {
                    float vClientOrigin[3];
                    GetClientAbsOrigin(iClient, vClientOrigin);

                    float vTargetOrigin[3];
                    GetClientAbsOrigin(iTarget, vTargetOrigin);

                    if (GetVectorDistance(vClientOrigin, vTargetOrigin, true) < g_fSqRange) {
                        // Remove item
                        int iGiverWeaponIdx = GetPlayerWeaponSlot(iClient, L4D2WeaponSlot_LightHealthItem);
                        RemovePlayerItem(iClient, iGiverWeaponIdx);

                        RemoveEntity(iGiverWeaponIdx);
                        iGiverWeaponIdx = GivePlayerItem(iTarget, szWeaponName); // Fixed only in the latest version of sourcemod 1.11

                        // If the entity was sucessfully given to the player
                        if (iGiverWeaponIdx > 0) {
                            // Call Event
                            Event eEvent = CreateEvent("weapon_given");
                            SetEventInt(eEvent, "userid",      GetClientUserId(iTarget));
                            SetEventInt(eEvent, "giver",       GetClientUserId(iClient));
                            SetEventInt(eEvent, "weapon",      iWeapId);
                            SetEventInt(eEvent, "weaponentid", iGiverWeaponIdx);
                            FireEvent(eEvent);
                        }
                    }
                }
            }

            if (g_bLagCompAvailable && g_bLagComp) {
                L4D2_LagComp_FinishLagCompensation(iClient);
                g_iPasser = -1;
            }
        }
    }
}

int GetClientAimTargetLOS(int iClient, bool bOnlyClients = true) {
    float vPos[3];
    GetClientEyePosition(iClient, vPos);

    float vAng[3];
    GetClientEyeAngles(iClient, vAng);

    // "GetClientAimTarget" uses (MASK_SOLID|CONTENTS_HITBOX|CONTENTS_DEBRIS)
    static const int LOS_CLEAR_FLAGS = MASK_VISIBLE_AND_NPCS|CONTENTS_GRATE|CONTENTS_HITBOX|CONTENTS_DEBRIS;
    Handle hTrace = TR_TraceRayFilterEx(vPos, vAng, LOS_CLEAR_FLAGS, RayType_Infinite, TraceFilter_IgnoreSelf, iClient);

    int iEnt = -1;

    float vEnd[3];
    if (TR_DidHit(hTrace)) {
        iEnt = TR_GetEntityIndex(hTrace);
        TR_GetEndPosition(vEnd, hTrace);
    }

    delete hTrace;

    if (iEnt == -1)
        return -1;

    if (bOnlyClients) {
        if (iEnt <= 0 || iEnt > MaxClients)
            return -1;
    }

    return iEnt;
}

bool TraceFilter_IgnoreSelf(int iEnt, int iMask, any iData) {
    return iData != iEnt;
}

bool IsPlayerIncap(int iClient) {
    return (GetEntProp(iClient, Prop_Send, "m_isIncapacitated", 1) == 1);
}