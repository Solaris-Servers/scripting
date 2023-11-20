#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <l4d2lib>
#include <left4dhooks>
#include <l4d2util>

int g_iSurvivorBonus[2];

// Cvars
ConVar g_cvHBRatio;
float  g_fHBRatio;

ConVar g_cvSurvivalBonusRatio;
float  g_fSurvivalBonusRatio;

ConVar g_cvMapMulti;
bool   g_bMapMulti;

ConVar g_cvCustomMaxDistance;
bool   g_bCustomMaxDistance;

ConVar g_cvTempMulti[3];
float  g_fTempMulti[3];

// Default Cvar Values
ConVar g_cvHealPct;
float  g_fHealPct;

ConVar g_cvPillsPct;
int    g_iPillsPct;

ConVar g_cvAdrenPct;
int    g_iAdrenPct;

public Plugin myinfo = {
    name        = "L4D2 Scoremod++",
    author      = "CanadaRox, ProdigySim, Tabun",
    description = "L4D2 Custom Scoring System (Health Bonus)",
    version     = "1.1b",
    url         = "https://bitbucket.org/CanadaRox/random-sourcemod-stuff"
};

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    CreateNative("SM_HealthBonus", Native_GetBonus);
    CreateNative("SM_AvgHealth",   Native_AvgHealth);

    RegPluginLibrary("l4d2_scoremod");
    return APLRes_Success;
}

any Native_GetBonus(Handle hPlugin, int iNumParams) {
    int iAliveCount;
    float fScore = CalculateAvgHealth(iAliveCount);
    return RoundToFloor(fScore * MapMulti() * g_fHBRatio + 400 * MapMulti() * g_fSurvivalBonusRatio) * iAliveCount;
}

any Native_AvgHealth(Handle hPlugin, int iNumParams) {
    return CalculateAvgHealth();
}

public void OnPluginStart() {
    g_cvHBRatio = CreateConVar(
    "SM_healthbonusratio", "2.0",
    "L4D2 Custom Scoring - Healthbonus Multiplier",
    FCVAR_NONE, true, 0.25, true, 5.0);
    g_fHBRatio = g_cvHBRatio.FloatValue;
    g_cvHBRatio.AddChangeHook(CvChg_HealthBonusRatio);

    g_cvSurvivalBonusRatio = CreateConVar(
    "SM_survivalbonusratio", "0.0",
    "Ratio to be used for a static survival bonus against Map distance. 25% == 100 points maximum health bonus on a 400 distance map",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_fSurvivalBonusRatio = g_cvSurvivalBonusRatio.FloatValue;
    g_cvSurvivalBonusRatio.AddChangeHook(CvChg_SurvivalBonusRatio);

    g_cvMapMulti = CreateConVar(
    "SM_mapmulti", "1",
    "L4D2 Custom Scoring - Increases Healthbonus Max to Distance Max",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bMapMulti = g_cvMapMulti.BoolValue;
    g_cvMapMulti.AddChangeHook(CvChg_MapMulti);

    g_cvCustomMaxDistance = CreateConVar(
    "SM_custommaxdistance", "0",
    "L4D2 Custom Scoring - Custom max distance from config",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bCustomMaxDistance = g_cvCustomMaxDistance.BoolValue;
    g_cvCustomMaxDistance.AddChangeHook(CvChg_CustomMaxDistance);

    g_cvTempMulti[0] = CreateConVar(
    "SM_tempmulti_incap_0", "0.30625",
    "L4D2 Custom Scoring - How important temp health is on survivors who have had no incaps",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_fTempMulti[0] = g_cvTempMulti[0].FloatValue;
    g_cvTempMulti[0].AddChangeHook(CvChg_TempMulti);

    g_cvTempMulti[1] = CreateConVar(
    "SM_tempmulti_incap_1", "0.17500",
    "L4D2 Custom Scoring - How important temp health is on survivors who have had one incap",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_fTempMulti[1] = g_cvTempMulti[1].FloatValue;
    g_cvTempMulti[1].AddChangeHook(CvChg_TempMulti);

    g_cvTempMulti[2] = CreateConVar(
    "SM_tempmulti_incap_2", "0.10000",
    "L4D2 Custom Scoring - How important temp health is on survivors who have had two incaps (black and white)",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_fTempMulti[2] = g_cvTempMulti[2].FloatValue;
    g_cvTempMulti[2].AddChangeHook(CvChg_TempMulti);

    g_cvHealPct = FindConVar("first_aid_heal_percent");
    g_fHealPct = g_cvHealPct.FloatValue;
    g_cvHealPct.AddChangeHook(CvChg_HealPct);

    g_cvPillsPct = FindConVar("pain_pills_health_value");
    g_iPillsPct = g_cvPillsPct.IntValue;
    g_cvPillsPct.AddChangeHook(CvChg_HealPct);

    g_cvAdrenPct = FindConVar("adrenaline_health_buffer");
    g_iAdrenPct = g_cvAdrenPct.IntValue;
    g_cvAdrenPct.AddChangeHook(CvChg_HealPct);

    RegConsoleCmd("sm_health", Cmd_Bonus);
    RegConsoleCmd("sm_damage", Cmd_Bonus);
    RegConsoleCmd("sm_bonus",  Cmd_Bonus);

    HookEvent("round_start", Event_RoundStart);
}

public void OnAllPluginsLoaded() {
    L4D2Lib_Available(true, LibraryExists("l4d2lib"));
}

public void OnLibraryAdded(const char[] szName) {
    if (strcmp(szName, "l4d2lib") == 0)
        L4D2Lib_Available(true, true);
}

public void OnLibraryRemoved(const char[] szName) {
    if (strcmp(szName, "l4d2lib") == 0)
        L4D2Lib_Available(true, false);
}

public void OnPluginEnd() {
    SurvivalBonus(false, 0, true);
    TieBreakerBonus(false, 0, true);
}

public void OnMapStart() {
    RequestFrame(OnMapStart_NextFrame);
}

void OnMapStart_NextFrame() {
    TieBreakerBonus(true, 0);

    MapMulti(true, (g_bMapMulti ? (float(L4D_GetVersusMaxCompletionScore()) / 400.0) : 1.00));

    if (g_bCustomMaxDistance && GetCustomMapMaxScore() > -1) {
        L4D_SetVersusMaxCompletionScore(GetCustomMapMaxScore());

        // to allow a distance score of 0 and a health bonus
        if (GetCustomMapMaxScore() > 0)
            MapMulti(true, (float(GetCustomMapMaxScore()) / 400.0));
    }

    for (int i = 0; i < sizeof(g_iSurvivorBonus); i++) {
        g_iSurvivorBonus[i] = 0;
    }
}

void CvChg_HealthBonusRatio(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fHBRatio = g_cvHBRatio.FloatValue;
}

void CvChg_SurvivalBonusRatio(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fSurvivalBonusRatio = g_cvSurvivalBonusRatio.FloatValue;
}

void CvChg_MapMulti(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bMapMulti = g_cvMapMulti.BoolValue;
}

void CvChg_CustomMaxDistance(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bCustomMaxDistance = g_cvCustomMaxDistance.BoolValue;
}

void CvChg_TempMulti(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    for (int i = 0; i < sizeof(g_cvTempMulti); i++) {
        g_fTempMulti[i] = g_cvTempMulti[i].FloatValue;
    }
}

void CvChg_HealPct(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fHealPct  = g_cvHealPct.FloatValue;
    g_iPillsPct = g_cvPillsPct.IntValue;
    g_iAdrenPct = g_cvAdrenPct.IntValue;
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    RoundOver(true, false);
}

public Action L4D2_OnEndVersusModeRound(bool bCountSurvivors) {
    RoundOver(true, true);

    int iRoundIdx = InSecondHalfOfRound();

    // Round just ended, save the current score.
    int iAliveCount;
    g_iSurvivorBonus[iRoundIdx] = RoundToFloor(CalculateAvgHealth(iAliveCount) * MapMulti() * g_fHBRatio + 400 * MapMulti() * g_fSurvivalBonusRatio);

    // If the score is nonzero, trust the SurvivalBonus var.
    g_iSurvivorBonus[iRoundIdx] = (g_iSurvivorBonus[iRoundIdx] ? CalculateSurvivalBonus() * iAliveCount : 0);

    for (int i = 0; i <= iRoundIdx; i++) {
        CPrintToChatAll("{blue}[{default}ScoreMod{blue}]{default} Round %d Bonus: {blue}%d", i + 1, g_iSurvivorBonus[i]);
    }

    if (iRoundIdx) {
        int iDifference;
        if (g_iSurvivorBonus[0] > g_iSurvivorBonus[1])
            iDifference = g_iSurvivorBonus[0] - g_iSurvivorBonus[1];
        else
            iDifference = g_iSurvivorBonus[1] - g_iSurvivorBonus[0];

        CPrintToChatAll("{blue}[{default}ScoreMod{blue}]{default} Difference: {blue}%d", iDifference);
    }

    if (g_bCustomMaxDistance && GetCustomMapMaxScore() > -1)
        CPrintToChatAll("{blue}[{default}ScoreMod{blue}]{default} Custom Max Distance: {blue}%d", GetCustomMapMaxScore());

    SurvivalBonus(true, CalculateSurvivalBonus());
    return Plugin_Continue;
}

Action Cmd_Bonus(int iClient, int iArgs) {
    if (RoundOver())
        return Plugin_Handled;

    if (iClient <= 0)
        return Plugin_Handled;

    if (!IsClientInGame(iClient))
        return Plugin_Handled;

    int iRoundIdx = InSecondHalfOfRound();

    int iAliveCount;
    float fAvgHealth = CalculateAvgHealth(iAliveCount);
    int iScore = RoundToFloor(fAvgHealth * MapMulti() * g_fHBRatio) * iAliveCount ;

    if (iRoundIdx) {
        int iDifference;
        if (g_iSurvivorBonus[0] > iScore)
            iDifference = g_iSurvivorBonus[0] - iScore;
        else
            iDifference = iScore - g_iSurvivorBonus[0];

        CPrintToChat(iClient, "{blue}[{default}ScoreMod{blue}]{default} Round 1 Bonus: {blue}%d{default} (Difference: {blue}%d{default})", g_iSurvivorBonus[0], iDifference);
    }

    CPrintToChat(iClient, "{blue}[{default}ScoreMod{blue}]{default} Round %d Bonus: {blue}%d", iRoundIdx + 1, iScore);
    CPrintToChat(iClient, "{blue}[{default}ScoreMod{blue}]{default} Average Health: {blue}%.02f", fAvgHealth);

    if (g_fSurvivalBonusRatio != 0.0)
        CPrintToChat(iClient, "{blue}[{default}ScoreMod{blue}]{default} Static Survival Bonus Per Survivor: {blue}%d", RoundToFloor(400 * MapMulti() * g_fSurvivalBonusRatio));

    if (g_bCustomMaxDistance && GetCustomMapMaxScore() != -1)
        CPrintToChat(iClient, "{blue}[{default}ScoreMod{blue}]{default} Custom Max Distance: {blue}%d", GetCustomMapMaxScore());

    return Plugin_Handled;
}

int CalculateSurvivalBonus() {
    return RoundToFloor(CalculateAvgHealth() * MapMulti() * g_fHBRatio + 400 * MapMulti() * g_fSurvivalBonusRatio);
}

float CalculateAvgHealth(int &iAliveCount = 0) {
    int iTotalHealth;
    int iTotalTempHealth[3];

    // Temporary Storage Variables for inventory
    int iCurrPermHP;
    int iCurrTempHP;
    int iIncapCount;

    int iSlot;

    char szBuffer[50];
    int  iSurvCount;

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (GetClientTeam(i) != L4D2Team_Survivor)
            continue;

        iSurvCount++;

        if (!IsPlayerAlive(i))
            continue;

        if (L4D_IsPlayerIncapacitated(i)) {
            if (!L4D_IsMissionFinalMap())
                iAliveCount++;
            continue;
        }

        // Get Main health stats
        iCurrPermHP = GetClientHealth(i);
        iCurrTempHP = L4D_GetPlayerTempHealth(i);
        iIncapCount = L4D_GetPlayerReviveCount(i);

        // Adjust for kits
        iSlot = GetPlayerWeaponSlot(i, 3);
        if (iSlot > -1) {
            GetEdictClassname(iSlot, szBuffer, sizeof(szBuffer));
            if (strcmp(szBuffer, "weapon_first_aid_kit") == 0) {
                iCurrPermHP = RoundToFloor(iCurrPermHP + ((100 - iCurrPermHP) * g_fHealPct));
                iCurrTempHP = 0;
                iIncapCount = 0;
            }
        }

        // Adjust for pills/adrenaline
        iSlot = GetPlayerWeaponSlot(i, 4);
        if (iSlot > -1) {
            GetEdictClassname(iSlot, szBuffer, sizeof(szBuffer));
            if (strcmp(szBuffer, "weapon_pain_pills") == 0)
                iCurrTempHP += g_iPillsPct;
            else if (strcmp(szBuffer, "weapon_adrenaline") == 0)
                iCurrTempHP += g_iAdrenPct;
        }

        // Enforce max 100 total health points
        if ((iCurrTempHP + iCurrPermHP) > 100)
            iCurrTempHP = 100 - iCurrPermHP;

        iAliveCount++;
        iTotalHealth += iCurrPermHP;
        iTotalTempHealth[iIncapCount] += iCurrTempHP;
    }

    float fTotalAdjustedTempHealth;
    for (int i = 0; i < sizeof(g_cvTempMulti); i++) {
        fTotalAdjustedTempHealth += iTotalTempHealth[i] * g_fTempMulti[i];
    }

    // Total Score = Average Health points * numAlive
    // Average Health points = Total Health Points / Survivor Count
    // Total Health Points = Total Permanent Health + Total Adjusted Temp Health
    // return Average Health Points
    float fAvgHealth  = (iTotalHealth + fTotalAdjustedTempHealth) / iSurvCount;
    return fAvgHealth;
}

int GetCustomMapMaxScore() {
    return L4D2Lib_Available() ? L4D2_GetMapValueInt("max_distance", -1) : -1;
}

bool L4D2Lib_Available(bool bSet = false, bool bVal = false) {
    static bool bAvailable;
    if (bSet)
        bAvailable = bVal;
    return bAvailable;
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

bool RoundOver(bool bSet = false, bool bVal = false) {
    static bool bRoundOver;
    if (bSet)
        bRoundOver = bVal;
    return bRoundOver;
}

float MapMulti(bool bSet = false, float fVal = 0.0) {
    static float fMapMulti;
    if (bSet)
        fMapMulti = fVal;
    return fMapMulti;
}