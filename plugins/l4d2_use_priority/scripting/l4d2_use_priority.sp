#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>

#define GAMEDATA "l4d2_use_priority"

// ====================================================================================================
//                  PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo = {
    name        = "[L4D2] Use Priority Patch",
    author      = "SilverShot",
    description = "Patches CBaseEntity::GetUsePriority preventing attached entities blocking +USE.",
    version     = "2.3",
    url         = "https://forums.alliedmods.net/showthread.php?t=327511"
}

public void OnPluginStart() {
    // ====================================================================================================
    // Detours
    // ====================================================================================================
    GameData gmData = new GameData(GAMEDATA);
    if (gmData == null) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);
    Handle hDetour = DHookCreateFromConf(gmData, "CBaseEntity::GetUsePriority");
    if (!hDetour) SetFailState("Failed to find \"CBaseEntity::GetUsePriority\" signature.");
    if (!DHookEnableDetour(hDetour, false, GetUsePriority_Pre))
        SetFailState("Failed to detour \"CBaseEntity::GetUsePriority\" pre.");
    delete hDetour;
    delete gmData;
}

// ====================================================================================================
//                  DETOURS
// ====================================================================================================
public MRESReturn GetUsePriority_Pre(int pThis, Handle hReturn, Handle hParams) {
    if (pThis == -1) return MRES_Ignored;
    int iParent = GetEntPropEnt(pThis, Prop_Send, "moveparent");
    // Is attached to something attached to clients?
    while (iParent > MaxClients) {
        iParent = GetEntPropEnt(iParent, Prop_Send, "moveparent");
    }
    // Don't allow using
    if (iParent > 0 && iParent <= MaxClients) {
        DHookSetReturn(hReturn, 0);
        return MRES_Supercede;
    }
    return MRES_Ignored;
}