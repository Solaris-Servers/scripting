#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

#define TEAM_INFECTED 3
#define Z_TANK 8

ConVar g_cvKeepThrowing;
bool   g_bKeepThrowing;
bool   g_bIsLeft4Dead2;

public Plugin myinfo = {
    name        = "Tank Rock Stumble Block",
    author      = "Jacob, Forgetest",
    description = "Fixes rocks disappearing if tank gets stumbled while throwing.",
    version     = "2.0",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    switch (GetEngineVersion()) {
        case Engine_Left4Dead  : g_bIsLeft4Dead2 = false;
        case Engine_Left4Dead2 : g_bIsLeft4Dead2 = true;
        default: {
            strcopy(szError, iErrMax, "Plugin supports L4D & 2 only");
            return APLRes_SilentFailure;
        }
    }
    return APLRes_Success;
}

public void OnPluginStart() {
    g_cvKeepThrowing = CreateConVar(
    "rock_stumble_throwing", "1",
    "Whether to keep throwing rock even when stumbled. NOTE: if disabled, Tank will get huge movement penalty after stumbled for a few time.",
    FCVAR_SPONLY, true, 0.0, true, 1.0);
    g_bKeepThrowing = g_cvKeepThrowing.BoolValue;
    g_cvKeepThrowing.AddChangeHook(CvarChg_KeepThrowing);
}

void CvarChg_KeepThrowing(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bKeepThrowing = g_cvKeepThrowing.BoolValue;
}

public Action L4D2_OnStagger(int iClient, int iSource) {
    if (!g_bKeepThrowing)
        return Plugin_Continue;

    if (!IsClientInGame(iClient))
        return Plugin_Continue;

    if (!IsTank(iClient))
        return Plugin_Continue;

    int iAbility = GetEntPropEnt(iClient, Prop_Send, "m_customAbility");
    if (iAbility == -1)
        return Plugin_Continue;

    if (!CThrow__IsActive(iAbility) && !CThrow__SelectingTankAttack(iAbility))
        return Plugin_Continue;

    return Plugin_Handled;
}

public void L4D2_OnStagger_Post(int iClient, int iSource) {
    if (g_bKeepThrowing)
        return;

    if (!IsClientInGame(iClient))
        return;

    if (!IsTank(iClient))
        return;

    int iAbility = GetEntPropEnt(iClient, Prop_Send, "m_customAbility");
    if (iAbility == -1)
        return;

    if (!CThrow__IsActive(iAbility) && !CThrow__SelectingTankAttack(iAbility))
        return;

    SetEntPropFloat(iClient, Prop_Send, "m_flCycle", 1.0);
}

bool CThrow__SelectingTankAttack(int iAbility) {
    if (!g_bIsLeft4Dead2) return false;
    static int iSelectingAttackOffs = -1;
    if (iSelectingAttackOffs == -1) iSelectingAttackOffs = FindSendPropInfo("CThrow", "m_hasBeenUsed") + 28;
    return GetEntData(iAbility, iSelectingAttackOffs, 1) > 0;
}

bool CThrow__IsActive(int iAbility) {
    CountdownTimer ct = CThrow__GetThrowTimer(iAbility);
    if (!CTimer_HasStarted(ct)) return false;
    return CTimer_IsElapsed(ct) ? false : true;
}

CountdownTimer CThrow__GetThrowTimer(int iAbility) {
    static int iThrowTimerOffs = -1;
    if (iThrowTimerOffs == -1) iThrowTimerOffs = FindSendPropInfo("CThrow", "m_hasBeenUsed") + 4;
    return view_as<CountdownTimer>(GetEntityAddress(iAbility) + view_as<Address>(iThrowTimerOffs));
}

bool IsTank(int iClient) {
    return (GetClientTeam(iClient) == TEAM_INFECTED && GetEntProp(iClient, Prop_Send, "m_zombieClass") == Z_TANK);
}