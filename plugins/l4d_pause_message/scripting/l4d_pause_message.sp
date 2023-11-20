#pragma newdecls required
#pragma semicolon 1
#include <sourcemod>

ConVar g_cvPausable;
bool   g_bPausable;

public void OnPluginStart() {
    g_cvPausable = FindConVar("sv_pausable");
    g_bPausable  = g_cvPausable.BoolValue;
    g_cvPausable.AddChangeHook(CvarChange);
    AddCommandListener(pauseCmd, "pause");
    AddCommandListener(pauseCmd, "setpause");
    AddCommandListener(pauseCmd, "unpause");
}

public void CvarChange(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bPausable = g_cvPausable.BoolValue;
}

public Action pauseCmd(int iClient, const char[] szCommand, int iArgs) {
    if (!g_bPausable) return Plugin_Handled;
    return Plugin_Continue;
}