#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>
#include <l4d2util>
#include <left4dhooks>
#include <solaris/stocks>

#define CONBUFSIZELARGE 4096
#define CONBUFSIZE      1024
#define CHARTHRESHOLD    160

char g_szClientName     [MAXPLAYERS + 1][64];
int  g_iPlayerLastHealth[MAXPLAYERS + 1];
int  g_iIncapacitatedOffs;

/**
 * Basic statistics
**/
int  g_iGotKills      [MAXPLAYERS + 1];
int  g_iGotCommon     [MAXPLAYERS + 1];
int  g_iDidDamage     [MAXPLAYERS + 1];
int  g_iDidDamageAll  [MAXPLAYERS + 1];
int  g_iDidDamageTank [MAXPLAYERS + 1];
int  g_iDidDamageWitch[MAXPLAYERS + 1];
int  g_iDidFF         [MAXPLAYERS + 1];

/**
 * Detailed statistics
**/
int  g_iDidDamageClass[MAXPLAYERS + 1][L4D2Infected_Size];
int  g_iTimesPinned   [MAXPLAYERS + 1][L4D2Infected_Size];
int  g_iTotalPinned   [MAXPLAYERS + 1];
int  g_iPillsUsed     [MAXPLAYERS + 1];
int  g_iBoomerPops    [MAXPLAYERS + 1];
int  g_iDmgReceived   [MAXPLAYERS + 1];

/**
 * Tank stats
**/
int  g_iCommonKilledDuringTank      [MAXPLAYERS + 1];
int  g_iSpecialInfectedDmgDuringTank[MAXPLAYERS + 1];
int  g_iPinnedDuringTank            [MAXPLAYERS + 1];
int  g_iRocksEaten                  [MAXPLAYERS + 1];
int  g_iTotalCommonKilledDuringTank;
int  g_iTotalSpecialInfectedDmgDuringTank;

int  g_iTotalKills;
int  g_iTotalCommon;
int  g_iTotalDamageTank;
int  g_iTotalDamageAll;
int  g_iTotalFF;

bool g_bInRound;

char g_szTmpString         [MAX_NAME_LENGTH];
char g_szConsoleBuf        [CONBUFSIZE];
char g_szDetailedConsoleBuf[CONBUFSIZE];
char g_szTankConsoleBuf    [CONBUFSIZE];

/**
 * PrintToConsole
**/
DataPack g_DataPack[MAXPLAYERS + 1];

/**
 * Avoid fake damage
**/
int g_iLastInfectedHealth[MAXPLAYERS + 1];

public Plugin myinfo = {
    name        = "Survivor MVP notification",
    author      = "Tabun, Artifacial",
    description = "Shows MVP for survivor team at end of round",
    version     = "0.4",
    url         = "https://github.com/alexberriman/l4d2_survivor_mvp"
};

/**
 *    =========
 *     Natives
 *    =========
**/
public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    CreateNative("SURVMVP_GetMVP",             Native_GetMVP);
    CreateNative("SURVMVP_GetMVPCI",           Native_GetMVPCI);
    CreateNative("SURVMVP_GetMVPDmgCount",     Native_GetMVPDmgCount);
    CreateNative("SURVMVP_GetMVPKills",        Native_GetMVPKills);
    CreateNative("SURVMVP_GetMVPDmgPercent",   Native_GetMVPDmgPercent);
    CreateNative("SURVMVP_GetMVPKillsPercent", Native_GetMVPKillsPercent);
    CreateNative("SURVMVP_GetMVPCIKills",      Native_GetMVPCIKills);
    CreateNative("SURVMVP_GetMVPCIPercent",    Native_GetMVPCIPercent);
    return APLRes_Success;
}

any Native_GetMVP(Handle hPlugin, int iNumParams) {
    int iClient = FindMVPSI();
    return iClient;
}

any Native_GetMVPCI(Handle hPlugin, int iNumParams) {
    int iClient = FindMVPCommon();
    return iClient;
}

any Native_GetMVPDmgCount(Handle hPlugin, int iNumParams) {
    int iClient = GetNativeCell(1);
    int iDmg    = iClient && g_iTotalDamageAll > 0 ? g_iDidDamageAll[iClient] : 0;
    return iDmg;
}

any Native_GetMVPKills(Handle hPlugin, int iNumParams) {
    int iClient = GetNativeCell(1);
    int iKills  = iClient && g_iTotalKills > 0 ? g_iGotKills[iClient] : 0;
    return iKills;
}

any Native_GetMVPDmgPercent(Handle hPlugin, int iNumParams) {
    int   iClient = GetNativeCell(1);
    float fDmgPrc = iClient && g_iTotalDamageAll > 0 ? (float(g_iDidDamageAll[iClient]) / float(g_iTotalDamageAll)) * 100 : 0.0;
    return fDmgPrc;
}

any Native_GetMVPKillsPercent(Handle hPlugin, int iNumParams) {
    int   iClient   = GetNativeCell(1);
    float iKillsPrc = iClient && g_iTotalKills > 0 ? (float(g_iGotKills[iClient]) / float(g_iTotalKills)) * 100 : 0.0;
    return iKillsPrc;
}

any Native_GetMVPCIKills(Handle hPlugin, int iNumParams) {
    int iClient = GetNativeCell(1);
    int iKills  = iClient && g_iTotalCommon > 0 ? g_iGotCommon[iClient] : 0;
    return iKills;
}

any Native_GetMVPCIPercent(Handle hPlugin, int iNumParams) {
    int   iClient   = GetNativeCell(1);
    float iKillsPrc = iClient && g_iTotalCommon > 0 ? (float(g_iGotCommon[iClient]) / float(g_iTotalCommon)) * 100 : 0.0;
    return iKillsPrc;
}

/**
 *    ======
 *     init
 *    ======
**/
public void OnPluginStart() {
    HookEvent("round_start",                Event_RoundStart,       EventHookMode_PostNoCopy);
    HookEvent("round_end",                  Event_RoundEnd,         EventHookMode_PostNoCopy);
    HookEvent("map_transition",             Event_RoundWon,         EventHookMode_PostNoCopy);
    HookEvent("finale_win",                 Event_RoundWon,         EventHookMode_PostNoCopy);
    HookEvent("player_spawn",               Event_PlayerSpawn,      EventHookMode_Post);
    HookEvent("player_hurt",                Event_PlayerHurt,       EventHookMode_Post);
    HookEvent("player_incapacitated_start", Event_PlayerIncapStart, EventHookMode_Post);
    HookEvent("player_death",               Event_PlayerDeath,      EventHookMode_Post);
    HookEvent("infected_hurt",              Event_InfectedHurt,     EventHookMode_Post);
    HookEvent("infected_death",             Event_InfectedDeath,    EventHookMode_Post);
    HookEvent("pills_used",                 Event_PillsUsed,        EventHookMode_Post);
    HookEvent("boomer_exploded",            Event_BoomerExploded,   EventHookMode_Post);
    HookEvent("charger_carry_end",          Event_ChargerCarryEnd,  EventHookMode_Post);
    HookEvent("jockey_ride",                Event_JockeyRide,       EventHookMode_Post);
    HookEvent("lunge_pounce",               Event_LungePounce,      EventHookMode_Post);
    HookEvent("choke_start",                Event_ChokeStart,       EventHookMode_Post);

    ConVar cvRestartGameMode = FindConVar("mp_restartgame");
    cvRestartGameMode.AddChangeHook(OnRestartGame);

    g_iIncapacitatedOffs = FindSendPropInfo("Tank", "m_isIncapacitated");

    RegConsoleCmd("sm_mvp",   Cmd_SurvivorMVP,  "Prints the current MVP for the survivor team");
    RegConsoleCmd("sm_mvpme", Cmd_ShowMVPStats, "Prints the client's own MVP-related stats");
}

public void L4D_OnEnterGhostState(int iClient) {
    g_iLastInfectedHealth[iClient] = 0;
}

public void OnClientPutInServer(int iClient) {
    g_iLastInfectedHealth[iClient] = 0;
    g_iPlayerLastHealth[iClient] = 0;
    GetClientName(iClient, g_szClientName[iClient], sizeof(g_szClientName[]));

    g_iGotKills      [iClient] = 0;
    g_iGotCommon     [iClient] = 0;
    g_iDidDamage     [iClient] = 0;
    g_iDidDamageAll  [iClient] = 0;
    g_iDidDamageWitch[iClient] = 0;
    g_iDidDamageTank [iClient] = 0;
    g_iDidFF         [iClient] = 0;

    for (int i = L4D2Infected_Smoker; i < L4D2Infected_Size; i++) {
        g_iDidDamageClass[iClient][i] = 0;
        g_iTimesPinned   [iClient][i] = 0;
    }

    g_iPillsUsed                   [iClient] = 0;
    g_iBoomerPops                  [iClient] = 0;
    g_iDmgReceived                 [iClient] = 0;
    g_iTotalPinned                 [iClient] = 0;
    g_iCommonKilledDuringTank      [iClient] = 0;
    g_iSpecialInfectedDmgDuringTank[iClient] = 0;
    g_iRocksEaten                  [iClient] = 0;
    g_iPinnedDuringTank            [iClient] = 0;

    SDKHook(iClient, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

public void OnClientDisconnect(int iClient) {
    g_iLastInfectedHealth[iClient] = 0;
    g_iPlayerLastHealth[iClient] = 0;
    strcopy(g_szClientName[iClient], sizeof(g_szClientName[]), "");

    g_iGotKills      [iClient] = 0;
    g_iGotCommon     [iClient] = 0;
    g_iDidDamage     [iClient] = 0;
    g_iDidDamageAll  [iClient] = 0;
    g_iDidDamageWitch[iClient] = 0;
    g_iDidDamageTank [iClient] = 0;
    g_iDidFF         [iClient] = 0;

    for (int i = L4D2Infected_Smoker; i < L4D2Infected_Size; i++) {
        g_iDidDamageClass[iClient][i] = 0;
        g_iTimesPinned   [iClient][i] = 0;
    }

    g_iPillsUsed                   [iClient] = 0;
    g_iBoomerPops                  [iClient] = 0;
    g_iDmgReceived                 [iClient] = 0;
    g_iTotalPinned                 [iClient] = 0;
    g_iCommonKilledDuringTank      [iClient] = 0;
    g_iSpecialInfectedDmgDuringTank[iClient] = 0;
    g_iRocksEaten                  [iClient] = 0;
    g_iPinnedDuringTank            [iClient] = 0;

    SDKUnhook(iClient, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

/**
 *    ====================================
 *     map load / round start / round end
 *    ====================================
**/
public void OnMapEnd() {
    g_bInRound = false;
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bInRound = true;
    for (int cl = 1; cl <= MaxClients; cl++) {
        g_iLastInfectedHealth[cl] = 0;
        g_iPlayerLastHealth[cl] = 0;

        g_iGotKills      [cl] = 0;
        g_iGotCommon     [cl] = 0;
        g_iDidDamage     [cl] = 0;
        g_iDidDamageAll  [cl] = 0;
        g_iDidDamageWitch[cl] = 0;
        g_iDidDamageTank [cl] = 0;
        g_iDidFF         [cl] = 0;

        for (int i = L4D2Infected_Smoker; i < L4D2Infected_Size; i++) {
            g_iDidDamageClass[cl][i] = 0;
            g_iTimesPinned   [cl][i] = 0;
        }

        g_iPillsUsed                   [cl] = 0;
        g_iBoomerPops                  [cl] = 0;
        g_iDmgReceived                 [cl] = 0;
        g_iTotalPinned                 [cl] = 0;
        g_iCommonKilledDuringTank      [cl] = 0;
        g_iSpecialInfectedDmgDuringTank[cl] = 0;
        g_iRocksEaten                  [cl] = 0;
        g_iPinnedDuringTank            [cl] = 0;
    }

    g_iTotalKills                        = 0;
    g_iTotalCommon                       = 0;
    g_iTotalDamageAll                    = 0;
    g_iTotalFF                           = 0;
    g_iTotalSpecialInfectedDmgDuringTank = 0;
    g_iTotalCommonKilledDuringTank       = 0;
    g_iTotalDamageTank                   = 0;
}

void Event_RoundEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!g_bInRound)
        return;

    CreateTimer(2.0, Timer_MVPPrint, _, TIMER_FLAG_NO_MAPCHANGE);
    g_bInRound = false;
}

void Event_RoundWon(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!g_bInRound)
        return;

    if (SDK_HasPlayerInfected())
        return;

    CreateTimer(0.1, Timer_MVPPrint, _, TIMER_FLAG_NO_MAPCHANGE);
    g_bInRound = false;
}

void OnRestartGame(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    if (StringToInt(szNewVal) == 0)
        return;

    if (!g_bInRound)
        return;

    CreateTimer(0.0, Timer_MVPPrint, _, TIMER_FLAG_NO_MAPCHANGE);
    g_bInRound = false;
}

/**
 *    ================
 *     cmds / reports
 *    ================
**/
Action Cmd_SurvivorMVP(int iClient, int iArgs) {
    char szPrintBuffer[CONBUFSIZELARGE];
    GetMVPString(szPrintBuffer, sizeof(szPrintBuffer));

    char szLines[8][192];
    int  iPieces = ExplodeString(szPrintBuffer, "\n", szLines, sizeof(szLines), sizeof(szLines[]));

    if (iClient && IsClientInGame(iClient)) {
        for (int i = 0; i < iPieces; i++) {
            CPrintToChat(iClient, "%s", szLines[i]);
        }
    } else {
        PrintToServer("\x01%s", szPrintBuffer);
    }

    PrintLoserz(true, iClient);
    PrintConsoleReport(iClient);
    return Plugin_Handled;
}

public Action Cmd_ShowMVPStats(int iClient, int iArgs) {
   PrintLoserz(true, iClient);
   return Plugin_Handled;
}

Action Timer_MVPPrint(Handle hTimer) {
    char szPrintBuffer[CONBUFSIZELARGE];

    GetMVPString(szPrintBuffer, sizeof(szPrintBuffer));
    PrintToServer("\x01%s", szPrintBuffer);

    char szLines[8][192];
    int  iPieces = ExplodeString(szPrintBuffer, "\n", szLines, sizeof(szLines), sizeof(szLines[]));

    for (int i = 0; i < iPieces; i++) {
        for (int cl = 1; cl <= MaxClients; cl++) {
            if (!IsClientInGame(cl)) continue;
            if (IsFakeClient(cl))    continue;
            CPrintToChat(cl, "{default}%s", szLines[i]);
        }
    }

    CreateTimer(0.1, PrintLosers, _, TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Handled;
}

Action PrintLosers(Handle hTimer) {
    PrintLoserz(false, -1);
    PrintConsoleReport(0);
    return Plugin_Handled;
}

void PrintLoserz(bool bSolo, int iClient) {
    char szTmpBuffer[512];

    if (g_iTotalDamageAll > 0) {
        int mvp_SI = FindMVPSI();
        int mvp_SI_losers[3];
        mvp_SI_losers[0] = FindMVPSI(mvp_SI);                                     // second place
        mvp_SI_losers[1] = FindMVPSI(mvp_SI, mvp_SI_losers[0]);                   // third
        mvp_SI_losers[2] = FindMVPSI(mvp_SI, mvp_SI_losers[0], mvp_SI_losers[1]); // fourth
        for (int i = 0; i < sizeof(mvp_SI_losers); i++) {
            if (mvp_SI_losers[i] > 0 && IsClientInGame(mvp_SI_losers[i]) && !IsFakeClient(mvp_SI_losers[i])) {
                if (bSolo) {
                    if (mvp_SI_losers[i] == iClient) {
                        FormatEx(szTmpBuffer, sizeof(szTmpBuffer), "{blue}Your Rank {green}SI: {olive}#%d - {blue}({default}%d {green}dmg {blue}[{default}%.0f%%{blue}]{olive}, {default}%d {green}kills {blue}[{default}%.0f%%{blue}])", i + 2, g_iDidDamageAll[mvp_SI_losers[i]], float(g_iDidDamageAll[mvp_SI_losers[i]]) / float(g_iTotalDamageAll) * 100, g_iGotKills[mvp_SI_losers[i]], float(g_iGotKills[mvp_SI_losers[i]]) / float(g_iTotalKills) * 100);
                        CPrintToChat(mvp_SI_losers[i], "%s", szTmpBuffer);
                    }
                } else {
                    FormatEx(szTmpBuffer, sizeof(szTmpBuffer), "{blue}Your Rank {green}SI: {olive}#%d - {blue}({default}%d {green}dmg {blue}[{default}%.0f%%{blue}]{olive}, {default}%d {green}kills {blue}[{default}%.0f%%{blue}])", i + 2, g_iDidDamageAll[mvp_SI_losers[i]], float(g_iDidDamageAll[mvp_SI_losers[i]]) / float(g_iTotalDamageAll) * 100, g_iGotKills[mvp_SI_losers[i]], float(g_iGotKills[mvp_SI_losers[i]]) / float(g_iTotalKills) * 100);
                    CPrintToChat(mvp_SI_losers[i], "%s", szTmpBuffer);
                }
            }
        }
    }

    if (g_iTotalCommon > 0) {
        int mvp_CI = FindMVPCommon();
        int mvp_CI_losers[3];
        mvp_CI_losers[0] = FindMVPCommon(mvp_CI);                                     // second place
        mvp_CI_losers[1] = FindMVPCommon(mvp_CI, mvp_CI_losers[0]);                   // third
        mvp_CI_losers[2] = FindMVPCommon(mvp_CI, mvp_CI_losers[0], mvp_CI_losers[1]); // fourth
        for (int i = 0; i < sizeof(mvp_CI_losers); i++) {
            if (mvp_CI_losers[i] > 0 && IsClientInGame(mvp_CI_losers[i]) && !IsFakeClient(mvp_CI_losers[i])) {
                if (bSolo) {
                    if (mvp_CI_losers[i] == iClient) {
                        FormatEx(szTmpBuffer, sizeof(szTmpBuffer), "{blue}Your Rank {green}CI{default}: {olive}#%d {blue}({default}%d {green}common {blue}[{default}%.0f%%{blue}])", i + 2, g_iGotCommon[mvp_CI_losers[i]], float(g_iGotCommon[mvp_CI_losers[i]]) / float(g_iTotalCommon) * 100);
                        CPrintToChat(mvp_CI_losers[i], "%s", szTmpBuffer);
                    }
                } else {
                    FormatEx(szTmpBuffer, sizeof(szTmpBuffer), "{blue}Your Rank {green}CI{default}: {olive}#%d {blue}({default}%d {green}common {blue}[{default}%.0f%%{blue}])", i + 2, g_iGotCommon[mvp_CI_losers[i]], float(g_iGotCommon[mvp_CI_losers[i]]) / float(g_iTotalCommon) * 100);
                    CPrintToChat(mvp_CI_losers[i], "%s", szTmpBuffer);
                }
            }
        }
    }

    if (g_iTotalFF > 0) {
        int mvp_FF = FindLVPFF();
        int mvp_FF_losers[3];
        mvp_FF_losers[0] = FindLVPFF(mvp_FF);                                     // second place
        mvp_FF_losers[1] = FindLVPFF(mvp_FF, mvp_FF_losers[0]);                   // third
        mvp_FF_losers[2] = FindLVPFF(mvp_FF, mvp_FF_losers[0], mvp_FF_losers[1]); // fourth
        for (int i = 0; i < sizeof(mvp_FF_losers); i++) {
            if (mvp_FF_losers[i] > 0 && IsClientInGame(mvp_FF_losers[i]) && !IsFakeClient(mvp_FF_losers[i])) {
                if (bSolo) {
                    if (mvp_FF_losers[i] == iClient) {
                        FormatEx(szTmpBuffer, sizeof(szTmpBuffer), "{blue}Your Rank {green}FF{default}: {olive}#%d {blue}({default}%d {green}friendly fire {blue}[{default}%.0f%%{blue}])", i + 2, g_iDidFF[mvp_FF_losers[i]], float(g_iDidFF[mvp_FF_losers[i]]) / float(g_iTotalFF) * 100);
                        CPrintToChat(mvp_FF_losers[i], "%s", szTmpBuffer);
                    }
                } else {
                    FormatEx(szTmpBuffer, sizeof(szTmpBuffer), "{blue}Your Rank {green}FF{default}: {olive}#%d {blue}({default}%d {green}friendly fire {blue}[{default}%.0f%%{blue}])", i + 2, g_iDidFF[mvp_FF_losers[i]], float(g_iDidFF[mvp_FF_losers[i]]) / float(g_iTotalFF) * 100);
                    CPrintToChat(mvp_FF_losers[i], "%s", szTmpBuffer);
                }
            }
        }
    }
}

/**
 * Track pill usage
**/
void Event_PillsUsed(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)
        return;

    if (!IsClientInGame(iClient))
        return;

    g_iPillsUsed[iClient]++;
}

/**
 * Track boomer pops
**/
void Event_BoomerExploded(Event eEvent, const char[] szName, bool bDontBroadcast) {
    bool bBiled = eEvent.GetBool("splashedbile");
    if (bBiled)
        return;

    int iAttacker = GetClientOfUserId(eEvent.GetInt("attacker"));
    if (iAttacker <= 0)
        return;

    if (!IsClientInGame(iAttacker))
        return;

    g_iBoomerPops[iAttacker]++;
}


/**
 * Track when someone gets charged (end of charge for level, or if someone shoots you off etc.)
**/
void Event_ChargerCarryEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("victim"));
    if (iClient <= 0)
        return;

    if (!IsClientInGame(iClient))
        return;
    g_iTimesPinned[iClient][L4D2Infected_Charger]++;
    g_iTotalPinned[iClient]++;
    if (L4D2_IsTankInPlay()) g_iPinnedDuringTank[iClient]++;
}

/**
 * Track when someone gets jockeyed.
**/
void Event_JockeyRide(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("victim"));
    if (iClient <= 0)
        return;

    if (!IsClientInGame(iClient))
        return;

    g_iTimesPinned[iClient][L4D2Infected_Jockey]++;
    g_iTotalPinned[iClient]++;
    if (L4D2_IsTankInPlay()) g_iPinnedDuringTank[iClient]++;
}

/**
 * Track when someone gets huntered.
**/
void Event_LungePounce(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("victim"));
    if (iClient <= 0)
        return;

    if (!IsClientInGame(iClient))
        return;

    g_iTimesPinned[iClient][L4D2Infected_Hunter]++;
    g_iTotalPinned[iClient]++;
    if (L4D2_IsTankInPlay()) g_iPinnedDuringTank[iClient]++;
}

/**
 * Track when someone gets smoked (we track when they start getting smoked, because anyone can get smoked)
**/
void Event_ChokeStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("victim"));
    if (iClient <= 0)
        return;

    if (!IsClientInGame(iClient))
        return;

    g_iTimesPinned[iClient][L4D2Infected_Smoker]++;
    g_iTotalPinned[iClient]++;
    if (L4D2_IsTankInPlay()) g_iPinnedDuringTank[iClient]++;
}

/**
 *    ============================
 *     track damage / track kills
 *    ============================
**/

void Event_PlayerSpawn(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));

    if (iClient <= 0)
        return;

    if (!IsInfected(iClient))
        return;

    g_iLastInfectedHealth[iClient] = GetClientHealth(iClient);
}

void Event_PlayerHurt(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iAttacker = GetClientOfUserId(eEvent.GetInt("attacker"));
    int iVictim   = GetClientOfUserId(eEvent.GetInt("userid"));
    int iHealth   = eEvent.GetInt("health");

    if (iHealth > 0)
        g_iLastInfectedHealth[iVictim] = iHealth;

    if (iAttacker <= 0)
        return;

    if (iVictim <= 0)
        return;

    if (iAttacker == iVictim)
        return;

    int iDmg = eEvent.GetInt("dmg_health");
    if (iDmg > 0) {
        if (IsSurvivor(iAttacker) && IsInfected(iVictim)) {
            int iClass = GetEntProp(iVictim, Prop_Send, "m_zombieClass");
            g_iDidDamageClass[iAttacker][iClass] += iDmg;
            if (iClass >= L4D2Infected_Smoker && iClass <= L4D2Infected_Charger) {
                if (iDmg > g_iLastInfectedHealth[iVictim])
                    iDmg = g_iLastInfectedHealth[iVictim];

                // If the tank is up, let's store separately
                if (L4D2_IsTankInPlay()) {
                    g_iSpecialInfectedDmgDuringTank[iAttacker] += iDmg;
                    g_iTotalSpecialInfectedDmgDuringTank       += iDmg;
                }

                g_iDidDamage   [iAttacker] += iDmg;
                g_iDidDamageAll[iAttacker] += iDmg;
                g_iTotalDamageAll          += iDmg;
            } else if (iClass == L4D2Infected_Tank && !IsTankDying(iVictim)) {
                g_iDidDamageTank[iAttacker] += iDmg;
                g_iTotalDamageTank          += iDmg;
            }
        } else if (IsSurvivor(iAttacker) && IsSurvivor(iVictim)) {
            g_iDidFF[iAttacker] += iDmg;
            g_iTotalFF          += iDmg;
        } else if (IsInfected(iAttacker) && IsSurvivor(iVictim)) {
            int iClass = GetEntProp(iAttacker, Prop_Send, "m_zombieClass");
            if (iClass == L4D2Infected_Tank) {
                char szWeapon[64];
                eEvent.GetString("weapon", szWeapon, sizeof(szWeapon));
                if (strcmp(szWeapon, "tank_rock") == 0)
                    g_iRocksEaten[iVictim]++;
                g_iDmgReceived[iVictim] += iDmg;
            }
        }
    }
}

void Event_PlayerIncapStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!L4D2_IsTankInPlay())
        return;

    int iVictim = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iVictim <= 0)
        return;

    if (!IsSurvivor(iVictim))
        return;

    int iAttacker = GetClientOfUserId(eEvent.GetInt("attacker"));
    if (iAttacker <= 0)
        return;

    if (!IsInfected(iAttacker))
        return;

    int iClass = GetEntProp(iVictim, Prop_Send, "m_zombieClass");
    if (iClass == L4D2Infected_Tank) {
        char szWeapon[64];
        eEvent.GetString("weapon", szWeapon, sizeof(szWeapon));

        if (strcmp(szWeapon, "tank_rock") == 0)
            g_iRocksEaten[iVictim]++;

        g_iDmgReceived[iVictim] += g_iPlayerLastHealth[iVictim];
    }

}

/**
 * When the infected are hurt (i.e. when a survivor hurts an SI)
 * We want to use this to track damage done to the witch.
**/
void Event_InfectedHurt(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iEntId = eEvent.GetInt("entityid");
    if (!IsWitch(iEntId))
        return;

    int iAttacker = GetClientOfUserId(eEvent.GetInt("attacker"));
    if (iAttacker <= 0)
        return;

    int iDmg = eEvent.GetInt("amount");
    if (IsSurvivor(iAttacker))
        g_iDidDamageWitch[iAttacker] += iDmg;
}

void Event_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iVictim   = GetClientOfUserId(eEvent.GetInt("userid"));
    int iAttacker = GetClientOfUserId(eEvent.GetInt("attacker"));

    if (iAttacker <= 0)
        return;

    if (iVictim <= 0)
        return;

    if (IsInfected(iVictim) && IsSurvivor(iAttacker)) {
        int iClass = GetEntProp(iVictim, Prop_Send, "m_zombieClass");
        if (iClass >= L4D2Infected_Smoker && iClass <= L4D2Infected_Charger) {
            g_iGotKills[iAttacker]++;
            g_iTotalKills++;
        }
    }
}

void Event_InfectedDeath(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iAttacker = GetClientOfUserId(eEvent.GetInt("attacker"));
    if (iAttacker <= 0 || !IsSurvivor(iAttacker))
        return;

    if (L4D2_IsTankInPlay()) {
        g_iCommonKilledDuringTank[iAttacker]++;
        g_iTotalCommonKilledDuringTank++;
    }

    g_iGotCommon[iAttacker]++;
    g_iTotalCommon++;
}

void OnTakeDamagePost(int iVictim, int iAttacker, int iInflictor, float fDamage, int iDamageType) {
    if (!L4D2_IsTankInPlay())
        return;

    if (!IsValidEntity(iVictim) || !IsValidEntity(iAttacker) || !IsValidEdict(iInflictor))
        return;

    if (iAttacker <= 0 || iAttacker > MaxClients)
        return;

    if (!IsSurvivor(iVictim) || !IsTank(iAttacker))
        return;

    int iPlayerHealth = GetSurvivorPermanentHealth(iVictim) + GetSurvivorTemporaryHealth(iVictim);
    g_iPlayerLastHealth[iVictim] = iPlayerHealth;
}

/**
 *     ========================
 *      MVP string & 'sorting'
 *     ========================
**/
void GetMVPString(char[] printBuffer, const int iSize) {
    char szTmpName[MAX_NAME_LENGTH];

    // SI MVP
    char mvp_SI_name[MAX_NAME_LENGTH];
    int  mvp_SI = FindMVPSI();
    if (mvp_SI > 0) {
        if (IsClientConnected(mvp_SI)) {
            GetClientName(mvp_SI, szTmpName, sizeof(szTmpName));
            if (IsFakeClient(mvp_SI)) StrCat(szTmpName, sizeof(szTmpName), " \x01[BOT]");
        } else {
            strcopy(szTmpName, sizeof(szTmpName), g_szClientName[mvp_SI]);
        }
        mvp_SI_name = szTmpName;
    } else {
        mvp_SI_name = "(nobody)";
    }

    // Common MVP
    char mvp_Common_name[MAX_NAME_LENGTH];
    int  mvp_Common = FindMVPCommon();

    if (mvp_Common > 0) {
        if (IsClientConnected(mvp_Common)) {
            GetClientName(mvp_Common, szTmpName, sizeof(szTmpName));
            if (IsFakeClient(mvp_Common)) StrCat(szTmpName, sizeof(szTmpName), " \x01[BOT]");
        } else {
            strcopy(szTmpName, sizeof(szTmpName), g_szClientName[mvp_Common]);
        }
        mvp_Common_name = szTmpName;
    } else {
        mvp_Common_name = "(nobody)";
    }

    // FF LVP
    char lvp_FF_name[MAX_NAME_LENGTH];
    int  lvp_FF = FindLVPFF();
    if (lvp_FF > 0) {
        if (IsClientConnected(lvp_FF)) {
            GetClientName(lvp_FF, szTmpName, sizeof(szTmpName));
            if (IsFakeClient(lvp_FF)) StrCat(szTmpName, sizeof(szTmpName), " \x01[BOT]");
        } else {
            strcopy(szTmpName, sizeof(szTmpName), g_szClientName[lvp_FF]);
        }
        lvp_FF_name = szTmpName;
    } else {
        lvp_FF_name = "(nobody)";
    }

    char szTmpBuffer[CONBUFSIZE];

    // report
    if (mvp_SI == 0 && mvp_Common == 0) {
        FormatEx(szTmpBuffer, sizeof(szTmpBuffer), "{blue}[{default}MVP{blue}]{default} {blue}({default}not enough action yet{blue}){default}\n");
        StrCat(printBuffer, iSize, szTmpBuffer);
    } else {
        if (mvp_SI > 0) {
            FormatEx(szTmpBuffer, sizeof(szTmpBuffer), "{blue}[{default}MVP{blue}] SI: {olive}%s {blue}({default}%d {green}dmg {blue}[{default}%.0f%%{blue}]{olive}, {default}%d {green}kills {blue}[{default}%.0f%%{blue}])\n", mvp_SI_name, g_iDidDamageAll[mvp_SI], (float(g_iDidDamageAll[mvp_SI]) / float(g_iTotalDamageAll)) * 100, g_iGotKills[mvp_SI], (float(g_iGotKills[mvp_SI]) / float(g_iTotalKills)) * 100);
            StrCat(printBuffer, iSize, szTmpBuffer);
        } else {
            StrCat(printBuffer, iSize, "{blue}[{default}MVP{blue}] SI: {blue}({default}nobody{blue}){default}\n");
        }
        if (mvp_Common > 0) {
            FormatEx(szTmpBuffer, sizeof(szTmpBuffer), "{blue}[{default}MVP{blue}] CI: {olive}%s {blue}({default}%d {green}common {blue}[{default}%.0f%%{blue}])\n", mvp_Common_name, g_iGotCommon[mvp_Common], (float(g_iGotCommon[mvp_Common]) / float(g_iTotalCommon)) * 100);
            StrCat(printBuffer, iSize, szTmpBuffer);
        }
    }
    // FF
    if (lvp_FF == 0) {
        FormatEx(szTmpBuffer, sizeof(szTmpBuffer), "{blue}[{default}LVP{blue}] FF{default}: {green}no friendly fire at all!{default}\n");
        StrCat(printBuffer, iSize, szTmpBuffer);
    } else {
        FormatEx(szTmpBuffer, sizeof(szTmpBuffer), "{blue}[{default}LVP{blue}] FF{default}: {olive}%s {blue}({default}%d {green}friendly fire {blue}[{default}%.0f%%{blue}]){default}\n", lvp_FF_name, g_iDidFF[lvp_FF], (float(g_iDidFF[lvp_FF]) / float(g_iTotalFF)) * 100);
        StrCat(printBuffer, iSize, szTmpBuffer);
    }

    /**
     * Build the console buffers
    **/

    // Clear the buffers
    g_szConsoleBuf         = "";
    g_szDetailedConsoleBuf = "";
    g_szTankConsoleBuf     = "";

    // Some constants
    const int iMaxNameLen = 20;
    const int iLength     = 15;

    char szClientName[MAX_NAME_LENGTH];

    int i;
    int mpv_done  [4];
    int mvp_losers[3];
    int iSurvLimit = FindConVar("survivor_limit").IntValue;
    for (int j = 1; j <= iSurvLimit; j++) {
        if (mvp_SI) {
            switch (j) {
                case 1: i = mvp_SI;
                case 2: i = mvp_losers[j - 2] = FindMVPSI(mvp_SI);
                case 3: i = mvp_losers[j - 2] = FindMVPSI(mvp_SI, mvp_losers[0]);
                case 4: i = mvp_losers[j - 2] = FindMVPSI(mvp_SI, mvp_losers[0], mvp_losers[1]);
            }
            if (i == 0) i = GetSurvivor(mpv_done);
        } else if (mvp_Common) {
            switch (j) {
                case 1: i = mvp_Common;
                case 2: i = mvp_losers[j - 2] = FindMVPCommon(mvp_Common);
                case 3: i = mvp_losers[j - 2] = FindMVPCommon(mvp_Common, mvp_losers[0]);
                case 4: i = mvp_losers[j - 2] = FindMVPCommon(mvp_Common, mvp_losers[0], mvp_losers[1]);
            }
            if (i == 0) i = GetSurvivor(mpv_done);
        } else {
            i = GetSurvivor(mpv_done);
        }
        mpv_done[j - 1] = i;
        if (i > 0 && IsClientInGame(i)) {
            GetClientName(i, szClientName, sizeof(szClientName));
            if (IsFakeClient(i)) StrCat(szClientName, sizeof(szClientName), " [BOT]");
        } else {
            strcopy(szClientName, sizeof(szClientName), g_szClientName[i]);
        }

        StripUnicode(szClientName);
        szClientName = g_szTmpString;
        szClientName[iMaxNameLen] = 0;

        /**
         * Let's output a range of basic statistics
        **/
        char szSiDmg[iLength];
        FormatEx(szSiDmg, iLength, "%8d", g_iDidDamageAll[i]);

        char szSiPrc[iLength];
        FormatEx(szSiPrc, iLength, "%7.1f", (float(g_iDidDamageAll[i]) / float(g_iTotalDamageAll)) * 100);

        char szSiKills[iLength];
        FormatEx(szSiKills, iLength, "%8d", g_iGotKills[i]);

        char szCiKills[iLength];
        FormatEx(szCiKills, iLength, "%8d", g_iGotCommon[i]);

        char szCiPrc[iLength];
        FormatEx(szCiPrc, iLength, "%7.1f", (float(g_iGotCommon[i]) / float(g_iTotalCommon)) * 100);

        char szTankDmg[iLength];
        FormatEx(szTankDmg, iLength, "%6d", L4D2_IsTankInPlay() ? 0 : g_iDidDamageTank[i]);

        char szWitchDmg[iLength];
        FormatEx(szWitchDmg, iLength, "%6d", g_iDidDamageWitch[i]);

        char szFf[iLength];
        FormatEx(szFf, iLength, "%6d", g_iDidFF[i]);

        // Format the basic stats
        FormatEx(g_szConsoleBuf, CONBUFSIZE,
        "%s| %20s | %8s | %7s | %8s | %8s | %7s | %6s | %6s | %6s                                   |\n",
        g_szConsoleBuf, szClientName, szSiDmg, szSiPrc, szSiKills, szCiKills, szCiPrc, szTankDmg, szWitchDmg, szFf);

        /**
         * Let's format the detailed statistics and add it to our console output string.
        **/
        char szSmokerDmg[iLength];
        FormatEx(szSmokerDmg, iLength, "%8d", g_iDidDamageClass[i][L4D2Infected_Smoker]);

        char szHunterDmg[iLength];
        FormatEx(szHunterDmg, iLength, "%8d", g_iDidDamageClass[i][L4D2Infected_Hunter]);

        char szChargerDmg[iLength];
        FormatEx(szChargerDmg,  iLength, "%8d", g_iDidDamageClass[i][L4D2Infected_Charger]);

        char szJockeyDmg[iLength];
        FormatEx(szJockeyDmg, iLength, "%7d", g_iDidDamageClass[i][L4D2Infected_Jockey]);

        char szSpitterDmg[iLength];
        FormatEx(szSpitterDmg, iLength, "%8d", g_iDidDamageClass[i][L4D2Infected_Spitter]);

        char szBoomerDmg[iLength];
        FormatEx(szBoomerDmg, iLength, "%7d", g_iDidDamageClass[i][L4D2Infected_Boomer]);

        char szPillUsage[iLength];
        FormatEx(szPillUsage, iLength, "%7d", g_iPillsUsed[i]);

        char szBoomPops[iLength];
        FormatEx(szBoomPops, iLength, "%5d", g_iBoomerPops[i]);

        char szDmgReceived[iLength];
        FormatEx(szDmgReceived, iLength, "%8d", g_iDmgReceived[i]);

        char szPinned[iLength];
        FormatEx(szPinned, iLength, "%8d", g_iTotalPinned[i]);

        FormatEx(g_szDetailedConsoleBuf, CONBUFSIZE,
        "%s| %20s | %8s | %7s | %8s | %8s | %8s | %7s | %8s | %8s | %7s | %5s           |\n",
        g_szDetailedConsoleBuf, szClientName, szPinned, szPillUsage, szDmgReceived, szSmokerDmg, szHunterDmg, szBoomerDmg, szSpitterDmg, szChargerDmg, szJockeyDmg, szBoomPops);

        /**
         * Let's format our tank statistics
        **/
        char szDmgToTank[iLength];
        FormatEx(szDmgToTank, iLength, "%9d", g_iDidDamageTank[i]);

        char szCommonDuringTank[iLength];
        FormatEx(szCommonDuringTank, iLength, "%8d", g_iCommonKilledDuringTank[i]);

        char szSiDuringTank[iLength];
        FormatEx(szSiDuringTank, iLength, "%7d", g_iSpecialInfectedDmgDuringTank[i]);

        char szTankPercentage[iLength];
        FormatEx(szTankPercentage, iLength, "%7.1f", (float(g_iDidDamageTank[i]) / float(g_iTotalDamageTank)) * 100);

        char szCommonPercent[iLength];
        FormatEx(szCommonPercent, iLength, "%7.1f", (float(g_iCommonKilledDuringTank[i]) / float(g_iTotalCommonKilledDuringTank)) * 100);

        char szSiPercent[iLength];
        FormatEx(szSiPercent, iLength, "%7.1f", (float(g_iSpecialInfectedDmgDuringTank[i]) / float(g_iTotalSpecialInfectedDmgDuringTank)) * 100);

        char szRocksAte[iLength];
        FormatEx(szRocksAte, iLength, "%6d", g_iRocksEaten[i]);

        char szTotalPinned[iLength];
        FormatEx(szTotalPinned, iLength, "%6d", g_iPinnedDuringTank[i]);

        FormatEx(g_szTankConsoleBuf, CONBUFSIZE,
        "%s| %20s | %9s | %8s | %8s | %8s | %7s | %8s | %6s | %8s                             | \n",
        g_szTankConsoleBuf, szClientName, szDmgToTank, szTankPercentage, szCommonDuringTank, szCommonPercent, szSiDuringTank, szSiPercent, szRocksAte, szTotalPinned);

        //| Name                 | Damage    | Percent  | Common   | Percent  | SI      | Percent  | Rocked | Pinned                             |
    }
}

int FindMVPSI(int iExcludeMeA = 0, int iExcludeMeB = 0, int iExcludeMeC = 0) {
    int iMaxIndex = 0;
    for (int i = 1; i < sizeof(g_iDidDamageAll); i++) {
        if (g_iDidDamageAll[i] > g_iDidDamageAll[iMaxIndex] && i != iExcludeMeA && i != iExcludeMeB && i != iExcludeMeC)
            iMaxIndex = i;
    }
    return iMaxIndex;
}

int FindMVPCommon(int iExcludeMeA = 0, int iExcludeMeB = 0, int iExcludeMeC = 0) {
    int iMaxIndex = 0;
    for (int i = 1; i < sizeof(g_iGotCommon); i++) {
        if (g_iGotCommon[i] > g_iGotCommon[iMaxIndex] && i != iExcludeMeA && i != iExcludeMeB && i != iExcludeMeC)
            iMaxIndex = i;
    }
    return iMaxIndex;
}

int FindLVPFF(int iExcludeMeA = 0, int iExcludeMeB = 0, int iExcludeMeC = 0) {
    int iMaxIndex = 0;
    for (int i = 1; i < sizeof(g_iDidFF); i++) {
        if (g_iDidFF[i] > g_iDidFF[iMaxIndex] && i != iExcludeMeA && i != iExcludeMeB && i != iExcludeMeC)
            iMaxIndex = i;
    }
    return iMaxIndex;
}

/**
 * Output the console report.
 * This seems like a really ineffective method of doing this. For some reason, it isn't outputting
 * the entire string to the console (and when I try to increase the buffer size I get an error). I
 * need to ask some of the other developers about this, but for the mean time the workaround I've
 * used (breaking the output up in to a range of different data values) should suffice.
 *
 * This method also shouldn't be this long. Should be broken up in to a range of smaller methods.
**/
void PrintConsoleReport(int iClient = 0) {
    float fCurrentTimer = 0.1;

    /**
     * Let's prepare the basic information.
    **/
    char szBasicHeader[CONBUFSIZE];
    char szBasic [CONBUFSIZELARGE];

    Format(szBasicHeader, CONBUFSIZE, "\n");
    Format(szBasicHeader, CONBUFSIZE, "%s| Basic Statistics                                                                                                                       |\n", szBasicHeader);
    Format(szBasicHeader, CONBUFSIZE, "%s|----------------------|----------|---------|----------|----------|---------|--------|--------|------------------------------------------|\n", szBasicHeader);
    Format(szBasicHeader, CONBUFSIZE, "%s| Name                 | Damage   | Percent | SI Kills | Commons  | Percent | Tank   | Witch  | FF                                       |\n", szBasicHeader);
    Format(szBasicHeader, CONBUFSIZE, "%s|----------------------|----------|---------|----------|----------|---------|--------|--------|------------------------------------------|",   szBasicHeader);
    Format(szBasic,  CONBUFSIZELARGE, "%s", g_szConsoleBuf);
    Format(szBasic,  CONBUFSIZELARGE, "%s|----------------------------------------------------------------------------------------------------------------------------------------|\n", szBasic);

    if (iClient > 0) {
        if (IsClientInGame(iClient)) {
            g_DataPack[iClient] = new DataPack();
            g_DataPack[iClient].WriteString(szBasicHeader);
            g_DataPack[iClient].WriteCell(GetClientUserId(iClient));
            CreateTimer(fCurrentTimer, TimerToConsole, g_DataPack[iClient]);
            fCurrentTimer += 0.1;
            g_DataPack[iClient] = new DataPack();
            g_DataPack[iClient].WriteString(szBasic);
            g_DataPack[iClient].WriteCell(GetClientUserId(iClient));
            CreateTimer(fCurrentTimer, TimerToConsole, g_DataPack[iClient]);
            fCurrentTimer += 0.1;
        }
    } else {
        for (int i = 1; i <= MaxClients; i++) {
            if (IsClientInGame(i) && !IsFakeClient(i)) {
                g_DataPack[i] = new DataPack();
                g_DataPack[i].WriteString(szBasicHeader);
                g_DataPack[i].WriteCell(GetClientUserId(i));
                CreateTimer(fCurrentTimer, TimerToConsole, g_DataPack[i]);
                fCurrentTimer += 0.1;
                g_DataPack[i] = new DataPack();
                g_DataPack[i].WriteString(szBasic);
                g_DataPack[i].WriteCell(GetClientUserId(i));
                CreateTimer(fCurrentTimer, TimerToConsole, g_DataPack[i]);
                fCurrentTimer += 0.1;
            }
        }
    }

    /**
     * Let's prepare the detailed information.
    **/
    char szDetailedHeader[CONBUFSIZE];
    char szDetailed [CONBUFSIZELARGE];

    Format(szDetailedHeader, CONBUFSIZELARGE, "\n");
    Format(szDetailedHeader, CONBUFSIZELARGE, "%s| Detailed Stats (pops = boomers killed before booming anyone | pinned = time pinned by SI | damage done to SI classes)                  |\n", szDetailedHeader);
    Format(szDetailedHeader, CONBUFSIZELARGE, "%s|----------------------|----------|---------|----------|----------|----------|---------|----------|----------|---------|-----------------|\n", szDetailedHeader);
    Format(szDetailedHeader, CONBUFSIZELARGE, "%s| Name                 | Pinned   | Pills   | DamageRec| Smoker   | Hunter   | Boomer  | Spitter  | Charger  | Jockey  | Pops            |\n", szDetailedHeader);
    Format(szDetailedHeader, CONBUFSIZELARGE, "%s|----------------------|----------|---------|----------|----------|----------|---------|----------|----------|---------|-----------------|",   szDetailedHeader);
    Format(szDetailed,       CONBUFSIZELARGE, "%s", g_szDetailedConsoleBuf);
    Format(szDetailed,       CONBUFSIZELARGE, "%s|----------------------------------------------------------------------------------------------------------------------------------------|\n", szDetailed);

    if (iClient > 0) {
        if (IsClientInGame(iClient)) {
            g_DataPack[iClient] = new DataPack();
            g_DataPack[iClient].WriteString(szDetailedHeader);
            g_DataPack[iClient].WriteCell(GetClientUserId(iClient));
            CreateTimer(fCurrentTimer, TimerToConsole, g_DataPack[iClient]);
            fCurrentTimer += 0.1;
            g_DataPack[iClient] = new DataPack();
            g_DataPack[iClient].WriteString(szDetailed);
            g_DataPack[iClient].WriteCell(GetClientUserId(iClient));
            CreateTimer(fCurrentTimer, TimerToConsole, g_DataPack[iClient]);
            fCurrentTimer += 0.1;
        }
    } else {
        for (int i = 1; i <= MaxClients; i++) {
            if (IsClientInGame(i) && !IsFakeClient(i)) {
                g_DataPack[i] = new DataPack();
                g_DataPack[i].WriteString(szDetailedHeader);
                g_DataPack[i].WriteCell(GetClientUserId(i));
                CreateTimer(fCurrentTimer, TimerToConsole, g_DataPack[i]);
                fCurrentTimer += 0.1;
                g_DataPack[i] = new DataPack();
                g_DataPack[i].WriteString(szDetailed);
                g_DataPack[i].WriteCell(GetClientUserId(i));
                CreateTimer(fCurrentTimer, TimerToConsole, g_DataPack[i]);
                fCurrentTimer += 0.1;
            }
        }
    }

    /**
    * Let's prepare the tank statistics
    * if it's not spawned ofc:)
    */
    if (!L4D2_IsTankInPlay()) {
        char szTankHeader[CONBUFSIZE];
        char szTank [CONBUFSIZELARGE];

        Format(szTankHeader, CONBUFSIZELARGE, "\n");
        Format(szTankHeader, CONBUFSIZELARGE, "%s| Tank stats - Damage dealt while tank was up                                                                                            |\n", szTankHeader);
        Format(szTankHeader, CONBUFSIZELARGE, "%s|----------------------|-----------|----------|----------|----------|---------|----------|--------|--------------------------------------|\n", szTankHeader);
        Format(szTankHeader, CONBUFSIZELARGE, "%s| Name                 | Damage    | Percent  | Common   | Percent  | SI      | Percent  | Rocked | Pinned                               |\n", szTankHeader);
        Format(szTankHeader, CONBUFSIZELARGE, "%s|----------------------|-----------|----------|----------|----------|---------|----------|--------|--------------------------------------|",   szTankHeader);
        Format(szTank,       CONBUFSIZELARGE, "%s", g_szTankConsoleBuf);
        Format(szTank,       CONBUFSIZELARGE, "%s|----------------------------------------------------------------------------------------------------------------------------------------|\n", szTank);

        if (iClient > 0) {
            if (IsClientInGame(iClient)) {
                g_DataPack[iClient] = new DataPack();
                g_DataPack[iClient].WriteString(szTankHeader);
                g_DataPack[iClient].WriteCell(GetClientUserId(iClient));
                CreateTimer(fCurrentTimer, TimerToConsole, g_DataPack[iClient]);
                fCurrentTimer += 0.1;
                g_DataPack[iClient] = new DataPack();
                g_DataPack[iClient].WriteString(szTank);
                g_DataPack[iClient].WriteCell(GetClientUserId(iClient));
                CreateTimer(fCurrentTimer, TimerToConsole, g_DataPack[iClient]);
                fCurrentTimer += 0.1;
            }
        } else {
            for (int i = 1; i <= MaxClients; i++) {
                if (IsClientInGame(i) && !IsFakeClient(i)) {
                    g_DataPack[i] = new DataPack();
                    g_DataPack[i].WriteString(szTankHeader);
                    g_DataPack[i].WriteCell(GetClientUserId(i));
                    CreateTimer(fCurrentTimer, TimerToConsole, g_DataPack[i]);
                    fCurrentTimer += 0.1;
                    g_DataPack[i] = new DataPack();
                    g_DataPack[i].WriteString(szTank);
                    g_DataPack[i].WriteCell(GetClientUserId(i));
                    CreateTimer(fCurrentTimer, TimerToConsole, g_DataPack[i]);
                    fCurrentTimer += 0.1;
                }
            }
        }
    }
}

Action TimerToConsole(Handle hTimer, DataPack dp) {
    if (dp == null) return Plugin_Handled;
    dp.Reset(false);
    char szToConsole[CONBUFSIZELARGE];
    dp.ReadString(szToConsole, sizeof(szToConsole));
    int iClient = GetClientOfUserId(dp.ReadCell());
    if (iClient > 0 && IsClientInGame(iClient)) PrintToConsole(iClient, "%s", szToConsole);
    delete dp;
    return Plugin_Handled;
}

/**
 *     ===================
 *      general functions
 *     ===================
**/
stock bool IsWitch(int iEnt) {
    if (iEnt > 0 && IsValidEntity(iEnt)) {
        char szClsName[64];
        GetEdictClassname(iEnt, szClsName, sizeof(szClsName));
        return strcmp(szClsName, "witch") == 0;
    }
    return false;
}

stock int GetSurvivor(int iExclude[4]) {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsSurvivor(i)) {
            bool bTagged = false;
            for (int j = 0; j < 4; j++) {
                if (iExclude[j] == i)
                    bTagged = true;
            }
            if (!bTagged) return i;
        }
    }
    return 0;
}

stock bool IsTankDying(int iTank) {
    return view_as<bool>(GetEntData(iTank, g_iIncapacitatedOffs));
}

void StripUnicode(char szBuffer[MAX_NAME_LENGTH]) {
    g_szTmpString = szBuffer;

    int iUni;
    int iCurrentChar;
    int iTmpCharLength;

    for (int i = 0; i < MAX_NAME_LENGTH - 3 && g_szTmpString[i] != 0; i++) {
        if ((g_szTmpString[i] & 0x80) == 0) {
            iCurrentChar   = g_szTmpString[i];
            iTmpCharLength = 0;
        } else if (((g_szTmpString[i] & 0xE0) == 0xC0) && ((g_szTmpString[i + 1] & 0xC0) == 0x80)) {
            iCurrentChar   = (g_szTmpString[i++] & 0x1f);
            iCurrentChar   = (iCurrentChar << 6);
            iCurrentChar  += (g_szTmpString[i] & 0x3f);
            iTmpCharLength = 1;
        } else if (((g_szTmpString[i] & 0xF0) == 0xE0) && ((g_szTmpString[i + 1] & 0xC0) == 0x80) && ((g_szTmpString[i + 2] & 0xC0) == 0x80)) {
            iCurrentChar   = (g_szTmpString[i++] & 0x0f);
            iCurrentChar   = (iCurrentChar << 6);
            iCurrentChar  += (g_szTmpString[i++] & 0x3f);
            iCurrentChar   = (iCurrentChar << 6);
            iCurrentChar  += (g_szTmpString[i] & 0x3f);
            iTmpCharLength = 2;
        } else if (((g_szTmpString[i] & 0xF8) == 0xF0) && ((g_szTmpString[i + 1] & 0xC0) == 0x80) && ((g_szTmpString[i + 2] & 0xC0) == 0x80) && ((g_szTmpString[i + 3] & 0xC0) == 0x80)) {
            iCurrentChar   = (g_szTmpString[i++] & 0x07);
            iCurrentChar   = (iCurrentChar << 6);
            iCurrentChar  += (g_szTmpString[i++] & 0x3f);
            iCurrentChar   = (iCurrentChar << 6);
            iCurrentChar  += (g_szTmpString[i++] & 0x3f);
            iCurrentChar   = (iCurrentChar << 6);
            iCurrentChar  += (g_szTmpString[i] & 0x3f);
            iTmpCharLength = 3;
        } else {
            iCurrentChar   = CHARTHRESHOLD + 1;
            iTmpCharLength = 0;
        }
        if (iCurrentChar > CHARTHRESHOLD) {
            iUni++;
            for (int j = iTmpCharLength; j >= 0; j--) {
                g_szTmpString[i - j] = 95;
            }
        }
    }
}