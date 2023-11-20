#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

ConVar g_cvNoCans;
bool   g_bNoCans;
int    g_iRepeat;

char g_szCanModelNames[][] = {
    "models/props_junk/gascan001a.mdl",
    "models/props_junk/propanecanister001a.mdl",
    "models/props_equipment/oxygentank01.mdl",
    "models/props_junk/explosive_box001.mdl"
};

public Plugin myinfo = {
    name        = "L4D2 Remove Cans",
    author      = "Jahze",
    version     = "0.2",
    description = "Removes oxygen, propane, gas cans, and fireworks",
    url         = "https://github.com/Attano/L4D2-Competitive-Framework"
}

public void OnPluginStart() {
    g_cvNoCans = CreateConVar(
    "l4d_no_cans", "1",
    "Removes oxygen, propane, gas cans, and fireworks",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bNoCans = g_cvNoCans.BoolValue;
    g_cvNoCans.AddChangeHook(NoCansChange);
    HookEvent("round_start", RoundStartHook);
}

void NoCansChange(ConVar cv, const char[] szOldValue, const char[] szNewValue) {
    g_bNoCans = g_cvNoCans.BoolValue;
}

void RoundStartHook(Event event, const char[] name, bool dontBroadcast) {
    if (!g_bNoCans) return;
    g_iRepeat = 0;
    CreateTimer(1.0, RoundStartNoCans, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

Action RoundStartNoCans(Handle hTimer) {
    int iEntity;
    while ((iEntity = FindEntityByClassname(iEntity, "prop_physics")) != -1) {
        if (!IsValidEntity(iEntity)) continue;
        if (!IsCan(iEntity))         continue;
        RemoveEntity(iEntity);
    }
    g_iRepeat++;
    if (g_iRepeat <= 10) return Plugin_Continue;
    return Plugin_Stop;
}

stock bool IsCan(int iEntity) {
    if (GetEntProp(iEntity, Prop_Send, "m_isCarryable", 1) <= 0) return false;
    char szModelName[128];
    GetEntPropString(iEntity, Prop_Data, "m_ModelName", szModelName, sizeof(szModelName));
    for (int i = 0; i < sizeof(g_szCanModelNames); i++) {
        if (strcmp(szModelName, g_szCanModelNames[i], false) != 0) continue;
        return true;
    }
    return false;
}