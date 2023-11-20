#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <sdktools>
#include <colors>

#define Z_TANK 8
#define TEAM_INFECTED 3

#define ZOMBIEMANAGER_GAMEDATA  "l4d2_zombiemanager"
#define LEFT4FRAMEWORK_GAMEDATA "left4dhooks.l4d2"

Address pZombieManager = Address_Null;

ConVar  g_cvBypassFlowDistance;
ConVar  g_cvBypassExtraFlowDistance;

Handle  g_hFlowCheckTimer;

float   g_fFurthestFlow;
float   g_fBypassFlow;
float   g_fProgressFlowPercent;
float   g_fPushWarningPercent;

int     m_nPendingMobCount;

bool    g_bAnnouncedTankSpawn;
bool    g_bAnnouncedHordeResume;
bool    g_bAnnouncedHordeMax;
bool    g_bTankInPlay;
bool    g_bTankInPlayDelay;

public Plugin myinfo = {
    name        = "L4D2 Tank Horde Monitor",
    author      = "Derpduck, Visor (l4d2_horde_equaliser)",
    description = "Monitors and changes state of infinite hordes during tanks",
    version     = "1.3",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart() {
    InitGameData();
    g_cvBypassFlowDistance = FindConVar("director_tank_bypass_max_flow_travel");
    g_cvBypassExtraFlowDistance = CreateConVar(
    "l4d2_tank_bypass_extra_flow", "1500.0",
    "Extra allowed flow distance to bypass tanks during infinite events (0 = disabled)",
    FCVAR_NONE, true, 0.0);

    HookEvent("round_start",  RoundStartEvent, EventHookMode_PostNoCopy);
    HookEvent("round_end",    RoundEndEvent,   EventHookMode_PostNoCopy);
    HookEvent("tank_spawn",   TankSpawnEvent,  EventHookMode_PostNoCopy);
    HookEvent("player_death", TankDeathEvent);
}

void InitGameData() {
    GameData gmData = new GameData(LEFT4FRAMEWORK_GAMEDATA);
    if (!gmData) SetFailState("%s gamedata missing or corrupt", LEFT4FRAMEWORK_GAMEDATA);
    pZombieManager = gmData.GetAddress("ZombieManager");
    if (!pZombieManager) SetFailState("Couldn't find the 'ZombieManager' address");
    delete gmData;

    GameData gmData2 = new GameData(ZOMBIEMANAGER_GAMEDATA);
    if (!gmData2) SetFailState("%s gamedata missing or corrupt", ZOMBIEMANAGER_GAMEDATA);
    m_nPendingMobCount = gmData2.GetOffset("ZombieManager->m_nPendingMobCount");
    if (m_nPendingMobCount == -1) SetFailState("Failed to get offset 'ZombieManager->m_nPendingMobCount'.");
    delete gmData2;
}

public void RoundStartEvent(Event eEvent, const char[] szName, bool bDontBroadcast) {
    ResetWarnings();
    TimerCleanUp();
    g_fBypassFlow = 0.0;
    g_fFurthestFlow = 0.0;
    g_fProgressFlowPercent = 0.0;
}

public void RoundEndEvent(Event eEvent, const char[] szName, bool bDontBroadcast) {
    ResetWarnings();
    TimerCleanUp();
    g_fBypassFlow = 0.0;
    g_fFurthestFlow = 0.0;
    g_fProgressFlowPercent = 0.0;
}

public void OnMapEnd() {
    ResetWarnings();
    TimerCleanUp();
    g_fBypassFlow = 0.0;
    g_fFurthestFlow = 0.0;
    g_fProgressFlowPercent = 0.0;
}

public void TankSpawnEvent(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!g_bTankInPlay){
        g_bTankInPlay = true;
        // Find current highest flow, and where the bypass point is
        g_fFurthestFlow = L4D2_GetFurthestSurvivorFlow();
        g_fBypassFlow   = g_fFurthestFlow + g_cvBypassFlowDistance.FloatValue;
        if (IsInfiniteHordeActive() && !g_bAnnouncedTankSpawn)
            AnnounceTankSpawn();
    }
}

public void TankDeathEvent(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient > 0 && IsInfected(iClient) && IsTank(iClient))
        CreateTimer(0.1, Timer_CheckTank);
}

public void OnClientDisconnect(int iClient) {
    // Was a bot tank kicked
    if (iClient > 0 && IsInfected(iClient) && IsTank(iClient) && IsFakeClient(iClient))
        CreateTimer(0.1, Timer_CheckTank);
}

public Action Timer_CheckTank(Handle hTimer) {
    int iTankClient = FindTankClient();
    if (!iTankClient || !IsPlayerAlive(iTankClient)) {
        ResetWarnings();
        TimerCleanUp();
    }
    return Plugin_Stop;
}

public void AnnounceTankSpawn() {
    g_fProgressFlowPercent = GetFlowUntilBypass(g_fFurthestFlow, g_fBypassFlow);
    CPrintToChatAll("<{olive}Horde{default}> Horde has {blue}paused{default} due to tank in play! Progressing by {blue}%0.1f%%{default} will start the horde.", g_fProgressFlowPercent);
    g_bAnnouncedTankSpawn = true;
    // Begin repeating flow checker
    g_hFlowCheckTimer = CreateTimer(2.0, FlowCheckTimer, _, TIMER_REPEAT);
}

public Action FlowCheckTimer(Handle hTimer) {
    if (!g_bTankInPlay || g_bAnnouncedHordeResume || g_bAnnouncedHordeMax) {
        g_hFlowCheckTimer = null;
        return Plugin_Stop;
    }
    // Extra check to prevent rush warning misfiring if tank spawns on the same frame as a horde spawn
    if (!g_bTankInPlayDelay)
        g_bTankInPlayDelay = true;
    // Return furthest achieved survivor flow
    g_fFurthestFlow = L4D2_GetFurthestSurvivorFlow();
    // Print warnings if approaching the bypass limit
    float fWarningPercent = GetFlowUntilBypass(g_fFurthestFlow, g_fBypassFlow);
    if (g_fProgressFlowPercent - fWarningPercent >= 1.0){
        g_fProgressFlowPercent = fWarningPercent;
        CPrintToChatAll("<{olive}Horde{default}> {blue}%0.1f%%{default} left until horde starts...", fWarningPercent);
    }
    return Plugin_Continue;
}

public Action L4D_OnSpawnMob(int &iAmount) {
    /////////////////////////////////////
    // - Called on Event Hordes.
    // - Called on Panic Event Hordes.
    // - Called on Natural Hordes.
    // - Called on Onslaught (Mini-finale or finale Scripts)
    // - Not Called on Boomer Hordes.
    // - Not Called on z_spawn mob.
    ////////////////////////////////////
    if (g_bTankInPlay && IsInfiniteHordeActive()){
        // If survivors have already pushed past the extra bypass distance we can ignore this
        if (g_bAnnouncedHordeMax){
            return Plugin_Continue;
        } else {
            // Calculate how far survivors have pushed
            g_fFurthestFlow = L4D2_GetFurthestSurvivorFlow();
            float fPushAmount = (g_fFurthestFlow - g_fBypassFlow) / (g_cvBypassFlowDistance.FloatValue + g_cvBypassExtraFlowDistance.FloatValue);
            // Clamp values
            if (fPushAmount < 0.0){
                fPushAmount = 0.0;
            } else if (fPushAmount > 1.0){
                fPushAmount = 1.0;
            }
            // Have survivors pushed past the bypass point?
            if (!g_bAnnouncedHordeResume && g_bTankInPlayDelay && fPushAmount >= 0.05){
                g_fPushWarningPercent = fPushAmount;
                int iPushPercent = RoundToNearest(fPushAmount * 100.0);
                CPrintToChatAll("<{olive}Horde{default}> Horde has {blue}resumed{default} at {green}%i%% strength{default}, pushing will increase the horde.", iPushPercent);
                g_bAnnouncedHordeResume = true;
            }
            // Horde strength prints
            if (fPushAmount - g_fPushWarningPercent >= 0.20 && fPushAmount != 1.0 && g_bAnnouncedHordeResume){
                g_fPushWarningPercent = fPushAmount;
                int iPushPercent = RoundToNearest(fPushAmount * 100.0);
                CPrintToChatAll("<{olive}Horde{default}> Horde is at {green}%i%% strength{default}...", iPushPercent);
            }
            // Have survivors have pushed past the extra distance we allow?
            if (fPushAmount == 1.0){
                CPrintToChatAll("<{olive}Horde{default}> Survivors have pushed too far, horde is at {green}100%% strength{default}!");
                g_bAnnouncedHordeMax = true;
            }
            // Scale amount of horde per mob with how far survivors have pushed
            int iNewAmount = RoundToNearest(iAmount * fPushAmount);
            SetPendingMobCount(iNewAmount);
            iAmount = iNewAmount;
            return Plugin_Handled;
        }
    }
    return Plugin_Continue;
}

bool IsInfiniteHordeActive() {
    int iCountDown = GetHordeCountdown();
    return (iCountDown > -1 && iCountDown <= 10);
}

void SetPendingMobCount(int iCount) {
    StoreToAddress(pZombieManager + view_as<Address>(m_nPendingMobCount), iCount, NumberType_Int32);
}

int GetHordeCountdown() {
    return (CTimer_HasStarted(L4D2Direct_GetMobSpawnTimer())) ? RoundFloat(CTimer_GetRemainingTime(L4D2Direct_GetMobSpawnTimer())) : -1;
}

bool IsInfected(int iClient) {
    return (IsClientInGame(iClient) && GetClientTeam(iClient) == TEAM_INFECTED);
}

bool IsTank(int iClient) {
    return (GetEntProp(iClient, Prop_Send, "m_zombieClass") == Z_TANK);
}

int FindTankClient() {
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsInfected(i) || !IsTank(i) || !IsPlayerAlive(i))
            continue;
        // Found tank, return
        return i;
    }
    return 0;
}

float GetFlowUntilBypass(float fCurrentFlowValue, float fBypassFlowValue) {
    float fCurrentFlowPercent = (fCurrentFlowValue / L4D2Direct_GetMapMaxFlowDistance());
    float fBypassFlowPercent  = (fBypassFlowValue / L4D2Direct_GetMapMaxFlowDistance());
    float fResult             = (fBypassFlowPercent - fCurrentFlowPercent) * 100;
    if (fResult < 0)
        fResult = 0.0;
    return fResult;
}

public void TimerCleanUp() {
    if (g_hFlowCheckTimer != null){
        delete g_hFlowCheckTimer;
        g_hFlowCheckTimer = null;
    }
}

public void ResetWarnings() {
    g_bTankInPlay           = false;
    g_bTankInPlayDelay      = false;
    g_bAnnouncedTankSpawn   = false;
    g_bAnnouncedHordeResume = false;
    g_bAnnouncedHordeMax    = false;
    g_fPushWarningPercent   = 0.0;
}