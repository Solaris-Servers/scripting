#pragma semicolon 1
#pragma newdecls required

/*
 * To-do:
 * Add flag cvar to control damage from different SI separately.
 * Add cvar to control whether tanks should reset frustration with hittable hits. Maybe.
 */
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <l4d2util>

#define CLASSNAME_LENGTH 64

#define TANK_ROCK 52

// Macros for easily referencing the Undo Damage array
#define UNDO_PERM 0
#define UNDO_TEMP 1
#define UNDO_SIZE 16

// Macros for stack argument array
#define STACK_VICTIM 0
#define STACK_DAMAGE 1
#define STACK_DISTANCE 2
#define STACK_TYPE 3
#define STACK_SIZE 4

// Announcement flags
#define ANNOUNCE_NONE 0
#define ANNOUNCE_CONSOLE 1
#define ANNOUNCE_CHAT 2

// Flags for different types of Friendly Fire
#define FFTYPE_NOTUNDONE 0
#define FFTYPE_TOOCLOSE 1
#define FFTYPE_CHARGERCARRY 2
#define FFTYPE_STUPIDBOTS 4
#define FFTYPE_MELEEFLAG 0x8000

// godframes control cvars
ConVar g_cvRageRock;
ConVar g_cvRageHittables;
ConVar g_cvHittable;
ConVar g_cvWitch;
ConVar g_cvFF;
ConVar g_cvSpit;
ConVar g_cvCommon;
ConVar g_cvHunter;
ConVar g_cvSmoker;
ConVar g_cvJockey;
ConVar g_cvCharger;
ConVar g_cvChargerStagger;
ConVar g_cvChargerFlags;
ConVar g_cvSpitFlags;
ConVar g_cvCommonFlags;
ConVar g_cvGodframeGlows;
ConVar g_cvRock;

// shotgun ff stuff
ConVar g_cvEnableShotFF;
ConVar g_cvModifier;
ConVar g_cvMinFF;
ConVar g_cvMaxFF;

bool   g_bBuckshot[MAXPLAYERS + 1] = {false, ...};

// undo ff
ConVar g_cvUndoFriendlyFire;
ConVar g_cvBlockZeroDmg;
ConVar g_cvPermDamageFraction;

int    g_iUndoFriendlyFireFlags;
int    g_iBlockZeroDmg;

int    g_iLastHealth      [MAXPLAYERS + 1][UNDO_SIZE][2];    // The Undo Damage array, with correlated arrays for holding the last revive count and current undo index
int    g_iLastPerm        [MAXPLAYERS + 1] = {100, ... };    // The permanent damage fraction requires some coordination between OnTakeDamage and player_hurt
int    g_iLastReviveCount [MAXPLAYERS + 1] = {0, ... };
int    g_iCurrentUndo     [MAXPLAYERS + 1] = {0, ... };
int    g_iTargetTempHealth[MAXPLAYERS + 1] = {0, ... };      // Healing is weird, so this keeps track of our target OR the target's temp health
int    g_iLastTemp        [MAXPLAYERS + 1] = {0, ... };

float  g_fPermFrac = 0.0;

bool   g_bChargerCarryNoFF[MAXPLAYERS + 1] = {false, ...};   // Flags for knowing when to undo friendly fire
bool   g_bStupidGuiltyBots[MAXPLAYERS + 1] = {false, ...};

// fake godframes
float  g_fFakeGodframeEnd      [MAXPLAYERS + 1] = {0.0, ...};
float  g_fFakeChargeGodframeEnd[MAXPLAYERS + 1] = {0.0, ...};

Handle g_hTimer[MAXPLAYERS + 1] = {null, ...};

int    g_iLastSI           [MAXPLAYERS + 1] = {0, ...};
int    g_iFrustrationOffset[MAXPLAYERS + 1] = {0, ...};      // frustration
int    g_iPelletsShot      [MAXPLAYERS + 1][MAXPLAYERS + 1]; // shotgun ff

bool   g_bLateLoad = false;                                  // late load

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] szError, int iErrMax) {
    CreateNative("GiveClientGodFrames", Native_GiveClientGodFrames);

    RegPluginLibrary("l4d2_godframes_control_merge");

    g_bLateLoad = bLate;
    return APLRes_Success;
}

// Natives
any Native_GiveClientGodFrames(Handle hPlugin, int iNumParams) {
    int iClient = GetNativeCell(1);

    if (!IsClientAndInGame(iClient))
        return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index or client is not in game (index %d)!", iClient);

    if (!IsPlayerAlive(iClient))
        return ThrowNativeError(SP_ERROR_NATIVE, "The client is not alive (index %d)!", iClient);

    float fGodFrameTime  = GetNativeCell(2);
    int   iAttackerClass = GetNativeCell(3);

    float fNow = GetGameTime();
    g_fFakeGodframeEnd[iClient] = fNow + fGodFrameTime;
    g_iLastSI[iClient] = iAttackerClass;

    SetGodFrameGlows(iClient);
    return 1;
}

public Plugin myinfo = {
    name        = "L4D2 Godframes Control combined with FF Plugins",
    author      = "Stabby, CircleSquared, Tabun, Visor, dcx, Sir, Spoon, A1m`, Sir",
    version     = "0.6.10",
    description = "Allows for control of what gets godframed and what doesnt along with integrated FF Support from l4d2_survivor_ff (by dcx and Visor) and l4d2_shotgun_ff (by Visor)",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart() {
    // godframes control cvars
    g_cvGodframeGlows = CreateConVar(
    "gfc_godframe_glows", "1",
    "Changes the rendering of survivors while godframed (red/transparent).",
    FCVAR_NONE, true, 0.0, true, 1.0);

    g_cvRageHittables = CreateConVar(
    "gfc_hittable_rage_override", "1",
    "Allow tank to gain rage from hittable hits. 0 blocks rage gain.",
    FCVAR_NONE, true, 0.0, true, 1.0);

    g_cvRageRock = CreateConVar(
    "gfc_rock_rage_override", "1",
    "Allow tank to gain rage from godframed hits. 0 blocks rage gain.",
    FCVAR_NONE, true, 0.0, true, 1.0);

    g_cvHittable = CreateConVar(
    "gfc_hittable_override", "1",
    "Allow hittables to always ignore godframes.",
    FCVAR_NONE, true, 0.0, true, 1.0);

    g_cvRock = CreateConVar(
    "gfc_rock_override", "0",
    "Allow hittables to always ignore godframes.",
    FCVAR_NONE, true, 0.0, true, 1.0);

    g_cvWitch = CreateConVar(
    "gfc_witch_override", "1",
    "Allow witches to always ignore godframes.",
    FCVAR_NONE, true, 0.0, true, 1.0);

    g_cvFF = CreateConVar(
    "gfc_ff_min_time", "0.3",
    "Minimum time before FF damage is allowed.",
    FCVAR_NONE, true, 0.0, true, 3.0);

    g_cvSpit = CreateConVar(
    "gfc_spit_extra_time", "0.7",
    "Additional godframe time before spit damage is allowed.",
    FCVAR_NONE, true, 0.0, true, 3.0);

    g_cvCommon = CreateConVar(
    "gfc_common_extra_time", "0.0",
    "Additional godframe time before common damage is allowed.",
    FCVAR_NONE, true, 0.0, true, 3.0);

    g_cvHunter = CreateConVar(
    "gfc_hunter_duration", "2.1",
    "How long should godframes after a pounce last?",
    FCVAR_NONE, true, 0.0, true, 3.0);

    g_cvJockey = CreateConVar(
    "gfc_jockey_duration", "0.0",
    "How long should godframes after a ride last?",
    FCVAR_NONE, true, 0.0, true, 3.0);

    g_cvSmoker = CreateConVar(
    "gfc_smoker_duration", "0.0",
    "How long should godframes after a pull or choke last?",
    FCVAR_NONE, true, 0.0, true, 3.0);

    g_cvCharger = CreateConVar(
    "gfc_charger_duration", "2.1",
    "How long should godframes after a pummel last?",
    FCVAR_NONE, true, 0.0, true, 3.0);

    g_cvChargerStagger = CreateConVar(
    "gfc_charger_stagger_extra_time", "0.0",
    "Additional godframe time before damage from ChargerFlags is allowed.",
    FCVAR_NONE, true, 0.0, true, 3.0);

    g_cvChargerFlags = CreateConVar(
    "gfc_charger_stagger_flags", "0",
    "What will be affected by extra charger stagger protection time. 1 - Common. 2 - Spit.",
    FCVAR_NONE, true, 0.0, true, 3.0);

    g_cvSpitFlags = CreateConVar(
    "gfc_spit_zc_flags", "6",
    "Which classes will be affected by extra spit protection time. 1 - Hunter. 2 - Smoker. 4 - Jockey. 8 - Charger.",
    FCVAR_NONE, true, 0.0, true, 15.0);

    g_cvCommonFlags = CreateConVar(
    "gfc_common_zc_flags", "0",
    "Which classes will be affected by extra common protection time. 1 - Hunter. 2 - Smoker. 4 - Jockey. 8 - Charger.",
    FCVAR_NONE, true, 0.0, true, 15.0);

    // undo ff
    g_cvUndoFriendlyFire = CreateConVar(
    "l4d2_undoff_enable", "7",
    "Bit flag: Enables plugin features (add together): 1 = too close, 2 = Charger carry, 4 = guilty bots, 7 = all, 0 = off",
    FCVAR_NONE, true, 0.0, true, 7.0);
    g_iUndoFriendlyFireFlags = g_cvUndoFriendlyFire.IntValue;
    g_cvUndoFriendlyFire.AddChangeHook(OnUndoFFEnableChanged);

    g_cvBlockZeroDmg = CreateConVar(
    "l4d2_undoff_blockzerodmg","7",
    "Bit flag: Block 0 damage friendly fire effects like recoil and vocalizations/stats (add together): 4 = bot hits human block recoil, 2 = block vocals/stats on ALL difficulties, 1 = block vocals/stats on everything EXCEPT Easy (flag 2 has precedence), 0 = off",
    FCVAR_NONE, true, 0.0, true, 7.0);
    g_iBlockZeroDmg = g_cvBlockZeroDmg.IntValue;
    g_cvBlockZeroDmg.AddChangeHook(OnUndoFFBlockZeroDmgChanged);

    g_cvPermDamageFraction = CreateConVar(
    "l4d2_undoff_permdmgfrac", "1.0",
    "Minimum fraction of damage applied to permanent health",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_fPermFrac = g_cvPermDamageFraction.FloatValue;
    g_cvPermDamageFraction.AddChangeHook(OnPermFracChanged);

    // shotgun ff stuff
    g_cvEnableShotFF = CreateConVar(
    "l4d2_shotgun_ff_enable", "1",
    "Enable Shotgun FF Module?",
    FCVAR_NONE, true, 0.0, true, 5.0);

    g_cvModifier = CreateConVar(
    "l4d2_shotgun_ff_multi", "0.5",
    "Shotgun FF damage modifier value",
    FCVAR_NONE, true, 0.0, true, 5.0);

    g_cvMinFF = CreateConVar(
    "l4d2_shotgun_ff_min", "1.0",
    "Minimum allowed shotgun FF damage; 0 for no limit",
    FCVAR_NONE, true, 0.0, false, 0.0);

    g_cvMaxFF = CreateConVar(
    "l4d2_shotgun_ff_max", "6.0",
    "Maximum allowed shotgun FF damage; 0 for no limit",
    FCVAR_NONE, true, 0.0, false, 0.0);

    // Events
    HookEvent("player_hurt",                Event_PlayerHurt,        EventHookMode_Post);
    HookEvent("charger_carry_start",        Event_ChargerCarryStart, EventHookMode_Post);
    HookEvent("charger_carry_end",          Event_ChargerCarryEnd,   EventHookMode_Post);
    HookEvent("friendly_fire",              Event_FriendlyFire,      EventHookMode_Pre);
    HookEvent("heal_begin",                 Event_HealBegin,         EventHookMode_Pre);
    HookEvent("heal_end",                   Event_HealEnd,           EventHookMode_Pre);
    HookEvent("heal_success",               Event_HealSuccess,       EventHookMode_Pre);
    HookEvent("player_incapacitated_start", Event_PlayerIncapStart,  EventHookMode_Pre);

    // Fake godframes
    HookEvent("tongue_release",     PostSurvivorRelease);
    HookEvent("pounce_end",         PostSurvivorRelease);
    HookEvent("jockey_ride_end",    PostSurvivorRelease);
    HookEvent("charger_pummel_end", PostSurvivorRelease);

    // Pass over stuff on passover to and from bots
    HookEvent("player_bot_replace", Event_PlayerBotReplace);
    HookEvent("bot_player_replace", Event_BotPlayerReplace);

    // Clear both fake and real just because
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

    if (g_bLateLoad) {
        for (int i = 1; i <= MaxClients; i++) {
            if (IsClientInGame(i)) {
                SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
                SDKHook(i, SDKHook_TraceAttack,  TraceAttackUndoFF);
                g_bBuckshot[i] = false;
            }
            for (int j = 0; j < UNDO_SIZE; j++) {
                g_iLastHealth[i][j][UNDO_PERM] = 0;
                g_iLastHealth[i][j][UNDO_TEMP] = 0;
            }
        }
    }
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    // clear both fake and real just because
    for (int i = 1; i <= MaxClients; i++) {
        g_fFakeGodframeEnd      [i] = 0.0;
        g_fFakeChargeGodframeEnd[i] = 0.0;
        g_bBuckshot             [i] = false;

        if (g_hTimer[i] != null)
            delete g_hTimer[i];
    }
}

void PostSurvivorRelease(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iVictim = GetClientOfUserId(eEvent.GetInt("victim"));

    // just in case
    if (iVictim <= 0)
        return;

    if (!IsClientInGame(iVictim))
        return;

    if (!IsPlayerAlive(iVictim))
        return;

    float fNow = GetGameTime();

    // sets fake godframe time based on cvars for each ZC
    if (StrContains(szName, "tongue") != -1) {
        g_fFakeGodframeEnd[iVictim] = fNow + g_cvSmoker.FloatValue;
        g_iLastSI[iVictim] = 2;
    } else if (StrContains(szName, "pounce") != -1) {
        g_fFakeGodframeEnd[iVictim] = fNow + g_cvHunter.FloatValue;
        g_iLastSI[iVictim] = 1;
    } else if (StrContains(szName, "jockey") != -1) {
        g_fFakeGodframeEnd[iVictim] = fNow + g_cvJockey.FloatValue;
        g_iLastSI[iVictim] = 4;
    } else if (StrContains(szName, "charger") != -1) {
        g_fFakeGodframeEnd[iVictim] = fNow + g_cvCharger.FloatValue;
        g_iLastSI[iVictim] = 8;
    }

    SetGodFrameGlows(iVictim);
}

public void L4D2_OnStagger_Post(int iClient, int iSource) {
    // Charger Impact handling, source is always null.
    if (IsValidSurvivor(iClient) && iSource == -1 && g_cvChargerStagger.FloatValue > 0.0) {
        float fNow = GetGameTime();

        // In case of multi-charger configs/modes.
        if (g_fFakeChargeGodframeEnd[iClient] > fNow)
            fNow = g_fFakeChargeGodframeEnd[iClient];

        g_fFakeChargeGodframeEnd[iClient] = fNow + g_cvChargerStagger.FloatValue;
    }
}

void Event_PlayerBotReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    HandlePlayerReplace(GetClientOfUserId(eEvent.GetInt("bot")), GetClientOfUserId(eEvent.GetInt("player")));
}

void Event_BotPlayerReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    HandlePlayerReplace(GetClientOfUserId(eEvent.GetInt("player")), GetClientOfUserId(eEvent.GetInt("bot")));
}

void HandlePlayerReplace(int iReplacer, int iReplacee) {
    g_fFakeGodframeEnd[iReplacer] = g_fFakeGodframeEnd[iReplacee];
    g_fFakeChargeGodframeEnd[iReplacer] = g_fFakeChargeGodframeEnd[iReplacee];
    g_iLastSI[iReplacer] = g_iLastSI[iReplacee];

    // Use 500 IQ to re-create 'accurate' timer on the replacer.
    if (g_hTimer[iReplacee] != null)
        delete g_hTimer[iReplacee];

    float fRemainingFakeGodFrames = g_fFakeGodframeEnd[iReplacer] - GetGameTime();
    if (fRemainingFakeGodFrames > 0.0)
        SetGodFrameGlows(iReplacer);
}

public void OnClientPutInServer(int iClient) {
    SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
    SDKHook(iClient, SDKHook_TraceAttack, TraceAttackUndoFF);
    g_bBuckshot[iClient] = false;
    for (int j = 0; j < UNDO_SIZE; j++) {
        g_iLastHealth[iClient][j][UNDO_PERM] = 0;
        g_iLastHealth[iClient][j][UNDO_TEMP] = 0;
    }
}

/* //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                                                 //
//                                                                                                                 //
//                               --------------    Godframe Control      --------------                            //
//                                                                                                                 //
//                                                                                                                 //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////// */

void Timed_SetFrustration(any iClient) {
    if (IsTank(iClient) && IsPlayerAlive(iClient)) {
        int iFrust = GetEntProp(iClient, Prop_Send, "m_frustration");
        iFrust += g_iFrustrationOffset[iClient];

        if      (iFrust > 100) iFrust = 100;
        else if (iFrust < 0)   iFrust = 0;

        SetEntProp(iClient, Prop_Send, "m_frustration", iFrust);
        g_iFrustrationOffset[iClient] = 0;
    }
}

public Action OnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &iDamagetype, int &iWeapon, float fDamageForce[3], float fDamagePosition[3]) {
    if (!IsValidSurvivor(iVictim))
        return Plugin_Continue;

    if (!IsValidEdict(iAttacker))
        return Plugin_Continue;

    if (!IsValidEdict(iInflictor))
        return Plugin_Continue;

    // left4dhooks
    CountdownTimer cTimerGod = L4D2Direct_GetInvulnerabilityTimer(iVictim);
    // set m_timestamp - 0.0
    if (cTimerGod != CTimer_Null) CTimer_Invalidate(cTimerGod);

    char szClassname[CLASSNAME_LENGTH];
    GetEntityClassname(iInflictor, szClassname, CLASSNAME_LENGTH);

    float fTimeLeft = g_fFakeGodframeEnd[iVictim] - GetGameTime();
    // commons
    if (strcmp(szClassname, "infected") == 0) {
        if (g_iLastSI[iVictim] & g_cvCommonFlags.IntValue)
            fTimeLeft += g_cvCommon.FloatValue;

        if (g_cvChargerFlags.IntValue & 1 && fTimeLeft <= 0.0) {
            float fChargingTime = g_fFakeChargeGodframeEnd[iVictim] - GetGameTime();
            fTimeLeft = fChargingTime > 0.0 ? fChargingTime : fTimeLeft;
        }
    }

    // spit
    if (strcmp(szClassname, "insect_swarm") == 0) {
        if (g_iLastSI[iVictim] & g_cvSpitFlags.IntValue)
            fTimeLeft += g_cvSpit.FloatValue;

        if (g_cvChargerFlags.IntValue & 2 && fTimeLeft <= 0.0) {
            float fChargingTime = g_fFakeChargeGodframeEnd[iVictim] - GetGameTime();
            fTimeLeft = fChargingTime > 0.0 ? fChargingTime : fTimeLeft;
        }
    }

    // friendly fire
    if (IsValidSurvivor(iAttacker)) {
        // Block FF While Capped
        if (IsSurvivorAttacked(iVictim)) {
            return Plugin_Handled;
        }

        // Block AI FF
        if (IsFakeClient(iVictim) && IsFakeClient(iAttacker)) {
            return Plugin_Handled;
        }

        /**
            #define DMG_PLASMA  (1 << 24)   // < Shot by Cremator

            Special case -- let this function know that we've manually applied damage
            I am expecting some info about HL3 at GDC in March, so I felt like choosing this
            exotic damage flag that stands for a cut enemy from HL2
        **/

        // if (iDamagetype == DMG_PLASMA)
            // return Plugin_Continue;

        fTimeLeft += g_cvFF.FloatValue;
        if (g_iUndoFriendlyFireFlags) {
            bool bUndone = false;
            int  iDmg = RoundToFloor(fDamage); // Damage to survivors is rounded down

            // Only check damage to survivors
            // - if it is greater than 0, OR
            // - if a human survivor did 0 damage (so we know when the engine forgives our friendly fire for us)
            if (iDmg > 0 && !IsFakeClient(iAttacker)) {
                // Remember health for undo
                int iVictimPerm = GetClientHealth(iVictim);
                int iVictimTemp = GetSurvivorTemporaryHealth(iVictim);

                // if attacker is not ourself, check for undo damage
                if (iAttacker != iVictim) {
                    char sWeaponName[CLASSNAME_LENGTH];
                    GetSafeEntityName(iWeapon, sWeaponName, sizeof(sWeaponName));

                    float fDistance = GetClientsDistance(iVictim, iAttacker);
                    float FFDist = GetWeaponFFDist(sWeaponName);
                    if ((g_iUndoFriendlyFireFlags & FFTYPE_TOOCLOSE) && (fDistance < FFDist)) {
                        bUndone = true;
                    } else if ((g_iUndoFriendlyFireFlags & FFTYPE_CHARGERCARRY) && (g_bChargerCarryNoFF[iVictim])) {
                        bUndone = true;
                    } else if ((g_iUndoFriendlyFireFlags & FFTYPE_STUPIDBOTS) && (g_bStupidGuiltyBots[iVictim])) {
                        bUndone = true;
                    } else if (iDmg == 0) {
                        // In order to get here, you must be a human Survivor doing 0 damage to another Survivor
                        bUndone = ((g_iBlockZeroDmg & 0x02) || ((g_iBlockZeroDmg & 0x01)));
                    }
                }

                // TODO: move to player_hurt?  and check to make sure damage was consistent between the two?
                // We prefer to do this here so we know what the player's state looked like pre-damage
                // Specifically, what portion of the damage was applied to perm and temp health,
                // since we can't tell after-the-fact what the damage was applied to
                // Unfortunately, not all calls to OnTakeDamage result in the player being hurt (e.g. damage during god frames)
                // So we use player_hurt to know when OTD actually happened
                if (!bUndone && iDmg > 0) {
                    int iPermDmg = RoundToCeil(g_fPermFrac * iDmg);
                    if (iPermDmg >= iVictimPerm) {
                        // Perm damage won't reduce permanent health below 1 if there is sufficient temp health
                        iPermDmg = iVictimPerm - 1;
                    }

                    int iTempDmg = iDmg - iPermDmg;
                    if (iTempDmg > iVictimTemp) {
                        // If TempDmg exceeds current temp health, transfer the difference to perm damage
                        iPermDmg += (iTempDmg - iVictimTemp);
                        iTempDmg = iVictimTemp;
                    }

                    // Don't add to undo list if player is incapped
                    if (!IsIncapacitated(iVictim)) {
                        // point at next undo cell
                        int iNextUndo = (g_iCurrentUndo[iVictim] + 1) % UNDO_SIZE;
                        if (iPermDmg < iVictimPerm) {
                            // This will call player_hurt, so we should store the damage done so that it can be added back if it is undone
                            g_iLastHealth[iVictim][iNextUndo][UNDO_PERM] = iPermDmg;
                            g_iLastHealth[iVictim][iNextUndo][UNDO_TEMP] = iTempDmg;
                            // We need some way to tell player_hurt how much perm/temp health we expected the player to have after this attack
                            // This is used to implement the fractional damage to perm health
                            // We can't just set their health here because this attack might not actually do damage
                            g_iLastPerm[iVictim] = iVictimPerm - iPermDmg;
                            g_iLastTemp[iVictim] = iVictimTemp - iTempDmg;
                        } else {
                            // This will call player_incap_start, so we should store their exact health and incap count at the time of attack
                            // If the incap is undone, we will restore these settings instead of adding them
                            g_iLastHealth[iVictim][iNextUndo][UNDO_PERM] = iVictimPerm;
                            g_iLastHealth[iVictim][iNextUndo][UNDO_TEMP] = iVictimTemp;
                            // This is used to tell player_incap_start the exact amount of damage that was done by the attack
                            g_iLastPerm[iVictim] = iPermDmg;
                            g_iLastTemp[iVictim] = iTempDmg;
                            // TODO: can we move to incapstart?
                            g_iLastReviveCount[iVictim] = GetEntProp(iVictim, Prop_Send, "m_currentReviveCount");
                        }
                    }
                }
            }

            if (bUndone)
                return Plugin_Handled;
        }

        if (g_cvEnableShotFF.BoolValue && fTimeLeft <= 0.0 && IsT1Shotgun(iWeapon)) {
            g_iPelletsShot[iVictim][iAttacker]++;
            if (!g_bBuckshot[iAttacker]) {
                g_bBuckshot[iAttacker] = true;
                ArrayStack aStack = new ArrayStack(3);
                aStack.Push(iWeapon);
                aStack.Push(iAttacker);
                aStack.Push(iVictim);
                RequestFrame(ProcessShot, aStack);
            }

            return Plugin_Handled;
        }
    }

    if (IsValidClientIndex(iAttacker) && IsTank(iAttacker)) {
        if (strcmp(szClassname, "prop_physics") == 0|| strcmp(szClassname, "prop_car_alarm") == 0) {
            if (g_cvRageHittables.BoolValue) {
                g_iFrustrationOffset[iAttacker] = -100;
            } else {
                g_iFrustrationOffset[iAttacker] = 0;
            }
            RequestFrame(Timed_SetFrustration, iAttacker);
        } else if (iWeapon == TANK_ROCK) {
            if (g_cvRageRock.BoolValue) {
                g_iFrustrationOffset[iAttacker] = -100;
            } else {
                g_iFrustrationOffset[iAttacker] = 0;
            }
            RequestFrame(Timed_SetFrustration, iAttacker);
        }
    }

    // means fake god frames are in effect
    if (fTimeLeft > 0) {
        if (strcmp(szClassname, "prop_physics") == 0 || strcmp(szClassname, "prop_car_alarm") == 0) { //hittables
            if (g_cvHittable.BoolValue) {
                return Plugin_Continue;
            }
        }

        // tank rock
        if (IsTankRock(iInflictor)) {
            if (g_cvRock.BoolValue) {
                return Plugin_Continue;
            }
        }

        // witches
        if (strcmp(szClassname, "witch") == 0) {
            if (g_cvWitch.BoolValue) {
                return Plugin_Continue;
            }
        }

        return Plugin_Handled;
    } else {
        g_iLastSI[iVictim] = 0;
    }

    return Plugin_Continue;
}

public void OnMapStart() {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            // remove transparency/color
            SetEntityRenderMode(i, RENDER_NORMAL);
            SetEntityRenderColor(i, 255, 255, 255, 255);
        }
    }
}

/* //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                                                 //
//                                                                                                                 //
//                          --------------    JUST UNDO FF STUFF      --------------                               //
//                                                                                                                 //
//                                                                                                                 //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////// */

// The sole purpose of this hook is to prevent survivor bots from causing the vision of human survivors to recoil
public Action TraceAttackUndoFF(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &iDamagetype, int &iAmmotype, int iHitbox, int iHitgroup) {
    // If none of the flags are enabled, don't do anything
    if (!g_iUndoFriendlyFireFlags)
        return Plugin_Continue;

    // Only interested in Survivor victims
    if (!IsValidSurvivor(iVictim))
        return Plugin_Continue;

    // If a valid survivor bot shoots a valid survivor human, block it to prevent survivor vision from getting experiencing recoil (it would have done 0 damage anyway)
    if ((g_iBlockZeroDmg & 0x04) && IsValidSurvivor(iAttacker) && IsFakeClient(iAttacker) && IsValidSurvivor(iVictim) && !IsFakeClient(iVictim))
        return Plugin_Handled;

    return Plugin_Continue;
}

// Apply fractional permanent damage here
// Also announce damage, and undo guilty bot damage
void Event_PlayerHurt(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!g_iUndoFriendlyFireFlags)
        return;

    int iVictim = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iVictim <= 0)
        return;

    if (!IsSurvivor(iVictim))
        return;

    int iAttacker    = GetClientOfUserId(eEvent.GetInt("attacker"));
    int iDmg         = eEvent.GetInt("dmg_cvealth");
    int iCurrentPerm = eEvent.GetInt("health");

    // When incapped you continuously get hurt by the world, so we just ignore incaps altogether
    if (iDmg > 0 && !IsIncapacitated(iVictim)) {
        // Cycle the undo pointer when we have confirmed that the damage was actually taken
        g_iCurrentUndo[iVictim] = (g_iCurrentUndo[iVictim] + 1) % UNDO_SIZE;

        // victim values are what OnTakeDamage expected us to have, current values are what the game gave us
        int iVictimPerm  = g_iLastPerm[iVictim];
        int iVictimTemp  = g_iLastTemp[iVictim];
        int iCurrentTemp = GetSurvivorTemporaryHealth(iVictim);

        // If this feature is enabled, some portion of damage will be applied to the temp health
        if (g_fPermFrac < 1.0 && iVictimPerm != iCurrentPerm) {
            // make sure we don't give extra health
            int iTotalHealthOld = iCurrentPerm + iCurrentTemp;
            int iTotalHealthNew = iVictimPerm + iVictimTemp;

            if (iTotalHealthOld == iTotalHealthNew) {
                SetEntityHealth(iVictim, iVictimPerm);
                SetEntPropFloat(iVictim, Prop_Send, "m_healthBuffer", float(iVictimTemp));
                SetEntPropFloat(iVictim, Prop_Send, "m_healthBufferTime", GetGameTime());
            }
        }
    }

    // Announce damage, and check for guilty bots that slipped through OnTakeDamage
    if (IsValidSurvivor(iAttacker)) {
        // Unfortunately, the friendly fire event only fires *after* OnTakeDamage has been called so it can't be blocked in time
        // So we must check here to see if the bots are guilty and undo the damage after-the-fact
        if ((g_iUndoFriendlyFireFlags & FFTYPE_STUPIDBOTS) && (g_bStupidGuiltyBots[iVictim])) {
            UndoDamage(iVictim);
        }
    }
}

// When a Survivor is incapped by damage, player_hurt will not fire
// So you may notice that the code here has some similarities to the code for player_hurt
void Event_PlayerIncapStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    // Cycle the incap pointer, now that the damage has been confirmed
    int iVictim = GetClientOfUserId(eEvent.GetInt("userid"));
    // Cycle the undo pointer when we have confirmed that the damage was actually taken
    g_iCurrentUndo[iVictim] = (g_iCurrentUndo[iVictim] + 1) % UNDO_SIZE;
    int iAttacker = GetClientOfUserId(eEvent.GetInt("attacker"));
    // Announce damage, and check for guilty bots that slipped through OnTakeDamage
    if (IsValidSurvivor(iAttacker)) {
        // Unfortunately, the friendly fire event only fires *after* OnTakeDamage has been called so it can't be blocked in time
        // So we must check here to see if the bots are guilty and undo the damage after-the-fact
        if ((g_iUndoFriendlyFireFlags & FFTYPE_STUPIDBOTS) && (g_bStupidGuiltyBots[iVictim]))
            UndoDamage(iVictim);
    }
}

// If a bot is guilty of creating a friendly fire event, undo it
// Also give the human some reaction time to realize the bot ran in front of them
void Event_FriendlyFire(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!(g_iUndoFriendlyFireFlags & FFTYPE_STUPIDBOTS))
        return;

    int iClient = GetClientOfUserId(eEvent.GetInt("guilty"));
    if (IsFakeClient(iClient)) {
        g_bStupidGuiltyBots[iClient] = true;
        CreateTimer(0.4, StupidGuiltyBotDelay, iClient, TIMER_FLAG_NO_MAPCHANGE);
    }
}

Action StupidGuiltyBotDelay(Handle hTimer, any iClient) {
    g_bStupidGuiltyBots[iClient] = false;
    return Plugin_Stop;
}

// While a Charger is carrying a Survivor, undo any friendly fire done to them
// since they are effectively pinned and pinned survivors are normally immune to FF
void Event_ChargerCarryStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!(g_iUndoFriendlyFireFlags & FFTYPE_CHARGERCARRY))
        return;

    int iClient = GetClientOfUserId(eEvent.GetInt("victim"));
    g_bChargerCarryNoFF[iClient] = true;
}

// End immunity about one second after the carry ends
// (there is some time between carryend and pummelbegin,
// but pummelbegin does not always get called if the charger died first, so it is unreliable
// and besides the survivor has natural FF immunity when pinned)
void Event_ChargerCarryEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("victim"));
    CreateTimer(1.0, ChargerCarryFFDelay, iClient, TIMER_FLAG_NO_MAPCHANGE);
}

Action ChargerCarryFFDelay(Handle hTimer, any iClient) {
    g_bChargerCarryNoFF[iClient] = false;
    return Plugin_Stop;
}

// For health kit undo, we must remember the target in HealBegin
void Event_HealBegin(Event eEvent, const char[] szName, bool bDontBroadcast) {
    // Not enabled? Done
    if (!g_iUndoFriendlyFireFlags)
        return;

    int iSubject = GetClientOfUserId(eEvent.GetInt("subject"));
    if (iSubject <= 0)
        return;

    if (!IsSurvivor(iSubject))
        return;

    if (!IsPlayerAlive(iSubject))
        return;

    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)
        return;

    if (!IsSurvivor(iClient))
        return;

    if (!IsPlayerAlive(iClient))
        return;

    // Remember the target for HealEnd, since that parameter is a lie for that event
    g_iTargetTempHealth[iClient] = iSubject;
}

// When healing ends, remember how much temp health the target had
// This way it can be restored in UndoDamage
void Event_HealEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    // Not enabled? Done
    if (!g_iUndoFriendlyFireFlags)
        return;

    int iClient  = GetClientOfUserId(eEvent.GetInt("userid"));
    int iSubject = g_iTargetTempHealth[iClient]; // this is used first to carry the subject...

    if (iSubject <= 0 || iSubject > MaxClients || !IsSurvivor(iSubject) || !IsPlayerAlive(iSubject)) {
        PrintToServer("Who did you heal? (%d)", iSubject);
        return;
    }

    int iTempHealth =  GetSurvivorTemporaryHealth(iSubject);
    if (iTempHealth < 0) iTempHealth = 0;

    // ...and second it is used to store the subject's temp health (since success knows the subject)
    g_iTargetTempHealth[iClient] = iTempHealth;
}

// Save the amount of health restored as negative so it can be undone
void Event_HealSuccess(Event eEvent, const char[] szName, bool bDontBroadcast) {
    // Not enabled? Done
    if (!g_iUndoFriendlyFireFlags)
        return;

    int iSubject = GetClientOfUserId(eEvent.GetInt("subject"));
    if (iSubject <= 0)
        return;

    if (!IsSurvivor(iSubject))
        return;

    if (!IsPlayerAlive(iSubject))
        return;

    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));

    int iNextUndo = (g_iCurrentUndo[iSubject] + 1) % UNDO_SIZE;
    g_iLastHealth [iSubject][iNextUndo][UNDO_PERM] = -eEvent.GetInt("health_restored");
    g_iLastHealth [iSubject][iNextUndo][UNDO_TEMP] = g_iTargetTempHealth[iClient];
    g_iCurrentUndo[iSubject] = iNextUndo;
}

// The magic behind Undo Damage
// Cycles through the array, can also undo incapacitations
void UndoDamage(int iClient) {
    if (IsValidSurvivor(iClient)) {
        int iThisUndo = g_iCurrentUndo[iClient];
        int iUndoPerm = g_iLastHealth[iClient][iThisUndo][UNDO_PERM];
        int iUndoTemp = g_iLastHealth[iClient][iThisUndo][UNDO_TEMP];

        int iNewHealth, iNewTemp;
        if (IsIncapacitated(iClient)) {
            // If player is incapped, restore their previous health and incap count
            iNewHealth = iUndoPerm;
            iNewTemp = iUndoTemp;
            CheatCommand(iClient, "give", "health");
            SetEntProp(iClient, Prop_Send, "m_currentReviveCount", g_iLastReviveCount[iClient]);
        } else {
            // add perm and temp health back to their existing health
            iNewHealth = GetClientHealth(iClient) + iUndoPerm;
            iNewTemp = iUndoTemp;
            if (iUndoPerm >= 0) {
                // undoing damage, so add current temp health do undoTemp
                iNewTemp += GetSurvivorTemporaryHealth(iClient);
            } else {
                // undoPerm is negative when undoing healing, so don't add current temp health
                // instead, give the health kit that was undone
                CheatCommand(iClient, "give", "weapon_first_aid_kit");
            }
        }

        if (iNewHealth > 100) {
            iNewHealth = 100; // prevent going over 100 health
        }

        if (iNewHealth + iNewTemp > 100) {
            iNewTemp = 100 - iNewHealth;
        }

        SetEntityHealth(iClient, iNewHealth);
        SetEntPropFloat(iClient, Prop_Send, "m_healthBuffer", float(iNewTemp));
        SetEntPropFloat(iClient, Prop_Send, "m_healthBufferTime", GetGameTime());

        // clear out the undo so it can't happen again
        g_iLastHealth[iClient][iThisUndo][UNDO_PERM] = 0;
        g_iLastHealth[iClient][iThisUndo][UNDO_TEMP] = 0;

        // point to the previous undo
        if (iThisUndo <= 0) {
            iThisUndo = UNDO_SIZE;
        }

        iThisUndo = iThisUndo - 1;
        g_iCurrentUndo[iClient] = iThisUndo;
    }
}

// Gets the distance between two survivors
// Accounting for any difference in height
float GetClientsDistance(int iVictim, int iAttacker) {
    float fMins[3], fMaxs[3];
    GetClientMins(iVictim, fMins);
    GetClientMaxs(iVictim, fMaxs);

    float fHalfHeight = fMaxs[2] - fMins[2] + 10;

    float fAttackerPos[3], fVictimPos[3];
    GetClientAbsOrigin(iVictim, fVictimPos);
    GetClientAbsOrigin(iAttacker, fAttackerPos);

    float fPosHeightDiff = fAttackerPos[2] - fVictimPos[2];

    if      (fPosHeightDiff > fHalfHeight)          fAttackerPos[2] -= fHalfHeight;
    else if (fPosHeightDiff < (-1.0 * fHalfHeight)) fVictimPos[2]   -= fHalfHeight;
    else                                            fAttackerPos[2]  = fVictimPos[2];

    return GetVectorDistance(fVictimPos, fAttackerPos, false);
}

// Gets per-weapon friendly fire undo distances
float GetWeaponFFDist(char[] szWeaponName) {
    if (strcmp(szWeaponName, "weapon_melee")  == 0 ||
        strcmp(szWeaponName, "weapon_pistol") == 0) {
        return 25.0;
    } else if (strcmp(szWeaponName, "weapon_smg")           == 0
            || strcmp(szWeaponName, "weapon_smg_silenced")  == 0
            || strcmp(szWeaponName, "weapon_smg_mp5")       == 0
            || strcmp(szWeaponName, "weapon_pistol_magnum") == 0) {
        return 30.0;
    } else if (strcmp(szWeaponName, "weapon_pumpshotgun")    == 0
            || strcmp(szWeaponName, "weapon_shotgun_chrome") == 0
            || strcmp(szWeaponName, "weapon_hunting_rifle")  == 0
            || strcmp(szWeaponName, "weapon_sniper_scout")   == 0
            || strcmp(szWeaponName, "weapon_sniper_awp")     == 0) {
        return 37.0;
    }
    return 0.0;
}

void GetSafeEntityName(int iEntity, char[] szName, const int iNameSize) {
    if (iEntity > 0 && IsValidEntity(iEntity)) {
        GetEntityClassname(iEntity, szName, iNameSize);
        return;
    }

    strcopy(szName, iNameSize, "Invalid");
}

void CheatCommand(int iClient, const char[] szCmd, const char[] szArg) {
    int iFlags = GetCommandFlags(szCmd);
    SetCommandFlags(szCmd, iFlags & ~FCVAR_CHEAT);
    FakeClientCommand(iClient, "%s %s", szCmd, szArg);
    SetCommandFlags(szCmd, iFlags);
}

bool IsClientAndInGame(int iClient) {
    return (iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient));
}

// Cvars
void OnUndoFFEnableChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iUndoFriendlyFireFlags = StringToInt(szNewVal);
}

void OnUndoFFBlockZeroDmgChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iBlockZeroDmg = StringToInt(szNewVal);
}

void OnPermFracChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fPermFrac = StringToFloat(szNewVal);
}

/* //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                                                 //
//                                                                                                                 //
//                              --------------    L4D2 Shotgun FF      --------------                              //
//                                                                                                                 //
//                                                                                                                 //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////// */
public void ProcessShot(ArrayStack aStack) {
    int iVictim = 0, iAttacker = 0, iWeapon = 0;
    if (!aStack.Empty) {
        iVictim   = aStack.Pop();
        iAttacker = aStack.Pop();
        iWeapon   = aStack.Pop();
    }

    if (IsClientAndInGame(iVictim) && IsClientAndInGame(iAttacker)) {
        CountdownTimer ctGod = L4D2Direct_GetInvulnerabilityTimer(iVictim); // left4dhooks
        if (ctGod != CTimer_Null) CTimer_Invalidate(ctGod); //set m_timestamp - 0.0
        // Replicate natural behaviour
        float fMinFF          = g_cvMinFF.FloatValue;
        float fMaxFFCvarValue = g_cvMaxFF.FloatValue;
        float fMaxFF          = fMaxFFCvarValue <= 0.0 ? 99999.0 : fMaxFFCvarValue;
        float fDamage         = L4D2Util_GetMaxFloat(fMinFF, L4D2Util_GetMinFloat((g_iPelletsShot[iVictim][iAttacker] * g_cvModifier.FloatValue), fMaxFF));
        g_iPelletsShot[iVictim][iAttacker] = 0;
        int iNewPelletCount = RoundFloat(fDamage);
        for (int i = 0; i < iNewPelletCount; i++) {
            SDKHooks_TakeDamage(iVictim, iAttacker, iAttacker, 1.0, DMG_BUCKSHOT, iWeapon, .bypassHooks = true);
        }
    }

    g_bBuckshot[iAttacker] = false;
    delete aStack;
}

bool IsT1Shotgun(int iEntity) {
    if (iEntity <= MaxClients)
        return false;

    if (!IsValidEdict(iEntity))
        return false;

    char szClassname[CLASSNAME_LENGTH];
    GetEdictClassname(iEntity, szClassname, sizeof(szClassname));
    return (strcmp(szClassname, "weapon_pumpshotgun") == 0 || strcmp(szClassname, "weapon_shotgun_chrome") == 0);
}

bool IsTankRock(int iEntity) {
    if (iEntity <= MaxClients)
        return false;

    if (!IsValidEdict(iEntity))
        return false;

    char szClassname[CLASSNAME_LENGTH];
    GetEdictClassname(iEntity, szClassname, sizeof(szClassname));
    return (strcmp(szClassname, "tank_rock") == 0);
}

void SetGodFrameGlows(int iClient) {
    if (g_hTimer[iClient])
        delete g_hTimer[iClient];

    float fNow = GetGameTime();
    if (g_fFakeGodframeEnd[iClient] <= fNow) {
        Timer_ResetGlow(null, iClient);
        return;
    }

    if (g_cvGodframeGlows.BoolValue) {
        // make player transparent/red while godframed
        SetEntityRenderMode(iClient, RENDER_GLOW);
        SetEntityRenderColor(iClient, 255, 0, 0, 200);
        g_hTimer[iClient] = CreateTimer(g_fFakeGodframeEnd[iClient] - fNow, Timer_ResetGlow, iClient);
    }
}

Action Timer_ResetGlow(Handle hTimer, any iClient) {
    if (IsClientAndInGame(iClient)) {
        // remove transparency/color
        SetEntityRenderMode(iClient, RENDER_NORMAL);
        SetEntityRenderColor(iClient, 255, 255, 255, 255);
    }

    g_hTimer[iClient] = null;
    return Plugin_Stop;
}