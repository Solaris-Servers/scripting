#pragma newdecls required
#pragma semicolon 1

/* SM Includes */
#include <sourcemod>
#include <sdktools>
#include <smac>

#define MAX_DETECTIONS 30

/* Globals */
int g_iTicksLeft [MAXPLAYERS + 1];
int g_iDetections[MAXPLAYERS + 1];
int g_iMaxTicks;

float g_fDetectedTime[MAXPLAYERS + 1];
float g_fPrevLatency [MAXPLAYERS + 1];

/* Plugin Info */
public Plugin myinfo = {
    name        = "SMAC Anti-Speedhack",
    author      = SMAC_AUTHOR,
    description = "Prevents speedhack cheats from working",
    version     = SMAC_VERSION,
    url         = SMAC_URL
};

/* Plugin Functions */
public void OnPluginStart() {
    // The server's tickrate * 2.0 as a buffer zone.
    g_iMaxTicks = RoundToCeil(1.0 / GetTickInterval() * 2.0);
    for (int i = 0; i < sizeof(g_iTicksLeft); i++) {
        g_iTicksLeft[i] = g_iMaxTicks;
    }

    CreateTimer(0.1, Timer_AddTicks, _, TIMER_REPEAT);
    LoadTranslations("smac.phrases");
}

public void OnClientConnected(int iClient) {
    g_iTicksLeft   [iClient] = g_iMaxTicks;
    g_iDetections  [iClient] = 0;
    g_fDetectedTime[iClient] = 0.0;
    g_fPrevLatency [iClient] = 0.0;
}

Action Timer_AddTicks(Handle timer) {
    static float fLastProcessed;
    int iNewTicks = RoundToCeil((GetEngineTime() - fLastProcessed) / GetTickInterval());
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        // Make sure latency didn't spike more than 5ms.
        // We want to avoid writing a lagging client to logs.
        float fLatency = GetClientLatency(i, NetFlow_Outgoing);
        if (!g_iTicksLeft[i] && FloatAbs(g_fPrevLatency[i] - fLatency) <= 0.005) {
            if (++g_iDetections[i] >= MAX_DETECTIONS && GetGameTime() > g_fDetectedTime[i]) {
                if (SMAC_CheatDetected(i, Detection_Speedhack, null) == Plugin_Continue) {
                    SMAC_PrintAdminNotice("%t", "SMAC_SpeedhackDetected", i);
                    // Only log once per connection.
                    if (g_fDetectedTime[i] == 0.0)
                        SMAC_LogAction(i, "is suspected of using speedhack.");
                }
                g_fDetectedTime[i] = GetGameTime() + 30.0;
            }
        } else if (g_iDetections[i]) {
            g_iDetections[i]--;
        }

        g_fPrevLatency[i] = fLatency;
        if ((g_iTicksLeft[i] += iNewTicks) > g_iMaxTicks)
            g_iTicksLeft[i] = g_iMaxTicks;
    }

    fLastProcessed = GetEngineTime();
    return Plugin_Continue;
}

public void OnPlayerRunCmdPre(int iClient, int iButtons) {
    // Ignore bots and not valid clients
    if (iClient <= 0)
        return;

    if (iClient > MaxClients)
        return;

    if (!IsClientInGame(iClient))
        return;

    if (IsFakeClient(iClient))
        return;

    if (!g_iTicksLeft[iClient])
        return;

    if (IsPlayerAlive(iClient))
        g_iTicksLeft[iClient]--;
}