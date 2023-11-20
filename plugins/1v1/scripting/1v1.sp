#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>

ConVar g_cvDmgThreshold;
int    g_iDmgThreshold;

public Plugin myinfo = {
    name        = "1v1 EQ",
    author      = "Blade + Confogl Team, Tabun, Visor",
    description = "A plugin designed to support 1v1.",
    version     = "0.1",
    url         = "https://github.com/Attano/Equilibrium"
};

public void OnPluginStart() {
    g_cvDmgThreshold = CreateConVar(
    "sm_1v1_dmgthreshold", "24",
    "Amount of damage done (at once) before SI suicides.",
    FCVAR_NONE, true, 1.0);
    g_iDmgThreshold = g_cvDmgThreshold.IntValue;
    g_cvDmgThreshold.AddChangeHook(CvChg_DmgThreshold);

    HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
}

void CvChg_DmgThreshold(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iDmgThreshold = g_cvDmgThreshold.IntValue;
}

void Event_PlayerHurt(Event eEvent, const char[] szName, bool bDontBroadcast) {
    static char szClsNames[][] = {
        "Unknown",
        "Smoker",
        "Boomer",
        "Hunter",
        "Spitter",
        "Jockey",
        "Charger",
        "Witch",
        "Tank",
        "Not SI"
    };

    int iAttacker = GetClientOfUserId(eEvent.GetInt("attacker"));
    if (iAttacker <= 0)
        return;

    if (!IsClientInGame(iAttacker))
        return;

    if (GetClientTeam(iAttacker) != 3)
        return;

    if (eEvent.GetInt("dmg_health") < g_iDmgThreshold)
        return;

    int iIdx = GetEntProp(iAttacker, Prop_Send, "m_zombieClass");
    if (iIdx == 8)
        return;

    CPrintToChatAll("{green}[{default}1v1{green}] {red}%N{default} {green}({default}%s{green}){default} had {olive}%d{default} health remaining!", iAttacker, szClsNames[iIdx], GetClientHealth(iAttacker));
    ForcePlayerSuicide(iAttacker);
}