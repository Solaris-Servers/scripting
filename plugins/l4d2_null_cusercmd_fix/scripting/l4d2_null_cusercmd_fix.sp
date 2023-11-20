#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>

public Plugin myinfo = {
    name        = "L4D2 Lag Compensation Null CUserCmd fix",
    author      = "fdxx",
    description = "Prevent crash: CLagCompensationManager::StartLagCompensation with NULL CUserCmd!!!",
    version     = "0.2",
    url         = "https://github.com/fdxx/l4d2_plugins"
}

public void OnPluginStart() {
    Init();
}

void Init() {
    GameData gmConf = new GameData("l4d2_null_cusercmd_fix");
    if (gmConf == null) SetFailState("Failed to load \"l4d2_null_cusercmd_fix.txt\" gamedata.");

    MemoryPatch mPatch = MemoryPatch.CreateFromConf(gmConf, "CLagCompensationManager::StartLagCompensation");
    if (!mPatch.Validate()) SetFailState("Verify patch failed.");
    if (!mPatch.Enable())   SetFailState("Enable patch failed.");
}