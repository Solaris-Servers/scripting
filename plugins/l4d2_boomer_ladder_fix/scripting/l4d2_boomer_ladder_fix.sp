#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sourcescramble>

MemoryPatch g_mPatchLadder;

public Plugin myinfo = {
    name        = "[L4D2] Boomer Ladder Fix",
    author      = "BHaType",
    description = "Fixes boomer auto teleport whenever hes close enough to ladder",
    version     = "0.1",
    url         = "https://forums.alliedmods.net/showthread.php?p=2768534"
};

public void OnPluginStart() {
    GameData gmData = new GameData("l4d2_boomer_ladder_fix");
    g_mPatchLadder = MemoryPatch.CreateFromConf(gmData, "CTerrorGameMovement::CheckForLadders");
    delete gmData;
    Patch(true);
}

void Patch(bool bEnable) {
    static bool bEnabled;
    if (bEnabled && !bEnable) {
        g_mPatchLadder.Disable();
        bEnabled = false;
    } else if (!bEnabled && bEnable) {
        g_mPatchLadder.Enable();
        bEnabled = true;
    }
}