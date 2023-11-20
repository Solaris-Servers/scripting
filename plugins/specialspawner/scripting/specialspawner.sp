#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <sourcescramble>

#include <colors>
#include <l4d2util>
#include <solaris/stocks>

ConVar g_cvGameMode;
bool   g_bIsSurvival;

bool   g_bIsRoundLive;

// Modules
#include "modules/SS_SpawnQuantities.sp"
#include "modules/SS_SpawnTimers.sp"
#include "modules/SS_SpawnQueue.sp"
#include "modules/SS_AgressiveSpecials.sp"

/***********************************************************************************************************************************************************************************
                        All credit for the spawn timer, quantities and queue modules goes to the developers of the 'l4d2_autoIS' plugin
***********************************************************************************************************************************************************************************/
public Plugin myinfo = {
    name        = "Special Spawner",
    author      = "Tordecybombo, breezy",
    description = "Provides customisable special infected spawing beyond vanilla coop limits",
    version     = "1.1.0",
    url         = "https://github.com/brxce/Gauntlet"
};

public void OnPluginStart() {
    SpawnQuantities_OnModuleStart();
    SpawnTimers_OnModuleStart();
    AggressiveSpecials_OnModuleStart();

    HookEvent("round_start",           Event_RoundStart,         EventHookMode_PostNoCopy);
    HookEvent("round_end",             Event_RoundEnd,           EventHookMode_PostNoCopy);
    HookEvent("mission_lost",          Event_RoundEnd,           EventHookMode_PostNoCopy);
    HookEvent("map_transition",        Event_RoundEnd,           EventHookMode_PostNoCopy);
    HookEvent("player_left_safe_area", Event_PlayerLeftSafeArea, EventHookMode_PostNoCopy);
    HookEvent("survival_round_start",  Event_SurvivalRoundStart, EventHookMode_PostNoCopy);

    g_cvGameMode = FindConVar("mp_gamemode");
    g_cvGameMode.AddChangeHook(ConVarChange_GameMode);

    // Customisation commands
    RegConsoleCmd("sm_limit", Cmd_SetLimit,  "Set individual, total and simultaneous SI spawn limits");
    RegConsoleCmd("sm_timer", Cmd_SetTimer,  "Set a variable or constant spawn time (seconds)");
}

/***********************************************************************************************************************************************************************************

                                                                    PER ROUND

***********************************************************************************************************************************************************************************/
public void OnConfigsExecuted() {
    g_bIsSurvival = SDK_IsSurvival();
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bIsRoundLive = false;
    GenerateIndex(true);
}

void Event_RoundEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bIsRoundLive = false;
    GenerateIndex(true);
}

void Event_PlayerLeftSafeArea(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (g_bIsSurvival)
        return;

    g_bIsRoundLive = true;
    SetCurrentTime();
    GenerateSpawnQueue();
}

void Event_SurvivalRoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bIsRoundLive = true;
    SetCurrentTime();
    GenerateSpawnQueue();
}

void ConVarChange_GameMode(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bIsSurvival = SDK_IsSurvival();
}

/***********************************************************************************************************************************************************************************

                                                           SPAWN TIMER AND CUSTOMISATION CMDS

***********************************************************************************************************************************************************************************/
Action Cmd_SetLimit(int iClient, int iArgs) {
    if (g_bIsRoundLive) {
        CPrintToChat(iClient, "{green}[{default}Gauntlet{green}]{default} This command can only be used before the round start");
        return Plugin_Handled;
    }

    if (!IsSurvivor(iClient)) {
        CPrintToChat(iClient, "{green}[{default}Gauntlet{green}]{default} You do not have access to this command");
        return Plugin_Handled;
    }

    if (iArgs < 2) {
        CPrintToChat(iClient, "{green}[{default}Gauntlet{green}] {blue}!limit {olive}<{default}class{olive}> <{default}limit{olive}>");
        CPrintToChat(iClient, "{green}[{default}Gauntlet{green}] {blue}<class> {default}[ all | max | group/wave | smoker | boomer | hunter | spitter | jockey | charger ]");
        CPrintToChat(iClient, "{green}[{default}Gauntlet{green}] {blue}<limit> {default}[ >= 0 ]");
        return Plugin_Handled;
    }

    char szTargetCls[32];
    GetCmdArg(1, szTargetCls, sizeof(szTargetCls));

    char szLimitValue[32];
    GetCmdArg(2, szLimitValue, sizeof(szLimitValue));

    int iLimitValue = StringToInt(szLimitValue);
    if (iLimitValue < 0 || iLimitValue > 10) {
        CPrintToChat(iClient, "{green}[{default}Gauntlet{green}] {blue}0{default} <= limit value <= {blue}10");
        return Plugin_Handled;
    }

    if (strcmp(szTargetCls, "all", false) == 0) {
        CPrintToChatAll("{green}[{default}Gauntlet{green}]{default} All SI limits have been set to {olive}%d", iLimitValue);
        for (int i = L4D2Infected_Smoker; i <= L4D2Infected_Charger; i++) {
            iSpawnLimits[i] = iLimitValue;
        }
    } else if (strcmp(szTargetCls, "max", false) == 0) {
        CPrintToChatAll("{green}[{default}Gauntlet{green}]{default} Max SI limit set to {olive}%i", iLimitValue);
        iSpecialLimit = iLimitValue;
    } else if (strcmp(szTargetCls, "group", false) == 0 || strcmp(szTargetCls, "wave", false) == 0) {
        CPrintToChatAll("{green}[{default}Gauntlet{green}]{default} SI wave spawn size set to {olive}%i", iLimitValue);
        iSpawnSize = iLimitValue;
    } else {
        for (int i = L4D2Infected_Smoker; i <= L4D2Infected_Charger; i++) {
            if (strcmp(L4D2_InfectedNames[i], szTargetCls, false) == 0) {
                CPrintToChatAll("{green}[{default}Gauntlet{green}] {blue}%s{default} limit set to {olive}%i", szTargetCls, iLimitValue);
                iSpawnLimits[i] = iLimitValue;
            }
        }
    }

    LoadCacheSpawnLimits();
    return Plugin_Handled;
}

Action Cmd_SetTimer(int iClient, int iArgs) {
    if (g_bIsRoundLive) {
        CPrintToChat(iClient, "{green}[{default}Gauntlet{green}]{default} This command can only be used before the round start");
        return Plugin_Handled;
    }

    if (!IsSurvivor(iClient)) {
        CPrintToChat(iClient, "{green}[{default}Gauntlet{green}]{default} You do not have access to this command");
        return Plugin_Handled;
    }

    if (iArgs == 0) {
        CPrintToChat(iClient, "{green}[{default}Gauntlet{green}]{default} {blue}!timer {olive}<{default}constant{olive}>{default} || {blue}!timer {olive}<{default}min{olive}> <{default}max{olive}>");
    } else if (iArgs == 1) {
        char szArg[8];
        GetCmdArg(1, szArg, sizeof(szArg));

        int iTime = StringToInt(szArg);
        if (iTime <= 0) iTime = 1;

        cvSpawnTimeMin.SetInt(iTime);
        cvSpawnTimeMax.SetInt(iTime);
        CPrintToChat(iClient, "{green}[{default}Gauntlet{green}]{default} Spawn timer set to constant {blue}%.1fs", float(iTime));
    } else if (iArgs > 1) {
        char szArg[8];

        GetCmdArg(1, szArg, sizeof(szArg));
        int iMin = StringToInt(szArg);

        GetCmdArg(2, szArg, sizeof(szArg));
        int iMax = StringToInt(szArg);

        if (iMin <= 0)    iMin = 1;
        if (iMax <= iMin) iMax = iMin;

        cvSpawnTimeMin.SetInt(iMin);
        cvSpawnTimeMax.SetInt(iMax);

        if (iMin == iMax)
            CPrintToChat(iClient, "{green}[{default}Gauntlet{green}]{default} Spawn timer set to constant {blue}%.1fs", float(iMin));
        else
            CPrintToChat(iClient, "{green}[{default}Gauntlet{green}]{default} Spawn timer will be between {blue}%.1f{default} and {blue}%.1fs", float(iMin), float(iMax));
    }

    return Plugin_Handled;
}

/***********************************************************************************************************************************************************************************

                                                           MODIFY SI LIMIT

***********************************************************************************************************************************************************************************/
public Action L4D_OnGetScriptValueInt(const char[] szKey, int &iRetVal) {
    if (strcmp(szKey, "MaxSpecials") == 0) {
        iRetVal = cvSILimitCap.IntValue;
        return Plugin_Handled;
    }

    return Plugin_Continue;
}