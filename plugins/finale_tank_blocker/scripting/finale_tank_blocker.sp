#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define FINALE_STAGE_TANK 8

StringMap g_FinaleExceptionMapsTrie;
int       g_iTankCount[2];

public Plugin myinfo = {
    name        = "Finale Even-Numbered Tank Blocker",
    author      = "Stabby, Visor",
    description = "Blocks even-numbered non-flow finale tanks.",
    version     = "2",
    url         = "http://github.com/ConfoglTeam/ProMod"
};

public void OnPluginStart() {
    RegServerCmd("finale_tank_default", SetFinaleExceptionMap);
    g_FinaleExceptionMapsTrie = new StringMap();
}

public Action SetFinaleExceptionMap(int iArgs) {
    char szMapName[64];
    GetCmdArg(1, szMapName, sizeof(szMapName));
    g_FinaleExceptionMapsTrie.SetValue(szMapName, true);
    return Plugin_Handled;
}

public Action L4D2_OnChangeFinaleStage(int &iFinaleType, const char[] iArgs) {
    char szMapName[64];
    GetCurrentMap(szMapName, sizeof(szMapName));

    int iDummy;
    if (g_FinaleExceptionMapsTrie.GetValue(szMapName, iDummy))
        return Plugin_Continue;

    if (iFinaleType == FINALE_STAGE_TANK) {
        if (++g_iTankCount[GameRules_GetProp("m_bInSecondHalfOfRound")] % 2 == 0)
            return Plugin_Handled;
    }
    return Plugin_Continue;
}

public void OnMapEnd() {
    g_iTankCount[0] = 0;
    g_iTankCount[1] = 0;
}