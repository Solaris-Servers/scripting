#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <left4dhooks>
#include <l4d2util>

stock const int g_iGetUpAnimations[SurvivorCharacter_Size - 1][5] = {
    //l4d2
    // 0: Nick, 1: Rochelle, 2: Coach, 3: Ellis
    //[][4] = Flying animation from being hit by a tank
    {620, 667, 671, 672, 629}, // Nick
    {629, 674, 678, 679, 637}, // Rochelle
    {621, 656, 660, 661, 629}, // Coach
    {625, 671, 675, 676, 634}, // Ellis

    //l4d1
    // 4: Bill, 5: Zoey, 6: Francis, 7: Louis
    {528, 759, 763, 764, 537}, // Bill
    {537, 819, 823, 824, 546}, // Zoey
    {531, 762, 766, 767, 540}, // Francis
    {528, 759, 763, 764, 537}  // Louis
};

bool g_bIsSurvivorStaggerBlocked[SurvivorCharacter_Size - 1];

public Plugin myinfo = {
    name        = "Stagger Blocker",
    author      = "Standalone (aka Manu), Visor, Sir, A1m`",
    description = "Block players from being staggered by Jockeys and Hunters for a time while getting up from a Hunter pounce & Charger pummel",
    version     = "1.4.2",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
}

public void OnPluginStart() {
    HookEvent("pounce_stopped",     Event_PounceChargeEnd);
    HookEvent("charger_pummel_end", Event_PounceChargeEnd);
    HookEvent("charger_carry_end",  Event_PounceChargeEnd);
    HookEvent("player_bot_replace", Event_PlayerBotReplace);
    HookEvent("bot_player_replace", Event_BotPlayerReplace);
    HookEvent("round_end",          Event_RoundEnd, EventHookMode_PostNoCopy);
}

void Event_RoundEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    ResetStaggerBlocked();
}

public void OnMapEnd() {
    ResetStaggerBlocked();
}

// Called when a Player replaces a Bot
void Event_BotPlayerReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iPlayer = GetClientOfUserId(eEvent.GetInt("player"));
    int iCharIdx = IdentifySurvivor(iPlayer);
    if (iCharIdx == SurvivorCharacter_Invalid) {
        return;
    }
    if (g_bIsSurvivorStaggerBlocked[iCharIdx]) {
        SDKHook(iPlayer, SDKHook_PostThink, OnThink);
    }
}

//Called when a Bot replaces a Player
void Event_PlayerBotReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iBot = GetClientOfUserId(eEvent.GetInt("bot"));
    int iCharIdx = IdentifySurvivor(iBot);
    if (iCharIdx == SurvivorCharacter_Invalid) {
        return;
    }
    if (g_bIsSurvivorStaggerBlocked[iCharIdx]) {
        SDKHook(iBot, SDKHook_PostThink, OnThink);
    }
}

void Event_PounceChargeEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("victim"));
    int iCharIdx = IdentifySurvivor(iClient);
    if (iCharIdx == SurvivorCharacter_Invalid) {
        return;
    }
    CreateTimer(0.2, HookOnThink, GetClientUserId(iClient));
    g_bIsSurvivorStaggerBlocked[iCharIdx] = true;
}

Action HookOnThink(Handle hTimer, any iUserId) {
    int iClient = GetClientOfUserId(iUserId);
    if (iClient && IsSurvivor(iClient)) {
        SDKHook(iClient, SDKHook_PostThink, OnThink);
    }
    return Plugin_Stop;
}

void OnThink(int iClient) {
    int iCharIdx = IdentifySurvivorFast(iClient);
    if (iCharIdx == SurvivorCharacter_Invalid) {
        return;
    }
    int iSequence = GetEntProp(iClient, Prop_Send, "m_nSequence");
    if (iSequence != g_iGetUpAnimations[iCharIdx][0] &&
        iSequence != g_iGetUpAnimations[iCharIdx][1] &&
        iSequence != g_iGetUpAnimations[iCharIdx][2] &&
        iSequence != g_iGetUpAnimations[iCharIdx][3] &&
        iSequence != g_iGetUpAnimations[iCharIdx][4]) {
        g_bIsSurvivorStaggerBlocked[iCharIdx] = false;
        SDKUnhook(iClient, SDKHook_PostThink, OnThink);
    }
}

public Action L4D2_OnStagger(int iTarget, int iSource) {
    if (!IsValidInfected(iSource))
        return Plugin_Continue;

    int iSourceClass = GetInfectedClass(iSource);
    if (iSourceClass != L4D2Infected_Hunter && iSourceClass != L4D2Infected_Jockey) {
        return Plugin_Continue;
    }

    int iCharIdx = IdentifySurvivor(iTarget);
    if (iCharIdx == SurvivorCharacter_Invalid) {
        return Plugin_Continue;
    }

    if (g_bIsSurvivorStaggerBlocked[iCharIdx]) {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action L4D2_OnPounceOrLeapStumble(int iVictim, int iAttacker) {
    if (IsValidInfected(iAttacker))
        return Plugin_Continue;

    int iSourceClass = GetInfectedClass(iAttacker);
    if (iSourceClass != L4D2Infected_Hunter && iSourceClass != L4D2Infected_Jockey) {
        return Plugin_Continue;
    }

    int iCharIdx = IdentifySurvivor(iVictim);
    if (iCharIdx == SurvivorCharacter_Invalid) {
        return Plugin_Continue;
    }

    if (g_bIsSurvivorStaggerBlocked[iCharIdx]) {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

void ResetStaggerBlocked() {
    for (int i = 0; i < (SurvivorCharacter_Size - 1); i++) {
        g_bIsSurvivorStaggerBlocked[i] = false;
    }
}