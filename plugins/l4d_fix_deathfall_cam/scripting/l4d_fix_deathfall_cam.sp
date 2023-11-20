#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools_engine>
#include <left4dhooks>

// Hud Element hiding flags
#define HIDEHUD_WEAPONSELECTION   (1 << 0)  // Hide ammo count & weapon selection
#define HIDEHUD_FLASHLIGHT        (1 << 1)
#define HIDEHUD_ALL               (1 << 2)
#define HIDEHUD_HEALTH            (1 << 3)  // Hide health & armor / suit battery
#define HIDEHUD_PLAYERDEAD        (1 << 4)  // Hide when local player's dead
#define HIDEHUD_NEEDSUIT          (1 << 5)  // Hide when the local player doesn't have the HEV suit
#define HIDEHUD_MISCSTATUS        (1 << 6)  // Hide miscellaneous status elements (trains, pickup history, death notices, etc)
#define HIDEHUD_CHAT              (1 << 7)  // Hide all communication elements (saytext, voice icon, etc)
#define HIDEHUD_CROSSHAIR         (1 << 8)  // Hide crosshairs
#define HIDEHUD_VEHICLE_CROSSHAIR (1 << 9)  // Hide vehicle crosshair
#define HIDEHUD_INVEHICLE         (1 << 10)
#define HIDEHUD_BONUS_PROGRESS    (1 << 11) // Hide bonus progress display (for bonus map challenges)

ArrayList g_aDeathFallClients;

public Plugin myinfo =  {
    name        = "[L4D2] Fix DeathFall Camera",
    author      = "Forgetest",
    description = "Prevent \"point_deathfall_camera\" and \"point_viewcontrol*\" permanently locking view.",
    version     = "1.6.1",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    CreateNative("L4D_ReleaseFromViewControl", Ntv_ReleaseFromViewControl);
    return APLRes_Success;
}

public any Ntv_ReleaseFromViewControl(Handle hPlugin, int iNumParams) {
    ReleaseFromViewControl(0, GetNativeCell(1));
    return 0;
}

public void OnPluginStart() {
    HookEvent("round_start",           Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("gameinstructor_nodraw", Event_NoDraw,     EventHookMode_PostNoCopy);
    HookEvent("player_team",           Event_PlayerTeam);
    HookEvent("player_death",          Event_PlayerDeath);
    g_aDeathFallClients = new ArrayList();
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (FindEntityByClassname(MaxClients + 1, "point_viewcontrol*") != INVALID_ENT_REFERENCE || FindEntityByClassname(MaxClients + 1, "point_deathfall_camera") != INVALID_ENT_REFERENCE)
        UTIL_ReleaseAllExceptSurv();
    g_aDeathFallClients.Clear();
}

// Fix intro cameras locking view on L4D1
void Event_NoDraw(Event eEvent, const char[] szName, bool bDontBroadcast) {
    UTIL_ReleaseAllExceptSurv();
}

void Event_PlayerTeam(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!g_aDeathFallClients.Length) return;
    // view locked for approximately 6.0s when survivors die
    CreateTimer(6.0, Timer_ReleaseView, eEvent.GetInt("userid"), TIMER_FLAG_NO_MAPCHANGE);
}

void Event_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!g_aDeathFallClients.Length) return;
    int iUserId = eEvent.GetInt("userid");
    if (g_aDeathFallClients.FindValue(iUserId) == -1) return;
    CreateTimer(6.0, Timer_ReleaseView, iUserId, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_ReleaseView(Handle hTimer, any iUserId) {
    int iIndex = g_aDeathFallClients.FindValue(iUserId);
    if (iIndex == -1) return Plugin_Stop;
    g_aDeathFallClients.Erase(iIndex);
    ReleaseFromViewControl(iUserId);
    return Plugin_Stop;
}

public Action L4D_OnFatalFalling(int iClient, int iCamera) {
    if (iClient <= 0)
        return Plugin_Continue;

    if (!AllowDamage())
        return Plugin_Handled;

    if (GetClientTeam(iClient) == 2 && !IsFakeClient(iClient) && IsPlayerAlive(iClient)) {
        // keep deathcam for a period until the player dies
        int iUserId = GetClientUserId(iClient);
        if (g_aDeathFallClients.FindValue(iUserId) == -1)
            g_aDeathFallClients.Push(iUserId);
        return Plugin_Continue;
    }
    return Plugin_Handled;
}

void SetViewEntity(int iClient, int iView) {
    SetEntPropEnt(iClient, Prop_Send, "m_hViewEntity", iView);
    SetClientViewEntity(iClient, IsValidEdict(iView) ? iView : iClient);
}

stock void ReleaseFromViewControl(int iUserId = 0, int iClient = 0) {
    if (iUserId > 0)
        iClient = GetClientOfUserId(iUserId);

    if (iClient <= 0)
        return;

    SetEntityFlags(iClient, GetEntityFlags(iClient) & ~FL_FROZEN);
    SetEntProp(iClient, Prop_Send, "m_bDrawViewmodel", 1, 1);
    SetViewEntity(iClient, -1);

    if (GetClientTeam(iClient) == 1) SetEntProp(iClient, Prop_Send, "m_iHideHUD", HIDEHUD_BONUS_PROGRESS | HIDEHUD_HEALTH);
    else                             SetEntProp(iClient, Prop_Send, "m_iHideHUD", HIDEHUD_BONUS_PROGRESS);

    SetEntPropEnt(iClient,   Prop_Send, "m_hZoomOwner", -1);
    SetEntProp(iClient,      Prop_Send, "m_iFOV",        0);
    SetEntProp(iClient,      Prop_Send, "m_iFOVStart",   0);
    SetEntPropFloat(iClient, Prop_Send, "m_flFOVRate", 0.0);
}

void UTIL_ReleaseAllExceptSurv() {
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))    continue;
        if (IsFakeClient(i))       continue;
        if (GetClientTeam(i) == 2) continue;
        ReleaseFromViewControl(0, i);
    }
}

bool AllowDamage() {
    static ConVar cvGod = null;
    if (cvGod == null) cvGod = FindConVar("god");
    return !cvGod.BoolValue;
}