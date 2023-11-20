#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <l4d2util>
#include <left4dhooks>

#undef REQUIRE_PLUGIN
#include <l4d_tank_damage_announce>
#define REQUIRE_PLUGIN

#define NONE     0
#define FREEZE   1
#define UNFREEZE 2
#define SAFEROOM 3
#define PASSED   4
#define RESET    5

ConVar g_cvNoTankRush;
bool   g_bNoTankRush;

ConVar g_cvUnfreezeSaferoom;
bool   g_bUnfreezeSaferoom;

ConVar g_cvUnfreezeAI;
bool   g_bUnfreezeAI;

public Plugin myinfo = {
    name        = "L4D2 No Tank Rush",
    author      = "Jahze, vintik, devilesk, Sir",
    version     = "1.1.4",
    description = "Stops distance points accumulating whilst the tank is alive, with the option of unfreezing distance on reaching the Saferoom",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart() {
    g_cvNoTankRush = CreateConVar(
    "l4d_no_tank_rush", "1",
    "Prevents survivor team from accumulating points whilst the tank is alive",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bNoTankRush = g_cvNoTankRush.BoolValue;
    g_cvNoTankRush.AddChangeHook(CvChg_NoTankRush);

    g_cvUnfreezeSaferoom = CreateConVar(
    "l4d_no_tank_rush_unfreeze_saferoom", "1",
    "Unfreezes Distance if a Survivor makes it to the end saferoom while the Tank is still up.",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bUnfreezeSaferoom = g_cvUnfreezeSaferoom.BoolValue;
    g_cvUnfreezeSaferoom.AddChangeHook(CvChg_UnfreezeSaferoom);

    g_cvUnfreezeAI = CreateConVar(
    "l4d_no_tank_rush_unfreeze_ai", "1",
    "Unfreeze distance if the Tank goes AI",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bUnfreezeAI = g_cvUnfreezeAI.BoolValue;
    g_cvUnfreezeAI.AddChangeHook(CvChg_UnfreezeAI);

    HookEvent("round_start",        Event_RoundStart);
    HookEvent("player_bot_replace", Event_PlayerBotReplace);

    if (L4D2_IsTankInPlay())
        TogglePoints(g_bNoTankRush, false, NONE);
}

public void OnPluginEnd() {
    TogglePoints(false, false, NONE);
}

void CvChg_NoTankRush(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bNoTankRush = g_cvNoTankRush.BoolValue;

    static bool bFreeze;
    bFreeze = g_bNoTankRush && L4D2_IsTankInPlay();
    TogglePoints(bFreeze, false, NONE);
}

void CvChg_UnfreezeSaferoom(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bUnfreezeSaferoom = g_cvUnfreezeSaferoom.BoolValue;
}

void CvChg_UnfreezeAI(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bUnfreezeAI = g_cvUnfreezeAI.BoolValue;
}



/**
    Events
            **/
public void OnMapStart() {
    TogglePoints(false, false, RESET);
}

public Action L4D2_OnEndVersusModeRound(bool bCountSurvivors) {
    if (!g_bUnfreezeSaferoom)
        return Plugin_Continue;

    if (!L4D2_IsTankInPlay())
        return Plugin_Continue;

    if (!bCountSurvivors)
        return Plugin_Continue;

    TogglePoints(false, true, SAFEROOM);
    return Plugin_Continue;
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!InSecondHalfOfRound())
        return;

    TogglePoints(false, false, NONE);
}

public void OnTankSpawn() {
    if (!g_bNoTankRush)
        return;

    TogglePoints(true, true, FREEZE);
}

void Event_PlayerBotReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!g_bUnfreezeAI)
        return;

    int iNewTank = GetClientOfUserId(eEvent.GetInt("bot"));

    if (GetClientTeam(iNewTank) != L4D2Team_Infected)
        return;

    if (GetEntProp(iNewTank, Prop_Send, "m_zombieClass") != L4D2Infected_Tank)
        return;

    TogglePoints(false, true, PASSED);
}

public void OnTankDeath() {
    if (L4D2_IsTankInPlay())
        return;

    TogglePoints(false, true, UNFREEZE);
}



/**
    Freeze/Unfreeze points
                            **/
void TogglePoints(bool bFreeze = true, bool bShowMsg = false, int iType = NONE) {
    static int iDistance = -1;

    if (iType == RESET) {
        iDistance = -1;
        return;
    }

    switch (bFreeze) {
        case true: {
            if (iDistance != -1)
                return;

            iDistance = L4D_GetVersusMaxCompletionScore();
            L4D_SetVersusMaxCompletionScore(0);
            if (bShowMsg) RequestFrame(OnNextFrame_Print, iType);
        }
        case false: {
            if (iDistance == -1)
                return;

            L4D_SetVersusMaxCompletionScore(iDistance);
            iDistance = -1;
            if (bShowMsg) RequestFrame(OnNextFrame_Print, iType);
        }
    }
}

void OnNextFrame_Print(int iType) {
    switch (iType) {
        case FREEZE   : CPrintToChatAll("{green}[{default}!{green}] {olive}Freezing{default} distance points!");
        case UNFREEZE : CPrintToChatAll("{green}[{default}!{green}] {olive}Unfreezing{default} distance points!");
        case SAFEROOM : CPrintToChatAll("{green}[{default}!{green}] {olive}Survivors{default} made it to the saferoom. {olive}Unfreezing{default} distance points!");
        case PASSED   : CPrintToChatAll("{green}[{default}!{green}] {olive}Tank{default} has been passed to AI. {olive}Unfreezing{default} distance points!");
    }
}