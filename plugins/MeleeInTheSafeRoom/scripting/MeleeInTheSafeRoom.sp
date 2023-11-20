#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <solaris/stocks>

#include "modules/variables.sp"
#include "modules/precache.sp"
#include "modules/convars.sp"
#include "modules/events.sp"
#include "modules/functions.sp"
#include "modules/stocks.sp"

public Plugin myinfo = {
    name        = "Melee In The Saferoom",
    author      = "N3wton",
    description = "Spawns a selection of melee weapons in the saferoom, at the start of each round.",
    version     = "2.0.8",
    url         = "https://forums.alliedmods.net/showthread.php?t=125164"
};

public void OnPluginStart() {
    InitConVars();
    InitEvents();
}

public void OnMapStart() {
    Precache_OnMapStart();
}