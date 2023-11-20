#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2util>

#include "modules/globals.sp"
#include "modules/functions.sp"
#include "modules/ai_boomer.sp"
#include "modules/ai_charger.sp"
#include "modules/ai_hunter.sp"
#include "modules/ai_jockey.sp"
#include "modules/ai_spitter.sp"
#include "modules/ai_tank.sp"

public Plugin myinfo = {
    name        = "AI:Hard SI",
    author      = "Breezy",
    description = "Improves the AI behaviour of special infected",
    version     = "2.0.0",
    url         = "github.com/breezyplease"
};

public void OnPluginStart() {
    Globals_OnModuleStart();

    HookEvent("round_end",            Event_RoundEnd,           EventHookMode_PostNoCopy);
    HookEvent("player_spawn",         Event_PlayerSpawn,        EventHookMode_Post);
    HookEvent("ability_use",          Event_AbilityUse,         EventHookMode_Post);
    HookEvent("charger_charge_start", Event_ChargerChargeStart, EventHookMode_Post);
    HookEvent("jockey_ride",          Event_JockeyRide,         EventHookMode_Pre);
}

public void OnMapEnd() {
    Hunter_RoundEnd();
    Jockey_RoundEnd();
}

void Event_RoundEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    Hunter_RoundEnd();
    Jockey_RoundEnd();
}

void Event_PlayerSpawn(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    Hunter_PlayerSpawn (iClient);
    Jockey_PlayerSpawn (iClient);
    Charger_PlayerSpawn(iClient);
}

void Event_AbilityUse(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));

    if (iClient <= 0)
        return;

    if (!IsClientInGame(iClient))
        return;

    if (!IsFakeClient(iClient))
        return;

    static char szAbility[16];
    eEvent.GetString("ability", szAbility, sizeof szAbility);

    if (strcmp(szAbility, "ability_vomit") == 0)
        BoomerVomit(iClient);

    if (strcmp(szAbility, "ability_lunge") == 0)
        HunterPounce(iClient);
}

void Event_ChargerChargeStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));

    if (iClient <= 0)
        return;

    if (!IsClientInGame(iClient))
        return;

    if (!IsFakeClient(iClient))
        return;

    ChargerCharge(iClient);
}

void Event_JockeyRide(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iAttacker = GetClientOfUserId(eEvent.GetInt("userid"));
    int iVictim   = GetClientOfUserId(eEvent.GetInt("victim"));
    Jockey_RideStart(iVictim, iAttacker);
}

public Action OnPlayerRunCmd(int iClient, int &iButtons) {
    if (!IsClientInGame(iClient))
        return Plugin_Continue;

    if (!IsFakeClient(iClient))
        return Plugin_Continue;

    if (GetClientTeam(iClient) != L4D2Team_Infected)
        return Plugin_Continue;

    if (!IsPlayerAlive(iClient))
        return Plugin_Continue;

    if (L4D_IsPlayerStaggering(iClient))
        return Plugin_Continue;

    switch (GetInfectedClass(iClient)) {
        case (L4D2Infected_Boomer)  : return Boomer_OnPlayerRunCmd (iClient, iButtons);
        case (L4D2Infected_Hunter)  : return Hunter_OnPlayerRunCmd (iClient, iButtons);
        case (L4D2Infected_Spitter) : return Spitter_OnPlayerRunCmd(iClient, iButtons);
        case (L4D2Infected_Jockey)  : return Jockey_OnPlayerRunCmd (iClient, iButtons);
        case (L4D2Infected_Charger) : return Charger_OnPlayerRunCmd(iClient, iButtons);
        case (L4D2Infected_Tank)    : return Tank_OnPlayerRunCmd   (iClient, iButtons);
    }

    return Plugin_Continue;
}

public Action L4D2_OnChooseVictim(int iBot, int &iTarget) {
    g_iCurTarget[iBot] = iTarget;
    return Plugin_Continue;
}

public Action L4D_OnGetRunTopSpeed(int iTarget, float &fRetVal) {
    g_fRunTopSpeed[iTarget] = fRetVal;
    return Plugin_Continue;
}

public void L4D2_OnStartCarryingVictim_Post(int iVictim, int iAttacker) {
    Charger_OnStartCarryingVictim_Post(iVictim, iAttacker);
}