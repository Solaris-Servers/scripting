#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>

#define GAMEDATA_FILE  "l4d_tongue_bend_fix"
#define KEY_UPDATEBEND "CTongue::UpdateBend"

StringMap g_smExceptions;
ConVar    g_cvExceptions;

enum {
    eExceptionDoor,
    eExceptionCarryable
};

public Plugin myinfo = {
    name        = "[L4D & 2] Tongue Bend Fix",
    author      = "Forgetest",
    description = "Fix unexpected tongue breaks for \"bending too many times\".",
    version     = "3.3",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

public void OnPluginStart() {
    GameData gmConf = new GameData(GAMEDATA_FILE);
    if (!gmConf) SetFailState("Missing gamedata \""...GAMEDATA_FILE..."\"");
    DynamicDetour dhDetour = DynamicDetour.FromConf(gmConf, KEY_UPDATEBEND);
    if (!dhDetour) SetFailState("Missing signature \""...KEY_UPDATEBEND..."\"");
    if (!dhDetour.Enable(Hook_Post, DTR_OnUpdateBend_Post)) SetFailState("Failed to post-detour \""...KEY_UPDATEBEND..."\"");
    delete gmConf;

    g_cvExceptions = CreateConVar(
    "tongue_bend_exception_flag", "3",
    "Flag to allow bending on certain types of entities. 1 = Doors, 2 = Carryable, 3 = All, 0 = Disable",
    FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0, true, 3.0);

    g_smExceptions = new StringMap();
    g_smExceptions.SetValue("prop_door_rotating",   eExceptionDoor);
    g_smExceptions.SetValue("weapon_gascan",        eExceptionCarryable);
    g_smExceptions.SetValue("weapon_propanetank",   eExceptionCarryable);
    g_smExceptions.SetValue("weapon_cola_bottles",  eExceptionCarryable);
    g_smExceptions.SetValue("weapon_fireworkcrate", eExceptionCarryable);
    g_smExceptions.SetValue("weapon_gnome",         eExceptionCarryable);
    g_smExceptions.SetValue("weapon_oxygentank",    eExceptionCarryable);
}

MRESReturn DTR_OnUpdateBend_Post(int pThis, DHookReturn hReturn) {
    int iOwner = GetEntPropEnt(pThis, Prop_Send, "m_owner");

    float vTonguePos[3];
    GetClientEyePosition(iOwner, vTonguePos);

    int iVictim = GetEntPropEnt(iOwner, Prop_Send, "m_tongueVictim");

    float vVictimPos[3];
    GetAbsOrigin(iVictim, vVictimPos, true);

    static int iOffs_m_BendPositions = -1;
    if (iOffs_m_BendPositions == -1) iOffs_m_BendPositions = FindSendPropInfo("CTongue", "m_bendPositions");

    float vFirstBendPos[3];
    GetEntDataVector(pThis, iOffs_m_BendPositions, vFirstBendPos);

    float vLastBendPos[3];
    GetEntDataVector(pThis, iOffs_m_BendPositions + 9 * 12, vLastBendPos);

    if (TestBendOnException(vTonguePos, vFirstBendPos) || TestBendOnException(vLastBendPos, vVictimPos) || TestBendOnException(vTonguePos, vVictimPos)) {
        hReturn.Value = 1;
        return MRES_Supercede;
    }
    // should be bugged, ignore now.
    if (GetEntProp(pThis, Prop_Send, "m_bendPointCount") > 9) {
        hReturn.Value = 0;
        return MRES_Supercede;
    }
    return MRES_Ignored;
}

bool TestBendOnException(const float vStart[3], const float vEnd[3]) {
    Handle hTrace = TR_TraceRayFilterEx(vStart, vEnd, MASK_VISIBLE_AND_NPCS|CONTENTS_WINDOW, RayType_EndPoint, TraceFilter_NoNPCsOrPlayer);
    if (TR_DidHit(hTrace)) {
        int i = TR_GetEntityIndex(hTrace);
        char szClassName[64];
        GetEntityClassname(i, szClassName, sizeof(szClassName));
        if (g_smExceptions.GetValue(szClassName, i) && (g_cvExceptions.IntValue & i)) {
            delete hTrace;
            return true;
        }
    }
    delete hTrace;
    return false;
}

bool TraceFilter_NoNPCsOrPlayer(int iEntity, int iContentsMask) {
    return iEntity > MaxClients;
}

// Credit to LuxLuma, from [left4dhooks_lux_library.inc]
/**
 * Get an entity's world space origin.
 * Note: Not all entities may support "CollisionProperty" for getting the center.
 * (https://github.com/LuxLuma/l4d2_structs/blob/master/collision_property.h)
 *
 * @param iEntity       Entity index to get origin of.
 * @param fVecOrigin    Vector to store origin in.
 * @param bCenter       True to get world space center, false otherwise.
 *
 * @error           Invalid entity index.
 **/
stock void GetAbsOrigin(int iEntity, float fVecOrigin[3], bool bCenter = false) {
    GetEntPropVector(iEntity, Prop_Data, "m_vecAbsOrigin", fVecOrigin);
    if (!bCenter) return;
    float fVecMins[3];
    GetEntPropVector(iEntity, Prop_Send, "m_vecMins", fVecMins);
    float fVecMaxs[3];
    GetEntPropVector(iEntity, Prop_Send, "m_vecMaxs", fVecMaxs);
    fVecOrigin[0] += (fVecMins[0] + fVecMaxs[0]) * 0.5;
    fVecOrigin[1] += (fVecMins[1] + fVecMaxs[1]) * 0.5;
    fVecOrigin[2] += (fVecMins[2] + fVecMaxs[2]) * 0.5;
}