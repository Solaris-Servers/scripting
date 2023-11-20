#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <l4d2util>
#include <solaris/stocks>

#define SI_GENERIC_BEGIN L4D2Infected_Smoker
#define SI_GENERIC_END   L4D2Infected_Charger
#define SI_MAX_SIZE      L4D2Infected_Size
#define SI_None          L4D2Infected_Common

enum {
    OverLimit_OK = 0,
    OverLimit_Dominator,
    OverLimit_Class,
    MAX_OverLimitReason
};

ArrayList
       g_arrSpawns;

bool   g_bIsLive;

int    g_iDominators;
int    g_iBlockInfBots;

bool   g_bPlayerSpawned[MAXPLAYERS + 1];
int    g_iStoredClass  [MAXPLAYERS + 1];

ConVar g_cvSILimits[SI_MAX_SIZE];
int    g_iSILimits [SI_MAX_SIZE];

ConVar g_cvDebug;
bool   g_bDebug;

ConVar g_cvSwapDuringTank;
bool   g_bSwapDuringTank;

ConVar g_cvNoSpitterDuringTank;
bool   g_bNoSpitterDuringTank;

ConVar g_cvAllowInfectedBots;
bool   g_bAllowInfectedBots;

ConVar g_cvMaxInfected;
int    g_iMaxInfected;

public Plugin myinfo = {
    name        = "[L4D2] Proper Sack Order",
    author      = "Sir, Forgetest",
    description = "Finally fix that pesky spawn rotation not being reliable",
    version     = "4.4.2",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart() {
    HookEvent("round_start", Event_RoundStart);
    HookEvent("round_end",   Event_RoundEnd);

    HookEvent("versus_round_start",   Event_RealRoundStart);
    HookEvent("scavenge_round_start", Event_RealRoundStart);

    InitSILimits();

    g_cvDebug = CreateConVar(
    "l4d2_sackorder_debug", "0",
    "Debuggin the plugin.",
    FCVAR_SPONLY|FCVAR_HIDDEN, true, 0.0, true, 1.0);
    g_bDebug = g_cvDebug.BoolValue;
    g_cvDebug.AddChangeHook(ConVarChanged_Debug);

    g_cvSwapDuringTank = CreateConVar(
    "l4d2_swapduringtank", "1",
    "Allow swap spitters and boomers during tank.",
    FCVAR_SPONLY|FCVAR_HIDDEN, true, 0.0, true, 1.0);
    g_bSwapDuringTank = g_cvSwapDuringTank.BoolValue;
    g_cvSwapDuringTank.AddChangeHook(ConVarChanged_SwapDuringTank);

    g_cvNoSpitterDuringTank = CreateConVar(
    "l4d2_nospitterduringtank", "1",
    "Prevents giving the infected team a spitter while the tank is alive.",
    FCVAR_SPONLY|FCVAR_HIDDEN, true, 0.0, true, 1.0);
    g_bNoSpitterDuringTank = g_cvNoSpitterDuringTank.BoolValue;
    g_cvNoSpitterDuringTank.AddChangeHook(ConVarChanged_NoSpitterDuringTank);

    g_cvAllowInfectedBots = FindConVar("director_allow_infected_bots");
    g_bAllowInfectedBots  = g_cvAllowInfectedBots.BoolValue;
    g_cvAllowInfectedBots.AddChangeHook(ConVarChanged_AllowInfectedBots);

    g_cvMaxInfected = FindConVar("z_max_player_zombies");
    g_iMaxInfected  = g_cvMaxInfected.IntValue;
    g_cvMaxInfected.AddChangeHook(ConVarChanged_MaxInfected);

    g_arrSpawns = new ArrayList();
}

void ConVarChanged_Debug(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bDebug = g_cvDebug.BoolValue;
}

void ConVarChanged_SwapDuringTank(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bSwapDuringTank = g_cvSwapDuringTank.BoolValue;
}

void ConVarChanged_NoSpitterDuringTank(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bNoSpitterDuringTank = g_cvNoSpitterDuringTank.BoolValue;
}

void ConVarChanged_AllowInfectedBots(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bAllowInfectedBots = g_cvAllowInfectedBots.BoolValue;
}

void ConVarChanged_MaxInfected(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iMaxInfected = g_cvMaxInfected.IntValue;
}

void InitSILimits() {
    char szBuffer[64];
    for (int SI = SI_GENERIC_BEGIN; SI <= SI_GENERIC_END; SI++) {
        FormatEx(szBuffer, sizeof(szBuffer), "z_versus_%c%s_limit", CharToLower(L4D2_InfectedNames[SI][0]), L4D2_InfectedNames[SI][1]);
        g_cvSILimits[SI] = FindConVar(szBuffer);
    }
}

public void OnConfigsExecuted() {
    g_iDominators = 53;
    static ConVar cvDominators;
    cvDominators = FindConVar("l4d2_dominators");
    if (cvDominators != null) g_iDominators = cvDominators.IntValue;

    g_iBlockInfBots = 0;
    static ConVar cvBlockInfBots;
    cvBlockInfBots = FindConVar("confogl_blockinfectedbots");
    if (cvBlockInfBots != null) g_iBlockInfBots = cvBlockInfBots.IntValue;
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    ToggleEvents(false);
    g_arrSpawns.Clear();
    g_bIsLive = false;
}

void Event_RoundEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    ToggleEvents(false);
    g_arrSpawns.Clear();
    g_bIsLive = false;
}

void Event_RealRoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!L4D_HasPlayerControlledZombies())
        return;

    if (g_bIsLive)
        return;

    ToggleEvents(true);
    FillQueue();
    g_bIsLive = true;
}

void ToggleEvents(bool bEnable) {
    static bool bEnabled = false;

    if (bEnable == bEnabled)
        return;

    if (bEnable) {
        HookEvent("player_team",        Event_PlayerTeam);
        HookEvent("player_death",       Event_PlayerDeath);
        HookEvent("bot_player_replace", Event_BotPlayerReplace);
        HookEvent("player_bot_replace", Event_PlayerBotReplace);
        bEnabled = true;
    } else {
        UnhookEvent("player_team",        Event_PlayerTeam);
        UnhookEvent("player_death",       Event_PlayerDeath);
        UnhookEvent("bot_player_replace", Event_BotPlayerReplace);
        UnhookEvent("player_bot_replace", Event_PlayerBotReplace);
        bEnabled = false;
    }
}

// --------------------------//
//       Player Actions      //
// --------------------------//

// Basic strategy:
// 1. Zombie classes is handled by a queue: pop the beginning, push to the end.
// 2. Return zombie class, based on the player state: ghost to the beginning, materialized to the end.

public void L4D_OnMaterializeFromGhost(int iClient) {
    PrintDebug("\x05%N \x05materialized \x01as (\x04%s\x01)", iClient, L4D2_InfectedNames[GetInfectedClass(iClient)]);
    g_bPlayerSpawned[iClient] = true;
}

void Event_PlayerTeam(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iTeam    = eEvent.GetInt("team");
    int iOldTeam = eEvent.GetInt("oldteam");

    if (iTeam == iOldTeam)
        return;

    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0 || !IsClientInGame(iClient))
        return;

    if (iTeam == L4D2Team_Infected) {
        if (!g_bAllowInfectedBots || g_iBlockInfBots)
            return;

        if (IsFakeClient(iClient))
            return;

        if (GetSICount(false) + 1 <= g_iMaxInfected)
            return;

        PrintDebug("Infected Team is \x04going over capacity \x01after \x05%N \x01joined", iClient);

        int iLastUserId = 0;
        for (int i = 1; i <= MaxClients; i++) {
            if (!IsClientInGame(i) || !IsPlayerAlive(i))
                continue;

            if (!IsFakeClient(i))
                continue;

            if (GetClientTeam(i) != L4D2Team_Infected)
                continue;

            if (GetInfectedClass(i) == L4D2Infected_Tank)
                continue;

            int iUserId = GetClientUserId(i);
            if (iLastUserId < iUserId)
                iLastUserId = iUserId;
        }

        if (iLastUserId > 0) {
            int iLastBot = GetClientOfUserId(iLastUserId);
            PrintDebug("\x05%N is selected to cull", iLastBot);
            ForcePlayerSuicide(iLastBot);
        }

        return;
    }

    if (iOldTeam == L4D2Team_Infected) {
        if (!IsPlayerAlive(iClient))
            return;

        PrintDebug("\x05%N \x01left Infected Team \x01as (\x04%s\x01)", iClient, L4D2_InfectedNames[GetInfectedClass(iClient)]);
        QueuePlayerSI(iClient);
    }
}

void Event_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0 || !IsClientInGame(iClient))
        return;

    if (GetClientTeam(iClient) != L4D2Team_Infected)
        return;

    PrintDebug("\x05%N \x01died \x01as (\x04%s\x01)", iClient, L4D2_InfectedNames[GetInfectedClass(iClient)]);
    QueuePlayerSI(iClient);
}

void Event_BotPlayerReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    HandlePlayerReplace(GetClientOfUserId(eEvent.GetInt("player")), GetClientOfUserId(eEvent.GetInt("bot")));
}

void Event_PlayerBotReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    HandlePlayerReplace(GetClientOfUserId(eEvent.GetInt("bot")), GetClientOfUserId(eEvent.GetInt("player")));
}

void HandlePlayerReplace(int iReplacer, int iReplacee) {
    // reported a compatibility issue with confoglcompmod BotKick module
    // well just dont use it which blocks client connection instead of slaying
    if (iReplacer <= 0 || iReplacee <= 0 || !IsClientInGame(iReplacer) || !IsClientInGame(iReplacee))
        return;

    if (GetClientTeam(iReplacer) != L4D2Team_Infected)
        return;

    PrintDebug("\x05%N \x01replaced \x05%N \x01as (\x04%s\x01)", iReplacer, iReplacee, L4D2_InfectedNames[GetInfectedClass(iReplacer)]);

    if (GetInfectedClass(iReplacer) == L4D2Infected_Tank && !IsFakeClient(iReplacer)) {
        PrintDebug("\x05%N \x01(\x04%s\x01) \x01replaced an \x04AI Tank", iReplacer, L4D2_InfectedNames[g_iStoredClass[iReplacer]]);
        QueuePlayerSI(iReplacer);
        return;
    }

    g_iStoredClass  [iReplacer] = g_iStoredClass  [iReplacee];
    g_bPlayerSpawned[iReplacer] = g_bPlayerSpawned[iReplacee]; // what if replacing ghost? :(

    g_iStoredClass  [iReplacee] = SI_None;
    g_bPlayerSpawned[iReplacee] = false;

    // compatible with "l4d2_nosecondchances"
    if (!IsPlayerAlive(iReplacer) || (IsFakeClient(iReplacer) && (!g_bAllowInfectedBots || g_iBlockInfBots)))
        QueuePlayerSI(iReplacer);
}

public void L4D_OnReplaceTank(int iTank, int iNewTank) {
    if (iNewTank <= 0 || iNewTank > MaxClients)
        return;

    if (!IsClientInGame(iNewTank) || !IsPlayerAlive(iNewTank))
        return;

    if (GetClientTeam(iNewTank) != L4D2Team_Infected)
        return;

    PrintDebug("\x05%N \x01(\x04%s\x01) \x01is going to replace \x05%N\x01's \x04Tank", iNewTank, L4D2_InfectedNames[GetInfectedClass(iNewTank)], iTank);
    QueuePlayerSI(iNewTank);
}

// Helper to check if the player entering ghost state has committed a despawn.
public Action L4D_OnEnterGhostStatePre(int iClient) {
    static int iAbortedControlOffs = -1;
    if (iAbortedControlOffs == -1)
        iAbortedControlOffs = FindSendPropInfo("CTerrorPlayer", "m_bSurvivorGlowEnabled") + 1;

    IsCulling(true, GetEntData(iClient, iAbortedControlOffs, 1) != 0);
    return Plugin_Continue;
}

// Give spawned player an SI from queue and/or remember what their class is.
public void L4D_OnEnterGhostState(int iClient) {
    int SI = GetInfectedClass(iClient);

    // Don't mess up when player despawns or round restarts.
    if (!IsCulling() && g_bIsLive) {
        int iTmp = PopQueuedSI(iClient);
        if (iTmp != SI_None) {
            SI = iTmp;
            L4D_SetClass(iClient, SI);
        }
    }

    PrintDebug("%N %s \x01as (\x04%s\x01)", iClient, IsCulling() ? "\x05respawned" : "\x01spawned", L4D2_InfectedNames[SI]);

    g_iStoredClass  [iClient] = SI;
    g_bPlayerSpawned[iClient] = false;
}

bool IsCulling(bool bSet = false, bool bVal = false) {
    static bool bIsCulling = false;
    if (bSet)
        bIsCulling = bVal;
    return bIsCulling;
}

// Swap boomer to spitter and back when a player pushes a button.
public void OnPlayerRunCmdPost(int iClient, int iButtons) {
    static bool bInAttack2[MAXPLAYERS + 1];
    static int  iInfCls;
    static int  iIdx;

    if (!g_bSwapDuringTank)
        return;

    if (!L4D2_IsTankInPlay())
        return;

    if (!IsValidInfected(iClient))
        return;

    if (g_bPlayerSpawned[iClient])
        return;

    // Player was holding m2, and now isn't. (Released)
    if (!(iButtons & IN_ATTACK2) && bInAttack2[iClient]) {
        bInAttack2[iClient] = false;
        return;
    }

    // Player was not holding m2, and now is. (Pressed)
    if ((iButtons & IN_ATTACK2) && !bInAttack2[iClient]) {
        bInAttack2[iClient] = true;
        iInfCls = g_iStoredClass[iClient];

        if (iInfCls == L4D2Infected_Boomer) {
            iIdx = g_arrSpawns.FindValue(L4D2Infected_Spitter);
            if (iIdx == -1)
                return;

            g_iStoredClass[iClient] = L4D2Infected_Spitter;
            L4D_SetClass(iClient, L4D2Infected_Spitter);
            PrintHintText(iClient, "Press <Mouse2> to change to boomer.");
            g_arrSpawns.Set(iIdx, iInfCls);
        } else if (iInfCls == L4D2Infected_Spitter) {
            iIdx = g_arrSpawns.FindValue(L4D2Infected_Boomer);
            if (iIdx == -1)
                return;

            g_iStoredClass[iClient] = L4D2Infected_Boomer;
            L4D_SetClass(iClient, L4D2Infected_Boomer);
            PrintHintText(iClient, "Press <Mouse2> to change to spitter.");
            g_arrSpawns.Set(iIdx, iInfCls);
        }
    }
}

// -----------------------//
//      Bot Spawning      //
// -----------------------//

// Change the bot's class on spawn to the one popped from queue
public Action L4D_OnSpawnSpecial(int &iZombieClass, const float vPos[3], const float vAng[3]) {
    PrintDebug("Director attempting to spawn (\x04%s\x01)", L4D2_InfectedNames[iZombieClass]);

    if (!g_bAllowInfectedBots || g_iBlockInfBots)
        return Plugin_Continue;

    if (GetSICount(false) + 1 > g_iMaxInfected) {
        PrintDebug("Blocking director spawn for \x03going over player limit\x01.");
        return Plugin_Handled;
    }

    BotInfectedClass(true, PopQueuedSI(-1));
    if (BotInfectedClass() == SI_None) {
        PrintDebug("Blocking director spawn for \x04running out of available SI\x01.");
        return Plugin_Handled;
    }

    iZombieClass = BotInfectedClass();
    PrintDebug("Overriding director spawn to (\x04%s\x01)", L4D2_InfectedNames[BotInfectedClass()]);
    return Plugin_Changed;
}

public void L4D_OnSpawnSpecial_Post(int iClient, int iZombieClass, const float vPos[3], const float vAng[3]) {
    PrintDebug("Director spawned a bot (expected \x05%s\x01, got %s%s\x01)", L4D2_InfectedNames[BotInfectedClass()], BotInfectedClass() == iZombieClass ? "\x05" : "\x04", L4D2_InfectedNames[iZombieClass]);

    if (!g_bAllowInfectedBots || g_iBlockInfBots)
        return;

    BotInfectedClass(true, SI_None);
    g_iStoredClass  [iClient] = iZombieClass;
    g_bPlayerSpawned[iClient] = true;
}

public void L4D_OnSpawnSpecial_PostHandled(int iClient, int iZombieClass, const float vPos[3], const float vAng[3]) {
    PrintDebug("Director's spawn was \x04blocked \x01(expected \x05%s\x01, got %s%s\x01)", L4D2_InfectedNames[BotInfectedClass()], BotInfectedClass() == iZombieClass ? "\x05" : "\x04", L4D2_InfectedNames[iZombieClass]);

    if (!g_bAllowInfectedBots || g_iBlockInfBots)
        return;

    if (BotInfectedClass() != SI_None) {
        QueueSI(BotInfectedClass(), true);
        BotInfectedClass(true, SI_None);
    }
}

int BotInfectedClass(bool bSet = false, int iVal = SI_None) {
    static int iClass = SI_None;
    if (bSet)
        iClass = iVal;
    return iClass;
}

// -------------------------//
//       Stocks & Such      //
// -------------------------//

void QueuePlayerSI(int iClient) {
    int SI = g_iStoredClass[iClient];
    if (IsAbleToQueue(SI, iClient))
        QueueSI(SI, !g_bPlayerSpawned[iClient]);

    g_iStoredClass  [iClient] = SI_None;
    g_bPlayerSpawned[iClient] = false;
}

void QueueSI(int SI, bool bFront) {
    if (bFront && g_arrSpawns.Length) {
        g_arrSpawns.ShiftUp(0);
        g_arrSpawns.Set(0, SI);
    } else {
        g_arrSpawns.Push(SI);
    }

    PrintDebug("Queuing (\x05%s\x01) to \x04%s", L4D2_InfectedNames[SI], bFront ? "the front" : "the end");
}

int PopQueuedSI(int iSkipClient) {
    static const char szOverLimitReason[MAX_OverLimitReason][] = {
        "",
        "Dominator limit",
        "Class limit"
    };

    int iSize = g_arrSpawns.Length;
    if (iSize == 0)
        return SI_None;

    for (int i = 0; i < iSize; i++) {
        int QueuedSI = g_arrSpawns.Get(i);

        int iStatus = IsClassOverLimit(QueuedSI, iSkipClient);
        if (iStatus == OverLimit_OK) {
            g_arrSpawns.Erase(i);
            PrintDebug("Popped (\x05%s\x01) after \x04%i \x01%s", L4D2_InfectedNames[QueuedSI], i + 1, (i + 1) > 1 ? "tries" : "try");
            return QueuedSI;
        } else {
            PrintDebug("Popping (\x05%s\x01) but \x03over limit \x01(\x03reason: %s\x01)", L4D2_InfectedNames[QueuedSI], szOverLimitReason[iStatus]);
        }
    }

    PrintDebug("\x04Failed to pop queued SI! \x01(size = \x05%i\x01)", iSize);
    return SI_None;
}

/**
 * TODO:
 *   Fill with the remaining first hit classes when the Infected Team isn't full?
 * NOTE:
 *   Director randomly picks a beginning index for the first hit
 *   i.e. if pick is 4, then first hit setup will be Spitter(4),Jockey(5),Charger(6),Smoker(1)
 */
void FillQueue() {
    int iCounts[SI_MAX_SIZE] = {0};
    CollectZombies(iCounts);

    char szClsString[255] = "";
    for (int SI = SI_GENERIC_BEGIN; SI <= SI_GENERIC_END; SI++) {
        g_iSILimits[SI] = g_cvSILimits[SI].IntValue;

        for (int j = 0; j < g_iSILimits[SI] - iCounts[SI]; j++) {
            g_arrSpawns.Push(SI);

            StrCat(szClsString, sizeof(szClsString), L4D2_InfectedNames[SI]);
            StrCat(szClsString, sizeof(szClsString), ", ");
        }
    }

    int iIdx = strlen(szClsString) - 2;
    if (iIdx < 0) iIdx = 0;
    szClsString[iIdx] = '\0';
    PrintDebug("Filled queue (%s)", szClsString);
}

/**
 * Check if specific class can be queued based on initial SI pool.
 *
 * NOTE:
 *   Static limits used here.
 */
bool IsAbleToQueue(int SI, int iSkipClient) {
    if (SI >= SI_GENERIC_BEGIN && SI <= SI_GENERIC_END) {
        int iCounts[SI_MAX_SIZE] = {0};

        // NOTE: We're checking after player actually spawns, it's necessary to ignore his class.
        CollectZombies(iCounts, iSkipClient);
        CollectQueuedZombies(iCounts);

        if (iCounts[SI] < g_iSILimits[SI])
            return true;
    }

    PrintDebug("\x04Unexpected class \x01(\x05%s\x01)", SI == -1 ? "INVALID" : L4D2_InfectedNames[SI]);
    return false;
}

/**
 * Check if specific class is over limit based on limit convars and dominator flags.
 *  1.  < class limit
 *  2a. not dominator
 *  2b. is dominator
 *  3b. total dominators < 3
 *
 * NOTE:
 *   Dynamic limits used here.
 *
 * TODO:
 *   No more redundant collecting zombies in the same frame?
 */
int IsClassOverLimit(int SI, int iSkipClient) {
    if (!g_cvSILimits[SI])
        return OverLimit_OK;

    int iCounts[SI_MAX_SIZE] = {0};

    // NOTE: We're checking after player actually spawns, it's necessary to ignore his class.
    CollectZombies(iCounts, iSkipClient);

    if (iCounts[SI] >= g_cvSILimits[SI].IntValue)
        return OverLimit_Class;

    if (NoSpitterDuringTank(SI))
        return OverLimit_Class;

    if (IsSupportAlive(SI, iCounts))
        return OverLimit_Class;

    if (!IsDominator(SI))
        return OverLimit_OK;

    int iDominatorCount = 0;
    for (int i = SI_GENERIC_BEGIN; i <= SI_GENERIC_END; i++) {
        if (IsDominator(i)) iDominatorCount += iCounts[i];
    }

    if (iDominatorCount >= 3)
        return OverLimit_Dominator;

    return OverLimit_OK;
}

bool NoSpitterDuringTank(int SI) {
    if (!g_bNoSpitterDuringTank)
        return false;

    if (SI != L4D2Infected_Spitter)
        return false;

    if (!L4D2_IsTankInPlay())
        return false;

    return true;
}

bool IsSupportAlive(int SI, const int[] iCounts) {
    if (g_bSwapDuringTank)
        return false;

    if (!L4D2_IsTankInPlay())
        return false;

    if (g_cvSILimits[L4D2Infected_Boomer].IntValue > 0 && g_cvSILimits[L4D2Infected_Spitter].IntValue  > 0) {
        if (SI == L4D2Infected_Boomer && iCounts[L4D2Infected_Spitter] > 0)
            return true;

        if (SI == L4D2Infected_Spitter && iCounts[L4D2Infected_Boomer] > 0)
            return true;
     }

    return false;
}

bool IsDominator(int SI) {
    return g_iDominators & (1 << (SI - 1)) > 0;
}

int CollectZombies(int iZombies[SI_MAX_SIZE], int iSkipClient = -1) {
    int iCount = 0;

    char szClsString[255] = "";
    for (int i = 1; i <= MaxClients; i++) {
        if (i == iSkipClient)
            continue;

        if (!IsClientInGame(i) || !IsPlayerAlive(i))
            continue;

        if (GetClientTeam(i) != L4D2Team_Infected)
            continue;

        int SI = g_iStoredClass[i];
        if (SI == SI_None)
            continue;

        iZombies[SI]++;
        iCount++;
        StrCat(szClsString, sizeof(szClsString), L4D2_InfectedNames[SI]);
        StrCat(szClsString, sizeof(szClsString), ", ");
    }

    int iIdx = strlen(szClsString) - 2;
    if (iIdx < 0) iIdx = 0;
    szClsString[iIdx] = '\0';
    PrintDebug("Collect zombies (%s)", szClsString);

    return iCount;
}

int CollectQueuedZombies(int iZombies[SI_MAX_SIZE]) {
    int iSize = g_arrSpawns.Length;

    char szClsString[255] = "";
    for (int i = 0; i < iSize; i++) {
        int SI = g_arrSpawns.Get(i);

        iZombies[SI]++;
        StrCat(szClsString, sizeof(szClsString), L4D2_InfectedNames[SI]);
        StrCat(szClsString, sizeof(szClsString), ", ");
    }

    int iIdx = strlen(szClsString) - 2;
    if (iIdx < 0) iIdx = 0;
    szClsString[iIdx] = '\0';
    PrintDebug("Collect queued zombies (%s)", szClsString);

    return iSize;
}

int GetSICount(bool bIsHumanOnly = true) {
    int iCount = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (GetClientTeam(i) != L4D2Team_Infected)
            continue;

        if (IsFakeClient(i)) {
            if (bIsHumanOnly)
                continue;

            if (GetInfectedClass(i) == L4D2Infected_Tank)
                continue;

            if (!IsPlayerAlive(i))
                continue;
        }

        iCount++;
    }

    return iCount;
}

void PrintDebug(const char[] szFormat, any ...) {
    if (!g_bDebug)
        return;

    char szMsg[255];
    VFormat(szMsg, sizeof(szMsg), szFormat, 2);

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        if (!ST_IsAdminClient(i))
            continue;

        PrintToChat(i, "\x04[DEBUG]\x01 %s", szMsg);
    }
}