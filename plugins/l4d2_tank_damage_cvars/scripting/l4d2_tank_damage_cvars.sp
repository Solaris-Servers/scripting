#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>

ConVar g_cvTankPoundDmg;
float  g_fTankPoundDmg;

ConVar g_cvTankRockDmg;
float  g_fTankRockDmg;

bool   g_bLateLoad;

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    g_bLateLoad = bLate;
    return APLRes_Success;
}

public Plugin myinfo = {
    name        = "L4D2 Tank Damage Cvars",
    author      = "Visor",
    description = "Toggle Tank attack damage per type",
    version     = "1.1",
    url         = "https://github.com/Attano/Equilibrium"
};

public void OnPluginStart() {
    g_cvTankPoundDmg = CreateConVar(
    "vs_tank_pound_damage", "24",
    "Amount of damage done by a vs tank's melee attack on incapped survivors",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_fTankPoundDmg = g_cvTankPoundDmg.FloatValue;
    g_cvTankPoundDmg.AddChangeHook(ConVarChanged_TankPoundDmg);

    g_cvTankRockDmg = CreateConVar(
    "vs_tank_rock_damage", "24",
    "Amount of damage done by a vs tank's rock",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_fTankRockDmg = g_cvTankRockDmg.FloatValue;
    g_cvTankRockDmg.AddChangeHook(ConVarChanged_TankRockDmg);

    if (g_bLateLoad) {
        for (int i = 1; i <= MaxClients; i++) {
            if (!IsClientInGame(i)) continue;
            OnClientPutInServer(i);
        }
    }
}

void ConVarChanged_TankPoundDmg(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fTankPoundDmg = g_cvTankPoundDmg.FloatValue;
}

void ConVarChanged_TankRockDmg(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fTankRockDmg = g_cvTankRockDmg.FloatValue;
}

public void OnClientPutInServer(int iClient) {
    SDKHook(iClient, SDKHook_OnTakeDamage, SDK_OnTakeDamage);
}

public Action SDK_OnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &fDmg, int &iDmgType, int &iWeapon, float fDmgForce[3], float fDmgPosition[3]) {
    if (!IsSurvivor(iVictim) || !IsTank(iAttacker))
        return Plugin_Continue;

    if (IsIncapped(iVictim) && IsTank(iInflictor)) {
        fDmg = g_fTankPoundDmg;
    } else if (IsTankRock(iInflictor)) {
        fDmg = g_fTankRockDmg;
    }

    return Plugin_Changed;
}

bool IsIncapped(int iClient) {
    return view_as<bool>(GetEntProp(iClient, Prop_Send, "m_isIncapacitated"));
}

bool IsSurvivor(int iClient) {
    return (iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient) && GetClientTeam(iClient) == 2);
}

bool IsTank(int iClient) {
    return (iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient) && GetClientTeam(iClient) == 3 && GetEntProp(iClient, Prop_Send, "m_zombieClass") == 8 && IsPlayerAlive(iClient));
}

bool IsTankRock(int iEnt) {
    if (iEnt > 0 && IsValidEntity(iEnt) && IsValidEdict(iEnt)) {
        char szClsName[64];
        GetEdictClassname(iEnt, szClsName, sizeof(szClsName));
        return strcmp(szClsName, "tank_rock") == 0;
    }
    return false;
}