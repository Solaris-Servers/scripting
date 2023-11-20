#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

#define ZC_CHARGER 6

#define CHARGER_DMG_IMPACT  10.0
#define CHARGER_DMG_STUMBLE  2.0
#define CHARGER_DMG_POUND   15.0

enum eInfectedWeapon {
    eTankWeapon,
    eChargerWeapon
}

StringMap g_smInflictors; // names to look up

bool      g_bLateLoad;

ConVar    g_cvDmgFirst;         // damage for first punch after spawning
ConVar    g_cvDmgSmash;         // damage for the smash-inpact (def.10)
ConVar    g_cvDmgStumble;       // damage for stumble
ConVar    g_cvDmgPound;         // damage for pound-slams (replaces natural cvar)
ConVar    g_cvDmgCappedVictim;  // scratch damage for capped Survivors
ConVar    g_cvDmgIncappedPound; // damage for incapped Survivors

ConVar    g_cvChargerPunchDmg;
float     g_fChargerPunchDmg;

bool      g_bChargerPunched [MAXPLAYERS + 1]; // whether charger player got a punch in current life
bool      g_bChargerCharging[MAXPLAYERS + 1]; // whether the charger is in a charge

int       g_iSurvivorProps[4];

public Plugin myinfo = {
    name        = "Charger Damage",
    author      = "Tabun, Jacob, Visor",
    description = "Charger damage modifier",
    version     = "0.4",
    url         = "https://github.com/Attano/L4D2-Competitive-Framework"
}

/* -------------------------------
 *      Init
 * ------------------------------- */

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    g_bLateLoad = bLate;
    return APLRes_Success;
}

public void OnPluginStart() {
    // hook already existing clients if loading late
    if (g_bLateLoad) {
        for (int i = 1; i <= MaxClients; i++) {
            if (!IsClientInGame(i))
                continue;

            SDKHook(i, SDKHook_OnTakeDamage, SDK_OnTakeDamage);
        }
    }

    // network prop offsets
    g_iSurvivorProps[0]  = FindSendPropInfoEx("CTerrorPlayer", "m_tongueOwner");
    g_iSurvivorProps[1]  = FindSendPropInfoEx("CTerrorPlayer", "m_pounceAttacker");
    g_iSurvivorProps[2]  = FindSendPropInfoEx("CTerrorPlayer", "m_jockeyAttacker");
    g_iSurvivorProps[3]  = FindSendPropInfoEx("CTerrorPlayer", "m_pummelAttacker");

    // cvars
    g_cvDmgFirst = CreateConVar(
    "charger_dmg_firstpunch", "-1",
    "Damage for first charger punch (in its life). -1 to ignore punch count",
    FCVAR_NONE, true, -1.0, false, 0.0);

    g_cvDmgSmash = CreateConVar(
    "charger_dmg_impact", "10",
    "Damage for impact after a charge.",
    FCVAR_NONE, true, 0.0, false, 0.0);

    g_cvDmgStumble = CreateConVar(
    "charger_dmg_stumble", "2",
    "Damage for stumbled impact after a charge.",
    FCVAR_NONE, true, 0.0, false, 0.0);

    g_cvDmgPound = CreateConVar(
    "charger_dmg_pound", "15",
    "Damage for pounds after charge/collision completed.",
    FCVAR_NONE, true, 0.0, false, 0.0);

    g_cvDmgCappedVictim = CreateConVar(
    "charger_dmg_cappedvictim", "-1",
    "Damage for capped Survivor victims. -1 to ignore capped status",
    FCVAR_NONE, true, -1.0, false, 0.0);

    g_cvDmgIncappedPound = CreateConVar(
    "charger_dmg_incapped", "-1",
    "Damage for incapped victims. -1 to ignore incapp status",
    FCVAR_NONE, true, -1.0, false, 0.0);

    // Default punch damage value
    g_cvChargerPunchDmg = FindConVar("charger_pz_claw_dmg");
    g_fChargerPunchDmg  = g_cvChargerPunchDmg.FloatValue;
    g_cvChargerPunchDmg.AddChangeHook(ChargerPunchDmgChanged);

    // hooks
    HookEvent("round_start",          RoundStart_Event,  EventHookMode_PostNoCopy);
    HookEvent("player_spawn",         PlayerSpawn_Event);
    HookEvent("charger_charge_start", ChargeStart_Event);
    HookEvent("charger_charge_end",   ChargeEnd_Event);

    // trie
    g_smInflictors = BuildInflictorTrie();
}

int FindSendPropInfoEx(const char[] szClassName, const char[] szPropName) {
    int iOffset = FindSendPropInfo(szClassName, szPropName);
    if (iOffset <= 0) SetFailState("Unable to find an offset for %s::%s", szClassName, szPropName);
    return iOffset;
}

/* -------------------------------
 *      General hooks / events
 * ------------------------------- */

public void OnClientPutInServer(int iClient) {
    SDKHook(iClient, SDKHook_OnTakeDamage, SDK_OnTakeDamage);
}

public void OnClientDisconnect(int iClient) {
    SDKUnhook(iClient, SDKHook_OnTakeDamage, SDK_OnTakeDamage);
}

public void OnMapStart() {
    SetCleanSlate();
}

void RoundStart_Event(Event eEvent, const char[] szName, bool bDontBroadcast) {
    SetCleanSlate();
}

void PlayerSpawn_Event(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)
        return;

    // just spawned, prepare for that first punch
    g_bChargerPunched [iClient] = false;
    g_bChargerCharging[iClient] = false;
}

void ChargeStart_Event(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)
        return;

    g_bChargerCharging[iClient] = true;
}

void ChargeEnd_Event(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0) return;
    g_bChargerCharging[iClient] = false;
}

void ChargerPunchDmgChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fChargerPunchDmg = g_cvChargerPunchDmg.FloatValue;
}

/* --------------------------------------
 *     GOT MY EYES ON YOU, DAMAGE
 * -------------------------------------- */

public Action SDK_OnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &fDmg, int &iDmgType, int &iWeapon, float vDmgForce[3], float vDmgPos[3]) {
    if (iVictim <= 0 || iVictim > MaxClients)
        return Plugin_Continue;

    if (iAttacker <= 0 || iAttacker > MaxClients)
        return Plugin_Continue;

    if (!IsClientInGame(iVictim))
        return Plugin_Continue;

    if (!IsClientInGame(iAttacker))
        return Plugin_Continue;

    if (GetClientTeam(iVictim) != TEAM_SURVIVOR)
        return Plugin_Continue;

    if (GetClientTeam(iAttacker) != TEAM_INFECTED)
        return Plugin_Continue;

    if (GetEntProp(iAttacker, Prop_Send, "m_zombieClass") != ZC_CHARGER)
        return Plugin_Continue;

    // only check player-to-player damage
    static char szClassName[64];
    GetClientWeapon(iInflictor, szClassName, sizeof(szClassName));

    // only check tank punch/rock and SI claws (also rules out anything but infected-to-survivor damage)
    eInfectedWeapon eWeaponID;
    if (!g_smInflictors.GetValue(szClassName, eWeaponID))
        return Plugin_Continue;

    if (eWeaponID != eChargerWeapon)
        return Plugin_Continue;

    // okay, it is a charger
    // bowl          = 10 + has force > 0,0,0
    // stumble       = 2 (+ small force)
    // charge impact = 10 + force 0,0,0
    // pound         = 15 + force 0,0,0

    if (vDmgForce[0] == 0.0 && vDmgForce[1] == 0.0 && vDmgForce[2] == 0.0) {
        if (fDmg == CHARGER_DMG_IMPACT) {
            // CHARGE IMPACT
            fDmg = g_cvDmgSmash.FloatValue;
            return Plugin_Changed;
        } else if (fDmg == CHARGER_DMG_POUND) {
            // POUND
            if (IsIncapped(iVictim) && g_cvDmgIncappedPound.FloatValue != -1) {
                fDmg = g_cvDmgIncappedPound.FloatValue;
                return Plugin_Changed;
            }

            fDmg = g_cvDmgPound.FloatValue;
            return Plugin_Changed;
        }
    } else if (fDmg == g_fChargerPunchDmg) {
        // PUNCH
        float fDmgFirst = g_cvDmgFirst.FloatValue;
        if (!g_bChargerPunched[iAttacker] && fDmgFirst != -1.0) {
            // this is the first attack
            g_bChargerPunched[iAttacker] = true;
            fDmg = fDmgFirst;
            return Plugin_Changed;
        }

        if (IsUnderAttack(iVictim && g_cvDmgCappedVictim.FloatValue != -1.0)) {
            // this is a (second+) charger punch (or first if firstpunch cvar is set to -1)
            fDmg = g_cvDmgCappedVictim.FloatValue;
            return Plugin_Changed;
        }
    } else if (fDmg == CHARGER_DMG_STUMBLE) {
        // STUMBLE
        fDmg = g_cvDmgStumble.FloatValue;
        return Plugin_Changed;
    }

    return Plugin_Continue;
}

/* --------------------------------------
 *     Shared function(s)
 * -------------------------------------- */

void SetCleanSlate() {
    for (int i = 1; i <= MaxClients; i++) {
        g_bChargerPunched [i] = false;
        g_bChargerCharging[i] = false;
    }
}

StringMap BuildInflictorTrie() {
    StringMap smWeapons = new StringMap();
    smWeapons.SetValue("weapon_tank_claw",    eTankWeapon);
    smWeapons.SetValue("tank_rock",           eTankWeapon);
    smWeapons.SetValue("weapon_charger_claw", eChargerWeapon);
    return smWeapons;
}

bool IsUnderAttack(int iSurvivor) {
    int iAttacker;
    for (int i = 0; i < sizeof(g_iSurvivorProps); i++) {
        iAttacker = GetEntDataEnt2(iSurvivor, g_iSurvivorProps[i]);
        if (iAttacker <= 0)
            continue;

        if (iAttacker > MaxClients)
            continue;

        if (!IsClientInGame(iAttacker))
            continue;

        return true;
    }

    return false;
}

bool IsIncapped(int client) {
    return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}