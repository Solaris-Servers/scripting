#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define ZC_CHARGER    6

bool g_bLateLoad;
bool g_bChargerPunched [MAXPLAYERS + 1];
bool g_bChargerCharging[MAXPLAYERS + 1];

public Plugin myinfo = {
    name        = "1v1 Practice Charger Damage",
    description = "For 1v1 practice, negates scratch damage.",
    author      = "Tabun",
    version     = "0.1c",
    url         = "nope"
};

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    g_bLateLoad = bLate;
    return APLRes_Success;
}

public void OnPluginStart() {
    HookEvent("round_start",          Event_RoundStart);
    HookEvent("player_spawn",         Event_PlayerSpawn);
    HookEvent("charger_charge_start", Event_ChargeStart);
    HookEvent("charger_charge_end",   Event_ChargeEnd);

    if (g_bLateLoad) {
        for (int i = 1; i <= MaxClients; i++) {
            if (!IsClientInGame(i)) continue;
            SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
        }
    }
}

public void OnClientPutInServer(int iClient) {
    SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
    g_bChargerPunched [iClient] = false;
    g_bChargerCharging[iClient] = false;
}

public void OnClientDisconnect(int iClient) {
    SDKUnhook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
    g_bChargerPunched [iClient] = false;
    g_bChargerCharging[iClient] = false;
}

public void OnMapStart() {
    SetCleanSlate();
}

void Event_RoundStart(Event eEvent, char[] szName, bool bDontBroadcast) {
    SetCleanSlate();
}

void Event_PlayerSpawn(Event eEvent, char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)                            return;
    if (IsClientInGame(iClient))                 return;
    if (GetClientTeam(iClient) != TEAM_INFECTED) return;
    if (GetEntProp(iClient, Prop_Send, "m_zombieClass") == ZC_CHARGER) {
        g_bChargerPunched [iClient] = false;
        g_bChargerCharging[iClient] = false;
    }
}

void Event_ChargeStart(Event eEvent, char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0) return;
    g_bChargerCharging[iClient] = true;
}

void Event_ChargeEnd(Event eEvent, char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0) return;
    g_bChargerCharging[iClient] = false;
}

public Action OnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &iDamageType, int &iWeapon, float vForce[3], float vPos[3]) {
    if (!IsClientAndInGame(iAttacker)) return Plugin_Continue;
    if (!IsClientAndInGame(iVictim))   return Plugin_Continue;
    if (!IsValidEdict(iInflictor))     return Plugin_Continue;

    if (GetClientTeam(iVictim)   != TEAM_SURVIVOR) return Plugin_Continue;
    if (GetClientTeam(iAttacker) != TEAM_INFECTED) return Plugin_Continue;

    if (GetEntProp(iAttacker, Prop_Send, "m_zombieClass") != ZC_CHARGER)
        return Plugin_Continue;

    char szClsName[64];
    if (iInflictor == iAttacker) {
        GetClientWeapon(iInflictor, szClsName, sizeof(szClsName));
    } else {
        GetEdictClassname(iInflictor, szClsName, sizeof(szClsName));
    }

    if (strcmp(szClsName, "weapon_charger_claw") == 0) {
        if (fDamage == 10.0) {
            if (vForce[0] == 0.0 && vForce[1] == 0.0 && vForce[2] == 0.0) {
                fDamage = 1.0;
                return Plugin_Changed;
            }
            if (!g_bChargerPunched[iAttacker]) {
                g_bChargerPunched[iAttacker] = true;
                fDamage = 0.0;
                return Plugin_Changed;
            }
            fDamage = 0.0;
            return Plugin_Changed;
        }
        if (fDamage == 2.0) {
            fDamage = 0.0;
            return Plugin_Changed;
        }
        if (fDamage == 15.0 && (vForce[0] == 0.0 && vForce[1] == 0.0 && vForce[2] == 0.0)) {
            fDamage = 0.0;
            int iRemainingHealth = GetClientHealth(iAttacker);
            CPrintToChatAll("{green}[{default}1v1{green}] {red}%N{default} had {olive}%d{default} health remaining!", iAttacker, iRemainingHealth);
            CreateTimer(0.05, Timer_DestroyCharger, GetClientUserId(iAttacker), TIMER_FLAG_NO_MAPCHANGE);
            return Plugin_Changed;
        }
        CPrintToChatAll("{green}[{red}!{green}]{default} Warning, charger doing a type of damage it shouldn't!");
        CPrintToChatAll("{green}[{red}!{green}]{default} infl.: [%s] type [%d] damage [%.0f] force [%.0f %.0f %.0f]", szClsName, iDamageType, fDamage, vForce[0], vForce[1], vForce[2]);
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

Action Timer_DestroyCharger(Handle timer, int iUserId) {
    int iClient = GetClientOfUserId(iUserId);
    if (iClient <= 0) return Plugin_Stop;
    ForcePlayerSuicide(iClient);
    return Plugin_Stop;
}

bool IsClientAndInGame(int iClient) {
    return iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient);
}

void SetCleanSlate() {
    for (int i = 1; i <= MaxClients; i++) {
        g_bChargerPunched [i] = false;
        g_bChargerCharging[i] = false;
    }
}