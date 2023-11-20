#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>

#define GAMEDATA "l4d2_drop_secondary"

int g_iHiddenWeaponOffs;

public Plugin myinfo = {
    name        = "L4D2 Drop Secondary",
    author      = "Jahze, Visor, NoBody & HarryPotter, sorallll",
    version     = "2.0",
    description = "Survivor players will drop their secondary weapon when they die",
    url         = "https://github.com/Attano/Equilibrium"
};

public void OnPluginStart() {
    InitGameData();
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
}

void InitGameData() {
    GameData gmConf = new GameData(GAMEDATA);
    if (!gmConf) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);
    g_iHiddenWeaponOffs = gmConf.GetOffset("CTerrorPlayer::OnIncapacitatedAsSurvivor::m_hHiddenWeapon");
    if (g_iHiddenWeaponOffs == -1) SetFailState("Failed to find offset: CTerrorPlayer::OnIncapacitatedAsSurvivor::m_hHiddenWeapon");
    delete gmConf;
}

void Event_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)                return;
    if (!IsClientInGame(iClient))    return;
    if (GetClientTeam(iClient) != 2) return;
    int iEnt = GetEntDataEnt2(iClient, g_iHiddenWeaponOffs);
    SetEntData(iClient, g_iHiddenWeaponOffs, -1);
    if (iEnt > MaxClients && IsValidEntity(iEnt) && GetEntPropEnt(iEnt, Prop_Data, "m_hOwnerEntity") == iClient) {
        float vTarget[3];
        GetEntPropVector(iEnt, Prop_Data, "m_vecAbsOrigin", vTarget);
        SDKHooks_DropWeapon(iClient, iEnt, vTarget, NULL_VECTOR, false);
    }
}