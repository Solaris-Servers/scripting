#pragma newdecls required
#pragma semicolon 1
#include <sourcemod>

ConVar g_cvCommonLimit;
int    g_iCommonLimit;

public Plugin myinfo = {
    name        = "Director-scripted common limit blocker",
    author      = "Tabun",
    description = "Prevents director scripted overrides of z_common_limit. Only affects scripted common limits higher than the cvar.",
    version     = "0.3",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
}

/* -------------------------------
 *      Init
 * ------------------------------- */

public void OnPluginStart() {
    // cvars
    g_cvCommonLimit = FindConVar("z_common_limit");
    g_iCommonLimit  = g_cvCommonLimit.IntValue;
    g_cvCommonLimit.AddChangeHook(CommonLimitChange);
}

void CommonLimitChange(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iCommonLimit = g_cvCommonLimit.IntValue;
}

/* -------------------------------
 *      General hooks / events
 * ------------------------------- */

public Action L4D_OnGetScriptValueInt(const char[] szKey, int &iRetVal) {
    if (strcmp(szKey, "CommonLimit") == 0) {
        if (iRetVal >= g_iCommonLimit) {
            iRetVal = g_iCommonLimit;
            return Plugin_Handled;
        }
    }
    return Plugin_Continue;
}