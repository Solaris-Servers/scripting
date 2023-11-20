/* -----------------------------------------------------------------------------------------------------------------------------------------------------
 *  Changelog:
 *  ---------
 *      2.2: (24.10.2021) (A1m`)
 *          1. Fixed: in some cases we received the coordinates of the infected 0.0.0, now the plugin always gets the correct coordinates.
 *
 *      2.0: (14.08.2021) (A1m`)
 *          1. Completely rewrite the method of identifying uncommon infected.
 *          2. Added some uncommon infected (fallen survivor and Jimmy Gibbs).
 *          3. Optimization and code improvement.
 *          4. Plugin tested for all uncommon infected.
 *          5. A bug is noticed in the plugin, sometimes we get zero coordinates on the SDKHook_SpawnPost, what should we do about it?
 *
 *      0.1d: (06.07.2021) (A1m`)
 *          1. fixes description of cvar 'sm_uncinfblock_enabled' after 12+- years of using the plugin :D.
 *
 *      0.1c: (23.06.2021) (A1m`)
 *          1. new syntax, little fixes.
 *
 *      0.1b:
 *          1. spawns infected after killing uncommon entity.
 *
 *      0.1a
 *          1. first version (not really optimized).
 *
 * -----------------------------------------------------------------------------------------------------------------------------------------------------
 * Plugin test results (these are all uncommon infected):
 *
 * L4D2Gender_Ceda = 11
 * Plugin flag: (11 - 11 = 0) (1 << 0) = 1
 * Uncommon infected spawned! Model: models/infected/common_male_ceda_l4d1.mdl, gender: 11, plugin flag: 1.
 * Uncommon infected spawned! Model: models/infected/common_male_ceda.mdl, gender: 11, plugin flag: 1.
 *
 * L4D2Gender_Crawler = 12
 * Plugin flag: (12 - 11 = 1) (1 << 1) = 2
 * Uncommon infected spawned! Model: models/infected/common_male_mud_L4D1.mdl, gender: 12, plugin flag: 2.
 * Uncommon infected spawned! Model: models/infected/common_male_mud.mdl, gender: 12, plugin flag: 2.
 *
 * L4D2Gender_Undistractable = 13
 * Plugin flag: (13 - 11 = 2) (1 << 2) = 4
 * Uncommon infected spawned! Model: models/infected/common_male_roadcrew_l4d1.mdl, gender: 13, plugin flag: 4.
 * Uncommon infected spawned! Model: models/infected/common_male_roadcrew.mdl, gender: 13, plugin flag: 4.
 * Uncommon infected spawned! Model: models/infected/common_male_baggagehandler_02.mdl, gender: 13, plugin flag: 4.
 * Note: common_male_roadcrew_rain.mdl is this model used in the game?
 *
 * L4D2Gender_Fallen = 14
 * Plugin flag: (14 - 11 = 3) (1 << 3) = 8
 * Uncommon infected spawned! Model: models/infected/common_male_fallen_survivor_l4d1.mdl, gender: 14, plugin flag: 8.
 * Uncommon infected spawned! Model: models/infected/common_male_fallen_survivor.mdl, gender: 14, plugin flag: 8.
 * Uncommon infected spawned! Model: models/infected/common_male_parachutist.mdl, gender: 14, plugin flag: 8.
 * Note: no, it's not the one that hangs on the tree on the map 'c3m2_swamp'.

 * L4D2Gender_Riot_Control = 15
 * Plugin flag: (15 - 11 = 4) (1 << 4) = 16
 * Uncommon infected spawned! Model: models/infected/common_male_riot.mdl, gender: 15, plugin flag: 16.
 * Note: there is a version for l4d1, but it is not used (common_male_riot_l4d1.mdl).

 * L4D2Gender_Clown = 16
 * Plugin flag: (16 - 11 = 5) (1 << 5) = 32
 * Uncommon infected spawned! Model: models/infected/common_male_clown.mdl, gender: 16, plugin flag: 32.

 * L4D2Gender_Jimmy = 17
 * Plugin flag: (17 - 11 = 6) (1 << 6) = 64
 * Uncommon infected spawned! Model: models/infected/common_male_jimmy.mdl, gender: 17, plugin flag: 64.
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <l4d2util/stocks>
#include <l4d2util/infected>

#define UNCOMMON_INFECTED_AMOUNT 7

public const char szUncommon[][] = {
    "ceda",
    "crawler",
    "undistractable",
    "fallen",
    "riot_control",
    "clown",
    "jimmy"
};

ConVar g_cvPluginEnabled;
bool   g_bPluginEnabled;

public Plugin myinfo = {
    name        = "Uncommon Infected Blocker",
    author      = "Tabun, A1m`",
    description = "Blocks uncommon infected from ruining your day.",
    version     = "2.2",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart() {
    g_cvPluginEnabled = CreateConVar(
    "sm_uncinfblock_enabled", "1",
    "Enable uncommon blocker plugin?",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bPluginEnabled = g_cvPluginEnabled.BoolValue;
    g_cvPluginEnabled.AddChangeHook(ConVarChanged);
}

public void ConVarChanged(ConVar cv, const char[] szOldValue, const char[] szNewValue) {
    g_bPluginEnabled = g_cvPluginEnabled.BoolValue;
}

public void OnEntityCreated(int iEntity, const char[] szClassName) {
    if (szClassName[0] != 'i' || !g_bPluginEnabled) {
        return;
    }
    if (strncmp(szClassName, "infected", 8, false) == 0) {
        SDKHook(iEntity, SDKHook_SpawnPost, Hook_OnEntitySpawned);
    }
}

public void Hook_OnEntitySpawned(int iEntity) {
    RequestFrame(OnNextFrame, EntIndexToEntRef(iEntity));
}

public void OnNextFrame(int iEntity) {
    if (EntRefToEntIndex(iEntity) == INVALID_ENT_REFERENCE || !IsValidEdict(iEntity)) {
        return;
    }
    int iUncommonInfected     = GetGender(iEntity) - L4D2Gender_Ceda;
    bool bIszUncommonInfected = (iUncommonInfected >= 0 && iUncommonInfected < UNCOMMON_INFECTED_AMOUNT);
    if (!bIszUncommonInfected)
        return;
    // get location
    float fLocation[3];
    GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fLocation);
    // kill the uncommon infected
    RemoveEntity(iEntity);
    // spawn infected in location instead
    SpawnNewInfected(fLocation);
}

void SpawnNewInfected(const float fLocation[3]) {
    int iInfected = CreateEntityByName("infected");
    if (iInfected < 1)
        return;
    /*
     * Original game code:
     * #define TICK_INTERVAL            (gpGlobals->interval_per_tick)
     * #define TIME_TO_TICKS( dt )      ( (int)( 0.5f + (float)(dt) / TICK_INTERVAL ) )
     * SetNextThink( TIME_TO_TICKS(gpGlobals->curtime ) );
    */
    int iTickTime = RoundToNearest(GetGameTime() / GetTickInterval()) + 5; // copied from uncommon spawner plugin, prolly helps avoid the zombie get 'stuck' ?
    SetEntProp(iInfected, Prop_Data, "m_nNextThinkTick", iTickTime);
    DispatchSpawn(iInfected);
    ActivateEntity(iInfected);
    TeleportEntity(iInfected, fLocation, NULL_VECTOR, NULL_VECTOR);
}