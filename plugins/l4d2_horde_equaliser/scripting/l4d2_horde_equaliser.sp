#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <l4d2lib>
#include <sdktools>
#include <colors>

#define Z_TANK 8
#define TEAM_INFECTED 3
#define MAX_SURVIVORS 4

#define ZOMBIEMANAGER_GAMEDATA  "l4d2_zombiemanager"
#define LEFT4FRAMEWORK_GAMEDATA "left4dhooks.l4d2"

#define HORDE_MIN_SIZE_AUDIAL_FEEDBACK 120
#define MAX_CHECKPOINTS 4

#define HORDE_SOUND "/npc/mega_mob/mega_mob_incoming.wav"

Address pZombieManager = Address_Null;

ConVar  g_cvSurvivorLimit;
ConVar  g_cvNoEventHordeDuringTanks;
ConVar  g_cvHordeCheckpointAnnounce;

bool    g_bMapStarted;
bool    g_bAnnouncedInChat;
bool    g_bAnnouncedEventEnd;
bool    g_bCheckpointAnnounced[MAX_CHECKPOINTS];
bool    g_bNoEventHordeDuringTanks;
bool    g_bHordeCheckpointAnnounce;

int     g_iSurvivorLimit;
int     g_iCommonLimit;
int     g_iCommonTank;
int     g_iCommonTotal;
int     g_iLastCheckpoint;
int     m_nPendingMobCount;

public Plugin myinfo = {
    name        = "L4D2 Horde Equaliser",
    author      = "Visor (original idea by Sir), A1m`",
    description = "Make certain event hordes finite",
    version     = "3.0.9",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart() {
    InitGameData();

    g_cvSurvivorLimit = FindConVar("survivor_limit");
    g_iSurvivorLimit  = g_cvSurvivorLimit.IntValue;
    g_cvSurvivorLimit.AddChangeHook(ConVarChanged_SurvivorLimit);

    g_cvNoEventHordeDuringTanks = CreateConVar(
    "l4d2_heq_no_tank_horde", "0",
    "Put infinite hordes on a 'hold up' during Tank fights",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bNoEventHordeDuringTanks = g_cvNoEventHordeDuringTanks.BoolValue;
    g_cvNoEventHordeDuringTanks.AddChangeHook(ConVarChanged_NoEventHordeDuringTanks);

    g_cvHordeCheckpointAnnounce = CreateConVar(
    "l4d2_heq_checkpoint_sound", "1",
    "Play the incoming mob sound at checkpoints (each 1/4 of total commons killed off) to simulate L4D1 behaviour",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bHordeCheckpointAnnounce = g_cvHordeCheckpointAnnounce.BoolValue;
    g_cvHordeCheckpointAnnounce.AddChangeHook(ConVarChanged_HordeCheckpointAnnounce);

    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

void ConVarChanged_SurvivorLimit(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iSurvivorLimit = g_cvSurvivorLimit.IntValue;
    if (g_bMapStarted) {
        g_iCommonLimit = GetModifiedHordeLimit(L4D2_GetMapValueInt("horde_limit", -1));
        g_iCommonTank  = L4D2_GetMapValueInt("horde_tank", -1);
    }
}

void ConVarChanged_NoEventHordeDuringTanks(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bNoEventHordeDuringTanks = g_cvNoEventHordeDuringTanks.BoolValue;
}

void ConVarChanged_HordeCheckpointAnnounce(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bHordeCheckpointAnnounce = g_cvHordeCheckpointAnnounce.BoolValue;
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

public void OnMapStart() {
    g_bMapStarted = true;
    g_iCommonLimit = GetModifiedHordeLimit(L4D2_GetMapValueInt("horde_limit", -1));
    g_iCommonTank  = L4D2_GetMapValueInt("horde_tank", -1);
    PrecacheSound(HORDE_SOUND);
}

public void OnMapEnd() {
    g_bMapStarted = false;
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_iCommonTotal       = 0;
    g_iLastCheckpoint    = 0;
    g_bAnnouncedInChat   = false;
    g_bAnnouncedEventEnd = false;
    for (int i = 0; i < MAX_CHECKPOINTS; i++) {
        g_bCheckpointAnnounced[i] = false;
    }
}

public void OnEntityCreated(int iEntity, const char[] szClassName) {
    if (g_iCommonLimit == -1)
        return;
    // TO-DO: Find a value that tells wanderers from active event commons?
    if (strcmp(szClassName, "infected") == 0 && IsInfiniteHordeActive()) {
        // Don't count in boomer hordes, alarm cars and wanderers during a Tank fight
        if (g_bNoEventHordeDuringTanks && IsTankUp())
            return;
        // Our job here is done
        if (g_iCommonTotal >= g_iCommonLimit) {
            if (!g_bAnnouncedEventEnd){
                CPrintToChatAll("<{olive}Horde{default}> {red}No{default} common remaining!");
                g_bAnnouncedEventEnd = true;
            }
            return;
        }
        g_iCommonTotal++;
        if (g_bHordeCheckpointAnnounce && (g_iCommonTotal >= ((g_iLastCheckpoint + 1) * RoundFloat(float(g_iCommonLimit / MAX_CHECKPOINTS))))) {
            if (g_iCommonLimit >= HORDE_MIN_SIZE_AUDIAL_FEEDBACK)
                EmitSoundToAll(HORDE_SOUND);
            int iRemaining = g_iCommonLimit - g_iCommonTotal;
            if (iRemaining != 0) CPrintToChatAll("<{olive}Horde{default}> {red}%i{default} common remaining..", iRemaining);
            g_bCheckpointAnnounced[g_iLastCheckpoint] = true;
            g_iLastCheckpoint++;
        }
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
    // "Pause" the infinite horde during the Tank fight
    if ((g_bNoEventHordeDuringTanks || g_iCommonTank > 0) && IsTankUp() && IsInfiniteHordeActive()) {
        SetPendingMobCount(0);
        iAmount = 0;
        return Plugin_Handled;
    }
    // Excluded map -- don't block any infinite hordes on this one
    if (g_iCommonLimit < 0)
        return Plugin_Continue;
    // If it's a "finite" infinite horde...
    if (IsInfiniteHordeActive()) {
        if (!g_bAnnouncedInChat) {
            CPrintToChatAll("<{olive}Horde{default}> A {blue}finite event{default} of {olive}%i{default} commons has started! Rush or wait it out, the choice is yours!", g_iCommonLimit);
            g_bAnnouncedInChat = true;
        }
        // ...and it's overlimit...
        if (g_iCommonTotal >= g_iCommonLimit) {
            SetPendingMobCount(0);
            iAmount = 0;
            return Plugin_Handled;
        }
    }
    // ...or not.
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

bool IsTankUp() {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED) {
            if (GetEntProp(i, Prop_Send, "m_zombieClass") == Z_TANK && IsPlayerAlive(i))
                return true;
        }
    }
    return false;
}

int GetModifiedHordeLimit(int iHordeLimit) {
    if (iHordeLimit == -1 || g_iSurvivorLimit == 4)
        return iHordeLimit;
    return iHordeLimit / MAX_SURVIVORS * g_iSurvivorLimit;
}