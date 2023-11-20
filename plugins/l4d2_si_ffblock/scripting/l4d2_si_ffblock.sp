#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#include <l4d2util/stocks>
#include <l4d2util/infected>

#define MAX_ENTITY_NAME_SIZE 64

ConVar g_cvSIBlockFF;
bool   g_bSIBlockFF;

ConVar g_cvTankBlockFF;
bool   g_bTankBlockFF;

ConVar g_cvBlockWitchFF;
bool   g_bBlockWitchFF;

public Plugin myinfo = {
    name        = "L4D2 Infected Friendly Fire Disable",
    author      = "ProdigySim, Don, Visor, A1m`",
    description = "Disables friendly fire between infected players.",
    version     = "2.1",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart() {
    g_cvSIBlockFF = CreateConVar(
    "l4d2_block_infected_ff", "1", "Disable SI->SI friendly fire",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bSIBlockFF = g_cvSIBlockFF.BoolValue;
    g_cvSIBlockFF.AddChangeHook(CvChg_SIBlockFF);

    g_cvTankBlockFF = CreateConVar(
    "l4d2_block_tank_ff", "0", "Disable Tank->SI friendly fire",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bTankBlockFF = g_cvTankBlockFF.BoolValue;
    g_cvTankBlockFF.AddChangeHook(CvChg_TankBlockFF);

    g_cvBlockWitchFF = CreateConVar(
    "l4d2_infected_ff_block_witch", "0", "Disable FF towards witches",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bBlockWitchFF = g_cvBlockWitchFF.BoolValue;
    g_cvBlockWitchFF.AddChangeHook(CvChg_BlockWitchFF);

    HookEvent("witch_spawn", Event_WitchSpawn, EventHookMode_Post);

    int iEntityMaxCount = GetEntityCount();
    for (int iEntity = 1; iEntity <= iEntityMaxCount; iEntity++) {
        if (iEntity <= MaxClients) {
            if (IsClientInGame(iEntity)) {
                SDKHook(iEntity, SDKHook_OnTakeDamage, Hook_PlayerOnTakeDamage);
            }
        } else {
            if (IsWitch(iEntity)) {
                SDKHook(iEntity, SDKHook_OnTakeDamage, Hook_WitchOnTakeDamage);
            }
        }
    }
}

void CvChg_SIBlockFF(ConVar cv, const char[] szOldValue, const char[] szNewValue) {
    g_bSIBlockFF = g_cvSIBlockFF.BoolValue;
}

void CvChg_TankBlockFF(ConVar cv, const char[] szOldValue, const char[] szNewValue) {
    g_bTankBlockFF = g_cvTankBlockFF.BoolValue;
}

void CvChg_BlockWitchFF(ConVar cv, const char[] szOldValue, const char[] szNewValue) {
    g_bBlockWitchFF = g_cvBlockWitchFF.BoolValue;
}

public void OnClientPutInServer(int iClient) {
    SDKHook(iClient, SDKHook_OnTakeDamage, Hook_PlayerOnTakeDamage);
}

Action Hook_PlayerOnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &iDamagetype) {
    if (!g_bSIBlockFF || !(iDamagetype & DMG_CLUB))
        return Plugin_Continue;

    if (!IsValidClient(iAttacker) || !IsValidClient(iVictim))
        return Plugin_Continue;

    if (!IsInfected(iAttacker) || !IsInfected(iVictim))
        return Plugin_Continue;

    int iZClass = GetEntProp(iAttacker, Prop_Send, "m_zombieClass");
    if (iZClass == L4D2Infected_Tank)
        return g_bTankBlockFF ? Plugin_Handled : Plugin_Continue;

    return Plugin_Handled;
}

void Event_WitchSpawn(Event eEvent, const char[] szEventName, bool bDontBroadcast) {
    int iWitch = eEvent.GetInt("witchid");
    SDKHook(iWitch, SDKHook_OnTakeDamage, Hook_WitchOnTakeDamage);
}

Action Hook_WitchOnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &iDamagetype) {
    if (!g_bBlockWitchFF || !(iDamagetype & DMG_CLUB))
        return Plugin_Continue;

    if (!IsValidClient(iAttacker))
        return Plugin_Continue;

    if (!IsWitch(iVictim) || !IsInfected(iAttacker))
        return Plugin_Continue;

    int iZClass = GetEntProp(iAttacker, Prop_Send, "m_zombieClass");
    return iZClass == L4D2Infected_Tank ? Plugin_Continue : Plugin_Handled;
}

bool IsValidClient(int iClient) {
    return iClient && iClient <= MaxClients;
}

bool IsWitch(int iEntity) {
    if (iEntity <= MaxClients || !IsValidEntity(iEntity))
        return false;

    char szClsName[MAX_ENTITY_NAME_SIZE];
    GetEdictClassname(iEntity, szClsName, sizeof(szClsName));

    // witch and witch_bride
    return (strncmp(szClsName, "witch", 5) == 0);
}