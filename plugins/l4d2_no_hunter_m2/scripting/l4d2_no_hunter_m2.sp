#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <l4d2util>
#include <left4dhooks>

ConVar g_cvEnabled;
int    g_iEnabled;

public Plugin myinfo = {
    name        = "L4D2 No Hunter M2",
    author      = "Visor, A1m",
    description = "Self-descriptive",
    version     = "3.4",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    RegPluginLibrary("l4d2_no_hunter_m2");
    return APLRes_Success;
}

public void OnPluginStart() {
    g_cvEnabled = CreateConVar(
    "l4d2_no_hunter_m2", "1",
    "Is plugin enabled. 0 = Disabled, 1 = Hunters shoving is blocked only during pounce, 2 = Hunter shoving is always blocked.",
    FCVAR_NONE, true, 0.0, true, 2.0);
    g_iEnabled = g_cvEnabled.IntValue;
    g_cvEnabled.AddChangeHook(ConVarChanged_Enabled);
}

void ConVarChanged_Enabled(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iEnabled = g_cvEnabled.IntValue;
}

public Action L4D_OnShovedBySurvivor(int iShover, int iShovee, const float vDir[3]) {
    return Shove_Handler(iShover, iShovee);
}

public Action L4D2_OnEntityShoved(int iShover, int iShovee, int weapon, float vDir[3], bool bIsHunterDeadstop) {
    return Shove_Handler(iShover, iShovee);
}

Action Shove_Handler(int iShover, int iShovee) {
    if (!g_iEnabled)
        return Plugin_Continue;

    if (!IsValidSurvivor(iShover))
        return Plugin_Continue;

    if (!IsHunter(iShovee))
        return Plugin_Continue;

    if (HasTarget(iShovee))
        return Plugin_Continue;

    if (g_iEnabled == 2)
        return Plugin_Handled;

    if (IsPlayingDeadstopAnimation(iShovee))
        return Plugin_Handled;

    return Plugin_Continue;
}

bool IsHunter(int iClient) {
    if (!IsValidInfected(iClient))
        return false;

    if (!IsPlayerAlive(iClient))
        return false;

    if (GetInfectedClass(iClient) != L4D2Infected_Hunter)
        return false;

    return true;
}

bool IsPlayingDeadstopAnimation(int iClient) {
    static const int iDeadstopSeq[] = {64, 67, 11, 8};
    int iSeq = GetEntProp(iClient, Prop_Send, "m_nSequence");
    for (int i = 0; i < sizeof(iDeadstopSeq); i++) {
        if (iDeadstopSeq[i] == iSeq)
            return true;
    }
    return false;
}

bool HasTarget(int iClient) {
    int iTarget = GetEntPropEnt(iClient, Prop_Send, "m_pounceVictim");
    return (IsValidSurvivor(iTarget) && IsPlayerAlive(iTarget));
}