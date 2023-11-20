/*
    Changelog
    ---------
        0.7 (Forgetest)
            - Fix sounds being emited from players other than jockeys.
        0.6 (A1m`)
            - Removed unnecessary comments, unnecessary functions and extra code.
            - Fixed return value in repeat timer, timer must be called more than 1 time. Replaced return value from 'Plugin_Stop' to 'Plugin_Continue'.
            - Fixed a possible problem when starting a new timer, the old one will always be deleted.
        0.5 (A1m`)
            -Fixed warnings when compiling a plugin on sourcemod 1.11.
        0.4 (Sir)
            - Refined the code a bit, simpler code.
            - Fixes an issue with timers still existing on players.
        0.3 (Sir)
            - Updated the code to the latest syntax.
            - Add additional checks/optimization to resolve potential and existing issues with 0.2-alpha.
        0.2-alpha (robex)
            - make sound always at a regular interval
        0.1b (Tabun)
            - fix error log spam
        0.1a (Tabun)
            - plays sound at set time after jockey spawns up
            - but only if the jockey isn't already making noise
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks> // For checking respawns.

#define TEAM_INFECTED           3
#define ZC_JOCKEY               5

ConVar g_cvJockeyVoiceInterval;

Handle g_hJockeySoundTimer[MAXPLAYERS + 1] = {null, ...};

static const char g_szJockeySound[][] = {
    "player/jockey/voice/idle/jockey_recognize02.wav",
    "player/jockey/voice/idle/jockey_recognize06.wav",
    "player/jockey/voice/idle/jockey_recognize07.wav",
    "player/jockey/voice/idle/jockey_recognize08.wav",
    "player/jockey/voice/idle/jockey_recognize09.wav",
    "player/jockey/voice/idle/jockey_recognize10.wav",
    "player/jockey/voice/idle/jockey_recognize11.wav",
    "player/jockey/voice/idle/jockey_recognize12.wav",
    "player/jockey/voice/idle/jockey_recognize13.wav",
    "player/jockey/voice/idle/jockey_recognize15.wav",
    "player/jockey/voice/idle/jockey_recognize16.wav",
    "player/jockey/voice/idle/jockey_recognize17.wav",
    "player/jockey/voice/idle/jockey_recognize18.wav",
    "player/jockey/voice/idle/jockey_recognize19.wav",
    "player/jockey/voice/idle/jockey_recognize20.wav",
    "player/jockey/voice/idle/jockey_recognize24.wav"
};

public Plugin myinfo = {
    name        = "Unsilent Jockey",
    author      = "Tabun, robex, Sir, A1m`",
    description = "Makes jockeys emit sound constantly.",
    version     = "0.7",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart() {
    // ConVars
    g_cvJockeyVoiceInterval = CreateConVar(
    "sm_unsilentjockey_interval", "2.0",
    "Interval between forced jockey sounds.",
    FCVAR_NONE, true, 0.0, false, 0.0);

    // Events
    HookEvent("player_spawn",    Event_PlayerSpawn);
    HookEvent("player_death",    Event_PlayerDeath);
    HookEvent("player_team",     Event_PlayerTeam);
    HookEvent("jockey_ride",     Event_JockeyRideStart);
    HookEvent("jockey_ride_end", Event_JockeyRideEnd);
}

public void OnMapStart() {
    // Precache
    for (int i = 0; i < sizeof(g_szJockeySound); i++) {
        PrecacheSound(g_szJockeySound[i], true);
    }
}

public void OnMapEnd() {
    for (int i = 1; i <= MaxClients; i++) {
        g_hJockeySoundTimer[i] = null;
    }
}

public void L4D_OnEnterGhostState(int iClient) {
    // Simply disable the timer if the client enters ghost mode and has the timer set.
    ChangeJockeyTimerStatus(iClient, false);
}

void Event_PlayerSpawn(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)             return;
    if (!IsClientInGame(iClient)) return;

    // Kill the sound timer if it exists (this will also trigger if you switch to Tank)
    ChangeJockeyTimerStatus(iClient, false);

    if (GetClientTeam(iClient) != TEAM_INFECTED)
        return;
    if (GetEntProp(iClient, Prop_Send, "m_zombieClass") != ZC_JOCKEY)
        return;

    // Setup the sound interval
    RequestFrame(JockeyRideEnd_NextFrame, GetClientUserId(iClient));
}

void Event_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)             return;
    if (!IsClientInGame(iClient)) return;
    ChangeJockeyTimerStatus(iClient, false); // Kill the sound timer if it exists
}

void Event_PlayerTeam(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    ChangeJockeyTimerStatus(iClient, false); // Kill the sound timer if it exists
}

void Event_JockeyRideStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    // Jockey ridin' a Survivor
    ChangeJockeyTimerStatus(iClient, false);
}

void Event_JockeyRideEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    RequestFrame(JockeyRideEnd_NextFrame, GetClientUserId(iClient)); // Check if our beloved Jockey is alive on the very next frame
}

void JockeyRideEnd_NextFrame(any iUserId) {
    int iClient = GetClientOfUserId(iUserId);
    if (iClient <= 0)             return;
    if (!IsClientInGame(iClient)) return;
    if (!IsPlayerAlive(iClient))  return;
    if (GetEntProp(iClient, Prop_Send, "m_isGhost"))
        return;
    // Resume our sound spam as the Jockey is still alive
    if (GetClientTeam(iClient) == TEAM_INFECTED && GetEntProp(iClient, Prop_Send, "m_zombieClass") == ZC_JOCKEY)
        ChangeJockeyTimerStatus(iClient, true);
}

void ChangeJockeyTimerStatus(int iClient, bool bEnable) {
    if (g_hJockeySoundTimer[iClient] != null) {
        KillTimer(g_hJockeySoundTimer[iClient], false);
        g_hJockeySoundTimer[iClient] = null;
    }
    if (bEnable) {
        DataPack dp;
        g_hJockeySoundTimer[iClient] = CreateDataTimer(g_cvJockeyVoiceInterval.FloatValue, Timer_DelayedJockeySound, dp, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
        dp.WriteCell(iClient);
        dp.WriteCell(GetClientUserId(iClient));
    }
}

Action Timer_DelayedJockeySound(Handle hTimer, DataPack dp) {
    dp.Reset();
    int iClient = dp.ReadCell();
    int iUserId = dp.ReadCell();

    if (iClient != GetClientOfUserId(iUserId)) {
        g_hJockeySoundTimer[iClient] = null;
        return Plugin_Stop;
    }

    int iRndPick = GetRandomInt(0, (sizeof(g_szJockeySound) - 1));
    EmitSoundToAll(g_szJockeySound[iRndPick], iClient, SNDCHAN_VOICE);
    return Plugin_Continue;
}