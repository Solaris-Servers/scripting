#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <left4dhooks>
#include <l4d2util/constants>

#define PLUGIN_TAG       "[GhostWarp]"
#define PLUGIN_TAG_COLOR "\x01[\x03GhostWarp\x01]"

enum struct SurvFlow {
    int   eSurvivorIndex;
    float eSurvivorFlow;
}

enum {
    eAllowCommand = (1 << 0),
    eAllowButton  = (1 << 1),
    eAllowAll     = (1 << 0)|(1 << 1)
};

int   g_iLastTargetSurvivor[MAXPLAYERS + 1] = {0,   ...};
float g_fGhostWarpDelay    [MAXPLAYERS + 1] = {0.0, ...};

ConVar    g_cvSurvivorLimit;
ConVar    g_cvGhostWarpDelay;
ConVar    g_cvGhostWarpFlag;

StringMap g_NameToGenderTrie;

public Plugin myinfo = {
    name        = "Infected Warp",
    author      = "Confogl Team, CanadaRox, A1m`",
    description = "Allows infected to warp to survivors",
    version     = "2.4",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart() {
    InitTrie();

    g_cvGhostWarpFlag = CreateConVar(
    "l4d2_ghost_warp_flag", "1",
    "Enable|Disable ghost warp. 0 - disable, 1 - enable warp via command 'sm_warpto', 2 - enable warp via button 'IN_ATTACK2', 3 - enable all.",
    FCVAR_NONE, true, 0.0, true, float(eAllowAll));

    g_cvGhostWarpDelay = CreateConVar(
    "l4d2_ghost_warp_delay", "0.45",
    "After how many seconds can ghost warp be reused. 0.0 - delay disabled (maximum delay 120 seconds).",
    FCVAR_NONE, true, 0.0, true, 120.0);

    g_cvSurvivorLimit = FindConVar("survivor_limit");

    RegConsoleCmd("sm_warptosurvivor", Cmd_WarpToSurvivor);
    RegConsoleCmd("sm_warpto",         Cmd_WarpToSurvivor);
    RegConsoleCmd("sm_warp",           Cmd_WarpToSurvivor);

    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

void InitTrie() {
    g_NameToGenderTrie = new StringMap();
    g_NameToGenderTrie.SetValue("nick",     L4D2Gender_Gambler);
    g_NameToGenderTrie.SetValue("rochelle", L4D2Gender_Producer);
    g_NameToGenderTrie.SetValue("coach",    L4D2Gender_Coach);
    g_NameToGenderTrie.SetValue("ellis",    L4D2Gender_Mechanic);
    g_NameToGenderTrie.SetValue("bill",     L4D2Gender_Nanvet);
    g_NameToGenderTrie.SetValue("zoey",     L4D2Gender_TeenGirl);
    g_NameToGenderTrie.SetValue("louis",    L4D2Gender_Manager);
    g_NameToGenderTrie.SetValue("francis",  L4D2Gender_Biker);
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    // GetGameTime (gpGlobals->curtime) starts from scratch every map.
    // Let's clean this up
    for (int iClient = 1; iClient <= MaxClients; iClient++) {
        g_iLastTargetSurvivor[iClient] = 0;
        g_fGhostWarpDelay[iClient] = 0.0;
    }
}

Action Cmd_WarpToSurvivor(int iClient, int iArgs) {
    if (iClient == 0) {
        ReplyToCommand(iClient, "%s This command is not available for the server!", PLUGIN_TAG);
        return Plugin_Handled;
    }

    if (!(g_cvGhostWarpFlag.IntValue & eAllowCommand)) {
        PrintToChat(iClient, "%s This command is \x04disabled\x01 now.", PLUGIN_TAG_COLOR);
        return Plugin_Handled;
    }

    if (GetClientTeam(iClient) != L4D2Team_Infected || GetEntProp(iClient, Prop_Send, "m_isGhost", 1) < 1 || !IsPlayerAlive(iClient)) {
        PrintToChat(iClient, "%s This command is only available for \x04infected\x01 ghosts.", PLUGIN_TAG_COLOR);
        return Plugin_Handled;
    }

    if (g_fGhostWarpDelay[iClient] >= GetGameTime()) {
        PrintToChat(iClient, "%s You can't use this command that often, wait another \x04%.01f\x01 sec.", PLUGIN_TAG_COLOR, g_fGhostWarpDelay[iClient] - GetGameTime());
        return Plugin_Handled;
    }

    if (iArgs < 1) {
        if (!WarpToRandomSurvivor(iClient, g_iLastTargetSurvivor[iClient]))
            PrintToChat(iClient, "%s No \x04survivors\x01 found!", PLUGIN_TAG_COLOR);
        return Plugin_Handled;
    }

    char szBuffer[9];
    GetCmdArg(1, szBuffer, sizeof(szBuffer));
    if (IsStringNumeric(szBuffer, sizeof(szBuffer))) {
        int iSurvivorFlowRank = StringToInt(szBuffer);
        if (iSurvivorFlowRank > 0 && iSurvivorFlowRank <= g_cvSurvivorLimit.IntValue) {
            int iSurvivorIndex = GetSurvivorOfFlowRank(iSurvivorFlowRank);
            if (iSurvivorIndex == 0) {
                PrintToChat(iClient, "%s No \x04survivors\x01 found!", PLUGIN_TAG_COLOR);
                return Plugin_Handled;
            }
            TeleportToSurvivor(iClient, iSurvivorIndex);
            return Plugin_Handled;
        }
        char szCmdName[18];
        GetCmdArg(0, szCmdName, sizeof(szCmdName));
        bool bWarp = WarpToRandomSurvivor(iClient, g_iLastTargetSurvivor[iClient]);
        PrintToChat(iClient, "%s You entered an \x04invalid\x01 survivor index!%s", PLUGIN_TAG_COLOR, (!bWarp) ? "" : " Teleport to a \x04random\x01 survivor!");
        PrintToChat(iClient, "%s Usage: \x04%s\x01 <1 - %d>", PLUGIN_TAG_COLOR, szCmdName, g_cvSurvivorLimit.IntValue);
        return Plugin_Handled;
    }

    int iGender = 0;
    String_ToLower(szBuffer, sizeof(szBuffer));

    if (!g_NameToGenderTrie.GetValue(szBuffer, iGender)) {
        char szCmdName[18];
        GetCmdArg(0, szCmdName, sizeof(szCmdName));
        bool bWarp = WarpToRandomSurvivor(iClient, g_iLastTargetSurvivor[iClient]);
        PrintToChat(iClient, "%s You entered the \x04wrong\x01 survivor name!%s", PLUGIN_TAG_COLOR, (!bWarp) ? "" : " Teleport to a \x04random\x01 survivor!");
        PrintToChat(iClient, "%s Usage: \x04%s\x01 <survivor name> ", PLUGIN_TAG_COLOR, szCmdName);
        return Plugin_Handled;
    }

    int iSurvivorCount = 0;
    int iSurvivorIndex = GetGenderOfSurvivor(iGender, iSurvivorCount);

    if (iSurvivorCount == 0) {
        PrintToChat(iClient, "%s No \x04survivors\x01 found!", PLUGIN_TAG_COLOR);
        return Plugin_Handled;
    }

    if (iSurvivorIndex == 0) {
        PrintToChat(iClient, "%s The \x04survivor\x01 you specified was \x04not found\x01!", PLUGIN_TAG_COLOR);
        return Plugin_Handled;
    }

    TeleportToSurvivor(iClient, iSurvivorIndex);
    return Plugin_Handled;
}

public void L4D_OnEnterGhostState(int iClient) {
    if (!(g_cvGhostWarpFlag.IntValue & eAllowButton))
        return;

    g_iLastTargetSurvivor[iClient] = 0;
    g_fGhostWarpDelay    [iClient] = 0.0;

    SDKUnhook(iClient, SDKHook_PostThinkPost, Hook_OnPostThinkPost);
    SDKHook(iClient,   SDKHook_PostThinkPost, Hook_OnPostThinkPost);
}

public void Hook_OnPostThinkPost(int iClient) {
    int iPressButtons = GetEntProp(iClient, Prop_Data, "m_afButtonPressed");

    // Key 'IN_RELOAD' was used in plugin 'confoglcompmod', do we need it?
    if (!(iPressButtons & IN_ATTACK2)) return;

    // For some reason, the game resets button 'IN_ATTACK2' for infected ghosts at some point.
    // So we need spam protection.
    if (g_fGhostWarpDelay[iClient] >= GetGameTime()) return;

    if (GetClientTeam(iClient) != L4D2Team_Infected || GetEntProp(iClient, Prop_Send, "m_isGhost", 1) < 1 || !IsPlayerAlive(iClient)) {
        SDKUnhook(iClient, SDKHook_PostThinkPost, Hook_OnPostThinkPost);
        g_iLastTargetSurvivor[iClient] = 0;
        return;
    }

    // We didn't find any survivors, is the round over?
    if (!WarpToRandomSurvivor(iClient, g_iLastTargetSurvivor[iClient])) {
        SDKUnhook(iClient, SDKHook_PostThinkPost, Hook_OnPostThinkPost);
        g_iLastTargetSurvivor[iClient] = 0;
    }
}

bool WarpToRandomSurvivor(int iInfected, int iLastWarpSurvivor) {
    int iRandomSurvivor = GetRandomSurvivorIndex(iLastWarpSurvivor);
    if (iRandomSurvivor == 0) return false;
    TeleportToSurvivor(iInfected, iRandomSurvivor);
    return true;
}

int GetRandomSurvivorIndex(int iExceptSurvivor = 0) {
    int iSurvivorIndex[MAXPLAYERS + 1], iSuvivorCount = 0, iSuvivorTotalCount = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))                    continue;
        if (GetClientTeam(i) != L4D2Team_Survivor) continue;
        if (!IsPlayerAlive(i))                     continue;
        iSuvivorTotalCount++;
        if (iExceptSurvivor > 0 && iExceptSurvivor == i)
            continue;
        iSurvivorIndex[iSuvivorCount++] = i;
    }
    // If all the survivors died
    if (iSuvivorTotalCount == 0) return 0;
    // If there is only 1 survivor left, which we did not include in the array
    if (iSuvivorCount == 0) return iExceptSurvivor;
    int iRandInt = GetURandomInt() % iSuvivorCount;
    return (iSurvivorIndex[iRandInt]);
}

void TeleportToSurvivor(int iInfected, int iSurvivor) {
    // ~Prevent people from spawning and then warp to survivor
    SetEntProp(iInfected, Prop_Send, "m_ghostSpawnState", SPAWNFLAG_TOOCLOSE);

    float fPosition[3];
    GetClientAbsOrigin(iSurvivor, fPosition);
    float fAnglestarget[3];
    GetClientAbsAngles(iSurvivor, fAnglestarget);

    TeleportEntity(iInfected, fPosition, fAnglestarget, NULL_VECTOR);
    g_iLastTargetSurvivor[iInfected] = iSurvivor;
    g_fGhostWarpDelay    [iInfected] = GetGameTime() + g_cvGhostWarpDelay.FloatValue;
}

int GetGenderOfSurvivor(int iGender, int &iSurvivorCount) {
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))                    continue;
        if (GetClientTeam(i) != L4D2Team_Survivor) continue;
        if (!IsPlayerAlive(i))                     continue;
        iSurvivorCount++;
        if (GetEntProp(i, Prop_Send, "m_Gender") == iGender)
            return i;
    }
    return 0;
}

int GetSurvivorOfFlowRank(int iRank) {
    int iArrayIndex = iRank - 1;

    SurvFlow eSurvArray;
    ArrayList FlowArray = new ArrayList(sizeof(eSurvArray));

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))                    continue;
        if (GetClientTeam(i) != L4D2Team_Survivor) continue;
        if (!IsPlayerAlive(i))                     continue;
        eSurvArray.eSurvivorIndex = i;
        eSurvArray.eSurvivorFlow  = L4D2Direct_GetFlowDistance(i);
        FlowArray.PushArray(eSurvArray, sizeof(eSurvArray));
    }
    int iArraySize = FlowArray.Length;
    if (iArraySize < 1) return 0;
    FlowArray.SortCustom(sortFunc);
    if (iArrayIndex >= iArraySize) iArrayIndex = iArraySize - 1;
    FlowArray.GetArray(iArrayIndex, eSurvArray, sizeof(eSurvArray));
    FlowArray.Clear();
    delete FlowArray;
    return eSurvArray.eSurvivorIndex;
}

int sortFunc(int i, int j, Handle hArray, Handle hHndl) {
    SurvFlow eSurvArray1;
    GetArrayArray(hArray, i, eSurvArray1, sizeof(eSurvArray1));
    SurvFlow eSurvArray2;
    GetArrayArray(hArray, j, eSurvArray2, sizeof(eSurvArray2));
    if (eSurvArray1.eSurvivorFlow > eSurvArray2.eSurvivorFlow) {
        return -1;
    } else if (eSurvArray1.eSurvivorFlow < eSurvArray2.eSurvivorFlow) {
        return 1;
    } else {
        return 0;
    }
}

bool IsStringNumeric(const char[] sString, const int MaxSize) {
    // Сounts string length to zero terminator
    int iSize = strlen(sString);
    // more security, so that the cycle is not endless
    for (int i = 0; i < iSize && i < MaxSize; i++) {
        if (sString[i] < '0' || sString[i] > '9') {
            return false;
        }
    }
    return true;
}

void String_ToLower(char[] str, const int MaxSize) {
    // Сounts string length to zero terminator
    int iSize = strlen(str);
    // more security, so that the cycle is not endless
    for (int i = 0; i < iSize && i < MaxSize; i++) {
        if (IsCharUpper(str[i])) {
            str[i] = CharToLower(str[i]);
        }
    }
    str[iSize] = '\0';
}