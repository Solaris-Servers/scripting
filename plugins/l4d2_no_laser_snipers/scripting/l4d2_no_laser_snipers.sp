#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>

bool g_bLateload = false;

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    g_bLateload = bLate;
    return APLRes_Success;
}

public void OnPluginStart() {
    if (g_bLateload) {
        for (int i = MaxClients + 1; i <= GetMaxEntities(); i++) {
            if (!IsValidEntity(i)) continue;
            char szClsName[20];
            GetEdictClassname(i, szClsName, sizeof(szClsName));
            if (strcmp(szClsName, "upgrade_laser_sight") == 0)
                SDKHook(i, SDKHook_Use, OnUseLaserSight);
        }
    }
}

public void OnEntityCreated(int iEnt, const char[] szClsName) {
    if (strcmp(szClsName, "upgrade_laser_sight") == 0)
        SDKHook(iEnt, SDKHook_Use, OnUseLaserSight);
}

Action OnUseLaserSight(int iEnt, int iActivator, int iCaller, UseType uType, float fValue) {
    if (iCaller <= 0)                return Plugin_Continue;
    if (iCaller > MaxClients)        return Plugin_Continue;
    if (!IsClientInGame(iCaller))    return Plugin_Continue;
    if (GetClientTeam(iCaller) != 2) return Plugin_Continue;
    if (uType != Use_Toggle)         return Plugin_Continue;
    int iSlot = GetPlayerWeaponSlot(iCaller, 0);
    if (iSlot > -1) {
        char szWeapon[100];
        GetEdictClassname(iSlot, szWeapon, sizeof(szWeapon));
        if (strcmp(szWeapon, "weapon_hunting_rifle") == 0 || strcmp(szWeapon, "weapon_sniper_military") == 0 || strcmp(szWeapon, "weapon_sniper_scout") == 0 || strcmp(szWeapon, "weapon_sniper_awp") == 0) {
            CPrintToChatAll("{red}[{default}Witch Party{red}]{default} You cannout equip laser on this weapon!");
            return Plugin_Handled;
        }
    }
    return Plugin_Continue;
}