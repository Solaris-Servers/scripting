#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <l4d2util>
#include <left4dhooks>
#include <colors>

#include <solaris/chat>
#include <solaris/votes>
#include <solaris/team_manager>
#include <solaris/stocks>

#undef REQUIRE_PLUGIN
#include <bosspercent>
#include <witch_and_tankifier>
#define REQUIRE_PLUGIN

// ========================
//  Defines
// ========================
#define NULL_VELOCITY view_as<float>({0.0, 0.0, 0.0})

enum {
    ReadyMode_None = 0,
    ReadyMode_PlayerReady,
    ReadyMode_TeamReady,
    ReadyMode_Loading
};

enum {
    WL_NotInWater = 0,
    WL_Feet,
    WL_Waist,
    WL_Eyes
};

// ========================
//  Plugin Variables
// ========================
/** Forwards **/
GlobalForward g_fwdPreInitiate;
GlobalForward g_fwdInitiate;
GlobalForward g_fwdPreCountdown;
GlobalForward g_fwdCountdown;
GlobalForward g_fwdPreLive;
GlobalForward g_fwdLive;
GlobalForward g_fwdCountdownCancelled;
GlobalForward g_fwdPlayerReady;
GlobalForward g_fwdTeamReady;
GlobalForward g_fwdPlayerUnready;
GlobalForward g_fwdTeamUnready;

/** Game Cvars **/
ConVar g_cvDirectorNoSpecials;
ConVar g_cvDirectorNoBosses;
ConVar g_cvGod;
ConVar g_cvSurvivorBotStop;
ConVar g_cvSurvivorLimit;
ConVar g_cvInfectedLimit;
ConVar g_cvInfiniteAmmo;

/** Plugin Cvars **/
// Basic
ConVar g_cvReadyEnabled;
ConVar g_cvReadyCfgName;
ConVar g_cvReadyServerName;
ConVar g_cvReadyServerNum;
// Game
ConVar g_cvReadyDisableSpawns;
ConVar g_cvReadySurvivorFreeze;
// Sound
ConVar g_cvReadyEnableSound;
ConVar g_cvReadyNotifySound;
ConVar g_cvReadyCountdownSound;
ConVar g_cvReadyLiveSound;
ConVar g_cvReadyChuckle;
ConVar g_cvReadySecret;
// Action
ConVar g_cvReadyDelay;
ConVar g_cvReadyForceExtra;
ConVar g_cvReadyUnbalancedStart;
ConVar g_cvReadyUnbalancedMin;

/** Standard Ready Up **/
int  g_iReadyUpMode;
bool g_bInLiveCountdown;
bool g_bInReadyUp;
bool g_bIsForceStart;
bool g_bReadySurvFreeze;

/** Reason enum for Countdown cancelling **/
enum DisruptType {
    eReadyStatus,
    eTeamShuffle,
    ePlayerDisconnect,
    eAdminAbort,
    eDisruptTypeSize
};

/** Boss Percent **/
bool g_bIsBossPctAvailable;

/** Witch and Tank spawn **/
bool g_bIsWitchAndTankifierAvailable;

/** Sub modules is included here **/
#include "readyup/action.sp"
#include "readyup/command.sp"
#include "readyup/footer.sp"
#include "readyup/game.sp"
#include "readyup/native.sp"
#include "readyup/panel.sp"
#include "readyup/player.sp"
#include "readyup/setup.sp"
#include "readyup/sound.sp"
#include "readyup/util.sp"

public Plugin myinfo = {
    name        = "L4D2 Ready-Up with convenience fixes",
    author      = "CanadaRox, Target",
    description = "New and improved ready-up plugin with optimal for convenience.",
    version     = "10.2.3",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

// ========================
//  Plugin Setup
// ========================
public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    SetupNatives();
    SetupForwards();
    RegPluginLibrary("readyup");
    return APLRes_Success;
}

public void OnPluginStart() {
    SetupConVars();
    SetupCommands();

    g_iReadyUpMode = g_cvReadyEnabled.IntValue;
    g_cvReadyEnabled.AddChangeHook(CvarChg_ReadyUpMode);

    g_bReadySurvFreeze = g_cvReadySurvivorFreeze.BoolValue;
    g_cvReadySurvivorFreeze.AddChangeHook(CvarChg_SurvFreeze);

    HookEvent("round_start",           Event_RoundStart,         EventHookMode_Pre);
    HookEvent("player_team",           Event_PlayerTeam,         EventHookMode_Post);
    HookEvent("gameinstructor_draw",   Event_GameInstructorDraw, EventHookMode_PostNoCopy);
    HookEvent("survival_round_start",  Event_SurvivalRoundStart, EventHookMode_PostNoCopy);
    HookEvent("player_left_safe_area", Event_PlayerLeftSafeArea, EventHookMode_PostNoCopy);
}

public void OnPluginEnd() {
    InitiateLive(false);
}

public void OnAllPluginsLoaded() {
    g_bIsBossPctAvailable           = LibraryExists("l4d_boss_percent");
    g_bIsWitchAndTankifierAvailable = LibraryExists("witch_and_tankifier");
}

public void OnLibraryAdded(const char[] szName) {
    if (strcmp(szName, "l4d_boss_percent") == 0)
        g_bIsBossPctAvailable = true;

    if (strcmp(szName, "witch_and_tankifier") == 0)
        g_bIsWitchAndTankifierAvailable = true;
}

public void OnLibraryRemoved(const char[] szName) {
    if (strcmp(szName, "l4d_boss_percent") == 0)
        g_bIsBossPctAvailable = false;

    if (strcmp(szName, "witch_and_tankifier") == 0)
        g_bIsWitchAndTankifierAvailable = false;
}

void FillServerNamer(char[] szServerNamer) {
    char szBuffer    [64];
    char szServerName[16];
    char szServerNum  [4];
    g_cvReadyServerName.GetString(szBuffer, sizeof szBuffer);
    if (FindConVar(szBuffer) == null) {
        FindConVar("hostname").GetString(szServerNamer, sizeof(szBuffer));
        return;
    }

    FindConVar(szBuffer).GetString(szServerName, sizeof(szServerName));
    g_cvReadyServerNum.GetString(szBuffer, sizeof szBuffer);
    if (FindConVar(szBuffer) == null) {
        FindConVar("hostname").GetString(szServerNamer, sizeof(szBuffer));
        return;
    }

    FindConVar(szBuffer).GetString(szServerNum, sizeof(szServerNum));
    // Done, we got server name and num
    FormatEx(szServerNamer, sizeof(szBuffer), "%s #%s", szServerName, szServerNum);
}

// ========================
//  ConVar Change
// ========================
void CvarChg_ReadyUpMode(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iReadyUpMode = cv.IntValue;
    if (!g_bInReadyUp)
        return;

    InitiateLive(false);
    InitiateReadyUp();
}

void CvarChg_SurvFreeze(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bReadySurvFreeze = cv.BoolValue;
    if (g_bInReadyUp) {
        ReturnTeamToSaferoom(L4D2Team_Survivor);
        SetTeamFrozen(L4D2Team_Survivor, g_bReadySurvFreeze);
    }
}

// ========================
//  Events
// ========================
void EntO_OnGameplayStart(const char[] szOutput, int iCaller, int iActivator, float fDelay) {
    InitiateReadyUp();
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    InitiateReadyUp(false);
}

void Event_GameInstructorDraw(Event eEvent, const char[] szName, bool bDontBroadcast) {
    // Workaround for restarting countdown after scavenge intro
    CreateTimer(0.1, Timer_RestartCountdowns, false, TIMER_FLAG_NO_MAPCHANGE);
}

void Event_PlayerTeam(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (g_iReadyUpMode == ReadyMode_PlayerReady || g_iReadyUpMode == ReadyMode_TeamReady) {
        int iUserId = eEvent.GetInt("userid");
        int iClient = GetClientOfUserId(iUserId);
        if (iClient <= 0)
            return;

        if (IsFakeClient(iClient))
            return;

        if (TM_IsPlayerRespectating(iClient))
            return;

        if (!g_bInReadyUp)
            return;

        if (g_bIsForceStart)
            return;

        int iOldTeam = eEvent.GetInt("oldteam");

        if (iOldTeam == L4D2Team_Survivor || iOldTeam == L4D2Team_Infected) {
            SetButtonTime(iClient);
            SetPlayerReady(iClient, false);
            SetTeamReady(iOldTeam,  false);

            if (eEvent.GetBool("disconnect")) {
                CancelFullReady(iClient, ePlayerDisconnect); // Player disconnecting
                return;
            }

            if (iOldTeam > L4D2Team_Spectator) {
                CancelFullReady(iClient, eTeamShuffle); // Player in-game swapping team
            }
        }
    }
}

void Event_SurvivalRoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    InitiateLive(false);
}

void Event_PlayerLeftSafeArea(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (SDK_IsSurvival())
        return;

    InitiateLive(false);
}

// ========================
//  Forwards
// ========================
public void OnMapStart() {
    PrecacheSounds();
    HookEntityOutput("info_director", "OnGameplayStart", EntO_OnGameplayStart);
}

/* This ensures all cvars are reset if the map is changed during ready-up */
public void OnMapEnd() {
    if (g_bInReadyUp)
        InitiateLive(false);
    PanelEnd();

}

public void OnClientPostAdminCheck(int iClient) {
    if (!g_bInReadyUp)
        return;

    if (!SDK_IsScavenge())
        return;

    if (IsFakeClient(iClient))
        return;

    ToggleCountdownPanel(false, iClient);
}

public void OnClientDisconnect(int iClient) {
    SetPlayerHiddenPanel(iClient, false);
    SetPlayerReady(iClient, false);
}

/* No need to do any other checks since it seems like this is required no matter what since the intros unfreezes players after the animation completes */
public void OnPlayerRunCmdPost(int iClient, int iButtons, int iImpulse, const float fVel[3], const float fAngles[3], int iWeapon, int iSubType, int iCmdNum, int iTickCount, int iSeed, const int iMouse[2]) {
    if (!g_bInReadyUp || !IsClientInGame(iClient))
        return;

    if (!IsFakeClient(iClient)) {
        static int iLastMouse[MAXPLAYERS + 1][2];
        // Mouse Movement Check
        if (iMouse[0] != iLastMouse[iClient][0] || iMouse[1] != iLastMouse[iClient][1]) {
            iLastMouse[iClient][0] = iMouse[0];
            iLastMouse[iClient][1] = iMouse[1];
            SetButtonTime(iClient);
        } else if (iButtons || iImpulse) {
            SetButtonTime(iClient);
        }
    }

    if (GetClientTeam(iClient) == L4D2Team_Survivor) {
        if (g_bReadySurvFreeze || g_bInLiveCountdown) {
            MoveType iMoveType = GetEntityMoveType(iClient);
            if (iMoveType != MOVETYPE_NONE && iMoveType != MOVETYPE_NOCLIP)
                SetClientFrozen(iClient, true);
        } else {
            if (GetEntProp(iClient, Prop_Send, "m_nWaterLevel") == WL_Eyes)
                ReturnPlayerToSaferoom(iClient, false);
        }
    }
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int iClient) {
    switch (g_iReadyUpMode) {
        case ReadyMode_None: {
            return Plugin_Continue;
        }
        case ReadyMode_PlayerReady, ReadyMode_TeamReady: {
            if (g_bInReadyUp) {
                CreateTimer(0.1, Timer_RestartCountdowns, false, TIMER_FLAG_NO_MAPCHANGE);
                ReturnPlayerToSaferoom(iClient, false);
                return Plugin_Handled;
            }
        }
        case ReadyMode_Loading: {
            if (!TM_IsFinishedLoading()) {
                CreateTimer(0.1, Timer_RestartCountdowns, false, TIMER_FLAG_NO_MAPCHANGE);
                ReturnPlayerToSaferoom(iClient, false);
                PrintHintText(iClient, "Please wait for others.\n%ds remaining!", TM_LoadingTimeRemaining());
                return Plugin_Handled;
            }
        }
    }

    return Plugin_Continue;
}

// ========================
//  Command Listener
// ========================
public void SolarisChat_OnChatMessagePost(const int iClient, const int iArgs, const int iTeam, const bool bTeamChat, const ArrayList aRecipients, const char[] szTagColor, const char[] szTag, const char[] szNameColor, const char[] szName, const char[] szMsgColor, const char[] szMsg) {
    SetButtonTime(iClient);
}

Action Vote_Callback(int iClient, const char[] szCommand, int iArgs) {
    // Fast ready / unready through default keybinds for voting
    if (!iClient || (SolarisVotes_IsVoteInProgress() && SolarisVotes_IsClientInVotePool(iClient)))
        return Plugin_Continue;
    char szArg[8];
    GetCmdArg(1, szArg, sizeof(szArg));
    if (strcmp(szArg, "Yes", false) == 0) {
        Cmd_Ready(iClient, 0);
    } else if (strcmp(szArg, "No", false) == 0) {
        Cmd_Unready(iClient, 0);
    }
    return Plugin_Continue;
}