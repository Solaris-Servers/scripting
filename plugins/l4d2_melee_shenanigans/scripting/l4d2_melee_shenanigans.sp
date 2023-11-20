#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define MAX_ENTITY_NAME 64

public Plugin myinfo = {
    name        = "L4D2 Melee Shenanigans",
    author      = "Sir",
    description = "Stops survivors keeping melee out after tank punch.",
    version     = "1.3",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
}

public void OnPluginStart() {
    HookEvent("player_hurt", Event_PlayerHit);
}

void Event_PlayerHit(Event eEvent, char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)                return;
    if (!IsClientInGame(iClient))    return;
    if (GetClientTeam(iClient) != 2) return;
    char szWeapon[12];
    eEvent.GetString("weapon", szWeapon, sizeof(szWeapon));
    if (strncmp(szWeapon, "tank_claw", 5, true) == 0) {
        int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
        if (!IsMelee(iWeapon)) return;
        int iPrimaryWeapon = GetPlayerWeaponSlot(iClient, 0);
        if (iPrimaryWeapon <= 0) return;
        // Force a weapon switch
        // Note: If a player's primary weapon is empty, it will still switch to the primary weapon, but then instantly switch back to the melee weapon.
        SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iPrimaryWeapon);
        // Prevent players instantly firing their Primary Weapon when they're holding down M1 with their melee.
        SetEntPropFloat(iPrimaryWeapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 0.1);
    }
}

bool IsMelee(int iEntity) {
    if (iEntity > MaxClients && IsValidEntity(iEntity)) {
        char szClassName[MAX_ENTITY_NAME];
        GetEntityClassname(iEntity, szClassName, sizeof(szClassName));
        return (strncmp(szClassName[7], "melee", 5, true) == 0);
    }
    return false;
}