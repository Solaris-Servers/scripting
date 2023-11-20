#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <l4d2util>
#include <left4dhooks>

#define TEAM_INDEX_SIZE 2

// request final update before round ends
GlobalForward
    g_fwdRequestUpdate;

int g_iDefibsUsed[TEAM_INDEX_SIZE] = {0, 0}; // defibs used this round
int g_iBonusAdded[TEAM_INDEX_SIZE] = {0, 0}; // bonus to be added when this round ends

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    // this forward requests all plugins to return their final modifications
    //  the cell parameter will be updated for each plugin responding to this forward
    //  so the last return value is the total of the final update modifications
    g_fwdRequestUpdate = CreateGlobalForward("PB_RequestFinalUpdate", ET_Ignore, Param_CellByRef);

    CreateNative("PB_AddRoundBonus",   Native_AddRoundBonus);
    CreateNative("PB_SetRoundBonus",   Native_SetRoundBonus);
    CreateNative("PB_GetRoundBonus",   Native_GetRoundBonus);

    RegPluginLibrary("l4d2_penalty_bonus");
    return APLRes_Success;
}

// -------
// Natives
// -------
any Native_GetRoundBonus(Handle hPlugin, int iNumParams) {
    return g_iBonusAdded[RoundIndex()];
}

any Native_SetRoundBonus(Handle hPlugin, int iNumParams) {
    int iBonus = GetNativeCell(1);
    g_iBonusAdded[RoundIndex()] = iBonus;
    return 1;
}

any Native_AddRoundBonus(Handle hPlugin, int iNumParams) {
    int iBonus = GetNativeCell(1);
    g_iBonusAdded[RoundIndex()] += iBonus;
    return 1;
}

public Plugin myinfo = {
    name        = "Penalty bonus system",
    author      = "Tabun, A1m`",
    description = "Allows other plugins to set bonuses for a round that will be given even if the saferoom is not reached.",
    version     = "2.1",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

// -----------------------
// Init and round handling
// -----------------------
public void OnPluginStart() {
    // hook events
    HookEvent("round_start",        Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("defibrillator_used", Event_DefibUsed,  EventHookMode_PostNoCopy);
}

public void OnPluginEnd() {
    DefibPenalty(false, 0, true, false); // reset
}

public void OnMapStart() {
    DefibPenalty(false, 0, true, false); // reset

    for (int i = 0; i < TEAM_INDEX_SIZE; i++) {
        g_iDefibsUsed[i] = 0;
        g_iBonusAdded[i] = 0;
    }
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    DefibPenalty(false, 0, true, false); // reset
}

// --------------
// Defib tracking
// --------------
void Event_DefibUsed(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_iDefibsUsed[RoundIndex()]++;
}

// --------------------
// Special Check
// --------------------
public Action L4D2_OnEndVersusModeRound(bool bCountSurvivors) {
    int iUpdateScore, iUpdateResult;

    // get update before setting the bonus
    Call_StartForward(g_fwdRequestUpdate);
    Call_PushCellRef(iUpdateScore);
    Call_Finish(iUpdateResult);

    // add the update to the round's bonus
    g_iBonusAdded[RoundIndex()] += iUpdateResult;

    SetBonus();

    return Plugin_Continue;
}

// Bonus
// -----
void SetBonus() {
    // only change anything if there's a bonus to set at all
    if (g_iBonusAdded[RoundIndex()] == 0) {
        DefibPenalty(false, 0, true, false); // reset
        return;
    }

    // set the bonus as though only 1 defib was used: so 1 * CalculateBonus
    int iBonus = CalculateBonus();

    // set bonus(penalty) cvar
    DefibPenalty(true, iBonus, false, false);

    // only set the amount of defibs used to 1 if there is a bonus to set
    GameRules_SetProp("m_iVersusDefibsUsed", (iBonus != 0) ? 1 : 0, 4, GameRules_GetProp("m_bAreTeamsFlipped", 4, 0));
}

int CalculateBonus() {
    // negative = actual bonus, otherwise it is a penalty
    return (DefibPenalty(false, 0, false, true) * g_iDefibsUsed[RoundIndex()]) - g_iBonusAdded[RoundIndex()];
}

// -----------------
// Support functions
// -----------------
int RoundIndex() {
    return InSecondHalfOfRound() ? 1 : 0;
}

int DefibPenalty(bool bSet = false, int iVal = 0, bool bReset = false, bool bDefVal = false) {
    static ConVar cv;
    static int val;
    if (cv == null) {
        cv = FindConVar("vs_defib_penalty");
        cv.RestoreDefault();
        val = cv.IntValue;
    }

    if (bReset) {
        cv.RestoreDefault();
        return val;
    }

    if (bSet)
        cv.SetInt(iVal);

    if (bDefVal)
        return val;

    return cv.IntValue;
}