#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

float g_fLastMeleeSwing[MAXPLAYERS + 1];
bool  g_bLate;

public Plugin myinfo = {
    name        = "Fast melee fix",
    author      = "sheo",
    description = "Fixes the bug with too fast melee attacks",
    version     = "2.1",
    url         = "http://steamcommunity.com/groups/b1com"
};

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    g_bLate = bLate;
    return APLRes_Success;
}

public void OnPluginStart() {
    HookEvent("weapon_fire", Event_WeaponFire);

    if (g_bLate) {
        for (int i = 1; i <= MaxClients; i++) {
            if (!IsClientInGame(i))
                continue;

            if (IsFakeClient(i))
                continue;

            SDKHook(i, SDKHook_WeaponSwitchPost, SDK_WeaponSwitchPost);
        }
    }
}

public void OnClientPutInServer(int iClient) {
    if (!IsFakeClient(iClient))
        SDKHook(iClient, SDKHook_WeaponSwitchPost, SDK_WeaponSwitchPost);
    g_fLastMeleeSwing[iClient] = 0.0;
}

void Event_WeaponFire(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));

    if (iClient <= 0)
        return;

    if (IsFakeClient(iClient))
        return;

    char szBuffer[64];
    eEvent.GetString("weapon", szBuffer, sizeof(szBuffer));

    if (strcmp(szBuffer, "melee") == 0)
        g_fLastMeleeSwing[iClient] = GetGameTime();
}

void SDK_WeaponSwitchPost(int iClient, int iWeapon) {
    if (IsFakeClient(iClient))
        return;

    if (!IsValidEntity(iWeapon))
        return;

    char szBuffer[32];
    GetEntityClassname(iWeapon, szBuffer, sizeof(szBuffer));

    if (strcmp(szBuffer, "weapon_melee") == 0) {
        float fShouldBeNextAttack = g_fLastMeleeSwing[iClient] + 0.92;
        float fByServerNextAttack = GetGameTime() + 0.5;
        SetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack", (fShouldBeNextAttack > fByServerNextAttack) ? fShouldBeNextAttack : fByServerNextAttack);
    }
}