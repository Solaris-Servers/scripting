#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

// shove penalty on a client before we stop adding to it and just let the game take over.
#define MAX_EXISTING_FATIGUE 3

/**
 * How much of a shove penalty will be added if a client melees when not fatigued.
 * If you _are_ fatigued (you can tell when you're fatigued, as meleeing causes the
 * "I'm bloody knackered, mate" icon to appear), then the game will just add the
 * standard count of 1 to your shove penalty, capped at a maximum of maximum of 6.
 *
 * I.e. this setting only has an effect until you're fatigued, at which point the
 * standard code takes over.
 */
ConVar g_cvNonFatiguedMeleePenalty;
int    g_iNonFatiguedMeleePenalty;


public Plugin myinfo = {
    name        = "L4D2 Melee Fatigue Control",
    description = "Allows players to set custom fatigue levels.",
    author      = "Rotoblin Team & Blade; rebuilt by Visor",
    version     = "0.1",
    url         = "https://github.com/ConfoglTeam/ProMod"
};

public void OnPluginStart() {
    g_cvNonFatiguedMeleePenalty = CreateConVar(
    "melee_penalty", "1",
    "Sets the value to be added to a survivor's shove penalty.",
    FCVAR_NONE, true, 1.0, false, 0.0);
    g_iNonFatiguedMeleePenalty = g_cvNonFatiguedMeleePenalty.IntValue;
    g_cvNonFatiguedMeleePenalty.AddChangeHook(ConVarChanged);
}

void ConVarChanged(ConVar cv, char[] szOldVal, char[] szNewVal) {
    g_iNonFatiguedMeleePenalty = g_cvNonFatiguedMeleePenalty.IntValue;
}

public void L4D_OnSwingStart(int iClient, int iWeapon) {
    // we need to subtract 1 from the current shove penalty prior to applying
    // our own as the game has already incremented the shove penalty before we got hold of it.
    int iShovePenalty = L4D_GetMeleeFatigue(iClient) - 1;
    if (iShovePenalty < 0) iShovePenalty = 0;
    if (iShovePenalty >= MAX_EXISTING_FATIGUE) return;
    int iNewFatigue = iShovePenalty + g_iNonFatiguedMeleePenalty;
    L4D_SetMeleeFatigue(iClient, iNewFatigue);
}

int L4D_GetMeleeFatigue(int iClient) {
    return GetEntProp(iClient, Prop_Send, "m_iShovePenalty");
}

void L4D_SetMeleeFatigue(int iClient, int iValue) {
    SetEntProp(iClient, Prop_Send, "m_iShovePenalty", iValue);
}