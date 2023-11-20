#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <left4dhooks>
#include <l4d2util>

bool   g_bIsAutoSlayerActive = true; // start true to prevent AutoSlayer being activated after round end or before round start
ConVar g_cvGracePeriod;
ConVar g_cvTeamClearDelay;
ConVar g_cvAutoSlayerMode;
ConVar g_cvSlayAllInfected;
Handle g_hAutoSlayerTimer;

char SI_Names[][] = {
    "Unknown",
    "Smoker",
    "Boomer",
    "Hunter",
    "Spitter",
    "Jockey",
    "Charger",
    "Witch",
    "Tank",
    "Not SI"
};

// This plugin was created because of a Hard12 bug where a survivor fails to take damage while pinned
// by special infected. If the whole team is immobilised, they get a grace period before they are AutoSlayerd.
public Plugin myinfo = {
    name        = "AutoSlayer",
    author      = "Breezy",
    description = "Slays configured team if survivors are simultaneously incapped/pinned",
    version     = "2.0",
    url         = "https://github.com/brxce/Gauntlet"
};

public void OnPluginStart() {
    // Cvar
    g_cvAutoSlayerMode = CreateConVar(
    "autoslayer_mode", "1",
    "On all survivors incapacitated/pinned : -1 = Slay survivors, 0 = OFF, 1 = Slay infected",
    FCVAR_NONE, true, -1.0, true, 1.0);
    g_cvAutoSlayerMode.AddChangeHook(OnAutoSlayerModeChange);

    g_cvGracePeriod = CreateConVar(
    "autoslayer_graceperiod", "7.0",
    "Time(sec) before pinned/incapacitated survivor team is slayed by 'slay survivors' AutoSlayer mode",
    FCVAR_NONE, true, 0.0, false, 0.0);

    g_cvTeamClearDelay = CreateConVar(
    "autoslayer_teamclear_delay", "3.0",
    "Time(sec) before survivor team is cleared by 'slay infected' AutoSlayer mode",
    FCVAR_NONE, true, 0.0);

    g_cvSlayAllInfected = CreateConVar(
    "autoslayer_slay_all_infected", "1",
    "0 = only infected pinning survivors are slayed, 1 = all infected are slayed",
    FCVAR_NONE, true, 0.0, true, 1.0);

    // Event hooks
    HookEvent("player_incapacitated",  Event_PlayerImmobilised,  EventHookMode_PostNoCopy);
    HookEvent("choke_start",           Event_PlayerImmobilised,  EventHookMode_PostNoCopy);
    HookEvent("lunge_pounce",          Event_PlayerImmobilised,  EventHookMode_PostNoCopy);
    HookEvent("charger_pummel_start",  Event_PlayerImmobilised,  EventHookMode_PostNoCopy);
    HookEvent("jockey_ride",           Event_PlayerImmobilised,  EventHookMode_PostNoCopy);
    HookEvent("player_left_safe_area", Event_PlayerLeftSafeArea, EventHookMode_PostNoCopy);
    HookEvent("player_hurt",           Event_PlayerHurt,         EventHookMode_Post);
    HookEvent("player_death",          Event_PlayerDeath,        EventHookMode_Pre);

    // Prevent AutoSlayer activating between maps
    HookEvent("map_transition", Event_PreventAutoSlayer, EventHookMode_PostNoCopy);
    HookEvent("mission_lost",   Event_PreventAutoSlayer, EventHookMode_PostNoCopy);
}

void OnAutoSlayerModeChange(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    KillTimer(g_hAutoSlayerTimer);
}

void Event_PreventAutoSlayer(Event eEvent, char[] szName, bool bDontBroadcast) {
    g_bIsAutoSlayerActive = true;
}

void Event_PlayerLeftSafeArea(Event eEvent, char[] szName, bool bDontBroadcast) {
    g_bIsAutoSlayerActive = false;
}

void Event_PlayerImmobilised(Event eEvent, char[] szName, bool bDontBroadcast) {
    AutoSlayer();
}

void Event_PlayerDeath(Event eEvent, char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient > 0 && IsSurvivor(iClient))
        AutoSlayer();
}

void AutoSlayer() {
    if (FindConVar("survivor_limit").IntValue == 1)
        return;
    if (g_cvAutoSlayerMode.IntValue != 0 && !g_bIsAutoSlayerActive && IsTeamImmobilised() && !IsTeamWiped()) {
        g_bIsAutoSlayerActive = true;
        CPrintToChatAll("{green}[{default}Gauntlet{green}]{default} Initiating AutoSlayer...");
        if (g_cvAutoSlayerMode.IntValue < 0) {
            g_hAutoSlayerTimer = CreateTimer(1.0, Timer_SlaySurvivors, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
        } else {
            CreateTimer(g_cvTeamClearDelay.FloatValue, Timer_SlaySpecialInfected, _, TIMER_FLAG_NO_MAPCHANGE);
        }
    }
}

Action Timer_SlaySurvivors(Handle hTimer) {
    static int iSecondsPassed = 0;
    int iCountDown = RoundToNearest(g_cvGracePeriod.FloatValue) - iSecondsPassed;
    // Check for survivors being cleared during the countdown
    if (!IsTeamImmobilised()) {
        CPrintToChatAll("{green}[{default}Gauntlet{green}]{default} AutoSlayer cancelled!");
        g_bIsAutoSlayerActive = false;
        iSecondsPassed         = 0;
        return Plugin_Stop;
    }
    // Countdown ended
    if (iCountDown <= 0) {
        g_bIsAutoSlayerActive = false;
        if (IsTeamImmobilised() && !IsTeamWiped()) {
            SlaySurvivors();
            CPrintToChatAll("{green}[{default}Gauntlet{green}]{default} AutoSlayed {blue}survivors!");
        } else {
            CPrintToChatAll("{green}[{default}Gauntlet{green}]{default} AutoSlayer cancelled!");
        }
        iSecondsPassed = 0;
        return Plugin_Stop;
    }
    CPrintToChatAll("{green}[{default}Gauntlet{olive}] {olive}%d...", iCountDown);
    iSecondsPassed++;
    return Plugin_Continue;
}

void SlaySurvivors() {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsSurvivor(i) && IsPlayerAlive(i))
            ForcePlayerSuicide(i);
    }
}

Action Timer_SlaySpecialInfected(Handle hTimer) {
    CPrintToChatAll("{green}[{default}Gauntlet{green}]{default} AutoSlayed {red}special infected!");
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i)) {
            if (IsPinningASurvivor(i)) {
                ForcePlayerSuicide(i);
            } else if (g_cvSlayAllInfected.BoolValue && !IsTank(i)) {
                ForcePlayerSuicide(i);
            }
        }
    }
    g_bIsAutoSlayerActive = false;
    return Plugin_Stop;
}

bool IsPinningASurvivor(int iClient) {
    bool bIsPinning = false;
    if (IsClientInGame(iClient) && IsPlayerAlive(iClient)) {
        if (GetEntPropEnt(iClient, Prop_Send, "m_tongueVictim") > 0)
            bIsPinning = true; // smoker
        if (GetEntPropEnt(iClient, Prop_Send, "m_pounceVictim") > 0)
            bIsPinning = true; // hunter
        if (GetEntPropEnt(iClient, Prop_Send, "m_pummelVictim") > 0)
            bIsPinning = true; // charger pounding
        if (GetEntPropEnt(iClient, Prop_Send, "m_jockeyVictim") > 0)
            bIsPinning = true; // jockey
    }
    return bIsPinning;
}

/**
 * @return: true if all survivors are either incapacitated or pinned
**/
bool IsTeamImmobilised() {
    // If any survivor is found to be alive and neither pinned nor incapacitated the team is not immobilised.
    bool bIsTeamImmobilised = true;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsSurvivor(i) && IsPlayerAlive(i)) {
            if (!IsSurvivorAttacked(i) && !IsIncapacitated(i)) {
                bIsTeamImmobilised = false;
                break;
            }
        }
    }
    return bIsTeamImmobilised;
}

/**
 * @return: true if all survivors are either incapacitated
**/
bool IsTeamWiped() {
    bool bIsTeamWiped = true;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsSurvivor(i) && IsPlayerAlive(i)) {
            if (!IsIncapacitated(i)) {
                bIsTeamWiped = false;
                break;
            }
        }
    }
    return bIsTeamWiped;
}

// 1 Survivor
void Event_PlayerHurt(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (FindConVar("survivor_limit").IntValue != 1)
        return;

    bool bSuccess = false;

    int iAttacker = GetClientOfUserId(eEvent.GetInt("attacker"));
    if (iAttacker <= 0 || !IsClientInGame(iAttacker) || GetClientTeam(iAttacker) != 3 || !IsPinningASurvivor(iAttacker))
        return;

    int iDamage = eEvent.GetInt("dmg_health");
    if (iDamage == 0)
        return;

    int iClass = GetZombieClass(iAttacker);
    switch (iClass) {
        case 1, 6: {
            bSuccess = true;
        }
        case 3: {
            if (iDamage >= FindConVar("z_pounce_damage").IntValue)
                bSuccess = true;
        }
        case 5: {
            if (iDamage >= FindConVar("z_jockey_ride_damage").IntValue)
                bSuccess = true;
        }
    }

    if (bSuccess) {
        int iHealth = GetClientHealth(iAttacker);
        CPrintToChatAll("{green}[{default}Gauntlet{green}] {red}%s{default} had {olive}%d{default} health remaining!", SI_Names[iClass], iHealth);
        ForcePlayerSuicide(iAttacker);

        if (g_cvSlayAllInfected.BoolValue) {
            for (int i = 1; i <= MaxClients; i++) {
                if (!IsClientInGame(i) || !IsFakeClient(i) || GetClientTeam(i) != 3 || !IsPlayerAlive(i) || IsTank(i))
                    continue;
                ForcePlayerSuicide(i);
            }
        }
    }
}

stock int GetZombieClass(int client) {
    return GetEntProp(client, Prop_Send, "m_zombieClass");
}