#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <l4d2lib>
#include <sdkhooks>
#include <sdktools>

#define Z_TANK 8
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

#define ZOMBIEMANAGER_GAMEDATA  "l4d2_zombiemanager"
#define LEFT4FRAMEWORK_GAMEDATA "left4dhooks.l4d2"

Address pZombieManager = Address_Null;

ConVar  g_cvCommonLimit;
int     g_iCommonLimit;

ConVar  g_cvSurvivorLimit;
int     g_iSurvivorLimit;

int     m_nPendingMobCount;
float   g_fSavedTime;

public Plugin myinfo =  {
    name        = "L4D2 Horde",
    author      = "Visor, Sir, A1m`",
    description = "Modifies Event Horde sizes and stops it completely during Tank",
    version     = "1.3",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart() {
    InitGameData();

    g_cvCommonLimit = FindConVar("z_common_limit");
    g_iCommonLimit  = g_cvCommonLimit.IntValue;
    g_cvCommonLimit.AddChangeHook(ConVarChanged_CommonLimit);

    g_cvSurvivorLimit = FindConVar("survivor_limit");
    g_iSurvivorLimit  = g_cvSurvivorLimit.IntValue;
    g_cvSurvivorLimit.AddChangeHook(ConVarChanged_SurvivorLimit);

    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

void ConVarChanged_CommonLimit(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iCommonLimit = g_cvCommonLimit.IntValue;
}

void ConVarChanged_SurvivorLimit(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iSurvivorLimit = g_cvSurvivorLimit.IntValue;
}

void InitGameData() {
    GameData gmData = new GameData(LEFT4FRAMEWORK_GAMEDATA);
    if (!gmData) SetFailState("%s gamedata missing or corrupt", LEFT4FRAMEWORK_GAMEDATA);
    pZombieManager = gmData.GetAddress("ZombieManager");
    if (!pZombieManager) SetFailState("Couldn't find the 'ZombieManager' address");
    delete gmData;

    GameData gmData2 = new GameData(ZOMBIEMANAGER_GAMEDATA);
    if (!gmData2) SetFailState("%s gamedata missing or corrupt", ZOMBIEMANAGER_GAMEDATA);
    m_nPendingMobCount = gmData2.GetOffset("ZombieManager->m_nPendingMobCount");
    if (m_nPendingMobCount == -1) SetFailState("Failed to get offset 'ZombieManager->m_nPendingMobCount'.");
    delete gmData2;
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_fSavedTime = 0.0;
}

public void OnEntityCreated(int iEnt, const char[] szClsName) {
    if (strcmp (szClsName, "infected") == 0) {
        if (IsInfiniteHordeActive() && !IsTankUp() && !ArePlayersBiled() && g_iSurvivorLimit > 1)
            SDKHook(iEnt, SDKHook_SpawnPost, CommonSpawnPost);
    }
}

public void CommonSpawnPost(int iEnt) {
    if (IsValidEntity(iEnt)) {
        if (GetAllCommon() > (g_iCommonLimit - 8))
            RemoveEntity(iEnt);
    }
}

public Action L4D_OnSpawnMob(int &iAmount) {
    /////////////////////////////////////
    // - Called on Event Hordes.
    // - Called on Panic Event Hordes.
    // - Called on Natural Hordes.
    // - Called on Onslaught (Mini-finale or finale Scripts)

    // - Not Called on Boomer Hordes.
    // - Not Called on z_spawn mob.
    ////////////////////////////////////

    float fTime = GetGameTime();
    float fHordeTimer;

    // "Pause" the infinite horde during the Tank fight
    if (IsInfiniteHordeActive()) {
        if (IsTankUp()) {
            SetPendingMobCount(0);
            iAmount = 0;
            return Plugin_Handled;
        } else {
            // Horde Timer
            if (fTime - g_fSavedTime > 10.0) {
                fHordeTimer = 0.0;
            } else {
                // Scale Horde depending on how often the timer triggers.
                fHordeTimer = fTime - g_fSavedTime;
                iAmount = RoundToCeil(fHordeTimer) * 2;
            }
        }
        g_fSavedTime = fTime;
    }

    return Plugin_Continue;
}

bool IsInfiniteHordeActive() {
    int iCountDown = GetHordeCountdown();
    return (iCountDown > -1 && iCountDown <= 10);
}

void SetPendingMobCount(int iCount) {
    StoreToAddress(pZombieManager + view_as<Address>(m_nPendingMobCount), iCount, NumberType_Int32);
}

int GetHordeCountdown() {
    return (CTimer_HasStarted(L4D2Direct_GetMobSpawnTimer())) ? RoundFloat(CTimer_GetRemainingTime(L4D2Direct_GetMobSpawnTimer())) : -1;
}

int GetAllCommon() {
    int iCount, iEnt = -1;
    while ((iEnt = FindEntityByClassname(iEnt, "infected")) != -1) {
        if (IsValidEntity(iEnt) && GetEntProp(iEnt, Prop_Send, "m_mobRush") > 0)
            iCount++;
    }
    return iCount;
}

bool ArePlayersBiled() {
    float fVomitFade, fNow = GetGameTime();
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR) {
            fVomitFade = GetEntPropFloat(i, Prop_Send, "m_vomitFadeStart");
            if (fVomitFade != 0.0 && fVomitFade + 8.0 > fNow) {
                return true;
            }
        }
    }
    return false;
}

bool IsTankUp() {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED) {
            if (GetEntProp(i, Prop_Send, "m_zombieClass") == Z_TANK && IsPlayerAlive(i))
                return true;
        }
    }
    return false;
}