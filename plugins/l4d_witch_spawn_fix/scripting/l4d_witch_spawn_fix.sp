#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>

#define GAMEDATA_FILE       "l4d_witch_spawn_fix"
#define KEY_PATCH_TANKCOUNT "CDirectorVersusMode::UpdateVersusBossSpawning::m_iTankCount"

MemoryPatch g_mPatchTankCount;
ConVar      g_cvFixWitchSpawn;

public Plugin myinfo = {
    name        = "[L4D & 2] Witch Spawn Fix",
    author      = "Forgetest",
    description = "Fix witch unable to spawn when tank is in play.",
    version     = "1.0",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

void InitGameData() {
    GameData gmConf = new GameData(GAMEDATA_FILE);
    if (gmConf == null) SetFailState("Missing gamedata \"" ... GAMEDATA_FILE ... "\"");
    g_mPatchTankCount = MemoryPatch.CreateFromConf(gmConf, KEY_PATCH_TANKCOUNT);
    if (!g_mPatchTankCount.Validate()) SetFailState("Failed to validate patch \"" ... KEY_PATCH_TANKCOUNT ... "\"");
    delete gmConf;
}

public void OnPluginStart() {
    InitGameData();

    g_cvFixWitchSpawn = CreateConVar(
    "sm_witch_spawn_patch", "1",
    "Fix witch spawn. 1 = Apply patch, 0 = Disable.",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_cvFixWitchSpawn.AddChangeHook(ConVarChanged_FixWitchSpawn);

    ApplyPatch(g_cvFixWitchSpawn.BoolValue);
}

void ConVarChanged_FixWitchSpawn(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    ApplyPatch(cv.BoolValue);
}

void ApplyPatch(bool bPatch) {
    static bool bPatched;
    if (bPatch && !bPatched) {
        g_mPatchTankCount.Enable();
    } else if (!bPatch && bPatched) {
        g_mPatchTankCount.Disable();
    }
    bPatched = bPatch;
}