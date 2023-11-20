#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>

#include <l4d2util/stocks>
#include <l4d2util/survivors>
#include <l4d2util/infected>

float  g_fGhostDelay;
float  g_fReported[MAXPLAYERS + 1][MAXPLAYERS + 1];
Handle g_hTongueParalyzeTimer;

public Plugin myinfo = {
    name        = "L4D2 Display Infected HP",
    author      = "Visor",
    version     = "1.2",
    description = "Survivors receive damage reports after they get capped",
    url         = "https://github.com/Attano/Equilibrium"
};

public void OnPluginStart() {
    HookEvent("round_start",          Event_RoundStart);
    HookEvent("player_death",         Event_PlayerDeath);
    HookEvent("charger_carry_start",  Event_CHJ_Attack);
    HookEvent("charger_pummel_start", Event_CHJ_Attack);
    HookEvent("lunge_pounce",         Event_CHJ_Attack);
    HookEvent("jockey_ride",          Event_CHJ_Attack);
    HookEvent("tongue_grab",          Event_SmokerAttackFirst);
    HookEvent("choke_start",          Event_SmokerAttackSecond);
}

public void OnConfigsExecuted() {
    g_fGhostDelay = FindConVar("z_ghost_delay_min").FloatValue;
}

public void OnClientPutInServer(int iClient) {
    for (int i = 1; i <= MaxClients; i++) {
        g_fReported[iClient][i] = 0.0;
    }
}

public void OnClientDisconnect(int iClient) {
    for (int i = 1; i <= MaxClients; i++) {
        g_fReported[iClient][i] = 0.0;
    }
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    for (int i = 1; i <= MaxClients; i++) {
        for (int j = 1; j <= MaxClients; j++) {
            g_fReported[i][j] = 0.0;
        }
    }
}

void Event_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0 || !IsInfected(iClient))
        return;
    int iZombieClass = IsTargetedSI(iClient);
    if (iZombieClass <= 0)
        return;
    if (iZombieClass == view_as<int>(L4D2Infected_Smoker)) {
        if (g_hTongueParalyzeTimer != null) {
            KillTimer(g_hTongueParalyzeTimer);
            g_hTongueParalyzeTimer = null;
        }
    }
}

void Event_CHJ_Attack(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iAttacker = GetClientOfUserId(eEvent.GetInt("userid"));
    int iVictim   = GetClientOfUserId(eEvent.GetInt("victim"));
    if (iAttacker <= 0 || !IsInfected(iAttacker) || !IsPlayerAlive(iAttacker))
        return;
    if (iVictim <= 0 || !IsSurvivor(iVictim) || IsFakeClient(iVictim) || !IsPlayerAlive(iVictim))
        return;
    PrintInflictedDamage(iVictim, iAttacker);
}

void Event_SmokerAttackFirst(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iAttackerId = eEvent.GetInt("userid");
    int iVictimId   = eEvent.GetInt("victim");
    if (g_hTongueParalyzeTimer != null) {
        KillTimer(g_hTongueParalyzeTimer);
        g_hTongueParalyzeTimer = null;
    }
    if (GetClientOfUserId(iAttackerId) <= 0 || GetClientOfUserId(iVictimId) <= 0)
        return;
    DataPack dp;
    g_hTongueParalyzeTimer = CreateDataTimer(1.1, CheckSurvivorState, dp, TIMER_FLAG_NO_MAPCHANGE);
    dp.WriteCell(iAttackerId);
    dp.WriteCell(iVictimId);
}

Action CheckSurvivorState(Handle hTimer, DataPack dp) {
    dp.Reset();
    int iAttacker = GetClientOfUserId(dp.ReadCell());
    int iVictim   = GetClientOfUserId(dp.ReadCell());
    if (iAttacker <= 0 || !IsInfected(iAttacker) || !IsPlayerAlive(iAttacker)) {
        g_hTongueParalyzeTimer = null;
        return Plugin_Stop;
    }
    if (iVictim <= 0 || !IsSurvivor(iVictim) || IsFakeClient(iVictim) || !IsPlayerAlive(iVictim)) {
        g_hTongueParalyzeTimer = null;
        return Plugin_Stop;
    }
    if (IsParalyzed(iVictim))
        PrintInflictedDamage(iVictim, iAttacker);
    g_hTongueParalyzeTimer = null;
    return Plugin_Stop;
}

void Event_SmokerAttackSecond(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iAttacker = GetClientOfUserId(eEvent.GetInt("userid"));
    int iVictim   = GetClientOfUserId(eEvent.GetInt("victim"));
    if (g_hTongueParalyzeTimer != null) {
        KillTimer(g_hTongueParalyzeTimer);
        g_hTongueParalyzeTimer = null;
    }
    if (iAttacker <= 0 || !IsInfected(iAttacker) || !IsPlayerAlive(iAttacker))
        return;
    if (iVictim <= 0 || !IsSurvivor(iVictim) || IsFakeClient(iVictim) || !IsPlayerAlive(iVictim))
        return;
    PrintInflictedDamage(iVictim, iAttacker);
}

public void PrintInflictedDamage(int iVictim, int iAttacker) {
    int   iZombieClass = GetInfectedClass(iAttacker);
    float fGameTime    = GetGameTime();
    if ((g_fReported[iVictim][iAttacker] + g_fGhostDelay) >= fGameTime)
        return;
    int iRemainingHealth = GetClientHealth(iAttacker);
    if (!IsFakeClient(iAttacker)) {
        CPrintToChatEx(iVictim, iAttacker, "{green}[{default}DmgReport{green}]{default} {teamcolor}%N{default} {green}({default}%s{green}){default} had {olive}%d{default} health remaining!", iAttacker, L4D2_InfectedNames[iZombieClass], iRemainingHealth);
    } else {
        CPrintToChat(iVictim, "{green}[{default}DmgReport{green}]{default} %s had {olive}%d{default} health remaining!", L4D2_InfectedNames[iZombieClass], iRemainingHealth);
    }
    g_fReported[iVictim][iAttacker] = GetGameTime();
}

int IsTargetedSI(int iClient) {
    int iZombieClass = GetInfectedClass(iClient);
    if (iZombieClass == L4D2Infected_Charger || iZombieClass == L4D2Infected_Hunter || iZombieClass == L4D2Infected_Jockey || iZombieClass == L4D2Infected_Smoker)
        return iZombieClass;
    return -1;
}

bool IsParalyzed(int iClient) {
    return (GetGameTime() - GetEntDataFloat(iClient, FindSendPropInfo("CTerrorPlayer", "m_tongueVictimTimer")) >= 1.0) && (GetEntData(iClient, FindSendPropInfo("CTerrorPlayer", "m_tongueOwner")) > 0);
}