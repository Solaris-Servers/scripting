#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define MAX_BOSSES 5
#define NULL_VELOCITY view_as<float>({0.0, 0.0, 0.0})

int g_iTankCount [2];
int g_iWitchCount[2];

bool g_bDeleteWitches;
bool g_bFinaleStarted;

float g_fTankSpawn [MAX_BOSSES][2][3];
float g_fWitchSpawn[MAX_BOSSES][2][3];

ConVar g_cvEnabled;
bool   g_bEnabled;

char g_szMap[64];

public void OnPluginStart() {
    g_cvEnabled = CreateConVar(
    "lock_boss_spawns", "1",
    "Enables forcing same coordinates for tank and witch spawns",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bEnabled = g_cvEnabled.BoolValue;
    g_cvEnabled.AddChangeHook(ConVarChange);
    HookEvent("round_end",    Event_RoundEnd,    EventHookMode_PostNoCopy);
    HookEvent("finale_start", Event_FinaleStart, EventHookMode_PostNoCopy);
}

public void OnMapStart() {
    g_bFinaleStarted = false;
    GetCurrentMap(g_szMap, sizeof(g_szMap));
    for (int i = 0; i <= 1; i++) {
        g_iTankCount [i] = 0;
        g_iWitchCount[i] = 0;
    }
}

void Event_RoundEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bDeleteWitches = true;
    CreateTimer(5.0, WitchTimerReset);
}

Action WitchTimerReset(Handle hTimer) {
    g_bDeleteWitches = false;
    return Plugin_Stop;
}

void Event_FinaleStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bFinaleStarted = true;
}

void ConVarChange(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bEnabled = g_cvEnabled.BoolValue;
}

public void L4D_OnSpawnTank_Post(int iClient, const float vPos[3], const float vAng[3]) {
    if (!g_bEnabled) return;
    // Don't touch tanks on finale events
    if (g_bFinaleStarted) return;
    // Don't track tank spawns on c5m5 or tank can spawn behind other team.
    if (strcmp(g_szMap, "c5m5_bridge") == 0) return;
    // Can't track more tanks if our witch array is full
    if (g_iTankCount[InSecondHalfOfRound()] >= MAX_BOSSES)
        return;
    if (!InSecondHalfOfRound()) {
        g_fTankSpawn[g_iTankCount[0]][0] = vPos;
        g_fTankSpawn[g_iTankCount[0]][1] = vAng;
        g_iTankCount[0]++;
    } else if (InSecondHalfOfRound() && g_iTankCount[0] > g_iTankCount[1]) {
        TeleportEntity(iClient, g_fTankSpawn[g_iTankCount[1]][0], g_fTankSpawn[g_iTankCount[1]][1], NULL_VELOCITY);
        g_iTankCount[1]++;
    }
}

public Action L4D_OnSpawnWitch(const float vPos[3], const float vAng[3]) {
    if (!g_bEnabled) return Plugin_Continue;
    // Used to delete round2 extra witches, which spawn on round start instead of by flow
    if (g_bDeleteWitches) return Plugin_Handled;
    return Plugin_Continue;
}

public void L4D_OnSpawnWitch_Post(int iEntity, const float vPos[3], const float vAng[3]) {
    if (!g_bEnabled) return;
    // Can't track more witches if our witch array is full
    if (g_iWitchCount[InSecondHalfOfRound()] >= MAX_BOSSES)
        return;
    if (!InSecondHalfOfRound()) {
        // If it's the first round, track our witch.
        g_fWitchSpawn[g_iWitchCount[0]][0] = vPos;
        g_fWitchSpawn[g_iWitchCount[0]][1] = vAng;
        g_iWitchCount[0]++;
    } else if (InSecondHalfOfRound() && g_iWitchCount[0] > g_iWitchCount[1]) {
        // Until we have found the same number of witches as from round1, teleport them to round1 locations
        TeleportEntity(iEntity, g_fWitchSpawn[g_iWitchCount[1]][0], g_fWitchSpawn[g_iWitchCount[1]][1], NULL_VELOCITY);
        g_iWitchCount[1]++;
    }
}

stock int InSecondHalfOfRound() {
    return GameRules_GetProp("m_bInSecondHalfOfRound");
}