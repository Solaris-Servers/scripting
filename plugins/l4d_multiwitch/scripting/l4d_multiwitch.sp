#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <left4dhooks>
#include <readyup>
#include <colors>

#include <l4d2util/stocks>
#include <l4d2util/tanks>

#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))
#define EXTRA_FLOW 3000.0
#define RESPAWN_FREQ 5.0

ConVar g_cvEnabled;
bool   g_bEnabled;

ConVar g_cvSpawnFreq;
float  g_fSpawnFreq;

ConVar g_cvSpawnFreqFaster;
float  g_fSpawnFreqFaster;

Handle g_hWitchSpawnTimer;
float  g_fLastSpawn;
bool   g_bIsRoundLive;
bool   g_bIsFaster;
bool   g_bFastRequest[2];

static const char g_szTeamName[][] = {
    "Spectator",
    "" ,
    "{olive}Survivor{default}",
    "{green}Infected{default}",
    "",
    "{green}Infected{default}",
    "{olive}Survivor{default}",
    "{green}Infected{default}"
};

public Plugin myinfo = {
    name        = "L4D2 Multiwitch",
    author      = "CanadaRox",
    description = "A plugin that spawns unlimited witches off of a timer.",
    version     = "1.0.0",
    url         = "https://github.com/CanadaRox/sourcemod-plugins/tree/master/mutliwitch"
};

public void OnPluginStart() {
    g_cvEnabled = CreateConVar(
    "l4d_multiwitch_enabled", "1",
    "Enable multiple witch spawning",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bEnabled = g_cvEnabled.BoolValue;
    g_cvEnabled.AddChangeHook(ConVarChanged);

    g_cvSpawnFreq = CreateConVar(
    "l4d_multiwitch_spawnfreq", "120",
    "How many seconds before the next witch spawns",
    FCVAR_NONE, true, 1.0, false, 0.0);
    g_fSpawnFreq = g_cvSpawnFreq.FloatValue;
    g_cvSpawnFreq.AddChangeHook(ConVarChanged);

    g_cvSpawnFreqFaster = CreateConVar(
    "l4d_multiwitch_spawnfreq_faster", "60",
    "How many seconds before the next witch spawns if faster witch spawn is enabled",
    FCVAR_NONE, true, 1.0, false, 0.0);
    g_fSpawnFreqFaster = g_cvSpawnFreqFaster.FloatValue;
    g_cvSpawnFreqFaster.AddChangeHook(ConVarChanged);

    RegConsoleCmd("sm_faster", Cmd_FastWitchTimer);
    RegAdminCmd("sm_forcefaster", Cmd_ForceFastWitchTimer, ADMFLAG_BAN, "Speed up Dem Witches");

    HookEvent("round_start",           Event_RoundStart,   EventHookMode_PostNoCopy);
    HookEvent("round_end",             Event_RoundEnd,     EventHookMode_PostNoCopy);
    HookEvent("player_left_safe_area", Event_LeftSafeArea, EventHookMode_PostNoCopy);
}

Action Cmd_FastWitchTimer(int iClient, int iArgs) {
    if (!g_bEnabled) {
        CPrintToChat(iClient, "{green}[{default}Witch Party{green}]{default} The Witch spawn timer is disabled!");
        return Plugin_Handled;
    }
    if (g_bIsRoundLive || InSecondHalfOfRound()) {
        CPrintToChat(iClient, "{green}[{default}Witch Party{green}]{default} The Witch spawn timer can be changed only before the first round is live!");
        return Plugin_Handled;
    }

    int iTeam = GetClientTeam(iClient);
    if ((iTeam == 2 || iTeam == 3) && !g_bFastRequest[iTeam - 2]) {
        g_bFastRequest[iTeam - 2] = true;
    } else {
        return Plugin_Handled;
    }

    if (g_bFastRequest[0] && g_bFastRequest[1]) {
        g_bIsFaster = !g_bIsFaster;
        if (g_bIsFaster) CPrintToChatAll("{green}[{default}Witch Party{green}]{default} Both teams have agreed to speed up the Witch timer!");
        else             CPrintToChatAll("{green}[{default}Witch Party{green}]{default} Both teams have agreed to slow down the Witch timer!");
    } else if (g_bFastRequest[0] || g_bFastRequest[1]) {
        if (g_bIsFaster) CPrintToChatAll("{green}[{default}Witch Party{green}]{default} The %s have requested to slow down the Witch spawn timer. The %s have 30 seconds to accept with the '!faster' command.", g_szTeamName[iTeam + 4], g_szTeamName[iTeam + 3]);
        else             CPrintToChatAll("{green}[{default}Witch Party{green}]{default} The %s have requested to speed up the Witch spawn timer. The %s have 30 seconds to accept with the '!faster' command.", g_szTeamName[iTeam + 4], g_szTeamName[iTeam + 3]);
        CreateTimer(30.0, Timer_ResetFastWitchRequest, _, TIMER_FLAG_NO_MAPCHANGE);
    }
    return Plugin_Handled;
}

Action Timer_ResetFastWitchRequest(Handle hTimer) {
    g_bFastRequest[0] = false;
    g_bFastRequest[1] = false;
    return Plugin_Stop;
}

Action Cmd_ForceFastWitchTimer(int iClient, int iArgs) {
    if (!g_bEnabled) {
        CPrintToChat(iClient, "{green}[{default}Witch Party{green}]{default} The Witch spawn timer is disabled!");
        return Plugin_Handled;
    }
    if (g_bIsRoundLive || InSecondHalfOfRound()) {
        CPrintToChat(iClient, "{green}[{default}Witch Party{green}]{default} The Witch spawn timer can be changed only before the first round is live!");
        return Plugin_Handled;
    }
    g_bIsFaster = !g_bIsFaster;
    if (g_bIsFaster) CPrintToChatAll("{green}[{default}Witch Party{green}]{default} The Witch spawn timer has been sped up by an admin!");
    else             CPrintToChatAll("{green}[{default}Witch Party{green}]{default} The Witch spawn timer has been slowed down by an admin!");
    return Plugin_Handled;
}

void ConVarChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bEnabled         = g_cvEnabled.BoolValue;
    g_fSpawnFreq       = g_cvSpawnFreq.FloatValue;
    g_fSpawnFreqFaster = g_cvSpawnFreqFaster.FloatValue;
    if (g_hWitchSpawnTimer != null) delete g_hWitchSpawnTimer;
    if (!g_bEnabled)     return;
    if (!g_bIsRoundLive) return;
    g_hWitchSpawnTimer = CreateTimer(g_bIsFaster ? g_fSpawnFreqFaster : g_fSpawnFreq, Timer_WitchSpawn, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
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
    g_hWitchSpawnTimer = CreateTimer(g_bIsFaster ? g_fSpawnFreqFaster : g_fSpawnFreq, Timer_WitchSpawn, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
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
    g_hWitchSpawnTimer = CreateTimer(1.0, Timer_WitchSpawn, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_WitchSpawn(Handle hTimer) {
    if (!g_bEnabled)     return Plugin_Continue;
    if (!g_bIsRoundLive) return Plugin_Continue;
    if (IsTankInPlay())  return Plugin_Continue;
    if (g_bIsFaster && ((GetGameTime() - g_fLastSpawn) < g_fSpawnFreqFaster))
        return Plugin_Continue;
    if (!g_bIsFaster && ((GetGameTime() - g_fLastSpawn) < g_fSpawnFreq))
        return Plugin_Continue;
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
    if (!g_bEnabled)     return Plugin_Continue;
    if (!g_bIsRoundLive) return Plugin_Continue;
    if (IsTankInPlay())  return Plugin_Continue;
    if (g_bIsFaster && ((GetGameTime() - g_fLastSpawn) < g_fSpawnFreqFaster))
        return Plugin_Continue;
    if (!g_bIsFaster && ((GetGameTime() - g_fLastSpawn) < g_fSpawnFreq))
        return Plugin_Continue;

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
                            AcceptEntityInput(iEnt, "Kill");
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

stock bool InSecondHalfOfRound() {
    return view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"));
}