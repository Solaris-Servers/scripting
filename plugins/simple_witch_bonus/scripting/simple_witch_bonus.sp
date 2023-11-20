#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <l4d2util>
#include <l4d2_penalty_bonus>

#define MAX_ENTITY_NAME 64

StringMap
       g_smWitches;

ConVar g_cvBonus;

public Plugin myinfo = {
    name        = "Simple Witch Kill Bonus",
    author      = "Tabun",
    description = "Gives bonus for witches getting killed without doing damage to survivors (uses pbonus).",
    version     = "0.9.2",
    url         = "https://github.com/Attano/L4D2-Competitive-Framework"
}

public void OnPluginStart() {
    g_cvBonus = CreateConVar(
    "sm_simple_witch_bonus", "25",
    "Bonus points to award for clean witch kills.",
    FCVAR_NONE, true, 0.0, false, 0.0);

    HookEvent("witch_spawn",                Event_WitchSpawn);
    HookEvent("witch_killed",               Event_WitchKilled);
    HookEvent("player_hurt",                Event_PlayerHurt);
    HookEvent("player_incapacitated_start", Event_PlayerIncap);

    g_smWitches = new StringMap();
}

// witch tracking
void Event_WitchSpawn(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iWitch = eEvent.GetInt("witchid");

    char szWitchKey[10];
    FormatEx(szWitchKey, sizeof(szWitchKey), "%x", iWitch);
    g_smWitches.SetValue(szWitchKey, 1);
}

// kill tracking
void Event_WitchKilled(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iWitch = eEvent.GetInt("witchid");
    if (!RemoveWitch(iWitch))
        return;

    // apply bonus, through PenaltyBonus
    int iBonus = g_cvBonus.IntValue;
    PB_AddRoundBonus(iBonus);
    CPrintToChatAll("{red}[{default}Witch Bonus{red}]{default} Killing the witch has awarded {red}%d{default} points!", iBonus);
}

void Event_PlayerHurt(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iVictim = GetClientOfUserId(eEvent.GetInt("userid"));
    if (!iVictim || !IsSurvivor(iVictim))
        return;

    int iWitch  = eEvent.GetInt("attackerentid");
    if (!IsWitch(iWitch))
        return;

    int iDamage = eEvent.GetInt("dmg_health");
    if (iDamage == 0)
        return;

    RemoveWitch(iWitch);
}

void Event_PlayerIncap(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iVictim = GetClientOfUserId(eEvent.GetInt("userid"));
    if (!iVictim || !IsSurvivor(iVictim))
        return;

    int iWitch = eEvent.GetInt("attackerentid");
    if (!IsWitch(iWitch))
        return;

    RemoveWitch(iWitch);
}

bool RemoveWitch(int iWitch) {
    char szWitchKey[10];
    FormatEx(szWitchKey, sizeof(szWitchKey), "%x", iWitch);
    return g_smWitches.Remove(szWitchKey);
}

bool IsWitch(int iEntity) {
    if (iEntity <= MaxClients || !IsValidEdict(iEntity) || !IsValidEntity(iEntity))
        return false;
    char szClassName[MAX_ENTITY_NAME];
    GetEdictClassname(iEntity, szClassName, sizeof(szClassName));
    // witch and witch_bride
    return (strncmp(szClassName, "witch", 5) == 0);
}