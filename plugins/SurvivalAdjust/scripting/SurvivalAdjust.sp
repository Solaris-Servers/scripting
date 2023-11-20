#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

bool g_bSpawn = true;

public Plugin myinfo = {
    name        = "Survival Adjustments",
    description = "<- Description ->",
    author      = "Sir",
    version     = "1.0",
    url         = ""
};

public void OnPluginStart() {
    HookEvent("player_spawn",         Event_PlayerSpawn);
    HookEvent("survival_round_start", Event_SurvivalRoundStart);
    HookEvent("round_end",            Event_RoundEnd);
}

public void OnMapStart() {
    g_bSpawn = true;
}

void Event_PlayerSpawn(Event eEvent, char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (!IsClientInGame(iClient))    return;
    if (GetClientTeam(iClient) != 2) return; 
    if (!g_bSpawn)                   return;
    CreateTimer(1.2, RemoveKit, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
}

void Event_SurvivalRoundStart(Event eEvent, char[] szName, bool bDontBroadcast) {
    g_bSpawn = false;
}

void Event_RoundEnd(Event eEvent, char[] szName, bool bDontBroadcast) {
    g_bSpawn = true;
}

Action RemoveKit(Handle hTimer, any iUserId) {
    int iClient = GetClientOfUserId(iUserId);
    if (iClient <= 0)                return Plugin_Stop;
    if (!IsClientInGame(iClient))    return Plugin_Stop;
    if (GetClientTeam(iClient) != 2) return Plugin_Stop;
    if (!g_bSpawn)                   return Plugin_Stop;
    int iKit   = GetPlayerWeaponSlot(iClient, 3);
    int iPills = GetPlayerWeaponSlot(iClient, 4);
    if (iKit != -1) {
        RemovePlayerItem(iClient, iKit);
        RemoveEdict(iKit);
    }
    if (iPills == -1) GivePlayerItem(iClient, "weapon_pain_pills");
    return Plugin_Stop;
}