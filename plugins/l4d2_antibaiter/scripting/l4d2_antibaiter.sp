/******************************************************************
*
* v0.1 ~ v1.2 by Visor
* ------------------------
* ------- Details: -------
* ------------------------
* > Creates a timer that runs checks to prevent Survivors from baiting attacks (Which is extremely boring)
* - Keeps track of Readyup, Event Hordes, Tanks, and Pauses to prevent sending in hordes unfairly.
*
* v1.3 by Sir (pointer to g_iHordeDelayChecks by devilesk)
* ------------------------
* ------- Details: -------
* ------------------------
* - Now resets internal "g_iHordeDelayChecks" on Round Live to prevent teams from suddenly getting a horde shortly after the round goes live. (Timer wouldn't even be visible at the top)
* - Now also resets saved "baiting" progress that didn't get reset after Event Hordes / Tank Spawns were triggered (Although, it'd be very unlikely that no SI would go in while these were active)
* - Fixed the Timer from showing up on the top while Tank was alive and SI just weren't attacking (to reset the timer) this was only a visual thing though, as the plugin already didn't spawn in horde when a Tank was up.
*
******************************************************************/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <sdkhooks>
#include <colors>
#include <l4d2util>
#include <pause>
#include <readyup>

#define CDIRECTOR_GAMEDATA "l4d2_cdirector" // m_PostMobDelayTimer offset

ConVar g_cvTimerStartDelay;
ConVar g_cvHordeCountdown;
ConVar g_cvMinProgressThreshold;
ConVar g_cvMaxInfected;
ConVar g_cvStopTimerOnBile;

bool   g_bIsRoundIsActive;
bool   g_bStopTimerOnBile;

float  g_fTimerStartDelay;
float  g_fHordeCountdown;
float  g_fMinProgress;
float  g_fStartingSurvivorCompletion;
float  g_fAliveSince[MAXPLAYERS + 1];

int    m_PostMobDelayTimerOffset;
int    g_iMaxInfected;
int    g_iHordeDelayChecks;
int    g_iZombieClass[MAXPLAYERS + 1];

public Plugin myinfo = {
    name        = "L4D2 Antibaiter",
    author      = "Visor, Sir (assisted by Devilesk), A1m`",
    description = "Makes you think twice before attempting to bait that shit",
    version     = "1.3.6",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart() {
    InitGameData();

    g_cvTimerStartDelay = CreateConVar(
    "l4d2_antibaiter_delay", "20",
    "Delay in seconds before the antibait algorithm kicks in",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_fTimerStartDelay = g_cvTimerStartDelay.FloatValue;
    g_cvTimerStartDelay.AddChangeHook(ConVarChanged);

    g_cvHordeCountdown = CreateConVar(
    "l4d2_antibaiter_horde_timer", "60",
    "Countdown in seconds to the panic horde",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_fHordeCountdown = g_cvHordeCountdown.FloatValue;
    g_cvHordeCountdown.AddChangeHook(ConVarChanged);

    g_cvMinProgressThreshold = CreateConVar(
    "l4d2_antibaiter_progress", "0.03",
    "Minimum progress the survivors must make to reset the antibaiter timer",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_fMinProgress = g_cvMinProgressThreshold.FloatValue;
    g_cvMinProgressThreshold.AddChangeHook(ConVarChanged);

    g_cvStopTimerOnBile = CreateConVar(
    "l4d2_antibaiter_bile_stop", "0",
    "Stop timer when a player is biled?",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bStopTimerOnBile = g_cvStopTimerOnBile.BoolValue;
    g_cvStopTimerOnBile.AddChangeHook(ConVarChanged);

    g_cvMaxInfected = FindConVar("z_max_player_zombies");
    g_iMaxInfected  = g_cvMaxInfected.IntValue;
    g_cvMaxInfected.AddChangeHook(MaxInfectedConVarChanged);

    HookEvent("round_start",           Event_RoundStart,    EventHookMode_PostNoCopy);
    HookEvent("round_end",             Event_RoundEnd,      EventHookMode_PostNoCopy);
    HookEvent("player_left_safe_area", Event_RoundGoesLive, EventHookMode_PostNoCopy);
    HookEvent("player_now_it",         Event_PlayerBiled,   EventHookMode_PostNoCopy);

    CreateTimer(1.0, AntibaiterThink, _, TIMER_REPEAT);
}

void InitGameData() {
    GameData gmData = new GameData(CDIRECTOR_GAMEDATA);
    if (!gmData) SetFailState("Gamedata '%s' missing or corrupt", CDIRECTOR_GAMEDATA);
    m_PostMobDelayTimerOffset = gmData.GetOffset("CDirectorScriptedEventManager->m_PostMobDelayTimer");
    if (m_PostMobDelayTimerOffset == -1) SetFailState("Invalid offset '%s'.", "CDirectorScriptedEventManager->m_PostMobDelayTimer");
    delete gmData;
}

void ConVarChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fTimerStartDelay = g_cvTimerStartDelay.FloatValue;
    g_fHordeCountdown  = g_cvHordeCountdown.FloatValue;
    g_fMinProgress     = g_cvMinProgressThreshold.FloatValue;
}

void MaxInfectedConVarChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iMaxInfected = g_cvMaxInfected.IntValue;
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bIsRoundIsActive = false;
}

void Event_RoundEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bIsRoundIsActive = false;
}

void Event_RoundGoesLive(Event eEvent, const char[] szName, bool bDontBroadcast) {
    StartRound();
}

void Event_PlayerBiled(Event eEvent, const char[] szName, bool bDontBroadcast) {
    bool bByBoom = eEvent.GetBool("by_boomer");
    if (bByBoom && g_bStopTimerOnBile) {
        g_iHordeDelayChecks = 0;
        if (IsCountdownRunning()) {
            HideCountdown();
            StopCountdown();
        }
    }
}

public void OnRoundIsLive() {
    StartRound();
}

void StartRound() {
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsInfected(i))    continue;
        if (!IsPlayerAlive(i)) continue;
        g_iZombieClass[i] = GetInfectedClass(i);
        g_fAliveSince[i]  = GetGameTime();
    }
    g_iHordeDelayChecks = 0; // Needs to be reset as it's not reset on Round End. (Prevents the Plugin from just picking up where it left off)
    g_bIsRoundIsActive  = true;
}

public Action AntibaiterThink(Handle hTimer) {
    if (!IsRoundActive())
        return Plugin_Handled;
    // These are all Events where we shouldn't even save Antibaiter's current status, invalidate the timer if it is active.
    if (IsPanicEventInProgress() || L4D2Direct_GetTankCount() > 0) {
        g_iHordeDelayChecks = 0;
        if (IsCountdownRunning()) {
            HideCountdown();
            StopCountdown();
        }
        return Plugin_Handled;
    }
    int iEligibleZombies;
    for (int i = 1; i <= MaxClients; i++)  {
        if (!IsInfected(i))  continue;
        if (IsFakeClient(i)) continue;
        if (IsPlayerAlive(i)) {
            g_iZombieClass[i] = GetInfectedClass(i);
            if (g_iZombieClass[i] > L4D2Infected_Common && g_iZombieClass[i] < L4D2Infected_Witch
            && g_fAliveSince[i] != -1.0 && GetGameTime() - g_fAliveSince[i] >= g_fTimerStartDelay)
                iEligibleZombies++;
        } else {
            g_fAliveSince[i] = -1.0;
            g_iHordeDelayChecks = 0;
            HideCountdown();
            StopCountdown();
        }
    }
    // 5th SI / spectator bug workaround
    if (iEligibleZombies > g_iMaxInfected)
        return Plugin_Continue;
    if (iEligibleZombies == g_iMaxInfected) {
        float fSurvivorCompletion = GetMaxSurvivorCompletion();
        float fProgress = fSurvivorCompletion - g_fStartingSurvivorCompletion;
        if (fProgress <= g_fMinProgress && g_iHordeDelayChecks >= RoundToNearest(g_fTimerStartDelay)) {
            if (IsCountdownRunning()) {
                if (HasCountdownElapsed()) {
                    HideCountdown();
                    LaunchHorde();
                    g_iHordeDelayChecks = 0;
                    CPrintToChatAll("{blue}[{default}Anti-baiter{blue}]{default} Prepare for the incoming horde!");
                }
            } else {
                InitiateCountdown();
            }
        } else {
            if (g_iHordeDelayChecks == 0)
                g_fStartingSurvivorCompletion = fSurvivorCompletion;
            if (fProgress > g_fMinProgress) {
                g_fStartingSurvivorCompletion = fSurvivorCompletion;
                g_iHordeDelayChecks = 0;
            }
            g_iHordeDelayChecks++;
            HideCountdown();
            StopCountdown();
        }
    }
    return Plugin_Handled;
}

public void L4D_OnEnterGhostState(int iClient) {
    g_iZombieClass[iClient] = GetInfectedClass(iClient);
    g_fAliveSince [iClient] = GetGameTime();
}

/*******************************/
/** Horde/countdown functions **/
/*******************************/

void InitiateCountdown() {
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i)) continue;
        if (IsFakeClient(i))    continue;
        ShowVGUIPanel(i, "ready_countdown", _, true);
    }
    CTimer_Start(CountdownPointer(), g_fHordeCountdown);
}

bool IsCountdownRunning() {
    return CTimer_HasStarted(CountdownPointer());
}

bool HasCountdownElapsed() {
    return CTimer_IsElapsed(CountdownPointer());
}

void StopCountdown() {
    CTimer_Invalidate(CountdownPointer());
}

void HideCountdown() {
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i)) continue;
        if (IsFakeClient(i))    continue;
        ShowVGUIPanel(i, "ready_countdown", _, false);
    }
}

void LaunchHorde() {
    int iInfoDirector = MaxClients + 1;
    if ((iInfoDirector = FindEntityByClassname(iInfoDirector, "info_director")) != INVALID_ENT_REFERENCE) {
        AcceptEntityInput(iInfoDirector, "ForcePanicEvent");
    }
}

CountdownTimer CountdownPointer() {
    return L4D2Direct_GetScavengeRoundSetupTimer();
}

CountdownTimer PostMobDelayTimer() {
    return view_as<CountdownTimer>(L4D_GetPointer(POINTER_EVENTMANAGER) + view_as<Address>(m_PostMobDelayTimerOffset));
}

/************/
/** Stocks **/
/************/
float GetMaxSurvivorCompletion() {
    float fFlow = 0.0;
    for (int i = 1; i <= MaxClients; i++) {
        // Prevent rushers from convoluting the logic
        if (!IsSurvivor(i))     continue;
        if (!IsPlayerAlive(i))  continue;
        if (IsIncapacitated(i)) continue;
        fFlow = L4D2Util_GetMaxFloat(fFlow, L4D2Direct_GetFlowDistance(i));
    }
    return (fFlow / L4D2Direct_GetMapMaxFlowDistance());
}

// Сan use prop 'm_bPanicEventInProgress' better?
// director_force_panic_event & car alarms etc.
bool IsPanicEventInProgress() {
    CountdownTimer pPanicCountdown = PostMobDelayTimer();
    if (!CTimer_IsElapsed(pPanicCountdown))
        return true;
    if (CTimer_HasStarted(L4D2Direct_GetMobSpawnTimer()))
        return (RoundFloat(CTimer_GetRemainingTime(L4D2Direct_GetMobSpawnTimer())) <= 10.0);
    return false;
}

bool IsRoundActive() {
    return g_bIsRoundIsActive && !IsInPause();
}