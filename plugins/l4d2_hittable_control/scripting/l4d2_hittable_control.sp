#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2util>

bool g_bLateLoad;         // Late load support!
bool g_bIsGauntletFinale; // Gauntlet finales do reduced hittable damage

float g_fOverkill       [MAXPLAYERS + 1][2048]; // Overkill, prolly don't need this big of a global array, could also use adt_array.
float g_fSpecialOverkill[MAXPLAYERS + 1][3];

#include "modules/convars.sp"
#include "modules/functions.sp"

public Plugin myinfo = {
    name        = "L4D2 Hittable Control",
    author      = "Stabby, Visor, Sir, Derpduck, Forgetest",
    version     = "0.7",
    description = "Allows for customisation of hittable damage values.",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    g_bLateLoad = bLate;
    CreateNative("L4D2_AreForkliftsUnbreakable", Native_UnbreakableForklifts);
    RegPluginLibrary("l4d2_hittable_control");
    return APLRes_Success;
}

any Native_UnbreakableForklifts(Handle hPlugin, int iNumParams) {
    return bUnbreakableForklifts;
}

public void OnPluginStart() {
    OnModuleStart_ConVars();

    if (g_bLateLoad) {
        for (int i = 1; i <= MaxClients; i++) {
            if (!IsClientInGame(i))
                continue;

            OnClientPutInServer(i);
        }
    }

    HookEvent("round_start",           Event_RoundStart,          EventHookMode_PostNoCopy);
    HookEvent("gauntlet_finale_start", Event_GauntletFinaleStart, EventHookMode_PostNoCopy);
}

public void OnClientPutInServer(int iClient) {
    SDKHook(iClient, SDKHook_OnTakeDamage, SDK_OnTakeDamage);
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    // Reset everything to make sure we don't run into issues when a map is restarted (as GameTime resets)
    for (int i = 1; i <= MaxClients; i++) {
        for (int e = 0; e < sizeof(g_fOverkill[]); e++) {
            g_fOverkill[i][e] = 0.0;
        }

        g_fSpecialOverkill[i][0] = 0.0;
        g_fSpecialOverkill[i][1] = 0.0;
        g_fSpecialOverkill[i][2] = 0.0;
    }

    g_bIsGauntletFinale = false;
    ToggleBreakableForklifts(bUnbreakableForklifts, 20.0); // Delay breakable forklift patch as it must run after vscripts
}

void Event_GauntletFinaleStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bIsGauntletFinale = true;
}

Action SDK_OnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &fDmg, int &iDmgType) {
    if (!IsValidEdict(iAttacker) || !IsValidEdict(iVictim) || !IsValidEdict(iInflictor))
        return Plugin_Continue;

    char szClsName[64];
    GetEdictClassname(iInflictor, szClsName, sizeof(szClsName));

    if (strcmp(szClsName,"prop_physics") != 0 && strcmp(szClsName,"prop_car_alarm") != 0)
        return Plugin_Continue;

    if (g_fOverkill[iVictim][iInflictor] - GetGameTime() > 0.0)
        return Plugin_Handled; // Overkill on this Hittable.

    if (IsTank(iVictim) && bTankSelfDamage)
        return Plugin_Handled; // Tank is hitting himself with the Hittable (+added usecase when the Tank would be hit by a hittable that he punched a hittable against before it hit him)

    if (GetClientTeam(iVictim) != 2)
        return Plugin_Continue; // Victim is not a Survivor.

    if (ProcessSpecialHittables(iVictim, iAttacker, iInflictor, fDmg))
        return Plugin_Handled;

    float fVal = fStandardIncapDamage;
    if (GetEntProp(iVictim, Prop_Send, "m_isIncapacitated") && fVal != -2) { // Survivor is Incapped. (Damage)
        if (fVal >= 0.0) {
            fDmg = fVal;
        } else {
            return Plugin_Continue;
        }
    } else {
        GetHittableDamage(iInflictor, fDmg);
    }

    // Use standard damage on gauntlet finales
    if (g_bIsGauntletFinale)
        fDmg = fDmg * 4.0 * fGauntletFinaleMulti;

    g_fOverkill[iVictim][iInflictor] = GetGameTime() + fOverHitInterval; //standardise them bitchin over-hits
    InvalidatePhysOverhitTimer(iVictim);
    return Plugin_Changed;
}