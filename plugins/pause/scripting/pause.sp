#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <readyup>
#include <sourcecomms>

#include <l4d2util/constants>
#include <l4d2util/stocks>
#include <l4d2util/infected>

#include <solaris/votes>
#include <solaris/team_manager>

#define SRV_NAME_LENGTH  32
#define TEAM_NAME_LENGTH 16

#define BLIP2    "buttons/blip2.wav"
#define BUTTON22 "buttons/button22.wav"

char g_szTeamString[][] = {
    "None",
    "Spectator",
    "Survivors",
    "Infected"
};

enum /*eSound*/ {
    eBlip2 = 0,
    eButton22
};

Handle g_hDeferredPauseTimer;
Handle g_hReadyCountdownTimer;

ConVar g_cvHostName;
ConVar g_cvNoclipDuringPause;
ConVar g_cvPausable;

ConVar g_cvPauseAllow;
ConVar g_cvReadyBlips;
ConVar g_cvReadyDelay;
ConVar g_cvPauseDelay;
ConVar g_cvPauseLimit;

bool   g_bRoundEnd;
bool   g_bAdminPause;
bool   g_bIsPaused;
bool   g_bTeamReady      [L4D2Team_Size];
bool   g_bHiddenManually [MAXPLAYERS + 1];
bool   g_bHiddenPanel    [MAXPLAYERS + 1];

char   g_szServerName    [SRV_NAME_LENGTH];
char   g_szInitiatorName [MAX_NAME_LENGTH];
char   g_szInitiatorTeam [TEAM_NAME_LENGTH];

float  g_fPauseTime;

int    g_iPauseDelay;
int    g_iReadyDelay;

Panel
    g_MenuPanel;

StringMap
    g_PauseTrie;

GlobalForward
    g_PauseForward,
    g_UnpauseForward;

public Plugin myinfo = {
    name        = "Pause plugin",
    author      = "CanadaRox",
    description = "Adds pause functionality without breaking pauses",
    version     = "8.0",
    url         = ""
};

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    CreateNative("IsInPause",    Native_IsInPause);
    CreateNative("ForcePause",   Native_SetPause);   // Native for solaris_team_manager
    CreateNative("ForceUnpause", Native_SetUnpause); // Native for solaris_team_manager
    g_PauseForward   = new GlobalForward("OnPause",   ET_Event);
    g_UnpauseForward = new GlobalForward("OnUnpause", ET_Event);
    RegPluginLibrary("pause");
    return APLRes_Success;
}

public void OnPluginStart() {
    RegConsoleCmd("sm_hide",        Cmd_Hide,        "Hides the pause panel so other menus can be seen");
    RegConsoleCmd("sm_show",        Cmd_Show,        "Shows a hidden pause panel");
    RegConsoleCmd("sm_pause",       Cmd_Pause,       "Pauses the game");
    RegConsoleCmd("sm_unpause",     Cmd_Unpause,     "Marks your iTeam as ready for an unpause");
    RegConsoleCmd("sm_ready",       Cmd_Unpause,     "Marks your iTeam as ready for an unpause");
    RegConsoleCmd("sm_r",           Cmd_Unpause,     "Marks your iTeam as ready for an unpause");
    RegConsoleCmd("sm_unready",     Cmd_Unready,     "Marks your iTeam as ready for an unpause");
    RegConsoleCmd("sm_nr",          Cmd_Unready,     "Marks your iTeam as ready for an unpause");
    RegConsoleCmd("sm_toggleready", Cmd_ToggleReady, "Toggles your iTeam's ready status");

    RegAdminCmd("sm_forcepause",   Cmd_ForcePause,   ADMFLAG_BAN, "Pauses the game and only allows admins to unpause");
    RegAdminCmd("sm_forceunpause", Cmd_ForceUnpause, ADMFLAG_BAN, "Unpauses the game regardless of iTeam ready status.  Must be used to unpause admin pauses");

    AddCommandListener(Unpause_Callback, "unpause");
    AddCommandListener(Vote_Callback,    "Vote");

    g_cvPausable          = FindConVar("sv_pausable");
    g_cvNoclipDuringPause = FindConVar("sv_noclipduringpause");

    g_cvHostName = FindConVar("hostname");
    g_cvHostName.GetString(g_szServerName, sizeof(g_szServerName));
    g_cvHostName.AddChangeHook(HostNameChanged);

    g_cvPauseAllow = CreateConVar(
    "sm_pause_allow", "1",
    "Allow players to pause the game",
    FCVAR_NONE, true, 0.0, true, 1.0);

    g_cvPauseDelay = CreateConVar(
    "sm_pause_delay", "0",
    "Delay to apply before a pause happens. Could be used to prevent Tactical Pauses",
    FCVAR_NONE, true, 0.0, false, 0.0);

    g_cvReadyDelay = CreateConVar(
    "l4d_ready_delay", "3",
    "Number of seconds to count down before the round goes live.",
    FCVAR_NONE, true, 0.0, false, 0.0);

    g_cvReadyBlips = CreateConVar(
    "l4d_ready_blips", "1",
    "Enable beep on unpause",
    FCVAR_NONE, true, 0.0, true, 1.0);

    g_cvPauseLimit = CreateConVar(
    "sm_pause_limit", "1",
    "Limits the amount of pauses a player can do in a single game",
    FCVAR_NONE, true, -1.0, false, 0.0);

    g_PauseTrie = new StringMap();
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("round_end",   Event_RoundEnd,   EventHookMode_PostNoCopy);
}

any Native_IsInPause(Handle hPlugin, int iNumParams) {
    return g_bIsPaused;
}

any Native_SetPause(Handle hPlugin, int iNumParams) {
    if (g_bIsPaused)
        return false;

    if (g_bRoundEnd)
        return false;

    if (IsInReady())
        return false;

    int iClient   = GetNativeCell(1);
    g_bAdminPause = GetNativeCell(2);
    if (iClient == 0) {
        strcopy(g_szInitiatorName, sizeof(g_szInitiatorName), "Server");
        strcopy(g_szInitiatorTeam, sizeof(g_szInitiatorTeam), "None");
    } else {
        int iTeam = GetClientTeam(iClient);
        GetClientName(iClient, g_szInitiatorName, sizeof(g_szInitiatorName));
        strcopy(g_szInitiatorTeam, sizeof(g_szInitiatorTeam), g_szTeamString[iTeam]);
    }
    Pause(iClient);
    return true;
}

any Native_SetUnpause(Handle hPlugin, int iNumParams) {
    if (!g_bIsPaused)
        return false;

    InitiateLiveCountdown(0);
    return true;
}

void HostNameChanged(ConVar cv, const char[] szOldValue, const char[] szNewValue) {
    g_cvHostName.GetString(g_szServerName, sizeof(g_szServerName));
}

public void OnClientPutInServer(int iClient) {
    if (!g_bIsPaused)
        return;

    if (IsFakeClient(iClient))
        return;

    CPrintToChatAll("{green}[{default}Pause{green}] {olive}%N{default} is now {blue}fully loaded{default} in game!", iClient);
    ChangeClientTeam(iClient, L4D2Team_Spectator);
}

public void OnClientDisconnect(int iClient) {
    g_bHiddenPanel   [iClient] = false;
    g_bHiddenManually[iClient] = false;
}

public void OnMapStart() {
    g_PauseTrie.Clear();
    PrecacheSound(BLIP2);
    PrecacheSound(BUTTON22);
    g_hReadyCountdownTimer = null;
}

public void OnMapEnd() {
    g_bRoundEnd = true;
    Unpause(0, false);
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bRoundEnd = false;
}

void Event_RoundEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (g_hDeferredPauseTimer != null) {
        KillTimer(g_hDeferredPauseTimer);
        g_hDeferredPauseTimer = null;
    }

    g_bRoundEnd = true;
    Unpause(0, false);
}

Action Vote_Callback(int iClient, char[] szCommand, int iArgs) {
    // Used to fast ready/unready through default keybinds for voting
    if (!g_bIsPaused)
        return Plugin_Continue;

    if (iClient <= 0)
        return Plugin_Continue;

    if (iClient > MaxClients)
        return Plugin_Continue;

    if (!IsClientInGame(iClient))
        return Plugin_Continue;

    if (GetClientTeam(iClient) == L4D2Team_Spectator)
        return Plugin_Continue;

    if (TM_IsPlayerRespectating(iClient))
        return Plugin_Continue;

    if (SolarisVotes_IsVoteInProgress() && SolarisVotes_IsClientInVotePool(iClient))
        return Plugin_Continue;

    static char szArg[8];
    GetCmdArg(1, szArg, sizeof(szArg));

    if (strcmp(szArg, "Yes", false) == 0) {
        Cmd_Unpause(iClient, 0);
    } else if (strcmp(szArg, "No", false) == 0) {
        Cmd_Unready(iClient, 0);
    }

    return Plugin_Continue;
}

Action Cmd_Hide(int iClient, int iArgs) {
    g_bHiddenPanel    [iClient] = true;
    g_bHiddenManually [iClient] = true;
    return Plugin_Handled;
}

Action Cmd_Show(int iClient, int iArgs) {
    g_bHiddenPanel    [iClient] = false;
    g_bHiddenManually [iClient] = false;
    return Plugin_Handled;
}

Action Cmd_Pause(int iClient, int iArgs) {
    if (!g_cvPauseAllow.BoolValue)
        return Plugin_Continue;

    if (IsInReady())
        return Plugin_Handled;

    if (g_iPauseDelay != 0)
        return Plugin_Handled;

    if (g_bIsPaused)
        return Plugin_Handled;

    if (g_bRoundEnd)
        return Plugin_Handled;

    if (iClient == 0) {
        strcopy(g_szInitiatorName, sizeof(g_szInitiatorName), "Server");
        strcopy(g_szInitiatorTeam, sizeof(g_szInitiatorTeam), "None");
        g_iPauseDelay = g_cvPauseDelay.IntValue;

        if (g_iPauseDelay == 0)
            AttemptPause(0);
        else
            CreateTimer(1.0, Timer_PauseDelay, 0, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

        return Plugin_Handled;
    }

    if (IsPlayer(iClient) && !TM_IsPlayerRespectating(iClient)) {
        char szSteamId[MAX_NAME_LENGTH];
        GetClientAuthId(iClient, AuthId_Steam2, szSteamId, sizeof(szSteamId), true);

        int iTeam = GetClientTeam(iClient);

        int iPauseCount;
        g_PauseTrie.GetValue(szSteamId, iPauseCount);

        if (iPauseCount < g_cvPauseLimit.IntValue || g_cvPauseLimit.IntValue == -1) {
            iPauseCount++;
            g_PauseTrie.SetValue(szSteamId, iPauseCount);

            char szPauseCount[64] = "";
            if (g_cvPauseLimit.IntValue != -1)
                FormatEx(szPauseCount, sizeof(szPauseCount), " ({olive}%d{default}/{olive}%d{default})", iPauseCount, g_cvPauseLimit.IntValue);

            CPrintToChatAllEx(iClient, "{green}[{default}Pause{green}] {teamcolor}%N{default} paused the game%s.", iClient, szPauseCount);
            GetClientName(iClient, g_szInitiatorName, sizeof(g_szInitiatorName));
            strcopy(g_szInitiatorTeam, sizeof(g_szInitiatorTeam), g_szTeamString[iTeam]);
            g_iPauseDelay = g_cvPauseDelay.IntValue;

            if (g_iPauseDelay == 0)
                AttemptPause(iClient);
            else
                CreateTimer(1.0, Timer_PauseDelay, GetClientUserId(iClient), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

            return Plugin_Handled;
        }

        CPrintToChatEx(iClient, iClient, "{green}[{default}Pause{green}] {teamcolor}You{default} have reached your pause limit ({olive}%d{default}/{olive}%d{default}).", iPauseCount, g_cvPauseLimit.IntValue);
        return Plugin_Handled;
    }

    return Plugin_Handled;
}

Action Timer_PauseDelay(Handle hTimer, any aUserId) {
    int iClient = 0;
    if (aUserId == 0)
        iClient = 0;
    else
        iClient = GetClientOfUserId(aUserId);

    if (g_iPauseDelay == 0) {
        CPrintToChatAll("{green}[{default}Pause{green}]{default} Game is paused!");
        AttemptPause(iClient);
        return Plugin_Stop;
    } else {
        CPrintToChatAll("{green}[{default}Pause{green}]{default} Game pause in: {olive}%d...", g_iPauseDelay);
        g_iPauseDelay--;
    }

    return Plugin_Continue;
}

Action Cmd_Unpause(int iClient, int iArgs) {
    if (g_bIsPaused && IsPlayer(iClient) && !TM_IsPlayerRespectating(iClient)) {
        int iClientTeam = GetClientTeam(iClient);
        if (!g_bTeamReady[iClientTeam])
            CPrintToChatAllEx(iClient, "{green}[{default}Pause{green}] {teamcolor}%N{default} marked {teamcolor}%s{default} as {olive}ready!", iClient, g_szTeamString[iClientTeam]);

        g_bTeamReady[iClientTeam] = true;
        if (g_bAdminPause)
            return Plugin_Handled;

        if (!CheckFullReady())
            return Plugin_Handled;

        InitiateLiveCountdown(GetClientUserId(iClient));
    }

    return Plugin_Handled;
}

Action Cmd_Unready(int iClient, int iArgs) {
    if (g_bIsPaused && IsPlayer(iClient) && !TM_IsPlayerRespectating(iClient)) {
        int iClientTeam = GetClientTeam(iClient);
        if (g_bTeamReady[iClientTeam])
            CPrintToChatAllEx(iClient, "{green}[{default}Pause{green}] {teamcolor}%N{default} marked {teamcolor}%s{default} as {olive}not ready!", iClient, g_szTeamString[iClientTeam]);

        g_bTeamReady[iClientTeam] = false;
        CancelFullReady(iClient);
    }

    return Plugin_Handled;
}

Action Cmd_ToggleReady(int iClient, int iArgs) {
    int iClientTeam = GetClientTeam(iClient);
    g_bTeamReady[iClientTeam] ? Cmd_Unready(iClient, 0) : Cmd_Unpause(iClient, 0);
    return Plugin_Handled;
}

Action Cmd_ForcePause(int iClient, int iArgs) {
    if (!g_bIsPaused && !g_bRoundEnd) {
        if (iClient == 0) {
            strcopy(g_szInitiatorName, sizeof(g_szInitiatorName), "Server");
            strcopy(g_szInitiatorTeam, sizeof(g_szInitiatorTeam), "None");
        } else {
            int iTeam = GetClientTeam(iClient);
            GetClientName(iClient, g_szInitiatorName, sizeof(g_szInitiatorName));
            strcopy(g_szInitiatorTeam, sizeof(g_szInitiatorTeam), g_szTeamString[iTeam]);
        }

        CPrintToChatAll("{green}[{default}Pause{green}] A {green}force pause{default} is issued by {olive}%s!", g_szInitiatorName);
        g_bAdminPause = true;
        Pause(iClient);
    }

    return Plugin_Handled;
}

Action Cmd_ForceUnpause(int iClient, int iArgs) {
    if (g_bIsPaused) {
        CPrintToChatAll("{green}[{default}Pause{green}] A {green}force unpause{default} is issued by {olive}%N!", iClient);
        InitiateLiveCountdown(GetClientUserId(iClient));
    }

    return Plugin_Handled;
}

void AttemptPause(int iClient) {
    if (g_hDeferredPauseTimer == null) {
        if (CanPause()) {
            Pause(iClient);
        } else {
            CPrintToChatAll("{green}[{default}Pause{green}]{default} This {olive}pause{default} has been delayed due to a {green}pick-up{default} in progress!");
            g_hDeferredPauseTimer = CreateTimer(0.1, Timer_DeferredPause, iClient == 0 ? 0 : GetClientUserId(iClient), TIMER_REPEAT);
        }
    }
}

Action Timer_DeferredPause(Handle hTimer, any aUserId) {
    int iClient = 0;
    if (aUserId == 0)
        iClient = 0;
    else
        iClient = GetClientOfUserId(aUserId);

    if (CanPause()) {
        g_hDeferredPauseTimer = null;
        Pause(iClient);
        return Plugin_Stop;
    }

    return Plugin_Continue;
}

void Pause(int iClient) {
    for (int iTeam; iTeam < L4D2Team_Size; iTeam++) {
        g_bTeamReady[iTeam] = false;
    }

    g_fPauseTime = GetEngineTime();
    g_bIsPaused  = true;

    if (g_hReadyCountdownTimer != null) {
        KillTimer(g_hReadyCountdownTimer);
        g_hReadyCountdownTimer = null;
    }

    Handle hTimer = CreateTimer(1.0, Timer_MenuRefresh, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    TriggerTimer(hTimer);

    g_cvPausable.SetBool(true);
    FakeClientCommand(iClient, "pause");
    g_cvPausable.SetBool(false);

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        int iTeam = GetClientTeam(i);
        if (iTeam == L4D2Team_Infected && IsInfectedGhost(i)) {
            SetEntProp(i, Prop_Send, "m_hasVisibleThreats", 1);
            int iButtons = GetClientButtons(i);
            if (iButtons & IN_ATTACK) {
                iButtons &= ~IN_ATTACK;
                SetClientButtons(i, iButtons);
                CPrintToChatEx(i, i, "{green}[{default}Pause{green}] {teamcolor}Your{default} spawn has been prevented because of the Pause.");
            }
        }

        if (iTeam == L4D2Team_Spectator && !IsFakeClient(i))
            SendConVarValue(i, g_cvNoclipDuringPause, "1");
    }

    Call_StartForward(g_PauseForward);
    Call_Finish();
}

void Unpause(int iClient, bool bReal = true) {
    g_bIsPaused       = false;
    g_bAdminPause     = false;
    g_szInitiatorName = "";
    g_szInitiatorTeam = "";

    if (!bReal)
        return;

    g_cvPausable.SetBool(true);
    FakeClientCommand(iClient, "pause");
    g_cvPausable.SetBool(false);

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;
        if (GetClientTeam(i) == L4D2Team_Spectator && !IsFakeClient(i))
            SendConVarValue(i, g_cvNoclipDuringPause, "0");
    }

    Call_StartForward(g_UnpauseForward);
    Call_Finish();
}

Action Timer_MenuRefresh(Handle hTimer) {
    if (g_bIsPaused) {
        UpdatePanel();
        return Plugin_Continue;
    }
    return Plugin_Stop;
}

void UpdatePanel() {
    if (SolarisVotes_IsVoteInProgress()) {
        int i = 1;
        while (i <= MaxClients) {
            if (IsClientInGame(i) && SolarisVotes_IsClientInVotePool(i))
                g_bHiddenPanel[i] = true;
            i++;
        }
    } else {
        int i = 1;
        while (i <= MaxClients) {
            if (IsClientInGame(i) && !g_bHiddenManually[i])
                g_bHiddenPanel[i] = false;
            i++;
        }
    }

    if (g_MenuPanel != null)
        delete g_MenuPanel;

    g_MenuPanel = new Panel();

    char szInfo[64];
    Format(szInfo, sizeof(szInfo), "▸ Server: %s", g_szServerName);
    g_MenuPanel.DrawText(szInfo);

    Format(szInfo, sizeof(szInfo), "▸ Slots: %d/%d", GetSeriousClientCount(), FindConVar("sv_maxplayers").IntValue);
    g_MenuPanel.DrawText(szInfo);

    FormatTime(szInfo, sizeof(szInfo), "▸ %d/%m/%Y - %I:%M%p", GetTime());
    g_MenuPanel.DrawText(szInfo);

    g_MenuPanel.DrawText(" ");
    g_MenuPanel.DrawText("▸ Ready Status");

    if (g_bAdminPause)
        g_MenuPanel.DrawText(" Note: Require admin to unpause!");

    if (GetTeamHumanCount(L4D2Team_Survivor) != 0)
        g_MenuPanel.DrawText(g_bTeamReady[L4D2Team_Survivor] ? " ☑ Survivors" : " ☐ Survivors");

    if (GetTeamHumanCount(L4D2Team_Infected) != 0)
        g_MenuPanel.DrawText(g_bTeamReady[L4D2Team_Infected] ? " ☑ Infected"  : " ☐ Infected");

    if (GetTeamHumanCount(L4D2Team_Survivor) == 0 && GetTeamHumanCount(L4D2Team_Infected) == 0)
        g_MenuPanel.DrawText(" No players!");

    g_MenuPanel.DrawText(" ");

    if (g_bAdminPause) {
        Format(szInfo, sizeof(szInfo), "▸ Force Pause -> %s (Admin)", g_szInitiatorName);
    } else {
        Format(szInfo, sizeof(szInfo), "▸ Initiator -> %s (%s)", g_szInitiatorName, g_szInitiatorTeam);
    }

    g_MenuPanel.DrawText(szInfo);

    char szDuration[16];
    int  iDuration = RoundToFloor(GetEngineTime() - g_fPauseTime);
    int  iSeconds  = (iDuration % 60);
    int  iMinutes  = (iDuration < 60) ? 0 : (iDuration / 60);
    Format(szDuration, sizeof(szDuration), "%s%d:%s%d", (iMinutes < 10 ? "0" : ""), iMinutes, (iSeconds < 10 ? "0" : ""), iSeconds);

    Format(szInfo, sizeof(szInfo), "▸ Duration: %s", szDuration);
    g_MenuPanel.DrawText(szInfo);

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (g_bHiddenPanel[i])
            continue;

        if (GetClientMenu(i) == MenuSource_Normal)
            continue;

        if (IsFakeClient(i) && !IsClientSourceTV(i))
            continue;

        g_MenuPanel.Send(i, DummyHandler, 1);
    }
}

void InitiateLiveCountdown(int iUserId) {
    if (g_hReadyCountdownTimer == null) {
        CPrintToChatAll("{green}[{default}Pause{green}]{default} Going {blue}live!");
        g_iReadyDelay = g_cvReadyDelay.IntValue;
        g_hReadyCountdownTimer = CreateTimer(1.0, Timer_ReadyCountdownDelay, iUserId, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    }
}

Action Timer_ReadyCountdownDelay(Handle hTimer, any aUserId) {
    int iClient = 0;
    if (aUserId == 0)
        iClient = 0;
    else
        iClient = GetClientOfUserId(aUserId);

    if (g_iReadyDelay == 0) {
        CPrintToChatAll("{green}[{default}Pause{green}]{default} Round is {blue}live{default}!");
        g_hReadyCountdownTimer = null;
        if (g_cvReadyBlips.BoolValue)
            CreateTimer(0.01, Timer_BlipDelay, eBlip2, TIMER_FLAG_NO_MAPCHANGE);

        Unpause(iClient);
        return Plugin_Stop;
    } else {
        if (g_cvReadyBlips.BoolValue)
            CreateTimer(0.01, Timer_BlipDelay, eButton22, TIMER_FLAG_NO_MAPCHANGE);

        CPrintToChatAll("{green}[{default}Pause{green}]{default} Live in: {blue}%d...", g_iReadyDelay);
        g_iReadyDelay--;
    }

    return Plugin_Continue;
}

Action Timer_BlipDelay(Handle hTimer, any aSound) {
    EmitSoundToAll(aSound == eBlip2 ? BLIP2 : BUTTON22, _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
    return Plugin_Stop;
}

void CancelFullReady(int iClient) {
    if (g_hReadyCountdownTimer != null) {
        KillTimer(g_hReadyCountdownTimer);
        g_hReadyCountdownTimer = null;
        CPrintToChatAllEx(iClient, "{green}[{default}Pause{green}] {teamcolor}%N{default} cancelled the {olive}countdown{default}!", iClient);
    }
}

Action Unpause_Callback(int iClient, const char[] szCommand, int iArgs) {
    return g_bIsPaused ? Plugin_Handled : Plugin_Continue;
}

bool CheckFullReady() {
    return (g_bTeamReady[L4D2Team_Survivor] || GetTeamHumanCount(L4D2Team_Survivor) == 0) && (g_bTeamReady[L4D2Team_Infected] || GetTeamHumanCount(L4D2Team_Infected) == 0);
}

bool IsPlayer(int iClient) {
    if (iClient <= 0)
        return false;

    if (iClient > MaxClients)
        return false;

    if (!IsClientInGame(iClient))
        return false;

    if (IsFakeClient(iClient))
        return false;

    if (GetClientTeam(iClient) <= L4D2Team_Spectator)
        return false;

    return true;
}

int DummyHandler(Menu mMenu, MenuAction maAction, int iClient, int iParam2) {
    /* Here goes nothing */
    return 0;
}

int GetTeamHumanCount(int iTeam) {
    int iHumans = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        if (GetClientTeam(i) != iTeam)
            continue;

        iHumans++;
    }

    return iHumans;
}

bool IsPlayerIncap(int iClient) {
    return view_as<bool>(GetEntProp(iClient, Prop_Send, "m_isIncapacitated"));
}

void SetClientButtons(int iClient, int iButtons) {
    if (!IsClientInGame(iClient))
        return;

    SetEntProp(iClient, Prop_Data, "m_nButtons", iButtons);
}

int GetSeriousClientCount() {
    int iClients = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientConnected(i))
            continue;

        if (IsFakeClient(i))
            continue;

        iClients++;
    }

    return iClients;
}

bool CanPause() {
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (!IsPlayerAlive(i))
            continue;

        if (GetClientTeam(i) != L4D2Team_Survivor)
            continue;

        if (IsPlayerIncap(i)) {
            if (GetEntProp(i, Prop_Send, "m_reviveOwner") > 0)
                return false;
        } else {
            if (GetEntProp(i, Prop_Send, "m_reviveTarget") > 0)
                return false;
        }
    }

    return true;
}