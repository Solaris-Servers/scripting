#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <left4dhooks>
#include <l4d2util>
#include <l4d2_penalty_bonus>
#include <readyup>
#include <pause>

#define MAXSTR 32

#define REPORT_EVENT_START (1 << 0)
#define REPORT_EVENT_END   (1 << 1)

#define PMODE_NODIST 1
#define PMODE_DIST   2

enum {
    eLoad,
    eClose,
    eUpdate
}

ConVar g_cvKeyValuesPath;

bool  g_bIsRoundLive;
bool  g_bHoldoutThisRound;                  // whether this map has a holdout event
bool  g_bHoldoutActive;                     // whether an event is ongoing
float g_fHoldoutPointFactor;

int g_iProgress;                            // progress through event
int g_iChrProgress[SurvivorCharacter_Size]; // per survivor character: the progress they made in an event (in seconds) -- used if they died earlier (-1 = never present)

int g_iHoldoutPointAbsolute;                // either this or factor is used, not both
int g_iHoldoutTime;
int g_iMapDistance;                         // current map distance (without deducted points for holdout pointsmode 2)
int g_iPointsBonus;                         // how many points the holdout bonus is worth
int g_iActualBonus;                         // what the players for this round actually get

int  g_iHoldoutStartHamId;                  // hammerid for start button
char g_szHoldoutStart[MAXSTR];              // 'ferry_button' (etc)
char g_szHoldoutStartClass[MAXSTR];         // 'logic_relay' (etc)
char g_szHoldoutStartHook[MAXSTR];          // 'OnTrigger' (etc)

int  g_iHoldoutEndHamId;                    // hammerid for end button
char g_szHoldoutEnd[MAXSTR];                // only included in case the timing varies or may be off...
char g_szHoldoutEndClass[MAXSTR];
char g_szHoldoutEndHook[MAXSTR];


/*
    Idea:
    -----
    Pure camping bonus, when survivors have no choice.
    Example: Swamp Fever 1 ferry:
        Survivors press button, the clock starts. It ends when the ferry
        actually arrives (not when they press the ferry button!).
        If they lived long enough for the ferry to arrive, they get
        the full holdout bonus.

*/

public Plugin myinfo = {
    name        = "Holdout Bonus",
    author      = "Tabun",
    description = "Gives bonus for (partially) surviving holdout/camping events. (Requires penalty_bonus.)",
    version     = "0.0.9",
    url         = "https://github.com/Tabbernaut/L4D2-Plugins"
};

public void OnPluginStart() {
    // cvars
    g_cvKeyValuesPath = CreateConVar(
    "sm_hbonus_configpath", "configs/holdoutmapinfo.txt",
    "The path to the holdoutmapinfo.txt with keyvalues for per-map holdout bonus settings.",
    FCVAR_NONE, false, 0.0, false, 0.0);
    g_cvKeyValuesPath.AddChangeHook(CvChg_KeyValuesPath);

    // events
    HookEvent("player_left_safe_area", Event_PlayerLeftSafeArea, EventHookMode_PostNoCopy);
    HookEvent("round_start",           Event_RoundStart,         EventHookMode_PostNoCopy);
    HookEvent("player_death",          Event_PlayerDeath,        EventHookMode_Post);
    HookEvent("defibrillator_used",    Event_DefibUsed,          EventHookMode_Post);

}

void CvChg_KeyValuesPath(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    KV_Update(eClose);
    KV_Update(eLoad);
    KV_Update(eUpdate);
}

public void OnMapStart() {
    // check for holdout event
    KV_Update(eClose);
    KV_Update(eLoad);
    KV_Update(eUpdate);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
    g_bIsRoundLive = false;

    // reset progress
    ResetTracking();

    if (!InSecondHalfOfRound())
        CreateTimer(1.0, Timer_SetDisplayPoints, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_SetDisplayPoints(Handle timer) {
    // store holdout bonus points (will get set again if round goes live for real)
    // this is just for display purposes
    g_iPointsBonus = g_iHoldoutPointAbsolute ? g_iHoldoutPointAbsolute : RoundFloat(float(L4D_GetVersusMaxCompletionScore()) * g_fHoldoutPointFactor);
    return Plugin_Stop;
}

void Event_PlayerLeftSafeArea(Event event, const char[] name, bool dontBroadcast) {
    OnRoundIsLive();
}

public void OnRoundIsLive() {
    if (!g_bHoldoutThisRound)
        return;

    if (g_bIsRoundLive)
        return;

    g_bIsRoundLive = true;

    g_iMapDistance = L4D_GetVersusMaxCompletionScore();
    g_iPointsBonus = g_iHoldoutPointAbsolute ? g_iHoldoutPointAbsolute : RoundFloat(float(g_iMapDistance) * g_fHoldoutPointFactor);
    L4D_SetVersusMaxCompletionScore(g_iMapDistance - g_iPointsBonus);

    // hook any triggers / buttons that may be required
    HookHoldOut();
}

// hook map logic to start the holdout tracking
void HookHoldOut() {
    int iEnt = -1;
    char szTargetName[128];

    // find and hook start entity
    if (strlen(g_szHoldoutStart) || g_iHoldoutStartHamId) {
        while ((iEnt = FindEntityByClassname(iEnt, g_szHoldoutStartClass)) != -1) {
            if (strlen(g_szHoldoutStart)) {
                GetEntityName(iEnt, szTargetName, sizeof(szTargetName));
                if (strcmp(szTargetName, g_szHoldoutStart, false) == 0) {
                    HookSingleEntityOutput(iEnt, g_szHoldoutStartHook, Hook_HoldOutStarts);
                    break;
                }
            } else if (g_iHoldoutStartHamId && GetEntProp(iEnt, Prop_Data, "m_iHammerID") == g_iHoldoutStartHamId) {
                HookSingleEntityOutput(iEnt, g_szHoldoutStartHook, Hook_HoldOutStarts);
                break;
            }
        }
    }

    // end
    if (strlen(g_szHoldoutEnd) || g_iHoldoutEndHamId) {
        while ((iEnt = FindEntityByClassname(iEnt, g_szHoldoutEndClass)) != -1) {
            if (strlen(g_szHoldoutEnd)) {
                GetEntityName(iEnt, szTargetName, sizeof(szTargetName));
                if (strcmp(szTargetName, g_szHoldoutEnd, false) == 0) {
                    HookSingleEntityOutput(iEnt, g_szHoldoutEndHook, Hook_HoldOutEnds);
                    break;
                }
            } else if (g_iHoldoutEndHamId && GetEntProp(iEnt, Prop_Data, "m_iHammerID") == g_iHoldoutEndHamId) {
                HookSingleEntityOutput(iEnt, g_szHoldoutEndHook, Hook_HoldOutEnds);
                break;
            }
        }
    }
}

// event tracking
void Hook_HoldOutStarts(const char[] szOutput, int iCaller, int iActivator, float fDelay) {
    if (g_bHoldoutActive)
        return;

    g_bHoldoutActive = true;

    // check every second
    CreateTimer(1.0, Timer_HoldOutCheck, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    ResetTracking();

    // take into account current survivor status
    int iChrIdx;

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (GetClientTeam(i) != L4D2Team_Survivor)
            continue;

        if (!IsPlayerAlive(i))
            continue;

        iChrIdx = IdentifySurvivorFast(i);
        g_iChrProgress[iChrIdx] = 0;
    }
}

void Hook_HoldOutEnds(const char[] szOutput, int iCaller, int iActivator, float fDelay) {
    // hooked on map logic
    // only use as safeguard / check for time
    if (g_bHoldoutActive) {
        // safeguard: make sure the whole time is awarded
        g_iProgress = g_iHoldoutTime;
        HoldOutEnds();
    }
}

public int PB_RequestFinalUpdate(int &iUpdate) {
    if (!g_bHoldoutActive)
        return iUpdate;

    // hold out ends, but note it's by request
    HoldOutEnds(true);
    iUpdate += g_iActualBonus;
    return iUpdate;
}

void HoldOutEnds(bool bRequest = false) {
    g_bHoldoutActive = false;
    g_iActualBonus = CalculateHoldOutBonus();

    if (!bRequest)
        PB_AddRoundBonus(g_iActualBonus);

    // only show bonus on event over
    DisplayBonusToAll();
}

void DisplayBonusToAll() {
    if (g_iActualBonus == 0)
        return;

    CPrintToChatAll("{blue}[{default}Holdout Bonus{blue}] {olive}%i{default} out of {olive}%i{default}.", g_iActualBonus, g_iPointsBonus);
}

// timer: every second while event is active
Action Timer_HoldOutCheck(Handle hTimer) {
    // stop if hook trigger already caught
    if (!g_bHoldoutActive)
        return Plugin_Stop;

    // ignore while paused
    if (IsInPause())
        return Plugin_Continue;

    g_iProgress++;
    // if set time entirely passed, stop the clock
    if (g_iProgress == g_iHoldoutTime) {
        HoldOutEnds();
        return Plugin_Stop;
    }

    return Plugin_Continue;
}

int CalculateHoldOutBonus() {
    // check status (of all survivors)
    // calculate bonus
    int   iTmpProgress = 0;
    float fBonusPart   = float(g_iPointsBonus) / float(L4D2Team_Size - 1);
    float fBonus       = 0.0;

    for (int iChrIdx = 0; iChrIdx < SurvivorCharacter_Size; iChrIdx++) {
        // skip ones dead from the start
        if (g_iChrProgress[iChrIdx] == -1)
            continue;

        // 0 means they made it until 'now'
        iTmpProgress = (g_iChrProgress[iChrIdx] == 0) ? g_iProgress : g_iChrProgress[iChrIdx];

        // add bonus for char
        fBonus += (g_iHoldoutTime != iTmpProgress) ? (fBonusPart / float(g_iHoldoutTime) * float(iTmpProgress)) : fBonusPart;
    }

    return RoundFloat(fBonus);
}

// death / revival tracking
void Event_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!g_bIsRoundLive || !g_bHoldoutActive)
        return;

    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)
        return;

    if (!IsClientInGame(iClient))
        return;

    if (GetClientTeam(iClient) != L4D2Team_Survivor)
        return;

    // stop progress for this character
    int iChrIdx = IdentifySurvivorFast(iClient);
    g_iChrProgress[iChrIdx] = g_iProgress;
}

void Event_DefibUsed(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!g_bIsRoundLive || !g_bHoldoutActive)
        return;

    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)
        return;

    if (!IsClientInGame(iClient))
        return;

    if (GetClientTeam(iClient) != L4D2Team_Survivor)
        return;

    // reset progress so it will be matched to g_iProgress
    int iChrIdx = IdentifySurvivorFast(iClient);
    g_iChrProgress[iChrIdx] = 0;
}

/** ---------
    Keyvalues
    --------- **/
void KV_Update(int iType) {
    static KeyValues kv;

    switch (iType) {
        case eLoad: {
            if (kv != null)
                delete kv;

            char szNameBuff[PLATFORM_MAX_PATH];
            g_cvKeyValuesPath.GetString(szNameBuff, sizeof(szNameBuff));
            BuildPath(Path_SM, szNameBuff, sizeof(szNameBuff), szNameBuff);

            kv = new KeyValues("HoldoutEvents");
            if (!kv.ImportFromFile(szNameBuff)) {
                LogError("Couldn't load HoldOutMapInfo data! (file: %s)", szNameBuff);
                delete kv;
                return;
            }
        }
        case eClose: {
            if (kv == null)
                return;

            delete kv;
        }
        case eUpdate: {
            // whether the map has a holdout event
            g_bHoldoutThisRound = false;

            // how much the event is worth as a fraction of map distance
            g_fHoldoutPointFactor = 0.0;

            // either this or factor is used, not both
            g_iHoldoutPointAbsolute = 0;

            // how long the event lasts
            g_iHoldoutTime = 0;

            if (kv == null)
                return;

            /*
                To Do:
                figure out a way to get information about how the event is started
                so we can do tracking.. targetname listening, I assume..
            */
            char szMap[64];
            GetCurrentMap(szMap, sizeof(szMap));

            // get keyvalues
            if (kv.JumpToKey(szMap)) {
                g_bHoldoutThisRound = view_as<bool>(kv.GetNum("holdout", 0));
                g_fHoldoutPointFactor = kv.GetFloat("pointfactor", 0.0);
                g_iHoldoutPointAbsolute = kv.GetNum("pointabsolute", 0);
                g_iHoldoutTime = kv.GetNum("time", 0);

                if (g_bHoldoutThisRound) {
                    kv.GetString("t_start", g_szHoldoutStart, MAXSTR, "");
                    g_iHoldoutStartHamId = kv.GetNum("t_s_hamid", 0);
                    kv.GetString("t_s_class", g_szHoldoutStartClass, MAXSTR, "");
                    kv.GetString("t_s_hook", g_szHoldoutStartHook, MAXSTR, "");

                    kv.GetString("t_end", g_szHoldoutEnd, MAXSTR, "");
                    g_iHoldoutEndHamId = kv.GetNum("t_e_hamid", 0);
                    kv.GetString("t_e_class", g_szHoldoutEndClass, MAXSTR, "");
                    kv.GetString("t_e_hook", g_szHoldoutEndHook, MAXSTR, "");
                }
            }
        }
    }
}

/** -------
    Support
    ------- **/
void ResetTracking() {
    g_iProgress    = 0;
    g_iActualBonus = 0;

    for (int i = 0; i < SurvivorCharacter_Size; i++) {
        g_iChrProgress[i] = -1;
    }
}

void GetEntityName(int iEnt, char[] sTargetName, int iSize) {
    GetEntPropString(iEnt, Prop_Data, "m_iName", sTargetName, iSize);
}