#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <l4d2util>
#include <colors>

#define STATELENGTH 64

#define TEAM_A 0
#define TEAM_B 1

#define FIRST_HALF  0
#define SECOND_HALF 1

ConVar g_cvTiebreakBonus;
int    g_iTiebreakBonus;

ConVar g_cvSurvivorLimit;
int    g_iSurvivorLimit;

bool   g_bInRound;
bool   g_bDamageBonus;

int    g_iRound;

char   g_szTeamState[2][STATELENGTH];
int    g_iTeamDamage[2];

public Plugin myinfo = {
    name        = "[L4D2] Infected Damage",
    author      = "elias (with the assistance of B[R]UTUS)",
    description = "Provides info about amount of SIs damage during round. Prevents an extra damage to be included in tiebreaker after round ends.",
    version     = "1.0.0",
    url         = "https://solaris-servers.ru/"
};

public void OnPluginStart() {
    g_cvTiebreakBonus = FindConVar("vs_tiebreak_bonus");
    g_iTiebreakBonus  = g_cvTiebreakBonus.IntValue;
    g_cvTiebreakBonus.AddChangeHook(ConVarChanged_SurvivalBonus);

    g_cvSurvivorLimit = FindConVar("survivor_limit");
    g_iSurvivorLimit  = g_cvSurvivorLimit.IntValue;
    g_cvSurvivorLimit.AddChangeHook(ConVarChanged_SurvivorLimit);

    RegConsoleCmd("sm_damage", Cmd_Damage);
    RegConsoleCmd("sm_dmg",    Cmd_Damage);

    HookEvent("round_start",  Event_RoundStart);
    HookEvent("player_death", Event_PlayerDeath);
}

Action Cmd_Damage(int iClient, int iArgs) {
    if (!g_bInRound)
        return Plugin_Handled;

    for (int iRound = 0; iRound <= g_iRound; iRound++) {
        CPrintToChat(iClient, "{blue}[{default}Total Damage{blue}]{default} Round {blue}#%i{default} damage: {blue}%i%s", (iRound + 1), g_iTeamDamage[iRound], iRound == g_iRound ? "" : g_szTeamState[iRound]);
    }

    if (g_iRound == SECOND_HALF) {
        CPrintToChat(iClient, "{blue}[{default}Total Damage{blue}]{default} Difference: {blue}%i", g_iTeamDamage[0] > g_iTeamDamage[1] ?
                                                                                                   g_iTeamDamage[0] - g_iTeamDamage[1] :
                                                                                                   g_iTeamDamage[1] - g_iTeamDamage[0]);
    }

    return Plugin_Handled;
}

void ConVarChanged_SurvivalBonus(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iTiebreakBonus = g_cvTiebreakBonus.IntValue;
}

void ConVarChanged_SurvivorLimit(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iSurvivorLimit = g_cvSurvivorLimit.IntValue;
}

public void OnClientPutInServer(int iClient) {
    SDKHook(iClient, SDKHook_OnTakeDamagePost, SDK_OnTakeDamagePost);
}

public void OnMapStart() {
    g_bDamageBonus = true;
    g_iRound       = InSecondHalfOfRound();
    for (int iRound = 0; iRound < 2; iRound++) {
        g_szTeamState[iRound][0] = '\0';
        g_iTeamDamage[iRound]    = 0;
    }
}

public void OnMapEnd() {
    g_bInRound = false;
    for (int iRound = 0; iRound < 2; iRound++) {
        g_szTeamState[iRound][0] = '\0';
        g_iTeamDamage[iRound]    = 0;
    }
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bInRound = true;
    g_iRound   = InSecondHalfOfRound();
}

void Event_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!g_bInRound)
        return;

    int iVictim = GetClientOfUserId(eEvent.GetInt("userid"));
    if (IsValidSurvivor(iVictim)) g_bDamageBonus = false;
}

public void SDK_OnTakeDamagePost(int iVictim, int iAttacker, int iInflictor, float fDamage, int iDamageType) {
    if (!IsValidSurvivor(iVictim))
        return;

    static bool bFlipped;
    bFlipped = view_as<bool>(GameRules_GetProp("m_bAreTeamsFlipped"));

    if (!g_bInRound) {
        GameRules_SetProp("m_iChapterDamage", g_iTeamDamage[g_iRound], 4, bFlipped ? TEAM_A : TEAM_B, true);
        return;
    }

    g_iTeamDamage[g_iRound] = GameRules_GetProp("m_iChapterDamage", 4, bFlipped ? TEAM_A : TEAM_B);

    if (g_bDamageBonus == false)
        return;

    if (g_iRound == FIRST_HALF)
        return;

    if (g_iTeamDamage[1] > g_iTeamDamage[0]) {
        g_bDamageBonus = false;
        for (int i = 1; i <= MaxClients; i++) {
            if (IsSurvivor(i) && !IsFakeClient(i)) CPrintToChat(i, "{blue}[{default}Total Damage{blue}]{default} Your team lost {blue}%i{default} points!", g_iTiebreakBonus);
            if (IsInfected(i) && !IsFakeClient(i)) CPrintToChat(i, "{blue}[{default}Total Damage{blue}]{default} Your team won {blue}%i{default} points!",  g_iTiebreakBonus);
        }
    }
}

public Action L4D2_OnEndVersusModeRound(bool bCountSurvivors) {
    if (!g_bInRound)
        return Plugin_Continue;

    static bool bFlipped;
    bFlipped = view_as<bool>(GameRules_GetProp("m_bAreTeamsFlipped"));
    g_iTeamDamage[g_iRound] = GameRules_GetProp("m_iChapterDamage", 4, bFlipped ? TEAM_A : TEAM_B);

    if (bCountSurvivors) FormatEx(g_szTeamState[g_iRound], STATELENGTH, " {green}[{default}%i/%i{green}]", GetUprightSurvivors(), g_iSurvivorLimit);
    else                 FormatEx(g_szTeamState[g_iRound], STATELENGTH, " {green}[{default}wiped out{green}]");

    for (int iRound = 0; iRound <= g_iRound; iRound++) {
        CPrintToChatAll("{blue}[{default}Total Damage{blue}]{default} Round {blue}#%i{default} damage: {blue}%i%s", (iRound + 1), g_iTeamDamage[iRound], g_szTeamState[iRound]);
    }

    g_bInRound = false;
    return Plugin_Continue;
}

stock int GetUprightSurvivors() {
    static int iCount;
    iCount = 0;

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (GetClientTeam(i) != 2)
            continue;

        if (IsPlayerAlive(i) && !IsIncapacitated(i) && !IsHangingFromLedge(i))
            iCount++;
    }

    return iCount;
}