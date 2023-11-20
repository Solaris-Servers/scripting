/*
======= Version 1.0 - 1.1 =======
// by Visor & Jacob.
- Fix boomer hordes being different sizes based on wandering common infected.

======= Version 1.2 - 1.4 =======
// by A1m`
- Added error output.
- Fixed offset.
- Windows support.

========== Version 1.5 ==========
// by Forgetest
- Replace code_patcher with Sourcescramble.

======= Version 1.6
// by Sir
- Thanks to Spoon for his l4d2_boomer_horde_control plugin, giving me the idea to support non-static numbers per biled Survivor. (And copy pasta explanation)
- Thanks to Alan for reviewing the code, testing and input.
- Refactored the plugin to allow for more control over the amount of horde spawned and its behaviour.
- Added support for non-Boomer related L4D_OnSpawnITMob events (Boomer Bile & Custom stuff).
- With this plugin I highly recommend tweaking the "z_notice_it_range" it ConVar, as wandering common will still pile in on top of this within a certain range. (Default 1500)

* ----------------------------------------------------------------------------------------------------------------
*
*   Please note, the amount of specified horde will spawn once the boomed survivor count reaches that amount.
*   Meaning, if you want a TOTAL of 15 common to spawn when two survivors are boomed you could use this:
*
*   boomer_horde_amount     1   5       -       Spawn 5 common when 1 survivor gets boomed
*   boomer_horde_amount     2   10      -       Spawn 10 common when 2nd survivor gets boomed (Total of 15 spawned.)
*
* ----------------------------------------------------------------------------------------------------------------
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>
#include <left4dhooks>

#define GAMEDATA               "boomer_horde_equalizer"
#define KEY_WANDERERSCONDITION "WanderersCondition"

ConVar g_cvPatchEnable;
bool   g_bPatchEnable;

ConVar g_cvOldBehaviourEvents;
bool   g_bOldBehaviourEvents;

ConVar g_cvMobMaxSize;
int    g_iMobMaxSize;

MemoryPatch
    g_mpWanderersCondition;

int  g_iBoomedSurvivorCount;
int  g_iBoomHordeEvent[32];
bool g_bBiledSurvivor[MAXPLAYERS + 1];

public Plugin myinfo = {
    name        = "Boomer Horde Equalizer (Refactored)",
    author      = "Visor, Jacob, A1m`, Sir",
    version     = "1.6",
    description = "Fixes boomer hordes being different sizes based on wandering commons (1.5) as well as adding zombies to the queue rather than relying on max_mob_size",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart() {
    InitGameData();
    // Events
    HookEvent("player_no_longer_it", Event_PlayerBoomedExpired);
    HookEvent("round_start",         Event_RoundStart);
    HookEvent("player_bot_replace",  Event_PlayerBotReplace);
    HookEvent("bot_player_replace",  Event_BotPlayerReplace);

    // ConVars.
    g_cvPatchEnable = CreateConVar(
    "boomer_horde_equalizer", "1",
    "Fix boomer hordes being different sizes based on wandering commons. (1 - enable, 0 - disable)",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bPatchEnable = g_cvPatchEnable.BoolValue;
    g_cvPatchEnable.AddChangeHook(Cvars_Changed);
    
    g_cvOldBehaviourEvents = CreateConVar(
    "boomer_horde_equalizer_events_default", "1",
    "Use default boomer behaviour during event hordes? - 1:Yes - 0:Override",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bOldBehaviourEvents = g_cvOldBehaviourEvents.BoolValue;
    g_cvOldBehaviourEvents.AddChangeHook(Cvars_Changed);

    g_cvMobMaxSize = FindConVar("z_mob_spawn_max_size");
    g_iMobMaxSize  = g_cvMobMaxSize.IntValue;
    g_cvMobMaxSize.AddChangeHook(Cvars_Changed);

    // Server Commands.
    RegServerCmd("boomer_horde_amount", Cmd_SetBoomHorde, "Usage: boomer_horde_amount <amount of boomed survivors> <amount of horde to spawn>");

    // Go & Hook.
    CheckPatch(g_bPatchEnable);
}

public void OnPluginEnd() {
    CheckPatch(false);
}

/* =================================================================================
                                    CONVARS
================================================================================= */
void Cvars_Changed(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bPatchEnable         = g_cvPatchEnable.BoolValue;
    g_iMobMaxSize          = g_cvMobMaxSize.IntValue;
    g_bOldBehaviourEvents  = g_cvOldBehaviourEvents.BoolValue;
    CheckPatch(g_bPatchEnable);
}

/* =================================================================================
                                SERVER COMMANDS
================================================================================= */
Action Cmd_SetBoomHorde(int iArgs) {
    // Check to make sure the arguments are set up right.
    if (iArgs != 2) return Plugin_Continue;

    // Get the amount of Survivors boomed.
    char szRequiredSurvivorsBoomed[32];
    GetCmdArg(1, szRequiredSurvivorsBoomed, sizeof(szRequiredSurvivorsBoomed));
    StripQuotes(szRequiredSurvivorsBoomed);

    // Get the amount of horde to spawn as a result.
    char szResultHordeSize[32];
    GetCmdArg(2, szResultHordeSize, sizeof(szResultHordeSize));
    StripQuotes(szResultHordeSize);

    // Store it in an array!
    g_iBoomHordeEvent[StringToInt(szRequiredSurvivorsBoomed, 10)] = StringToInt(szResultHordeSize, 10);
    return Plugin_Continue;
}


/* =================================================================================
                                    EVENTS
================================================================================= */
void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    // Just in case.
    g_iBoomedSurvivorCount = 0;
    for (int i = 1; i <= MaxClients; i++) {
        g_bBiledSurvivor[i] = false;
    }
}

void Event_PlayerBotReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iPlayer = GetClientOfUserId(eEvent.GetInt("player"));
    if (!g_bBiledSurvivor[iPlayer]) return;
    int iBot = GetClientOfUserId(eEvent.GetInt("bot"));
    g_bBiledSurvivor[iPlayer] = false;
    g_bBiledSurvivor[iBot]    = true;
}

void Event_BotPlayerReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iBot = GetClientOfUserId(eEvent.GetInt("bot"));
    if (!g_bBiledSurvivor[iBot]) return;
    int iPlayer = GetClientOfUserId(eEvent.GetInt("player"));
    g_bBiledSurvivor[iBot]    = false;
    g_bBiledSurvivor[iPlayer] = true;
}

void Event_PlayerBoomedExpired(Event eEvent, const char[] szName, bool bDontBroadcast) {
    // This event only triggers on players (Bile bomb on SI or Boomer bile on Survivors)
    // Will only have to check if the player is a Survivor.
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (!g_bBiledSurvivor[iClient]) return;
    g_bBiledSurvivor[iClient] = false;
    g_iBoomedSurvivorCount--;
}

public Action L4D_OnSpawnITMob(int &iAmount) {
    // Rather than spawning common through this, we add them to the pending queue.
    // This allows us to go past the z_common_limit
    // Keep in mind that the default value of wandering common is 20 and will be added to the outcome of the calculation if they are within the default range of 3000 units.
    // Which happens in the following two cases:
    // - Players Biled * Horde per Player size exceeds z_common_limit
    // - Pulled Wanderers + (Players Biled * Horde per Player size) exceeds z_common_limit

    // Set default Horde to the z_mob_spawn_max_size convar.
    int HordeToQueue = g_iMobMaxSize;
    // An additional check for Infinite Hordes (events)
    // We'll use "old-school" boomer_horde_equalizer method in this case, unless plugin user prefers the new method (not recommended)
    if (g_bOldBehaviourEvents && IsInfiniteHordeActive()) {
        iAmount = HordeToQueue;
        return Plugin_Changed;
    }

    // We do not know yet whether a Survivor was biled.
    // We'll use this for client storage.
    int iPlayers;
    for (int i = 1; i <= MaxClients; i++) {
        if (g_bBiledSurvivor[i])   continue;
        if (!IsClientInGame(i))    continue;
        if (GetClientTeam(i) != 2) continue;
        if (!IsBoomed(i))          continue;
        // We 'break' here because this will trigger every time someone gets biled (for the first time) by either a boomer
        // or bilebomb (also triggers on groundhit for Bilebomb)
        // This way we don't increase g_iBoomedSurvivorCount unless an actual Survivor is biled.
        g_iBoomedSurvivorCount++;
        g_bBiledSurvivor[i] = true;
        iPlayers = i;
        break;
    }
    // Actual Survivor bile that triggered this?
    if (iPlayers > 0) {
        // Did we specify the amount of common for this amount of Survivors biled?
        if (g_iBoomHordeEvent[g_iBoomedSurvivorCount] > 0) HordeToQueue = g_iBoomHordeEvent[g_iBoomedSurvivorCount];
    } else {
        // This will fire in cases where it wasn't a Survivor that got biled.
        // We'll use "old-school" boomer_horde_equalizer method in this case, unless plugin user prefers the new method (most DEFINITELY NOT recommended)
        iAmount = HordeToQueue;
        return Plugin_Changed;
    }

    L4D2Direct_SetPendingMobCount(L4D2Direct_GetPendingMobCount() + HordeToQueue);
    return Plugin_Handled;
}

/* =================================================================================
                                    STOCKS
================================================================================= */
void InitGameData() {
    GameData gmConf = new GameData(GAMEDATA);
    if (!gmConf) SetFailState("Gamedata '%s.txt' missing or corrupt.", GAMEDATA);
    g_mpWanderersCondition = MemoryPatch.CreateFromConf(gmConf, KEY_WANDERERSCONDITION);
    if (g_mpWanderersCondition == null || !g_mpWanderersCondition.Validate())
        SetFailState("Failed to validate MemoryPatch \"" ... KEY_WANDERERSCONDITION ... "\"");
    delete gmConf;
}

void CheckPatch(bool bIsPatch) {
    static bool bIsPatched = false;
    if (bIsPatch && !bIsPatched) {
        g_mpWanderersCondition.Enable();
        bIsPatched = true;
    } else if (!bIsPatch && bIsPatched) {
        g_mpWanderersCondition.Disable();
        bIsPatched = false;
    }
}

bool IsBoomed(int iClient) {
    return ((GetEntPropFloat(iClient, Prop_Send, "m_vomitStart") + 0.01) > GetGameTime());
}

bool IsInfiniteHordeActive() {
    int iCountDown = GetHordeCountdown();
    return (iCountDown > -1 && iCountDown <= 10);
}

int GetHordeCountdown() {
    return (CTimer_HasStarted(L4D2Direct_GetMobSpawnTimer())) ? RoundFloat(CTimer_GetRemainingTime(L4D2Direct_GetMobSpawnTimer())) : -1;
}