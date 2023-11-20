#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

ConVar g_cvKillOnCrash;

public Plugin myinfo = {
    name        = "AI Tank Gank",
    author      = "Stabby",
    version     = "0.2",
    description = "Kills tanks on pass to AI."
};

public void OnPluginStart() {
    g_cvKillOnCrash = CreateConVar(
    "tankgank_killoncrash", "0",
    "If 0, tank will not be killed if the player that controlled it crashes.",
    FCVAR_NONE, true,  0.0, true, 1.0);
    HookEvent("player_bot_replace", Event_PlayerBotReplace);
}

void Event_PlayerBotReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iPrevTank = GetClientOfUserId(eEvent.GetInt("player"));
    int iNewTank  = GetClientOfUserId(eEvent.GetInt("bot"));
    if (GetClientTeam(iNewTank) != 3) return;
    if (GetEntProp(iNewTank, Prop_Send, "m_zombieClass") != 8) return;
    if (iPrevTank == 0 && !g_cvKillOnCrash.BoolValue) {
        CreateTimer(1.0, Timed_CheckAndKill, GetClientUserId(iNewTank), TIMER_FLAG_NO_MAPCHANGE);
        return;
    }
    ForcePlayerSuicide(iNewTank);
}

Action Timed_CheckAndKill(Handle hTimer, any aUserId) {
    int iNewTank = GetClientOfUserId(aUserId);
    if (iNewTank <= 0) return Plugin_Stop;
    if (IsFakeClient(iNewTank)) ForcePlayerSuicide(iNewTank);
    return Plugin_Stop;
}