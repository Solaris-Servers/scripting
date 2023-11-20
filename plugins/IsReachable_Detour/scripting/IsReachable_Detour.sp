#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>

#define GAMEDATA "IsReachable_Detour"

DynamicDetour g_dhDetour;

public Plugin myinfo = {
    name        = "[L4D2][NIX] IsReachable_Detour",
    author      = "Dragokas",
    description = "Fixing the valve crash with null pointer dereference in SurvivorBot::IsReachable(CBaseEntity *)",
    version     = "1.0",
    url         = "https://github.com/ValveSoftware/Source-1-Games/issues/3432"
}

public void OnPluginStart() {
    GameData gmConf = new GameData(GAMEDATA);
    if (gmConf == null) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);
    SetupDetour(gmConf);
    delete gmConf;
}

public void OnPluginEnd() {
    if (!DHookDisableDetour(g_dhDetour, false, IsReachable))
        SetFailState("Failed to disable detour \"SurvivorBot::IsReachable\".");
}

void SetupDetour(GameData gmConf) {
    g_dhDetour = DynamicDetour.FromConf(gmConf, "SurvivorBot::IsReachable");
    if (!g_dhDetour) SetFailState("Failed to find \"SurvivorBot::IsReachable\" signature.");
    if (!DHookEnableDetour(g_dhDetour, false, IsReachable))
        SetFailState("Failed to start detour \"SurvivorBot::IsReachable\".");
}

public MRESReturn IsReachable(Handle hReturn, Handle hParams) {
    int iPtr = DHookGetParam(hParams, 1);
    if (iPtr == 0) {
        DHookSetReturn(hReturn, 0);
        return MRES_Supercede;
    }
    return MRES_Ignored;
}