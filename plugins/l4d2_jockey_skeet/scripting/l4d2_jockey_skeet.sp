#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <colors>

ConVar g_cvLeapDamageInterrupt;
ConVar g_cvJockeyHealth;

bool   g_bLateLoad;

float  g_fInflictedDamage[MAXPLAYERS + 1][MAXPLAYERS + 1];
float  g_fLeapDamageInterrupt;
float  g_fJockeyHealth;

GlobalForward
    g_ForwardJockeySkeeted;

public Plugin myinfo = {
    name        = "L4D2 Jockey Skeet",
    author      = "Visor",
    description = "A dream come true",
    version     = "1.2.1",
    url         = "https://github.com/Attano/Equilibrium"
};

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    RegPluginLibrary("l4d2_jockey_skeet");
    g_ForwardJockeySkeeted = new GlobalForward("OnJockeySkeet", ET_Ignore, Param_Cell, Param_Cell);
    g_bLateLoad = bLate;
    return APLRes_Success;
}

public void OnPluginStart() {
    g_cvLeapDamageInterrupt = CreateConVar(
    "z_jockey_interrupt_dmg", "215.0",
    "Taking this much damage interrupts a leap attempt",
    FCVAR_NONE, true, 10.0, true, 325.0);
    g_fLeapDamageInterrupt = g_cvLeapDamageInterrupt.FloatValue;
    g_cvLeapDamageInterrupt.AddChangeHook(ConVarChanged);

    g_cvJockeyHealth = FindConVar("z_jockey_health");
    g_fJockeyHealth = g_cvJockeyHealth.FloatValue;
    g_cvJockeyHealth.AddChangeHook(ConVarChanged);

    if (g_bLateLoad) {
        for (int i = 1; i <= MaxClients; i++) {
            if (IsClientInGame(i)) {
                SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
            }
        }
    }
}

public void ConVarChanged(ConVar cv, const char[] szOldValue, const char[] szNewValue) {
    g_fLeapDamageInterrupt = g_cvLeapDamageInterrupt.FloatValue;
    g_fJockeyHealth        = g_cvJockeyHealth.FloatValue;
}

public void OnClientPutInServer(int iClient) {
    SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int iClient) {
    SDKUnhook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &iDamageType, int &iWeapon, float fDamageForce[3], float fDamagePosition[3]) {
    if (!IsJockey(iVictim) || !IsSurvivor(iAttacker) || IsFakeClient(iAttacker))
        return Plugin_Continue;
    if (!HasJockeyTarget(iVictim) && IsAttachable(iVictim) && IsShotgun(iWeapon)) {
        g_fInflictedDamage[iVictim][iAttacker] += fDamage;
        if (g_fInflictedDamage[iVictim][iAttacker] >= g_fLeapDamageInterrupt) {
            fDamage = g_fJockeyHealth;
            Call_StartForward(g_ForwardJockeySkeeted);
            Call_PushCell(iAttacker);
            Call_PushCell(iVictim);
            Call_Finish();
            return Plugin_Changed;
        }
        CreateTimer(0.1, ResetDamageCounter, iVictim);
    }
    return Plugin_Continue;
}

public Action ResetDamageCounter(Handle hTimer, any iVictim) {
    for (int i = 1; i <= MaxClients; i++) {
        g_fInflictedDamage[iVictim][i] = 0.0;
    }
    return Plugin_Stop;
}

bool IsSurvivor(int iClient) {
    return (iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient) && GetClientTeam(iClient) == 2);
}

bool IsJockey(int iClient) {
    return (iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient) && GetClientTeam(iClient) == 3 && GetEntProp(iClient, Prop_Send, "m_zombieClass") == 5 && GetEntProp(iClient, Prop_Send, "m_isGhost") != 1);
}

bool HasJockeyTarget(int iInfected) {
    int iClient = GetEntPropEnt(iInfected, Prop_Send, "m_jockeyVictim");
    return (IsSurvivor(iClient) && IsPlayerAlive(iClient));
}

bool IsAttachable(int iJockey) {
    return !(GetEntityFlags(iJockey) & FL_ONGROUND) && GetEntityMoveType(iJockey) != MOVETYPE_LADDER;
}

bool IsShotgun(int iWeapon) {
    if (iWeapon > 0 && IsValidEntity(iWeapon)) {
        char szClassName[64];
        GetEdictClassname(iWeapon, szClassName, sizeof(szClassName));
        return (StrEqual(szClassName, "weapon_pumpshotgun") || StrEqual(szClassName, "weapon_shotgun_chrome") || StrEqual(szClassName, "weapon_autoshotgun") || StrEqual(szClassName, "weapon_shotgun_spas"));
    }
    return false;
}