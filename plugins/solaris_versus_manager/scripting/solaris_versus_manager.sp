#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <left4dhooks>
#include <l4d2util>

#include "modules/variables.sp"
#include "modules/menu.sp"
#include "modules/vote.sp"

#include "settings/deadstops.sp"
#include "settings/items.sp"
#include "settings/tank_attack.sp"
#include "settings/tank_rush.sp"

public Plugin myinfo = {
    name        = "[Solaris] Versus Manager",
    author      = "elias",
    description = "Allows the Players to change vanilla settings.",
    version     = "1.0.0",
    url         = "https://solaris-servers.ru/"
};

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    AskPluginLoad2_TankAttack();
    RegPluginLibrary("solaris_versus_manager");
    return APLRes_Success;
}

public void OnPluginStart() {
    OnModuleStart_Vote();
    OnModuleStart_Menu();
    OnModuleStart_ItemManager();

    HookEvent("round_start",        Event_RoundStart);
    HookEvent("player_bot_replace", Event_PlayerBotReplace);
}

public void OnAllPluginsLoaded() {
    OnAllPluginsLoaded_TankAttack();
}

public void OnPluginEnd() {
    OnModuleEnd_TankRush();
}

public void OnMapStart() {
    OnMapStart_Variables();
    OnMapStart_TankRush();
}

public void OnMapEnd() {
    OnMapEnd_Variables();
}

public void OnClientConnected(int iClient) {
    OnClientConnected_Variables(iClient);
}

public void OnClientDisconnect(int iClient) {
    OnClientDisconnect_Variables(iClient);
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    Evt_RoundStart_Rush();
    Evt_RoundStart_Items();
}

void Event_PlayerBotReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iBot = GetClientOfUserId(eEvent.GetInt("bot"));
    Evt_PlayerBotReplace(iBot);
}