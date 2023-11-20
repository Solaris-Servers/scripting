#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

ConVar g_cvAllow;
int    g_iAllow;

public Plugin myinfo = {
    name        = "[L4D2] Fix First-Hit",
    author      = "Forgetest",
    description = "Fix first hit classes varying between halves and in scavenge staying the same for rounds.",
    version     = "2.4",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

public void OnPluginStart() {
    g_cvAllow = CreateConVar(
    "l4d2_scvng_firsthit_shuffle", "1",
    "Shuffle first hit classes. Affects only Scavenge mode. Value: 1 = Shuffle every round, 2 = Shuffle every match, 0 = Disable.",
    FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0, true, 2.0);
    g_iAllow = g_cvAllow.IntValue;
    g_cvAllow.AddChangeHook(ConVarChanged_Allow);

    HookEvent("round_start",             Event_RoundStart);
    HookEvent("round_end",               Event_RoundEnd);
    HookEvent("scavenge_round_finished", Event_ScavengeRoundFinished);
    HookEvent("scavenge_match_finished", Event_ScavengeMatchFinished);
    HookEvent("player_team",             Event_PlayerTeam);
    HookEvent("player_transitioned",     Event_PlayerTransitioned);
}

void ConVarChanged_Allow(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iAllow = g_cvAllow.IntValue;
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i)) continue;
        if (IsFakeClient(i))    continue;
        ResetClassSpawnSystem(i);
    }
}

void Event_RoundEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i)) continue;
        if (IsFakeClient(i))    continue;
        ResetClassSpawnSystem(i);
    }
}

void Event_ScavengeRoundFinished(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (g_iAllow == 1 && GameRules_GetProp("m_bInSecondHalfOfRound", 1)) {
        SetRandomSeed(GetTime());
        L4D2_SetFirstSpawnClass(GetRandomInt(1, 6));
    }
}

void Event_ScavengeMatchFinished(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (g_iAllow > 0) {
        SetRandomSeed(GetTime());
        L4D2_SetFirstSpawnClass(GetRandomInt(1, 6));
    }
}

void Event_PlayerTeam(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iTeam = eEvent.GetInt("team");
    if (iTeam != 3 || iTeam == eEvent.GetInt("oldteam"))
        return;

    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0 || !IsClientInGame(iClient))
        return;

    if (IsFakeClient(iClient)) {
        char szNetCls[64];
        GetEntityNetClass(iClient, szNetCls, sizeof(szNetCls));
        if (strcmp(szNetCls, "SurvivorBot") == 0) {
            SDKHook(iClient, SDKHook_SpawnPost, SDK_OnSpawnPost);
            return;
        }
    }

    ResetClassSpawnSystem(iClient);
}

void SDK_OnSpawnPost(int iClient) {
    if (IsClientInGame(iClient)) {
        // ForcePlayerSuicide(iClient);
        SetEntProp(iClient, Prop_Send, "m_zombieClass", 9);
    }
}

void Event_PlayerTransitioned(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0 || !IsClientInGame(iClient))
        return;
    ResetClassSpawnSystem(iClient);
}

void ResetClassSpawnSystem(int iClient) {
    static int iTimeOffs  = -1;
    static int iCountOffs = -1;

    if (iCountOffs == -1) {
        iCountOffs = FindSendPropInfo("CTerrorPlayer", "m_classSpawnCount");
        iTimeOffs  = iCountOffs - 9 * 4;
    }

    float fNow = GetGameTime();
    for (int i = 0; i <= 8; i++) {
        SetEntData(iClient, iCountOffs + i * 4, 0, 4);
        SetEntDataFloat(iClient, iTimeOffs + i * 4, fNow);
    }
}