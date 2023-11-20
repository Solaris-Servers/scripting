#if defined __TANK_RUSH__
    #endinput
#endif
#define __TANK_RUSH__

/*======================================================================================
    Plugin Info:

*   Name    :   L4D2 No Tank Rush
*   Author  :   Jahze, vintik, devilesk, Sir
*   Descrp  :   Stops distance points accumulating whilst the tank is alive, with the option of unfreezing distance on reaching the Saferoom.
*   Link    :   https://github.com/SirPlease/L4D2-Competitive-Rework

========================================================================================*/

#undef REQUIRE_PLUGIN
#include <l4d_tank_damage_announce>
#define REQUIRE_PLUGIN

#define NONE     0
#define FREEZE   1
#define UNFREEZE 2
#define SAFEROOM 3
#define PASSED   4
#define RESET    5


/**
    Events
            **/

void OnModuleEnd_TankRush() {
    TogglePoints(false, false, NONE);
}

void OnMapStart_TankRush() {
    TogglePoints(false, false, RESET);
}

public Action L4D2_OnEndVersusModeRound(bool bCountSurvivors) {
    if (!L4D2_IsTankInPlay())
        return Plugin_Continue;

    if (!bCountSurvivors)
        return Plugin_Continue;

    TogglePoints(false, true, SAFEROOM);
    return Plugin_Continue;
}

void Evt_RoundStart_Rush() {
    if (!InSecondHalfOfRound())
        return;

    TogglePoints(false, false, NONE);
}

void Evt_PlayerBotReplace(int iBot) {
    if (GetClientTeam(iBot) != L4D2Team_Infected)
        return;

    if (GetEntProp(iBot, Prop_Send, "m_zombieClass") != L4D2Infected_Tank)
        return;

    TogglePoints(false, true, PASSED);
}

public void OnTankSpawn() {
    if (!FreezePointsEnabled())
        return;

    TogglePoints(true, true, FREEZE);
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

bool FreezePointsEnabled(bool bSet = false, bool bVal = false) {
    static bool bFreeze;

    if (bSet)
        bFreeze = bVal;

    return bFreeze;
}