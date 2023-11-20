#pragma newdecls required
#pragma semicolon 1
#include <sourcemod>

public Plugin myinfo = {
    name        = "Incap Punch Fix",
    author      = "CanadaRox",
    description = "Survivors go flying when they are incapped with a punch!!",
    version     = "1.0",
    url         = ""
};

public void OnPluginStart() {
    HookEvent("player_incapacitated", PlayerIncap);
}

public void PlayerIncap(Event eEvent, char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    char szWeapon[256];
    eEvent.GetString("weapon", szWeapon, sizeof(szWeapon));
    if (StrEqual(szWeapon, "tank_claw")) {
        SetEntProp(iClient, Prop_Send, "m_isIncapacitated", 0);
        SetEntityHealth(iClient, 0);
        CreateTimer(0.1, Reincap_Timer, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action Reincap_Timer(Handle timer, any iUserId) {
    int iClient = GetClientOfUserId(iUserId);
    if (iClient < 1) return Plugin_Stop;
    SetEntProp(iClient, Prop_Send, "m_isIncapacitated", 1);
    SetEntityHealth(iClient, 300);
    return Plugin_Stop;
}