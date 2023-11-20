#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <l4d2util>
#include <left4dhooks>
#include <colors>
#include <solaris/votes>
#include <solaris/stocks>

#include "modules/panel.sp"
#include "modules/deadstops.sp"

public Plugin myinfo = {
    name        = "Gauntlet Manager",
    author      = "elias",
    description = "Show gauntlet settings in panel before round is live.",
    version     = "1.0.0",
    url         = "https://solaris-servers.ru/"
};

public void OnPluginStart() {
    HookEvent("round_start",           Event_RoundStart,         EventHookMode_PostNoCopy);
    HookEvent("player_left_safe_area", Event_PlayerLeftSafeArea, EventHookMode_PostNoCopy);
    HookEvent("survival_round_start",  Event_SurvivalRoundStart, EventHookMode_PostNoCopy);

    OnModuleStart_DeadStops();
}

public void OnMapEnd() {
    OnMapEnd_Panel();
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    IsRoundLive(true, false);
    InitInfo();
}

void Event_PlayerLeftSafeArea(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (SDK_IsSurvival())
        return;

    IsRoundLive(true, true);
}

void Event_SurvivalRoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    IsRoundLive(true, true);
}

bool IsRoundLive(bool bSet = false, bool bVal = false) {
    static bool bLive = false;

    if (bSet)
        bLive = bVal;

    return bLive;
}