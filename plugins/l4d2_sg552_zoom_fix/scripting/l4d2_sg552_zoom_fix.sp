#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>

public Plugin myinfo = {
    name        = "[L4D2] SG552 - Zoom out on reload",
    author      = "Altair Sossai",
    description = "Remove zoom from the SG552 weapon when reloading, preventing the player's camera from getting stuck",
    version     = "1.1",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
}

public void OnPluginStart() {
    HookEvent("weapon_zoom", Event_WeaponZoom);
}

void Event_WeaponZoom(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));

    if (GetEntProp(iClient, Prop_Send, "m_hZoomOwner") == -1 && UsingTheGunSG552(iClient))
        UnZoom(iClient);
}

void UnZoom(int iClient) {
    SetEntPropFloat(iClient, Prop_Send, "m_flFOVTime", 0.0);
    SetEntPropFloat(iClient, Prop_Send, "m_flFOVRate", 0.0);
    SetEntProp     (iClient, Prop_Send, "m_iFOV",      0);
}

bool UsingTheGunSG552(int iClient) {
    int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");

    static char szClsName[20];
    GetEntityClassname(iWeapon, szClsName, sizeof(szClsName));

    return strcmp(szClsName, "weapon_rifle_sg552") == 0;
}