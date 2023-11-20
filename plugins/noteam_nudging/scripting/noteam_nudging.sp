#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define NOAVOID_ADDTIME 2.0

public Plugin myinfo = {
    name        = "[L4D/L4D2]noteam_nudging",
    author      = "Lux",
    description = "Prevents small push effect between survior players, bots still get pushed.",
    version     = "1.0",
    url         = "-"
};

public void OnPluginStart() {
    CreateTimer(1.0, UpdateAvoid, _, TIMER_REPEAT);
}

public Action UpdateAvoid(Handle hTimer) {
    float flTime = GetGameTime();
    float flPropTime;
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i) || IsFakeClient(i))
            continue;
        flPropTime = GetEntPropFloat(i, Prop_Send, "m_noAvoidanceTimer", 1);
        if (flPropTime > flTime + NOAVOID_ADDTIME)
            continue;
        SetEntPropFloat(i, Prop_Send, "m_noAvoidanceTimer", flTime + NOAVOID_ADDTIME, 1);
    }
    return Plugin_Continue;
}