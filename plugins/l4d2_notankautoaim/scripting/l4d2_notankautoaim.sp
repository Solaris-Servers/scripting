#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>

#define GAMEDATA "l4d2_notankautoaim"

ConVar
    g_cvPatchEnable;

MemoryPatch
    hPatch_ClawTargetScan;

public Plugin myinfo = {
    name        = "L4D2 Tank Claw Fix",
    author      = "Jahze(patch data), Visor(SM), A1m`",
    description = "Removes the Tank claw's undocumented auto-aiming ability",
    version     = "0.5",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework/"
}

public void OnPluginStart() {
    InitGameData();
    g_cvPatchEnable = CreateConVar(
    "l4d2_notankautoaim", "1",
    "Remove the Tank claw's undocumented auto-aiming ability (1 - enable, 0 - disable)",
    FCVAR_NONE, true, 0.0, true, 1.0);
    CheckPatch(g_cvPatchEnable.BoolValue);
    g_cvPatchEnable.AddChangeHook(Cvars_Changed);
}

void InitGameData() {
    GameData gmData = new GameData(GAMEDATA);
    if (!gmData) {
        SetFailState("Gamedata '%s.txt' missing or corrupt", GAMEDATA);
    }
    hPatch_ClawTargetScan = MemoryPatch.CreateFromConf(gmData, "ClawTargetScan");
    if (hPatch_ClawTargetScan == null || !hPatch_ClawTargetScan.Validate()) {
        SetFailState("Failed to validate MemoryPatch 'ClawTargetScan'.");
    }
    delete gmData;
}

public void Cvars_Changed(ConVar cv, const char[] oldValue, const char[] newValue) {
    CheckPatch(cv.BoolValue);
}

public void OnPluginEnd() {
    CheckPatch(false);
}

void CheckPatch(bool IsPatch) {
    static bool IsPatched = false;
    if (IsPatch) {
        if (IsPatched) {
            PrintToServer("[" ... GAMEDATA ... "] Plugin already enabled");
            return;
        }
        if (!hPatch_ClawTargetScan.Enable()) {
            SetFailState("[" ... GAMEDATA ... "] Failed to enable patch 'ClawTargetScan'");
        }
        // GAMEDATA == plugin name
        PrintToServer("[" ... GAMEDATA ... "] Successfully patched 'ClawTargetScan'.");
        IsPatched = true;
    } else {
        if (!IsPatched) {
            PrintToServer("[" ... GAMEDATA ... "] Plugin already disabled");
            return;
        }
        hPatch_ClawTargetScan.Disable();
        IsPatched = false;
    }
}