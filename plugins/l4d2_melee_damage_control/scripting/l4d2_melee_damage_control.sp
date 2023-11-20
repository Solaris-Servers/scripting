#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#include <l4d2util/survivors>
#include <l4d2util/infected>
#include <l4d2util/constants>

#define MAX_ENTITY_NAME 64

bool   g_bMeleeDmgFixEnable;
bool   g_bLateLoad;

float  g_fChargerMeleeDamage;
float  g_fTankMeleeNerfDamage;

ConVar g_cvMeleeDmgFix;
ConVar g_cvMeleeDmgCharger;
ConVar g_cvTankDmgMeleeNerfPercentage;

public Plugin myinfo = {
    name        = "L4D2 Melee Damage Fix&Control",
    description = "Fix melees weapons not applying correct damage values on infected. Allows manipulate melee damage on some infected.",
    author      = "Visor, Sir, A1m`",
    version     = "2.1",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    g_bLateLoad = bLate;
    return APLRes_Success;
}

public void OnPluginStart() {
    g_cvMeleeDmgFix = CreateConVar(
    "l4d2_melee_damage_fix", "1.0",
    "Enable fix melees weapons not applying correct damage values on infected (damage no longer depends on hitgroup).",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bMeleeDmgFixEnable = g_cvMeleeDmgFix.BoolValue;
    g_cvMeleeDmgFix.AddChangeHook(Cvars_Changed);

    g_cvTankDmgMeleeNerfPercentage = CreateConVar(
    "l4d2_melee_damage_tank_nerf", "-1.0",
    "Melee damage dealt to tank per swing (a zero or negative value disables this).",
    FCVAR_NONE, false, 0.0, false, 0.0);
    g_fTankMeleeNerfDamage = g_cvTankDmgMeleeNerfPercentage.FloatValue;
    g_cvTankDmgMeleeNerfPercentage.AddChangeHook(Cvars_Changed);

    g_cvMeleeDmgCharger = CreateConVar(
    "l4d2_melee_damage_charger", "-1.0",
    "Melee damage dealt to сharger per swing (a zero or negative value disables this).",
    FCVAR_NONE, false, 0.0, false, 0.0);
    g_fChargerMeleeDamage = g_cvMeleeDmgCharger.FloatValue;
    g_cvMeleeDmgCharger.AddChangeHook(Cvars_Changed);

    if (g_bLateLoad) {
        for (int i = 1; i <= MaxClients; i++) {
            if (IsClientInGame(i)) {
                OnClientPutInServer(i);
            }
        }
    }
}

public void OnPluginEnd() {
    g_cvTankDmgMeleeNerfPercentage.SetFloat(-1.0);
    g_cvMeleeDmgCharger.SetFloat(-1.0);
}

public void Cvars_Changed(ConVar cv, const char[] szOldValue, const char[] szNewValue) {
    g_bMeleeDmgFixEnable   = g_cvMeleeDmgFix.BoolValue;
    g_fTankMeleeNerfDamage = g_cvTankDmgMeleeNerfPercentage.FloatValue;
    g_fChargerMeleeDamage  = g_cvMeleeDmgCharger.FloatValue;
}

public void OnClientPutInServer(int iClient) {
    SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int iClient) {
    SDKUnhook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &iDamagetype) {
    // DMG_SLOWBURN - works for all types of melee weapons
    if (!(iDamagetype & DMG_SLOWBURN))
        return Plugin_Continue;
    if (fDamage <= 0.0 || !IsMelee(iInflictor))
        return Plugin_Continue;
    if (!IsValidInfected(iVictim) || !IsValidSurvivor(iAttacker))
        return Plugin_Continue;
    int iZClass = GetEntProp(iVictim, Prop_Send, "m_zombieClass", 4);
    if (iZClass <= L4D2Infected_Jockey) {
        if (g_bMeleeDmgFixEnable) {
            fDamage = float(GetClientHealth(iVictim));
            return Plugin_Changed;
        }
    } else if (iZClass == L4D2Infected_Charger) {
        if (g_fChargerMeleeDamage > 0.0) {
            float fHealth = float(GetClientHealth(iVictim));
            // Take care of low health Chargers to prevent Overkill damage.
            // Deal requested Damage to Chargers.
            fDamage = (fHealth < g_fChargerMeleeDamage) ? fHealth : g_fChargerMeleeDamage;
            return Plugin_Changed;
        }
    } else if (iZClass == L4D2Infected_Tank) {
        if (g_fTankMeleeNerfDamage > 0.0) {
            fDamage = (fDamage * (100.0 - g_fTankMeleeNerfDamage)) / 100.0;
            return Plugin_Changed;
        }
    }
    return Plugin_Continue;
}

bool IsMelee(int iEntity) {
    if (iEntity > MaxClients && IsValidEntity(iEntity)) {
        char szClassName[MAX_ENTITY_NAME];
        GetEntityClassname(iEntity, szClassName, sizeof(szClassName));
        return (strncmp(szClassName[7], "melee", 5, true) == 0);
    }
    return false;
}