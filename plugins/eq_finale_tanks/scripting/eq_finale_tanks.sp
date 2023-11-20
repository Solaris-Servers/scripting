#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define MAP_NAME_MAX_LENGTH 64

/*
// from https://developer.valvesoftware.com/wiki/L4D2_Director_Scripts
enum {
    FINALE_GAUNTLET_1               = 0,
    FINALE_HORDE_ATTACK_1           = 1,
    FINALE_HALFTIME_BOSS            = 2,
    FINALE_GAUNTLET_2               = 3,
    FINALE_HORDE_ATTACK_2           = 4,
    FINALE_FINAL_BOSS               = 5,
    FINALE_HORDE_ESCAPE             = 6,
    FINALE_CUSTOM_PANIC             = 7,
    FINALE_CUSTOM_TANK              = 8,
    FINALE_CUSTOM_SCRIPTED          = 9,
    FINALE_CUSTOM_DELAY             = 10,
    FINALE_CUSTOM_CLEAROUT          = 11,
    FINALE_GAUNTLET_START           = 12,
    FINALE_GAUNTLET_HORDE           = 13,
    FINALE_GAUNTLET_HORDE_BONUSTIME = 14,
    FINALE_GAUNTLET_BOSS_INCOMING   = 15,
    FINALE_GAUNTLET_BOSS            = 16,
    FINALE_GAUNTLET_ESCAPE          = 17
};
*/

StringMap g_smFirstTankSpawningScheme;
StringMap g_smSecondTankSpawningScheme;

enum /* TankSpawningScheme */ {
    eSkip,
    eFlowAndSecondOnEvent,
    eFirstOnEvent
};

int g_iSpawnScheme;
int g_iTankCount;

public Plugin myinfo = {
    name        = "EQ2 Finale Tank Manager",
    author      = "Visor, Electr0",
    description = "Either two event tanks or one flow and one (second) event tank",
    version     = "2.5.2",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart() {
    g_smFirstTankSpawningScheme  = new StringMap();
    g_smSecondTankSpawningScheme = new StringMap();

    RegServerCmd("tank_map_flow_and_second_event", Cmd_SetMapFirstTankSpawningScheme);
    RegServerCmd("tank_map_only_first_event",      Cmd_SetMapSecondTankSpawningScheme);

    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

Action Cmd_SetMapFirstTankSpawningScheme(int iArgs) {
    if (iArgs != 1) {
        PrintToServer("Usage: tank_map_flow_and_second_event <mapname>");
        LogError("Usage: tank_map_flow_and_second_event <mapname>");
        return Plugin_Handled;
    }

    char szMapName[MAP_NAME_MAX_LENGTH];
    GetCmdArg(1, szMapName, sizeof(szMapName));
    g_smFirstTankSpawningScheme.SetValue(szMapName, true);
    return Plugin_Handled;
}

Action Cmd_SetMapSecondTankSpawningScheme(int iArgs) {
    if (iArgs != 1) {
        PrintToServer("Usage: tank_map_only_first_event <mapname>");
        LogError("Usage: tank_map_only_first_event <mapname>");
        return Plugin_Handled;
    }

    char szMapName[MAP_NAME_MAX_LENGTH];
    GetCmdArg(1, szMapName, sizeof(szMapName));
    g_smSecondTankSpawningScheme.SetValue(szMapName, true);
    return Plugin_Handled;
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    CreateTimer(8.0, Timer_ProcessTankSpawn, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_ProcessTankSpawn(Handle hTimer) {
    g_iSpawnScheme = eSkip;
    g_iTankCount   = 0;

    char szMapName[MAP_NAME_MAX_LENGTH];
    GetCurrentMap(szMapName, sizeof(szMapName));

    int iDummy;

    if (g_smFirstTankSpawningScheme.GetValue(szMapName, iDummy))
        g_iSpawnScheme = eFlowAndSecondOnEvent;

    if (g_smSecondTankSpawningScheme.GetValue(szMapName, iDummy))
        g_iSpawnScheme = eFirstOnEvent;

    if (IsTankAllowed() && g_iSpawnScheme != eSkip)
        L4D2Direct_SetVSTankToSpawnThisRound(InSecondHalfOfRound(), (g_iSpawnScheme == eFlowAndSecondOnEvent));

    return Plugin_Stop;
}

public Action L4D2_OnChangeFinaleStage(int &iFinalType, const char[] szArg) {
    if (g_iSpawnScheme != eSkip && (iFinalType == FINALE_CUSTOM_TANK || iFinalType == FINALE_GAUNTLET_BOSS || iFinalType == FINALE_GAUNTLET_ESCAPE)) {
        g_iTankCount++;
        if ((g_iSpawnScheme == eFlowAndSecondOnEvent && g_iTankCount != 2) || (g_iSpawnScheme == eFirstOnEvent && g_iTankCount != 1))
            return Plugin_Handled;
    }
    return Plugin_Continue;
}

stock int InSecondHalfOfRound() {
    return GameRules_GetProp("m_bInSecondHalfOfRound");
}

stock bool IsTankAllowed() {
    return FindConVar("versus_tank_chance_finale").FloatValue > 0.0;
}