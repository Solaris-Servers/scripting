#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <left4dhooks>
#include <colors>
#include <l4d2util>
#include <solaris/stocks>

#define SHOTGUN_BLAST_TIME   0.1
#define HOP_CHECK_TIME       0.1
#define HOPEND_CHECK_TIME    0.1      // after streak end (potentially) detected, to check for realz?
#define SHOVE_TIME           0.05
#define MAX_CHARGE_TIME      12.0     // maximum time to pass before charge checking ends
#define CHARGE_CHECK_TIME    0.25     // check interval for survivors flying from impacts
#define CHARGE_END_CHECK     2.5      // after client hits ground after getting impact-charged: when to check whether it was a death
#define CHARGE_END_RECHECK   3.0      // safeguard wait to recheck on someone getting incapped out of bounds
#define VOMIT_DURATION_TIME  2.25     // how long the boomer vomit stream lasts -- when to check for boom count
#define ROCK_CHECK_TIME      0.34     // how long to wait after rock entity is destroyed before checking for skeet/eat (high to avoid lag issues)
#define CARALARM_MIN_TIME    0.11     // maximum time after touch/shot => alarm to connect the two events (test this for LAG)

#define MIN_DC_TRIGGER_DMG   300      // minimum amount a 'trigger' / drown must do before counted as a death action
#define MIN_DC_FALL_DMG      175      // minimum amount of fall damage counts as death-falling for a deathcharge
#define WEIRD_FLOW_THRESH    900.0    // -9999 seems to be break flow.. but meh
#define MIN_FLOWDROPHEIGHT   350.0    // minimum height a survivor has to have dropped before a WEIRD_FLOW value is treated as a DC spot
#define MIN_DC_RECHECK_DMG   100      // minimum damage from map to have taken on first check, to warrant recheck

#define HOP_ACCEL_THRESH     0.01     // bhop speed increase must be higher than this for it to count as part of a hop streak

#define HITGROUP_HEAD        1

#define DMG_CRUSH            (1 << 0)     // crushed by falling or moving object.
#define DMG_BULLET           (1 << 1)     // shot
#define DMG_SLASH            (1 << 2)     // cut, clawed, stabbed
#define DMG_CLUB             (1 << 7)     // crowbar, punch, headbutt
#define DMG_BUCKSHOT         (1 << 29)    // not quite a bullet. Little, rounder, different.

#define CUT_SHOVED           1            // smoker got shoved
#define CUT_SHOVEDSURV       2            // survivor got shoved
#define CUT_KILL             3            // reason for tongue break (release_type)
#define CUT_SLASH            4            // this is used for others shoving a survivor free too, don't trust .. it involves tongue damage?

#define VICFLG_CARRIED       (1 << 0)     // was the one that the charger carried (not impacted)
#define VICFLG_FALL          (1 << 1)     // flags stored per charge victim, to check for deathchargeroony -- fallen
#define VICFLG_DROWN         (1 << 2)     // drowned
#define VICFLG_HURTLOTS      (1 << 3)     // whether the victim was hurt by 400 dmg+ at once
#define VICFLG_TRIGGER       (1 << 4)     // killed by trigger_hurt
#define VICFLG_AIRDEATH      (1 << 5)     // died before they hit the ground (impact check)
#define VICFLG_KILLEDBYOTHER (1 << 6)     // if the survivor was killed by an SI other than the charger
#define VICFLG_WEIRDFLOW     (1 << 7)     // when survivors get out of the map and such
#define VICFLG_WEIRDFLOWDONE (1 << 8)     // checked, don't recheck for this

bool g_bIsPvE;

// trie values: weapon type
enum WeaponType {
    WPTYPE_NONE,
    WPTYPE_SNIPER,
    WPTYPE_MAGNUM,
    WPTYPE_GL
};

// trie values: OnEntityCreated classname
enum OEC {
    OEC_TANKROCK,
    OEC_TRIGGER
};

// trie values: special abilities
enum Ability {
    ABL_HUNTERLUNGE,
    ABL_ROCKTHROW
};

GlobalForward g_fwdHeadShot;
GlobalForward g_fwdSkeet;
GlobalForward g_fwdSkeetHurt;
GlobalForward g_fwdSkeetMelee;
GlobalForward g_fwdSkeetSniper;
GlobalForward g_fwdHunterDeadstop;
GlobalForward g_fwdBoomerPop;
GlobalForward g_fwdBoomerPopEarly;
GlobalForward g_fwdLevel;
GlobalForward g_fwdLevelHurt;
GlobalForward g_fwdTongueCut;
GlobalForward g_fwdSmokerSelfClear;
GlobalForward g_fwdRockSkeeted;
GlobalForward g_fwdHunterDP;
GlobalForward g_fwdDeathCharge;
GlobalForward g_fwdClear;
GlobalForward g_fwdVomitLanded;
GlobalForward g_fwdBHopStreak;
GlobalForward g_fwdAlarmTriggered;

StringMap g_smWeapons;                                           // weapon check
StringMap g_smEntityCreated;                                     // getting classname of entity created
StringMap g_smAbility;                                           // ability check
StringMap g_smRocks;                                             // tank rock tracking

// all SI / pinners
int    g_iSpecialVictim[MAXPLAYERS + 1];                         // current victim (set in traceattack, so we can check on death)
float  g_fSpawnTime    [MAXPLAYERS + 1];                         // time the SI spawned up
float  g_fPinTime      [MAXPLAYERS + 1][2];                      // time the SI pinned a target: 0 = start of pin (tongue pull, charger carry); 1 = carry end / tongue reigned in

// hunters: skeets/pounces
float  g_fHunterTracePouncing [MAXPLAYERS + 1];                  // time when the hunter was still pouncing (in traceattack) -- used to detect pouncing status
int    g_iPounceDamage        [MAXPLAYERS + 1];                  // how much damage on last 'highpounce' done
int    g_iHunterHealth        [MAXPLAYERS + 1];                  // how much health the hunter had the last time it was seen taking damage
float  g_vPouncePosition      [MAXPLAYERS + 1][3];               // position that a hunter pounced from (or charger started his carry)
bool   g_bShotCounted         [MAXPLAYERS + 1][MAXPLAYERS + 1];
int    g_iDmgDealt            [MAXPLAYERS + 1][MAXPLAYERS + 1];
int    g_iShotsDealt          [MAXPLAYERS + 1][MAXPLAYERS + 1];

// deadstops
float  g_fVictimLastShove[MAXPLAYERS + 1][MAXPLAYERS + 1];       // when was the player shoved last by attacker? (to prevent doubles)

// levels / charges
int    g_iChargerHealth  [MAXPLAYERS + 1];                       // how much health the charger had the last time it was seen taking damage
float  g_fChargeTime     [MAXPLAYERS + 1];                       // time the charger's charge last started, or if victim, when impact started
int    g_iChargeVictim   [MAXPLAYERS + 1];                       // who got charged
int    g_iVictimCharger  [MAXPLAYERS + 1];                       // for a victim, by whom they got charge(impacted)
int    g_iVictimFlags    [MAXPLAYERS + 1];                       // flags stored per charge victim: VICFLAGS_
int    g_iVictimMapDmg   [MAXPLAYERS + 1];                       // for a victim, how much the cumulative map damage is so far (trigger hurt / drowning)
float  g_fChargeVictimPos[MAXPLAYERS + 1][3];                    // location of each survivor when it got hit by the charger

// pops
bool   g_bBoomerHitSomebody[MAXPLAYERS + 1];                     // false if boomer didn't puke/exploded on anybody
int    g_iBoomerGotShoved  [MAXPLAYERS + 1];                     // count boomer was shoved at any point
int    g_iBoomerVomitHits  [MAXPLAYERS + 1];                     // how many booms in one vomit so far
int    g_iBoomerKiller     [MAXPLAYERS + 1];
int    g_iBoomerShover     [MAXPLAYERS + 1];
Handle g_hBoomerShoveTimer [MAXPLAYERS + 1];

// smoker clears
bool   g_bSmokerClearCheck  [MAXPLAYERS + 1];                    // [smoker] smoker dies and this is set, it's a self-clear if g_iSmokerVictim is the killer
int    g_iSmokerVictim      [MAXPLAYERS + 1];                    // [smoker] the one that's being pulled
int    g_iSmokerVictimDamage[MAXPLAYERS + 1];                    // [smoker] amount of damage done to a smoker by the one he pulled
bool   g_bSmokerShoved      [MAXPLAYERS + 1];                    // [smoker] set if the victim of a pull manages to shove the smoker

// rocks
int    g_iRocksBeingThrownCount;                                 // so we can do a push/pop type check for who is throwing a created rock
int    g_iTankRockClient[MAXPLAYERS + 1];                        // stores the tank client

// hops
bool   g_bIsHopping     [MAXPLAYERS + 1];                        // currently in a hop streak
bool   g_bHopCheck      [MAXPLAYERS + 1];                        // flag to check whether a hopstreak has ended (if on ground for too long.. ends)
int    g_iHops          [MAXPLAYERS + 1];                        // amount of hops in streak
float  g_fHopTopVelocity[MAXPLAYERS + 1];                        // maximum velocity in hopping streak
float  g_fLastHop       [MAXPLAYERS + 1][3];                     // velocity vector of last jump

// cvars
ConVar g_cvGameMode;

ConVar g_cvSelfClearThresh;                                     // cvar damage while self-clearing from smokers
ConVar g_cvHunterDPThresh;                                      // cvar damage for hunter highpounce
ConVar g_cvBHopMinInitSpeed;                                    // cvar lower than this and the first jump won't be seen as the start of a streak
ConVar g_cvBHopContSpeed;                                       // cvar speed at which hops are considered succesful even if not speed increase is made

ConVar g_cvMaxPounceDistance;                                   // z_pounce_damage_range_max
ConVar g_cvMinPounceDistance;                                   // z_pounce_damage_range_min
ConVar g_cvMaxPounceDamage;                                     // z_hunter_max_pounce_bonus_damage;

/*****************************************************************
            L I B R A R Y   I N C L U D E S
*****************************************************************/
#include "l4d2_skill_detect/tracking.sp"
#include "l4d2_skill_detect/report.sp"
#include "l4d2_skill_detect/prints.sp"

public Plugin myinfo = {
    name        = "[L4D2] Skill Detection (skeets, levels)",
    author      = "Tabun",
    description = "Detects and reports skeets, levels, highpounces, etc.",
    version     = "1.1",
    url         = "https://github.com/Tabbernaut/L4D2-Plugins"
}

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    g_fwdHeadShot = CreateGlobalForward(
    "OnHeadShot",
    ET_Ignore, Param_Cell, Param_Cell);

    g_fwdBoomerPop = CreateGlobalForward(
    "OnBoomerPop",
    ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Float);

    g_fwdBoomerPopEarly = CreateGlobalForward(
    "OnBoomerPopEarly",
    ET_Ignore, Param_Cell, Param_Cell, Param_Cell);

    g_fwdLevel = CreateGlobalForward(
    "OnChargerLevel",
    ET_Ignore, Param_Cell, Param_Cell);

    g_fwdLevelHurt = CreateGlobalForward(
    "OnChargerLevelHurt",
    ET_Ignore, Param_Cell, Param_Cell, Param_Cell);

    g_fwdHunterDeadstop = CreateGlobalForward(
    "OnHunterDeadstop",
    ET_Ignore, Param_Cell, Param_Cell);

    g_fwdSkeetSniper = CreateGlobalForward(
    "OnSkeetSniper",
    ET_Ignore, Param_Cell, Param_Cell);

    g_fwdSkeetMelee = CreateGlobalForward(
    "OnSkeetMelee",
    ET_Ignore, Param_Cell, Param_Cell);

    g_fwdSkeetHurt = CreateGlobalForward(
    "OnSkeetHurt",
    ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);

    g_fwdSkeet = CreateGlobalForward(
    "OnSkeet",
    ET_Ignore, Param_Cell, Param_Cell, Param_Cell);

    g_fwdTongueCut = CreateGlobalForward(
    "OnTongueCut",
    ET_Ignore, Param_Cell, Param_Cell);

    g_fwdSmokerSelfClear = CreateGlobalForward(
    "OnSmokerSelfClear",
    ET_Ignore, Param_Cell, Param_Cell, Param_Cell);

    g_fwdRockSkeeted = CreateGlobalForward(
    "OnTankRockSkeeted",
    ET_Ignore, Param_Cell, Param_Cell);

    g_fwdHunterDP = CreateGlobalForward(
    "OnHunterHighPounce",
    ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Float, Param_Cell, Param_Cell);

    g_fwdDeathCharge = CreateGlobalForward(
    "OnDeathCharge",
    ET_Ignore, Param_Cell, Param_Cell, Param_Float, Param_Float, Param_Cell);

    g_fwdClear = CreateGlobalForward(
    "OnSpecialClear",
    ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Float, Param_Cell);

    g_fwdVomitLanded = CreateGlobalForward(
    "OnBoomerVomitLanded",
    ET_Ignore, Param_Cell, Param_Cell);

    g_fwdBHopStreak = CreateGlobalForward(
    "OnBunnyHopStreak",
    ET_Ignore, Param_Cell, Param_Cell, Param_Float);

    g_fwdAlarmTriggered = CreateGlobalForward(
    "OnCarAlarmTriggered",
    ET_Ignore, Param_Cell);

    RegPluginLibrary("l4d2_skill_detect");
    return APLRes_Success;
}

public void OnPluginStart() {
    // hooks
    OnHookEvent();

    g_cvGameMode = FindConVar("mp_gamemode");
    g_cvGameMode.AddChangeHook(ConVarChanged_GameMode);

    g_cvSelfClearThresh = CreateConVar(
    "sm_skill_selfclear_damage", "200",
    "How much damage a survivor must at least do to a smoker for him to count as self-clearing.",
    FCVAR_NONE, true, 0.0, false, 0.0);

    g_cvHunterDPThresh = CreateConVar(
    "sm_skill_hunterdp_height", "400",
    "Minimum height of hunter pounce for it to count as a DP.",
    FCVAR_NONE, true, 0.0, false, 0.0);

    g_cvBHopMinInitSpeed = CreateConVar(
    "sm_skill_bhopinitspeed", "150",
    "The minimal speed of the first jump of a bunnyhopstreak (0 to allow 'hops' from standstill).",
    FCVAR_NONE, true, 0.0, false, 0.0);

    g_cvBHopContSpeed = CreateConVar(
    "sm_skill_bhopkeepspeed", "300",
    "The minimal speed at which hops are considered succesful even if not speed increase is made.",
    FCVAR_NONE, true, 0.0, false, 0.0);

    g_cvMaxPounceDistance = FindConVar("z_pounce_damage_range_max");
    if (g_cvMaxPounceDistance == null) {
        g_cvMaxPounceDistance = CreateConVar(
        "z_pounce_damage_range_max", "1000.0",
        "Not available on this server, added by l4d2_skill_detect.",
        FCVAR_NONE, true, 0.0, false, 0.0);
    }

    g_cvMinPounceDistance = FindConVar("z_pounce_damage_range_min");
    if (g_cvMinPounceDistance == null) {
        g_cvMinPounceDistance = CreateConVar(
        "z_pounce_damage_range_min", "300.0",
        "Not available on this server, added by l4d2_skill_detect.",
        FCVAR_NONE, true, 0.0, false, 0.0);
    }

    g_cvMaxPounceDamage = FindConVar("z_hunter_max_pounce_bonus_damage");
    if (g_cvMaxPounceDamage == null) {
        g_cvMaxPounceDamage = CreateConVar(
        "z_hunter_max_pounce_bonus_damage", "49",
        "Not available on this server, added by l4d2_skill_detect.",
        FCVAR_NONE, true, 0.0, false, 0.0);
    }

    // tries
    g_smWeapons = new StringMap();
    g_smWeapons.SetValue("hunting_rifle",               WPTYPE_SNIPER);
    g_smWeapons.SetValue("sniper_military",             WPTYPE_SNIPER);
    g_smWeapons.SetValue("sniper_awp",                  WPTYPE_SNIPER);
    g_smWeapons.SetValue("sniper_scout",                WPTYPE_SNIPER);
    g_smWeapons.SetValue("pistol_magnum",               WPTYPE_MAGNUM);
    g_smWeapons.SetValue("grenade_launcher_projectile", WPTYPE_GL);

    g_smEntityCreated = new StringMap();
    g_smEntityCreated.SetValue("tank_rock",    OEC_TANKROCK);
    g_smEntityCreated.SetValue("trigger_hurt", OEC_TRIGGER);

    g_smAbility = new StringMap();
    g_smAbility.SetValue("ability_lunge", ABL_HUNTERLUNGE);
    g_smAbility.SetValue("ability_throw", ABL_ROCKTHROW);

    g_smRocks = new StringMap();
}

void OnHookEvent() {
    HookEvent("round_start",                Event_RoundStart,        EventHookMode_PostNoCopy);
    HookEvent("scavenge_round_start",       Event_RoundStart,        EventHookMode_PostNoCopy);

    HookEvent("player_spawn",               Event_PlayerSpawn,       EventHookMode_Post);
    HookEvent("player_hurt",                Event_PlayerHurt,        EventHookMode_Pre);
    HookEvent("player_death",               Event_PlayerDeath,       EventHookMode_Pre);
    HookEvent("ability_use",                Event_AbilityUse,        EventHookMode_Post);
    HookEvent("lunge_pounce",               Event_LungePounce,       EventHookMode_Post);
    HookEvent("player_shoved",              Event_PlayerShoved,      EventHookMode_Post);
    HookEvent("player_jump",                Event_PlayerJumped,      EventHookMode_Post);
    HookEvent("player_jump_apex",           Event_PlayerJumpApex,    EventHookMode_Post);

    HookEvent("player_now_it",              Event_PlayerBoomed,      EventHookMode_Post);

    HookEvent("jockey_ride",                Event_JockeyRide,        EventHookMode_Post);
    HookEvent("tongue_grab",                Event_TongueGrab,        EventHookMode_Post);
    HookEvent("tongue_pull_stopped",        Event_TonguePullStopped, EventHookMode_Post);
    HookEvent("choke_start",                Event_ChokeStart,        EventHookMode_Post);
    HookEvent("choke_stopped",              Event_ChokeStop,         EventHookMode_Post);
    HookEvent("charger_carry_start",        Event_ChargeCarryStart,  EventHookMode_Post);
    HookEvent("charger_carry_end",          Event_ChargeCarryEnd,    EventHookMode_Post);
    HookEvent("charger_impact",             Event_ChargeImpact,      EventHookMode_Post);
    HookEvent("charger_pummel_start",       Event_ChargePummelStart, EventHookMode_Post);

    HookEvent("player_incapacitated_start", Event_IncapStart,        EventHookMode_Post);
    HookEvent("triggered_car_alarm",        Event_TriggeredCarAlarm, EventHookMode_Post);

    HookEvent("weapon_fire",                Event_WeaponFire,        EventHookMode_Post);
}

public void OnConfigsExecuted() {
    g_bIsPvE = !SDK_HasPlayerInfected();
}

void ConVarChanged_GameMode(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bIsPvE = !SDK_HasPlayerInfected();
}

/*
    --------
    support
    --------
*/

stock int GetSurvivorTempHealth(int iClient) {
    static ConVar cv;
    if (cv == null)
        cv = FindConVar("pain_pills_decay_rate");

    float fHealthBuffer         = GetEntPropFloat(iClient, Prop_Send, "m_healthBuffer");
    float fHealthBufferDuration = GetGameTime() - GetEntPropFloat(iClient, Prop_Send, "m_healthBufferTime");
    int   iTempHealth           = RoundToCeil(fHealthBuffer - (fHealthBufferDuration * cv.FloatValue)) - 1;

    return (iTempHealth > 0) ? iTempHealth : 0;
}

stock int ShiftTankThrower() {
    int iTank = -1;

    if (!g_iRocksBeingThrownCount)
        return -1;

    iTank = g_iTankRockClient[0];

    // shift the tank array downwards, if there are more than 1 throwers
    if (g_iRocksBeingThrownCount > 1) {
        for (int x = 1; x <= g_iRocksBeingThrownCount; x++) {
            g_iTankRockClient[x - 1] = g_iTankRockClient[x];
        }
    }

    g_iRocksBeingThrownCount--;
    return iTank;
}

stock bool IsValidClientInGame(int iClient) {
    return (IsValidClientIndex(iClient) && IsClientInGame(iClient));
}