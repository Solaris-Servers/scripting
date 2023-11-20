#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>

#define GAMEDATA_FILE        "l4dvs_boss_spawn_water_fix"
#define KEY_PATCH_TANKSPAWN  "UpdateVersusBossSpawning__tankspawn_underwater_patch"
#define KEY_PATCH_WITCHSPAWN "UpdateVersusBossSpawning__witchspawn_underwater_patch"

public Plugin myinfo = {
    name        = "[L4D & 2] Boss Spawn Water Fix",
    author      = "Forgetest",
    description = "Fix boss unable to spawn on watery areas.",
    version     = "1.0",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

public void OnPluginStart() {
    GameData gmConf = new GameData(GAMEDATA_FILE);
    if (gmConf == null)
        SetFailState("Missing gamedata \"" ... GAMEDATA_FILE ... "\"");

    CreateEnabledPatch(gmConf, KEY_PATCH_TANKSPAWN);
    CreateEnabledPatch(gmConf, KEY_PATCH_WITCHSPAWN);

    delete gmConf;
}

MemoryPatch CreateEnabledPatch(GameData gmConf, const char[] szName) {
    MemoryPatch mPatch = MemoryPatch.CreateFromConf(gmConf, szName);
    if (!mPatch.Enable()) SetFailState("Failed to patch \"%s\"", szName);
    return mPatch;
}