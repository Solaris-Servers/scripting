#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <confogl>
#define REQUIRE_PLUGIN

bool g_bConfogl = false;

#include "l4d2lib/rounds.sp"
#include "l4d2lib/mapinfo.sp"
#include "l4d2lib/tanks.sp"
#include "l4d2lib/survivors.sp"

public Plugin myinfo = {
    name        = "L4D2Lib",
    author      = "Confogl Team",
    description = "Useful natives and fowards for L4D2 Plugins",
    version     = "3.2",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    /* Plugin Native Declarations */
    Rounds_AskPluginLoad2();
    MapInfo_AskPluginLoad2();
    Tanks_AskPluginLoad2();
    Survivors_AskPluginLoad2();
    /* Register our library */
    RegPluginLibrary("l4d2lib");
    return APLRes_Success;
}

public void OnPluginStart() {
    HookEvent("round_start",        Event_RoundStart,        EventHookMode_PostNoCopy);
    HookEvent("round_end",          Event_RoundEnd,          EventHookMode_PostNoCopy);
    HookEvent("player_disconnect",  Event_PlayerDisconnect,  EventHookMode_PostNoCopy);
    HookEvent("player_spawn",       Event_PlayerSpawn,       EventHookMode_PostNoCopy);
    HookEvent("player_bot_replace", Event_PlayerBotReplace,  EventHookMode_PostNoCopy);
    HookEvent("bot_player_replace", Event_BotPlayerReplace,  EventHookMode_PostNoCopy);
    HookEvent("defibrillator_used", Event_DefibrillatorUsed, EventHookMode_PostNoCopy);
    HookEvent("player_team",        Event_PlayerTeam,        EventHookMode_PostNoCopy);
    HookEvent("tank_spawn",         Event_TankSpawn);
    HookEvent("item_pickup",        Event_ItemPickup);
    HookEvent("player_death",       Event_PlayerDeath);
    MapInfo_Init();
}

public void OnPluginEnd() {
    MapInfo_OnPluginEnd();
}

public void OnLibraryAdded(const char[] szName) {
    if (strcmp(szName, "confogl", true) == 0) {
        g_bConfogl = true;
        MapInfo_Reload();
    }
}

public void OnLibraryRemoved(const char[] szName) {
    if (strcmp(szName, "confogl", true) == 0) {
        g_bConfogl = false;
        MapInfo_Reload();
    }
}

public void OnMapStart() {
    MapInfo_OnMapStart_Update();
    Tanks_OnMapStart();
}

public void OnMapEnd() {
    MapInfo_OnMapEnd_Update();
    Rounds_OnMapEnd_Update();
}

/* Events */
void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    Rounds_OnRoundStart_Update();
    Tanks_RoundStart();
    Survivors_RebuildArray();
}

void Event_RoundEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    Rounds_OnRoundEnd_Update();
}

void Event_PlayerDisconnect(Event eEvent, const char[] szName, bool bDontBroadcast) {
    Survivors_RebuildArray();
    MapInfo_PlayerDisconnect(eEvent);
}

void Event_PlayerSpawn(Event eEvent, const char[] szName, bool bDontBroadcast) {
    Survivors_RebuildArray();
}

void Event_PlayerBotReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    Survivors_RebuildArray();
}

void Event_BotPlayerReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    Survivors_RebuildArray();
}

void Event_DefibrillatorUsed(Event eEvent, const char[] szName, bool bDontBroadcast) {
    Survivors_RebuildArray();
}

void Event_PlayerTeam(Event eEvent, const char[] szName, bool bDontBroadcast) {
    Survivors_RebuildArray_Delay();
}

void Event_TankSpawn(Event eEvent, const char[] szName, bool bDontBroadcast) {
    Tanks_TankSpawn(eEvent);
}

void Event_ItemPickup(Event eEvent, const char[] szName, bool bDontBroadcast) {
    Tanks_ItemPickup(eEvent);
}

void Event_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast) {
    Tanks_PlayerDeath(eEvent);
    Survivors_RebuildArray();
}