#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <solaris/stocks>

bool g_bThirdPerson    [MAXPLAYERS + 1];
bool g_bThirdPersonFix [MAXPLAYERS + 1];
bool g_bThirdPersonPrev[MAXPLAYERS + 1];
bool g_bIsPvP;

ConVar        g_cvGameMode;
GlobalForward g_fwdOnThirdPersonChanged;

public Plugin myinfo = {
    name        = "[L4D2] Third person detect",
    author      = "MasterMind420 & Lux",
    description = "Detects thirdpersonshoulder command for other plugins to use",
    version     = "1.5.3",
    url         = "https://forums.alliedmods.net/showthread.php?p=2529779"
};

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    EngineVersion evGame = GetEngineVersion();
    if (evGame != Engine_Left4Dead2) {
        strcopy(szError, iErrMax, "Plugin only supports Left 4 Dead 2.");
        return APLRes_SilentFailure;
    }

    g_fwdOnThirdPersonChanged = CreateGlobalForward(
    "TP_OnThirdPersonChanged",
    ET_Event, Param_Cell, Param_Cell);

    CreateNative("TP_IsInThirdPerson", Native_IsInThirdPerson);

    RegPluginLibrary("l4d2_third_person_detect");
    return APLRes_Success;
}

void TP_PushForwardToPlugins(int iClient, bool bOverride = false, bool bIsThirdPerson = false) {
    Call_StartForward(g_fwdOnThirdPersonChanged);
    Call_PushCell(iClient);
    Call_PushCell(bOverride ? bIsThirdPerson : g_bThirdPerson[iClient]);
    Call_Finish();
}

any Native_IsInThirdPerson(Handle hPlugin, int iNumParams) {
    int iClient = GetNativeCell(1);
    return g_bThirdPerson[iClient];
}

public void OnPluginStart() {
    HookEvent("player_team",      Event_TeamChange);
    HookEvent("player_death",     Event_PlayerDeath);
    HookEvent("survivor_rescued", Event_SurvivorRescued);

    g_cvGameMode = FindConVar("mp_gamemode");
    g_cvGameMode.AddChangeHook(ConVarChanged);

    CreateTimer(0.25, Timer_ThirdPersonCheck, _, TIMER_REPEAT);
}

public void OnMapStart() {
    CvarsChanged();
}

void ConVarChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    CvarsChanged();
}

void CvarsChanged() {
    static bool bWasPvP;
    g_bIsPvP = SDK_HasPlayerInfected();
    if (g_bIsPvP) {
        for (int i = 1; i <= MaxClients; i++) {
            if (!IsClientInGame(i)) continue;
            if (IsFakeClient(i))    continue;
            TP_PushForwardToPlugins(i, true, false);
        }
        bWasPvP = true;
    } else if (bWasPvP) {
        for (int i = 1; i <= MaxClients; i++) {
            if (!IsClientInGame(i)) continue;
            if (IsFakeClient(i))    continue;
            TP_PushForwardToPlugins(i);
        }
        bWasPvP = false;
    }
}

public void OnClientPutInServer(int iClient) {
    if (IsFakeClient(iClient)) return;
    TP_PushForwardToPlugins(iClient, true, false);
    g_bThirdPersonFix[iClient] = true;
}

public void OnClientDisconnect(int iClient) {
    if (IsFakeClient(iClient)) return;
    g_bThirdPerson    [iClient] = false;
    g_bThirdPersonFix [iClient] = false;
    g_bThirdPersonPrev[iClient] = false;
}

Action Timer_ThirdPersonCheck(Handle hTimer) {
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i)) continue;
        if (IsFakeClient(i))    continue;
        QueryClientConVar(i, "c_thirdpersonshoulder", QueryClientConVarCallback);
    }
    return Plugin_Continue;
}

void QueryClientConVarCallback(QueryCookie szCookie, int iClient, ConVarQueryResult qResult, const char[] szCvarName, const char[] szCvarVal) {
    if (!IsClientInGame(iClient))     return;
    if (IsClientInKickQueue(iClient)) return;
    static bool bValue;
    bValue = view_as<bool>(StringToInt(szCvarVal));
    g_bThirdPersonPrev[iClient] = g_bThirdPerson[iClient];
    g_bThirdPerson    [iClient] = bValue;
    if (g_bThirdPersonPrev[iClient] != g_bThirdPerson[iClient] || g_bThirdPersonFix[iClient]) {
        if (g_bIsPvP) TP_PushForwardToPlugins(iClient, true, false);
        else          TP_PushForwardToPlugins(iClient);
        g_bThirdPersonFix[iClient] = false;
    }
}

void Event_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)             return;
    if (!IsClientInGame(iClient)) return;
    if (IsFakeClient(iClient))    return;
    g_bThirdPersonFix[iClient] = true;
}

void Event_SurvivorRescued(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("victim"));
    if (iClient <= 0)             return;
    if (!IsClientInGame(iClient)) return;
    if (IsFakeClient(iClient))    return;
    g_bThirdPersonFix[iClient] = true;
}

void Event_TeamChange(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)             return;
    if (!IsClientInGame(iClient)) return;
    if (IsFakeClient(iClient))    return;
    g_bThirdPersonFix[iClient] = true;
}