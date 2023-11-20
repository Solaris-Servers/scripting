#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <l4d2lib>
#include <l4d2util>
#include <colors>

#define TEAM_INDEX_SIZE 2
#define STATE_BUFFER_SIZE 32

ConVar g_cvBonusPerSurvivorMultiplier;
ConVar g_cvPermanentHealthProportion;
ConVar g_cvPillsHpFactor;
ConVar g_cvPillsMaxBonus;

ConVar g_cvSurvLimit;
int    g_iSurvLimit;

float g_fMapHpBonus;
float g_fMapDmgBonus;
float g_fMapTmpHpBonus;
float g_fMapBonus;
int   g_iMapDistance;

float g_fPermHpWorth;
float g_fTmpHpWorth;
int   g_iPillWorth;

float g_fSurvBonus[TEAM_INDEX_SIZE];
int   g_iLostTmpHp[TEAM_INDEX_SIZE];
int   g_iInfDmg   [TEAM_INDEX_SIZE];

int   g_iTmpHp[MAXPLAYERS + 1];

public Plugin myinfo = {
    name        = "L4D2 Scoremod+",
    author      = "Visor",
    description = "The next generation scoring mod",
    version     = "2.2.2",
    url         = "https://github.com/Attano/L4D2-Competitive-Framework"
};

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    CreateNative("SMPlus_GetHealthBonus",    Native_GetHealthBonus);
    CreateNative("SMPlus_GetDamageBonus",    Native_GetDamageBonus);
    CreateNative("SMPlus_GetPillsBonus",     Native_GetPillsBonus);
    CreateNative("SMPlus_GetMaxHealthBonus", Native_GetMaxHealthBonus);
    CreateNative("SMPlus_GetMaxDamageBonus", Native_GetMaxDamageBonus);
    CreateNative("SMPlus_GetMaxPillsBonus",  Native_GetMaxPillsBonus);

    LateLoad(true, bLate);

    RegPluginLibrary("l4d2_hybrid_scoremod");
    return APLRes_Success;
}

any Native_GetHealthBonus(Handle hPlugin, int iNumParams) {
    return RoundToFloor(GetSurvivorHealthBonus());
}

any Native_GetMaxHealthBonus(Handle hPlugin, int iNumParams) {
    return RoundToFloor(g_fMapHpBonus);
}

any Native_GetDamageBonus(Handle hPlugin, int iNumParams) {
    return RoundToFloor(GetSurvivorDamageBonus());
}

any Native_GetMaxDamageBonus(Handle hPlugin, int iNumParams) {
    return RoundToFloor(g_fMapDmgBonus);
}

any Native_GetPillsBonus(Handle hPlugin, int iNumParams) {
    return RoundToFloor(GetSurvivorPillBonus());
}

any Native_GetMaxPillsBonus(Handle hPlugin, int iNumParams) {
    return g_iSurvLimit * g_iPillWorth;
}

public void OnPluginStart() {
    g_cvBonusPerSurvivorMultiplier = CreateConVar(
    "sm2_bonus_per_survivor_multiplier", "0.5",
    "Total Survivor Bonus = this * Number of Survivors * Map Distance",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_cvBonusPerSurvivorMultiplier.AddChangeHook(CvChg_Variables);

    g_cvPermanentHealthProportion = CreateConVar(
    "sm2_permament_health_proportion", "0.75",
    "Permanent Health Bonus = this * Map Bonus; rest goes for Temporary Health Bonus",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_cvPermanentHealthProportion.AddChangeHook(CvChg_Variables);

    g_cvPillsHpFactor = CreateConVar(
    "sm2_pills_hp_factor", "6.0",
    "Unused pills HP worth = map bonus HP value / this",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_cvPillsHpFactor.AddChangeHook(CvChg_Variables);

    g_cvPillsMaxBonus = CreateConVar(
    "sm2_pills_max_bonus", "30",
    "Unused pills cannot be worth more than this",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_cvPillsMaxBonus.AddChangeHook(CvChg_Variables);

    g_cvSurvLimit = FindConVar("survivor_limit");
    g_iSurvLimit  = g_cvSurvLimit.IntValue;
    g_cvSurvLimit.AddChangeHook(CvChg_SurvLimit);

    HookEvent("round_start",          Event_RoundStart);
    HookEvent("revive_success",       Event_PlayerRevived);
    HookEvent("player_ledge_grab",    Event_PlayerLedgeGrab);
    HookEvent("player_incapacitated", Event_PlayerIncapped);
    HookEvent("player_hurt",          Event_PlayerHurt);

    RegConsoleCmd("sm_health",  Cmd_Bonus);
    RegConsoleCmd("sm_damage",  Cmd_Bonus);
    RegConsoleCmd("sm_bonus",   Cmd_Bonus);

    RegConsoleCmd("sm_mapinfo", Cmd_MapInfo);

    if (LateLoad()) {
        for (int i = 1; i <= MaxClients; i++) {
            if (!IsClientInGame(i))
                continue;

            OnClientPutInServer(i);
        }
    }
}

public void OnPluginEnd() {
    SurvivalBonus(false, 0, true);
    TieBreakerBonus(false, 0, true);
}

public void OnMapStart() {
    RequestFrame(OnMapStart_NextFrame);
}

void OnMapStart_NextFrame() {
    for (int i = 0; i < TEAM_INDEX_SIZE; i++) {
        g_iLostTmpHp[i] = 0;
        g_iInfDmg[i] = 0;
        TiebreakerEligibility(i, true, false);
    }

    GetVariables();
}

void CvChg_Variables(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    GetVariables();
}

void CvChg_SurvLimit(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iSurvLimit = g_cvSurvLimit.IntValue;
}

void GetVariables() {
    TieBreakerBonus(true, 0);

    g_iMapDistance = L4D2_GetMapValueInt("max_distance", L4D_GetVersusMaxCompletionScore());
    L4D_SetVersusMaxCompletionScore(g_iMapDistance);

    float fPermHealthProportion = g_cvPermanentHealthProportion.FloatValue;
    float fTempHealthProportion = 1.0 - fPermHealthProportion;

    g_fMapBonus      = g_iMapDistance * (g_cvBonusPerSurvivorMultiplier.FloatValue * g_iSurvLimit);
    g_fMapHpBonus    = g_fMapBonus * fPermHealthProportion;
    g_fMapDmgBonus   = g_fMapBonus * fTempHealthProportion;
    g_fMapTmpHpBonus = g_iSurvLimit * 100 / fPermHealthProportion * fTempHealthProportion;
    g_fPermHpWorth   = g_fMapBonus / g_iSurvLimit / 100 * fPermHealthProportion;
    g_fTmpHpWorth    = g_fMapBonus * fTempHealthProportion / g_fMapTmpHpBonus;
    g_iPillWorth     = Clamp(RoundToNearest(50 * (g_fPermHpWorth / g_cvPillsHpFactor.FloatValue) / 5) * 5, 5, g_cvPillsMaxBonus.IntValue);
}

public void OnClientPutInServer(int iClient) {
    SDKHook(iClient, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

public void OnClientDisconnect(int iClient) {
    SDKUnhook(iClient, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

Action Cmd_Bonus(int iClient, int iArgs) {
    if (RoundOver())
        return Plugin_Handled;

    if (iClient <= 0)
        return Plugin_Handled;

    if (!IsClientInGame(iClient))
        return Plugin_Handled;

    char szArg[64];
    GetCmdArg(1, szArg, sizeof(szArg));

    float fHealthBonus   = GetSurvivorHealthBonus();
    float fDamageBonus   = GetSurvivorDamageBonus();
    float fPillsBonus    = GetSurvivorPillBonus();
    float fMaxPillsBonus = float(g_iPillWorth * g_iSurvLimit);

    char szSurvivorState[32];
    SurvivorState(false, 0, szSurvivorState, sizeof(szSurvivorState));

    if (strcmp(szArg, "full") == 0) {
        if (InSecondHalfOfRound())
            CPrintToChat(iClient, "{blue}R#1{default} Bonus: {blue}%d{default}/{blue}%d{default} <{olive}%.1f%%{default}> [%s]", RoundToFloor(g_fSurvBonus[0]),
                                                                                                                                 RoundToFloor(g_fMapBonus + fMaxPillsBonus),
                                                                                                                                 CalculateBonusPercent(g_fSurvBonus[0]),
                                                                                                                                 szSurvivorState);

        CPrintToChat(iClient, "{blue}R#%i{default} Bonus: {blue}%d{default} <{olive}%.1f%%{default}> [HB: {blue}%d{default} <{olive}%.1f%%{default}> | DB: {blue}%d{default} <{olive}%.1f%%{default}> | PB: {blue}%d{default} <{olive}%.1f%%{default}>]", RoundIndex() + 1,
                                                                                                                                                                                                                                                          RoundToFloor(fHealthBonus + fDamageBonus + fPillsBonus),
                                                                                                                                                                                                                                                          CalculateBonusPercent(fHealthBonus + fDamageBonus + fPillsBonus, g_fMapHpBonus + g_fMapDmgBonus + fMaxPillsBonus),
                                                                                                                                                                                                                                                          RoundToFloor(fHealthBonus),
                                                                                                                                                                                                                                                          CalculateBonusPercent(fHealthBonus, g_fMapHpBonus),
                                                                                                                                                                                                                                                          RoundToFloor(fDamageBonus),
                                                                                                                                                                                                                                                          CalculateBonusPercent(fDamageBonus, g_fMapDmgBonus),
                                                                                                                                                                                                                                                          RoundToFloor(fPillsBonus),
                                                                                                                                                                                                                                                          CalculateBonusPercent(fPillsBonus, fMaxPillsBonus));
    } else if (strcmp(szArg, "lite") == 0) {
        CPrintToChat(iClient, "{blue}R#%i{default} Bonus: {blue}%d{default} <{olive}%.1f%%{default}>", RoundIndex() + 1,
                                                                                                       RoundToFloor(fHealthBonus + fDamageBonus + fPillsBonus),
                                                                                                       CalculateBonusPercent(fHealthBonus + fDamageBonus + fPillsBonus, g_fMapHpBonus + g_fMapDmgBonus + fMaxPillsBonus));
    } else {
        if (InSecondHalfOfRound())
            CPrintToChat(iClient, "{blue}R#1{default} Bonus: {blue}%d{default} <{olive}%.1f%%{default}>", RoundToFloor(g_fSurvBonus[0]),
                                                                                                          CalculateBonusPercent(g_fSurvBonus[0]));

        CPrintToChat(iClient, "{blue}R#%i{default} Bonus: {blue}%d{default} <{olive}%.1f%%{default}> [HB: {olive}%.0f%%{default} | DB: {olive}%.0f%%{default} | PB: {olive}%.0f%%{default}]", RoundIndex() + 1,
                                                                                                                                                                                              RoundToFloor(fHealthBonus + fDamageBonus + fPillsBonus),
                                                                                                                                                                                              CalculateBonusPercent(fHealthBonus + fDamageBonus + fPillsBonus, g_fMapHpBonus + g_fMapDmgBonus + fMaxPillsBonus),
                                                                                                                                                                                              CalculateBonusPercent(fHealthBonus, g_fMapHpBonus), CalculateBonusPercent(fDamageBonus, g_fMapDmgBonus),
                                                                                                                                                                                              CalculateBonusPercent(fPillsBonus, fMaxPillsBonus));
    }

    return Plugin_Handled;
}

Action Cmd_MapInfo(int iClient, int iArgs) {
    float fMaxPillsBonus = float(g_iPillWorth * g_iSurvLimit);
    float fTotalBonus    = g_fMapBonus + fMaxPillsBonus;
    CPrintToChat(iClient, "{blue}[{default}Hybrid Bonus :: {olive}%iv%i{default} Map Info{blue}]", g_iSurvLimit, g_iSurvLimit);
    CPrintToChat(iClient, "Distance: {blue}%d{default}", g_iMapDistance);
    CPrintToChat(iClient, "Total Bonus: {blue}%d{default} <{olive}100.0%%{default}>", RoundToFloor(fTotalBonus));
    CPrintToChat(iClient, "Health Bonus: {blue}%d{default} <{olive}%.1f%%{default}>", RoundToFloor(g_fMapHpBonus), CalculateBonusPercent(g_fMapHpBonus, fTotalBonus));
    CPrintToChat(iClient, "Damage Bonus: {blue}%d{default} <{olive}%.1f%%{default}>", RoundToFloor(g_fMapDmgBonus), CalculateBonusPercent(g_fMapDmgBonus, fTotalBonus));
    CPrintToChat(iClient, "Pills Bonus: {blue}%d{default} (max {blue}%d{default}) <{olive}%.1f%%{default}>", g_iPillWorth, RoundToFloor(fMaxPillsBonus), CalculateBonusPercent(fMaxPillsBonus, fTotalBonus));
    CPrintToChat(iClient, "Tiebreaker: {blue}%d{default}", g_iPillWorth);
    return Plugin_Handled;
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    for (int i = 1; i <= MaxClients; i++) {
        g_iTmpHp[i] = 0;
    }

    RoundOver(true, false);
}

void Event_PlayerLedgeGrab(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    g_iLostTmpHp[RoundIndex()] += L4D2Direct_GetPreIncapHealthBuffer(iClient);
}

void Event_PlayerIncapped(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)
        return;

    if (!IsSurvivor(iClient))
        return;

    g_iLostTmpHp[RoundIndex()] += RoundToFloor((g_fMapDmgBonus / 100.0) * 5.0 / g_fTmpHpWorth);
}

void Event_PlayerRevived(Event eEvent, const char[] szName, bool bDontBroadcast) {
    bool bLedge = eEvent.GetBool("ledge_hang");
    if (!bLedge)
        return;

    int iClient = GetClientOfUserId(eEvent.GetInt("subject"));
    if (iClient <= 0)
        return;

    if (!IsSurvivor(iClient))
        return;

    RequestFrame(Revival, iClient);
}

void Revival(any aClient) {
    g_iLostTmpHp[RoundIndex()] -= GetSurvivorTemporaryHealth(aClient);
}

void Event_PlayerHurt(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iVictim = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iVictim <= 0)
        return;

    if (!IsSurvivor(iVictim))
        return;

    if (IsIncapacitated(iVictim))
        return;

    int iAttacker = GetClientOfUserId(eEvent.GetInt("attacker"));
    if (iAttacker <= 0)
        return;

    if (!IsSurvivor(iAttacker))
        return;

    int iDamageType = eEvent.GetInt("type");
    if (iDamageType != DMG_PLASMA)
        return;

    int iDamage = eEvent.GetInt("dmg_health");
    if (iDamage < GetSurvivorPermanentHealth(iVictim))
        return;

    g_iTmpHp[iVictim] = GetSurvivorTemporaryHealth(iVictim);

    if (iDamage > g_iTmpHp[iVictim])
        iDamage = g_iTmpHp[iVictim];

    g_iLostTmpHp[RoundIndex()] += iDamage;
    g_iTmpHp[iVictim] = GetSurvivorTemporaryHealth(iVictim) - iDamage;
}

public void OnTakeDamagePost(int iVictim, int iAttacker, int iInflictor, float fDmg, int iDmgType) {
    if (iVictim <= 0)
        return;

    if (iVictim > MaxClients)
        return;

    if (!IsSurvivor(iVictim))
        return;

    if (!IsIncapacitated(iVictim)) {
        g_iTmpHp[iVictim] = GetSurvivorTemporaryHealth(iVictim);
        if (!IsAnyInfected(iAttacker))
            g_iInfDmg[RoundIndex()] += (fDmg <= 100.0 ? RoundFloat(fDmg) : 100);
    }

    if (!IsPlayerAlive(iVictim) || (IsIncapacitated(iVictim) && !IsHangingFromLedge(iVictim))) {
        g_iLostTmpHp[RoundIndex()] += g_iTmpHp[iVictim];
    } else if (!IsHangingFromLedge(iVictim)) {
        g_iLostTmpHp[RoundIndex()] += g_iTmpHp[iVictim] ? (g_iTmpHp[iVictim] - GetSurvivorTemporaryHealth(iVictim)) : 0;
    }

    g_iTmpHp[iVictim] = IsIncapacitated(iVictim) ? 0 : GetSurvivorTemporaryHealth(iVictim);
}

public Action L4D2_OnEndVersusModeRound(bool bCountSurvivors) {
    if (RoundOver())
        return Plugin_Continue;

    int iTeam               = RoundIndex();
    int iSurvivalMultiplier = GetUprightSurvivors();

    g_fSurvBonus[iTeam] = GetSurvivorHealthBonus() + GetSurvivorDamageBonus() + GetSurvivorPillBonus();
    g_fSurvBonus[iTeam] = float(RoundToFloor(g_fSurvBonus[iTeam] / float(g_iSurvLimit)) * g_iSurvLimit);

    if (iSurvivalMultiplier > 0 && RoundToFloor(g_fSurvBonus[iTeam] / iSurvivalMultiplier) >= g_iSurvLimit) {
        SurvivalBonus(true, RoundToFloor(g_fSurvBonus[iTeam] / iSurvivalMultiplier));
        g_fSurvBonus[iTeam] = float(SurvivalBonus() * iSurvivalMultiplier);

        char szSurvivorState[STATE_BUFFER_SIZE];
        FormatEx(szSurvivorState, STATE_BUFFER_SIZE, "%i/%i", iSurvivalMultiplier, g_iSurvLimit);

        SurvivorState(true, iTeam, szSurvivorState, STATE_BUFFER_SIZE);
    } else {
        g_fSurvBonus[iTeam] = 0.0;
        SurvivorState(true, iTeam, (iSurvivalMultiplier == 0 ? "{olive}wiped out{default}" : "{olive}bonus depleted{default}"), STATE_BUFFER_SIZE);
        TiebreakerEligibility(iTeam, true, (iSurvivalMultiplier == g_iSurvLimit));
    }

    if (iTeam > 0 && TiebreakerEligibility(0) && TiebreakerEligibility(1)) {
        GameRules_SetProp("m_iChapterDamage", g_iInfDmg[0], _, 0, true);
        GameRules_SetProp("m_iChapterDamage", g_iInfDmg[1], _, 1, true);
        if (g_iInfDmg[0] != g_iInfDmg[1])
            TieBreakerBonus(true, g_iPillWorth);
    }

    CreateTimer(3.0, Timer_PrintRoundEndStats, _, TIMER_FLAG_NO_MAPCHANGE);
    RoundOver(true, true);
    return Plugin_Continue;
}

Action Timer_PrintRoundEndStats(Handle hTimer) {
    int iIdx = RoundIndex();
    char[][] szSurvivorState = new char[iIdx + 1][STATE_BUFFER_SIZE];
    for (int i = 0; i <= iIdx; i++) {
        SurvivorState(false, i, szSurvivorState[i], STATE_BUFFER_SIZE);
        CPrintToChatAll("{blue}R#%i{default} Bonus: {blue}%d{default}/{blue}%d{default} <{olive}%.1f%%{default}> {blue}[{default}%s{blue}]", (i + 1), RoundToFloor(g_fSurvBonus[i]), RoundToFloor(g_fMapBonus + float(g_iPillWorth * g_iSurvLimit)), CalculateBonusPercent(g_fSurvBonus[i]), szSurvivorState[i]);
    }

    if (InSecondHalfOfRound() && TiebreakerEligibility(0) && TiebreakerEligibility(1)) {
        CPrintToChatAll("{blue}[{default}Tiebreaker{blue}]{default} Team {olive}%#1{default} - {blue}%i{default}, Team {green}%#2{default} - {blue}%i{default}", g_iInfDmg[0], g_iInfDmg[1]);
        if (g_iInfDmg[0] == g_iInfDmg[1])
            CPrintToChatAll("{green}[{default}!{green}] {blue}Teams have performed absolutely equal! Impossible to decide a clear round winner");
    }

    return Plugin_Stop;
}

float GetSurvivorHealthBonus() {
    static float fHealthBonus;
    fHealthBonus = 0.0;

    static int iSurvivorCount;
    iSurvivorCount = 0;

    static int iSurvivalMultiplier;
    iSurvivalMultiplier = 0;

    for (int i = 1; i <= MaxClients && iSurvivorCount < g_iSurvLimit; i++) {
        if (!IsSurvivor(i))
            continue;

        iSurvivorCount++;

        if (!IsPlayerAlive(i))
            continue;

        if (IsIncapacitated(i))
            continue;

        if (IsHangingFromLedge(i))
            continue;

        iSurvivalMultiplier++;
        fHealthBonus += GetSurvivorPermanentHealth(i) * g_fPermHpWorth;
    }

    return (fHealthBonus / g_iSurvLimit * iSurvivalMultiplier);
}

float GetSurvivorDamageBonus() {
    int   iSurvivalMultiplier = GetUprightSurvivors();
    float fDamageBonus = (g_fMapTmpHpBonus - float(g_iLostTmpHp[RoundIndex()])) * g_fTmpHpWorth / g_iSurvLimit * iSurvivalMultiplier;
    return (fDamageBonus > 0.0 && iSurvivalMultiplier > 0) ? fDamageBonus : 0.0;
}

float GetSurvivorPillBonus() {
    static int iPillsBonus;
    iPillsBonus = 0;

    static int iSurvivorCount;
    iSurvivorCount = 0;

    for (int i = 1; i <= MaxClients && iSurvivorCount < g_iSurvLimit; i++) {
        if (!IsSurvivor(i))
            continue;

        iSurvivorCount++;

        if (!IsPlayerAlive(i))
            continue;

        if (IsIncapacitated(i))
            continue;

        if (!HasPills(i))
            continue;

        iPillsBonus += g_iPillWorth;
    }

    return float(iPillsBonus);
}

float CalculateBonusPercent(float fScore, float fMaxBonus = -1.0) {
    return fScore / (fMaxBonus == -1.0 ? (g_fMapBonus + float(g_iPillWorth * g_iSurvLimit)) : fMaxBonus) * 100;
}

/**
 * Stocks
**/
int Clamp(int val_0, int val_1, int iMax) {
    return ((val_0) > (iMax)) ? (iMax) : (((val_0) < (val_1)) ? (val_1) : (val_0));
}

int RoundIndex() {
    return InSecondHalfOfRound() ? 1 : 0;
}

bool IsAnyInfected(int iEnt) {
    if (iEnt > 0 && iEnt <= MaxClients) {
        return IsClientInGame(iEnt) && GetClientTeam(iEnt) == 3;
    } else if (iEnt > MaxClients) {
        char szClsName[64];
        GetEdictClassname(iEnt, szClsName, sizeof(szClsName));
        return (strcmp(szClsName, "infected") == 0 || strcmp(szClsName, "witch") == 0);
    }

    return false;
}

int GetUprightSurvivors() {
    static int iAliveCount;
    iAliveCount = 0;

    static int iSurvivorCount;
    iSurvivorCount = 0;

    for (int i = 1; i <= MaxClients && iSurvivorCount < g_iSurvLimit; i++) {
        if (!IsSurvivor(i))
            continue;

        iSurvivorCount++;

        if (!IsPlayerAlive(i))
            continue;

        if (IsIncapacitated(i))
            continue;

        if (IsHangingFromLedge(i))
            continue;

        iAliveCount++;
    }

    return iAliveCount;
}

bool HasPills(int iClient) {
    int iItem = GetPlayerWeaponSlot(iClient, 4);
    if (!IsValidEdict(iItem))
        return false;
    char szBuffer[64];
    GetEdictClassname(iItem, szBuffer, sizeof(szBuffer));
    return strcmp(szBuffer, "weapon_pain_pills") == 0;
}

bool LateLoad(bool bSet = false, bool bVal = false) {
    static bool bLateLoad;
    if (bSet)
        bLateLoad = bVal;
    return bLateLoad;
}

bool RoundOver(bool bSet = false, bool bVal = false) {
    static bool bRoundOver;
    if (bSet)
        bRoundOver = bVal;
    return bRoundOver;
}

int TieBreakerBonus(bool bSet = false, int iVal = 0, bool bReset = false) {
    static ConVar cv;
    if (cv == null)
        cv = FindConVar("vs_tiebreak_bonus");

    if (bReset) {
        cv.RestoreDefault();
        return cv.IntValue;
    }

    if (bSet)
        cv.SetInt(iVal);

    return cv.IntValue;
}

int SurvivalBonus(bool bSet = false, int iVal = 0, bool bReset = false) {
    static ConVar cv;
    if (cv == null)
        cv = FindConVar("vs_survival_bonus");

    if (bReset) {
        cv.RestoreDefault();
        return cv.IntValue;
    }

    if (bSet)
        cv.SetInt(iVal);

    return cv.IntValue;
}

bool TiebreakerEligibility(int iIdx, bool bSet = false, bool bVal = false) {
    static bool bEligibility[TEAM_INDEX_SIZE];
    if (bSet)
        bEligibility[iIdx] = bVal;
    return bEligibility[iIdx];
}

void SurvivorState(bool bSet = false, int iIdx = 0, char[] szBuffer, int iLen) {
    static char szSurvivorState[TEAM_INDEX_SIZE][STATE_BUFFER_SIZE];
    if (bSet)
        strcopy(szSurvivorState[iIdx], STATE_BUFFER_SIZE, szBuffer);
    strcopy(szBuffer, iLen, szSurvivorState[iIdx]);
}