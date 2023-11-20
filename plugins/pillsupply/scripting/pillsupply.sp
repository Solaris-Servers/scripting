#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <l4d2util>

#define EMPTY_SLOT -1

public Plugin myinfo = {
    name        = "Pill Supply",
    author      = "Breezy",
    description = "Supplies survivors a set of pills upon leaving saferoom",
    version     = "1.0",
    url         = "https://github.com/brxce/Gauntlet"
};

/***********************************************************************************************************************************************************************************

                                                                                PER ROUND

***********************************************************************************************************************************************************************************/
public void OnPluginStart() {
    HookEvent("player_left_safe_area", Event_PlayerLeftSafeArea, EventHookMode_PostNoCopy); // restoring health of survivors respawning with 50 health from a death in the previous map
}

void Event_PlayerLeftSafeArea(Event eEvent, const char[] szName, bool bDontBroadcast) {
    DistributePills();
}

/***********************************************************************************************************************************************************************************

                                                                                STARTING PILLS

***********************************************************************************************************************************************************************************/

public void DistributePills() {
    // iterate though all clients
    for (int i = 1; i <= MaxClients; i++) {
        // check player is a survivor
        if (!IsSurvivor(i)) continue;
        // check pills slot is empty
        if (GetPlayerWeaponSlot(i, 5) != EMPTY_SLOT)
            continue;
        GivePlayerItem(i, "weapon_pain_pills");
    }
}