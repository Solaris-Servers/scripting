#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <left4dhooks>
#include <colors>
#include <readyup>

#include <l4d2util/stocks>
#include <l4d2util/tanks>

#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))
#define EXTRA_FLOW   3000.0
#define RESPAWN_FREQ 5.0

ConVar g_cvEnabled;
bool   g_bEnabled;

ConVar g_cvSpawnFreq;
float  g_fSpawnFreq;

Handle g_hWitchSpawnTimer;
float  g_fLastSpawn;
bool   g_bIsRoundLive;

public Plugin myinfo = {
    name        = "L4D2 Multiwitch",
    author      = "CanadaRox",
    description = "A plugin that spawns unlimited witches off of a timer.",
    version     = "1.0",
    url         = "https://github.com/CanadaRox/sourcemod-plugins/tree/master/mutliwitch"
};

public void OnPluginStart() {
    g_cvEnabled = CreateConVar(
    "l4d_1v1multiwitch_enabled", "0",
    "Enable multiple witch spawning",
    FCVAR_NONE, true, 1.0, true, 1.0);
    g_bEnabled = g_cvEnabled.BoolValue;
    g_cvEnabled.AddChangeHook(ConVarChanged);

    g_cvSpawnFreq = CreateConVar(
    "l4d_1v1multiwitch_spawnfreq", "30",
    "How many seconds before the next witch spawns",
    FCVAR_NONE, true, 1.0, false, 0.0);
    g_fSpawnFreq = g_cvSpawnFreq.FloatValue;
    g_cvSpawnFreq.AddChangeHook(ConVarChanged);

    RegConsoleCmd("sm_witch", Cmd_Witch);

    HookEvent("round_start",           Event_RoundStart,   EventHookMode_PostNoCopy);
    HookEvent("round_end",             Event_RoundEnd,     EventHookMode_PostNoCopy);
    HookEvent("player_left_safe_area", Event_LeftSafeArea, EventHookMode_PostNoCopy);
}

void ConVarChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bEnabled   = g_cvEnabled.BoolValue;
    g_fSpawnFreq = g_cvSpawnFreq.FloatValue;
    if (g_hWitchSpawnTimer != null) delete g_hWitchSpawnTimer;
    if (!g_bEnabled)     return;
    if (!g_bIsRoundLive) return;
    g_hWitchSpawnTimer = CreateTimer(g_fSpawnFreq, Timer_WitchSpawn, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void OnPluginEnd() {
    g_cvEnabled.SetBool(false);
    g_cvSpawnFreq.SetInt(30);
}

public Action Cmd_Witch(int iClient, int iArgs) {
    if (iArgs < 1) {
        CPrintToChat(iClient, "{green}[{default}MultiWitch{green}]{olive} Usage: !witch <10-30> or <0> to disable.");
        return Plugin_Handled;
    }

    char szArg[8];
    GetCmdArg(1, szArg, sizeof(szArg));

    if (!IsInteger(szArg)) {
        CPrintToChat(iClient, "{green}[{default}MultiWitch{green}]{olive} Use only {green}numeric{olive} argument (0, <10-30>).");
        return Plugin_Handled;
    }

    if (StringToFloat(szArg) == 0) {
        g_cvEnabled.SetBool(false);
        CPrintToChatAll("{green}[{default}MultiWitch{green}]{olive} Disabled.");
        return Plugin_Handled;
    }

    if (StringToFloat(szArg) < 10.0 || StringToFloat(szArg) > 30.0) {
        CPrintToChat(iClient, "{green}[{default}MultiWitch{green}]{olive} Usage: !witch <10-30> or <0> to disable.");
        return Plugin_Handled;
    }

    g_cvEnabled.SetBool(true);
    g_cvSpawnFreq.SetFloat(StringToFloat(szArg));
    CPrintToChatAll("{green}[{default}MultiWitch{green}]{olive} %.1f seconds timer enabled.", StringToFloat(szArg));
    return Plugin_Handled;
}

public void OnMapStart() {
    CreateTimer(RESPAWN_FREQ, Timer_WitchRespawn, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapEnd() {
    g_hWitchSpawnTimer = null;
}

public void OnRoundIsLive() {
    g_bIsRoundLive = true;
    if (g_hWitchSpawnTimer != null) delete g_hWitchSpawnTimer;
    g_hWitchSpawnTimer = CreateTimer(g_fSpawnFreq, Timer_WitchSpawn, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
    g_bIsRoundLive = false;
    g_fLastSpawn   = 0.0;
}

void Event_RoundEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bIsRoundLive = false;
    g_fLastSpawn   = 0.0;
    if (g_hWitchSpawnTimer != null) delete g_hWitchSpawnTimer;
}

void Event_LeftSafeArea(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (g_bIsRoundLive) return;
    g_bIsRoundLive = true;
    if (g_hWitchSpawnTimer != null) delete g_hWitchSpawnTimer;
    g_hWitchSpawnTimer = CreateTimer(g_fSpawnFreq, Timer_WitchSpawn, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_WitchSpawn(Handle hTimer) {
    if (!g_bEnabled)                                   return Plugin_Continue;
    if (IsTankInPlay())                                return Plugin_Continue;
    if (!g_bIsRoundLive)                               return Plugin_Continue;
    if ((GetGameTime() - g_fLastSpawn) < g_fSpawnFreq) return Plugin_Continue;
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i)) continue;
        int iFlags = GetCommandFlags("z_spawn_old");
        SetCommandFlags("z_spawn_old", iFlags ^ FCVAR_CHEAT);
        FakeClientCommand(i, "z_spawn_old witch auto");
        SetCommandFlags("z_spawn_old", iFlags);
        g_fLastSpawn = GetGameTime();
        return Plugin_Continue;
    }
    return Plugin_Continue;
}

Action Timer_WitchRespawn(Handle hTimer) {
    if (!g_bEnabled)                                   return Plugin_Continue;
    if (IsTankInPlay())                                return Plugin_Continue;
    if (!g_bIsRoundLive)                               return Plugin_Continue;
    if ((GetGameTime() - g_fLastSpawn) < g_fSpawnFreq) return Plugin_Continue;

    char    szBuffer[64];
    float   fFlow;
    int     iWitchSpawnCount;
    float   fOrigin[3];
    int     iSequence;
    Address pNavArea;

    int   iPsychonic   = GetMaxEntities();
    float fSurvMaxFlow = GetMaxSurvivorCompletion();
    if (fSurvMaxFlow > EXTRA_FLOW) {
        for (int iEnt = MaxClients + 1; iEnt <= iPsychonic; iEnt++) {
            if (IsValidEntity(iEnt) && GetEntityClassname(iEnt, szBuffer, sizeof(szBuffer)) && StrEqual(szBuffer, "witch")) {
                iSequence = GetEntProp(iEnt, Prop_Send, "m_nSequence");
                /* Wandering witch: */
                /* standing - 2 */
                /* wandering - 10, 11 */
                /* time startle - 30 */

                /* Sitting witch: */
                /* sitting - 4 */
                /* angry - 27 */
                /* full anger - 29 */

                /* Both: */
                /* running - 6 */
                /* jump climbing - 66 */
                /* ladder climbing - 72, 74 */
                /* dying - 74 */

                /* We only want to respawn fully passive witches */
                switch (iSequence) {
                    case 2, 10, 11, 4: {
                        GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", fOrigin);
                        pNavArea = L4D2Direct_GetTerrorNavArea(fOrigin);
                        fFlow = L4D2Direct_GetTerrorNavAreaFlow(pNavArea);
                        if (fSurvMaxFlow > fFlow + EXTRA_FLOW) {
                            RemoveEntity(iEnt);
                            iWitchSpawnCount++;
                        }
                    }
                }
            }
        }
    }

    if (iWitchSpawnCount) {
        for (int i = 1; i <= MaxClients; i++) {
            if (!IsClientInGame(i)) continue;
            int iFlags = GetCommandFlags("z_spawn_old");
            SetCommandFlags("z_spawn_old", iFlags ^ FCVAR_CHEAT);
            for (int j = 0; j < iWitchSpawnCount; j++) {
                FakeClientCommand(i, "z_spawn_old witch auto");
            }
            SetCommandFlags("z_spawn_old", iFlags);
            g_fLastSpawn = GetGameTime();
            break;
        }
    }
    return Plugin_Continue;
}

stock float GetMaxSurvivorCompletion() {
    float   fFlow = 0.0;
    float   fTmpFlow;
    float   fOrigin[3];
    Address pNavArea;
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))    continue;
        if (GetClientTeam(i) != 2) continue;
        GetClientAbsOrigin(i, fOrigin);
        pNavArea = L4D2Direct_GetTerrorNavArea(fOrigin);
        if (pNavArea != Address_Null) {
            fTmpFlow = L4D2Direct_GetTerrorNavAreaFlow(pNavArea);
            fFlow = MAX(fFlow, fTmpFlow);
        }
    }
    return fFlow;
}

stock bool IsInteger(const char[] szBuffer) {
    int iLen = strlen(szBuffer);
    for (int i = 0; i < iLen; i++) {
        if (!IsCharNumeric(szBuffer[i]))
            return false;
    }
    return true;
}