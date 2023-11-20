#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

ConVar g_cvRestoreRatio;

public Plugin myinfo = {
    name        = "Despawn Health",
    author      = "Jacob",
    description = "Gives Special Infected health back when they despawn.",
    version     = "1.3",
    url         = "github.com/jacob404/myplugins"
}

public void OnPluginStart() {
    g_cvRestoreRatio = CreateConVar(
    "si_restore_ratio", "0.5",
    "How much of the clients missing HP should be restored? 1.0 = Full HP",
    FCVAR_NONE, true, 0.0, true, 1.0);
}

public void L4D_OnEnterGhostState(int iClient) {
    int iCurrentHealth = GetClientHealth(iClient);
    int iMaxHealth = GetEntProp(iClient, Prop_Send, "m_iMaxHealth");

    if (iCurrentHealth != iMaxHealth) {
        int iMissingHealth = iMaxHealth - iCurrentHealth;
        int iNewHP = RoundFloat(iMissingHealth * g_cvRestoreRatio.FloatValue) + iCurrentHealth;
        SetEntityHealth(iClient, iNewHP);
    }
}