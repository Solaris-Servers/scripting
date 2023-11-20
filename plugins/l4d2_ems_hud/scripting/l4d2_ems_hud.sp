#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sourcescramble>
#include <l4d2_ems_hud>

MemoryPatch g_mPatch_HUDFrameUpdate_Patch1;
MemoryPatch g_mPatch_HUDFrameUpdate_Patch2;

public void OnPluginStart() {
    GameData gmConf = new GameData("l4d2_ems_hud");
    if (gmConf == null)
        SetFailState("Failed to load \"l4d2_ems_hud.txt\" gamedata.");

    g_mPatch_HUDFrameUpdate_Patch1 = MemoryPatch.CreateFromConf(gmConf, "CScriptHud::HUDFrameUpdate::Ptach1");
    if (!g_mPatch_HUDFrameUpdate_Patch1.Validate())
        SetFailState("Verify patch: CScriptHud::HUDFrameUpdate::Ptach1 failed.");
    g_mPatch_HUDFrameUpdate_Patch1.Enable();

    g_mPatch_HUDFrameUpdate_Patch2 = MemoryPatch.CreateFromConf(gmConf, "CScriptHud::HUDFrameUpdate::Ptach2");
    if (!g_mPatch_HUDFrameUpdate_Patch2.Validate())
        SetFailState("Verify patch: CScriptHud::HUDFrameUpdate::Ptach2 failed.");
    g_mPatch_HUDFrameUpdate_Patch2.Enable();

    delete gmConf;
}

public void OnMapStart() {
    EnableHUD();
}