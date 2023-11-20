#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>
#include <sdkhooks>
#include <l4d2util/constants>

#define GAMEDATA_FILE             "l4d2_pistol_delay"
#define RATE_OF_FIRE_OFFSET_NAME  "CTerrorGun::GetRateOfFire"
#define IS_FULLY_AUTO_OFFSET_NAME "CTerrorGun::IsFullyAutomatic" // funny

#define MIN_RATE_OF_FIRE          0.001
#define MAX_RATE_OF_FIRE          5.0

#define DEF_RITE_OF_FIRE_SINGLE   0.175
#define DEF_RITE_OF_FIRE_DUALIES  0.075   // Look at function 'CPistol::GetRateOfFire'
#define DEF_RITE_OF_FIRE_INCAP    0.3     // Equals cvar 'survivor_incapacitated_cycle_time'

bool g_bLateLoad = false;

DynamicHook g_dhRateOfFire = null;

ConVar g_cvPistolDelaySingle = null;
float  g_fPistolDelaySingle  = DEF_RITE_OF_FIRE_SINGLE;

ConVar g_cvPistolDelayDualies = null;
float  g_fPistolDelayDualies  = DEF_RITE_OF_FIRE_DUALIES;

public Plugin myinfo = {
    name        = "L4D2 pistol delay",
    author      = "A1m`",
    version     = "1.3",
    description = "Allows you to adjust the rate of fire of pistols (with a high tickrate, the rate of fire of dual pistols is very high).",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErrMax) {
    g_bLateLoad = bLate;
    return APLRes_Success;
}

void InitGameData() {
    GameData gmConf = new GameData(GAMEDATA_FILE);
    if (!gmConf) SetFailState("Gamedata '"... GAMEDATA_FILE ...".txt' missing or corrupt.");
    int iRateOfFireOffs = gmConf.GetOffset(RATE_OF_FIRE_OFFSET_NAME);
    if (iRateOfFireOffs == -1) SetFailState("Failed to get offset '"... RATE_OF_FIRE_OFFSET_NAME ..."'.");
    g_dhRateOfFire = new DynamicHook(iRateOfFireOffs, HookType_Entity, ReturnType_Float, ThisPointer_CBaseEntity);
    delete gmConf;
}

public void OnPluginStart() {
    InitGameData();

    char szDefVal[64];
    FloatToString(DEF_RITE_OF_FIRE_SINGLE, szDefVal, sizeof(szDefVal));

    g_cvPistolDelaySingle = CreateConVar(
    "l4d_pistol_delay_single", szDefVal,
    "Minimum time (in seconds) between single pistol shots",
    FCVAR_NOTIFY, true, MIN_RATE_OF_FIRE, true, MAX_RATE_OF_FIRE);

    // Value 'DEF_RITE_OF_FIRE_DUALIES' probably too low for a high tickrate
    g_cvPistolDelayDualies = CreateConVar(
    "l4d_pistol_delay_dualies", "0.1",
    "Minimum time (in seconds) between dual pistol shots",
    FCVAR_NOTIFY, true, MIN_RATE_OF_FIRE, true, MAX_RATE_OF_FIRE);

    g_fPistolDelayDualies = ClampFloat(g_cvPistolDelayDualies.FloatValue, MIN_RATE_OF_FIRE, MAX_RATE_OF_FIRE);
    g_fPistolDelaySingle  = ClampFloat(g_cvPistolDelaySingle.FloatValue,  MIN_RATE_OF_FIRE, MAX_RATE_OF_FIRE);

    g_cvPistolDelaySingle.AddChangeHook(ConVarChanged_PistolDelay);
    g_cvPistolDelayDualies.AddChangeHook(ConVarChanged_PistolDelay);

    LateLoad();
}

void ConVarChanged_PistolDelay(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fPistolDelaySingle  = ClampFloat(g_cvPistolDelaySingle.FloatValue,  MIN_RATE_OF_FIRE, MAX_RATE_OF_FIRE);
    g_fPistolDelayDualies = ClampFloat(g_cvPistolDelayDualies.FloatValue, MIN_RATE_OF_FIRE, MAX_RATE_OF_FIRE);
}

void LateLoad() {
    if (!g_bLateLoad) return;
    int iEnt = INVALID_ENT_REFERENCE;
    while ((iEnt = FindEntityByClassname(iEnt, "weapon_pistol")) != INVALID_ENT_REFERENCE) {
        if (!IsValidEntity(iEnt)) continue;
        g_dhRateOfFire.HookEntity(Hook_Pre, iEnt, CPistol_OnGetRiteOfFire);
    }
}

public void OnEntityCreated(int iEnt, const char[] szName) {
    if (szName[0] != 'w' || strcmp("weapon_pistol", szName) != 0)
        return;
    g_dhRateOfFire.HookEntity(Hook_Pre, iEnt, CPistol_OnGetRiteOfFire);
}

MRESReturn CPistol_OnGetRiteOfFire(int iWeapon, DHookReturn hReturn) {
    int iOwner = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwner");
    if (iOwner != -1 && IsIncapacitated(iOwner))
        return MRES_Ignored;
    if (GetEntProp(iWeapon, Prop_Send, "m_isDualWielding", 1) < 1) {
        hReturn.Value = (GetEntProp(iWeapon, Prop_Send, "m_iClip1") <= 0) ? 1.5 * g_fPistolDelaySingle : g_fPistolDelaySingle;
        return MRES_Supercede;
    }
    hReturn.Value = (GetEntProp(iWeapon, Prop_Send, "m_iClip1") <= 0) ? 0.2 : g_fPistolDelayDualies;
    return MRES_Supercede;
}

bool IsIncapacitated(int iClient) {
    if (GetEntProp(iClient, Prop_Send, "m_lifeState") == LIFE_ALIVE)
        return (GetEntProp(iClient, Prop_Send, "m_isIncapacitated", 1) > 0);
    return false;
}

float ClampFloat(float fInc, float fLow, float fHigh) {
    return (fInc > fHigh) ? fHigh : ((fInc < fLow) ? fLow : fInc);
}