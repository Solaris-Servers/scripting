#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>
#include <left4dhooks>

#define GAMEDATA               "boomer_horde_equalizer"
#define KEY_WANDERERSCONDITION "WanderersCondition"

ConVar
    g_cvPatchEnable,
    g_cvZMobSpawnMaxSize;

MemoryPatch
    g_hPatch_WanderersCondition;

public Plugin myinfo = {
    name        = "Boomer Horde Equalizer",
    author      = "Visor, Jacob, A1m`",
    version     = "1.5",
    description = "Fixes boomer hordes being different sizes based on wandering commons.",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart() {
    InitGameData();
    g_cvPatchEnable = CreateConVar(
    "boomer_horde_equalizer", "1",
    "Fix boomer hordes being different sizes based on wandering commons. (1 - enable, 0 - disable)",
    FCVAR_NONE, true, 0.0, true, 1.0);
    CheckPatch(g_cvPatchEnable.BoolValue);
    g_cvPatchEnable.AddChangeHook(Cvars_Changed);
    g_cvZMobSpawnMaxSize = FindConVar("z_mob_spawn_max_size");
}

void InitGameData() {
    GameData gmData = new GameData(GAMEDATA);
    if (!gmData) {
        SetFailState("Gamedata '%s.txt' missing or corrupt.", GAMEDATA);
    }
    g_hPatch_WanderersCondition = MemoryPatch.CreateFromConf(gmData, KEY_WANDERERSCONDITION);
    if (g_hPatch_WanderersCondition == null || !g_hPatch_WanderersCondition.Validate()) {
        SetFailState("Failed to validate MemoryPatch \"" ... KEY_WANDERERSCONDITION ... "\"");
    }
    delete gmData;
}

public Action L4D_OnSpawnITMob(int &iAmount) {
    iAmount = g_cvZMobSpawnMaxSize.IntValue;
    return Plugin_Changed;
}

public void Cvars_Changed(ConVar cv, const char[] sOldValue, const char[] sNewValue) {
    CheckPatch(cv.BoolValue);
}

public void OnPluginEnd() {
    CheckPatch(false);
}

void CheckPatch(bool bIsPatch) {
    static bool bIsPatched = false;
    if (bIsPatch) {
        if (bIsPatched) {
            PrintToServer("[" ... GAMEDATA ... "] Plugin already enabled");
            return;
        }
        if (!g_hPatch_WanderersCondition.Enable()) {
            SetFailState("[" ... GAMEDATA ... "] Failed to enable patch '" ... KEY_WANDERERSCONDITION ... "'.");
        }
        // GAMEDATA == plugin name
        PrintToServer("[" ... GAMEDATA ... "] Successfully patched '" ... KEY_WANDERERSCONDITION ... "'.");
        bIsPatched = true;
    } else {
        if (!bIsPatched) {
            PrintToServer("[" ... GAMEDATA ... "] Plugin already disabled");
            return;
        }
        g_hPatch_WanderersCondition.Disable();
        bIsPatched = false;
    }
}