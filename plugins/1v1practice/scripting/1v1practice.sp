#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <readyup>
#include <solaris/stocks>

public Plugin myinfo = {
    name        = "1v1 Practice",
    description = "1v1 practice",
    author      = "epilimic",
    version     = "6.1p",
    url         = "http://buttsecs.org"
};

public void OnPluginStart() {
    RegConsoleCmd("sm_safe",     Cmd_SafeRoom);
    RegConsoleCmd("sm_ammo",     Cmd_GiveAmmo);
    RegConsoleCmd("sm_noclipme", Cmd_Noclip);
    RegConsoleCmd("sm_sb_stop",  Cmd_SBStop);

    HookEvent("player_hurt", Event_PlayerHurt);
}

void Event_PlayerHurt(Event eEvent, char[] szName, bool bDontBroadcast) {
    int iAttacker = GetClientOfUserId(eEvent.GetInt("attacker"));
    if (iAttacker <= 0) return;
    int iDamage = eEvent.GetInt("dmg_health");
    int iClass  = GetZombieClass(iAttacker);
    if (GetClientTeam(iAttacker) == 3 && iClass % 2 && iDamage > 0) {
        int iRemainingHealth = GetClientHealth(iAttacker);
        CPrintToChatAll("{green}[{default}1v1{green}] {red}%N{default} had {olive}%d{default} health remaining!", iAttacker, iRemainingHealth);
        ForcePlayerSuicide(iAttacker);
    }
}

public void OnRoundIsLive() {
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))    continue;
        if (GetClientTeam(i) != 2) continue;
        if (!IsPlayerAlive(i))     continue;
        SetEntityHealth(i, 20000);
        SetEntProp(i, Prop_Send, "m_iMaxHealth", 20000);
    }
}

Action Cmd_SafeRoom(int iClient, int iArgs) {
    if (iClient <= 0)                return Plugin_Handled;
    if (!IsClientInGame(iClient))    return Plugin_Handled;
    if (GetClientTeam(iClient) != 2) return Plugin_Handled;
    if (!IsPlayerAlive(iClient))     return Plugin_Handled;
    ReturnPlayerToSaferoom(iClient);
    return Plugin_Handled;
}

Action Cmd_GiveAmmo(int iClient, int iArgs) {
    if (iClient <= 0)                return Plugin_Handled;
    if (!IsClientInGame(iClient))    return Plugin_Handled;
    if (GetClientTeam(iClient) != 2) return Plugin_Handled;
    if (!IsPlayerAlive(iClient))     return Plugin_Handled;
    SDK_AmmoSpawnUse(iClient);
    return Plugin_Handled;
}

Action Cmd_SBStop(int iClient, int iArgs) {
    if (iClient <= 0)             return Plugin_Handled;
    if (!IsClientInGame(iClient)) return Plugin_Handled;

    if (FindConVar("sb_stop").BoolValue) {
        FindConVar("sb_stop").SetBool(false);
        CPrintToChat(iClient, "{green}[{default}Practiceogl{green}] {blue}Survivor Bots Enabled!");
    } else {
        FindConVar("sb_stop").SetBool(true);
        CPrintToChat(iClient, "{green}[{default}Practiceogl{green}] {red}Survivor Bots Disabled!");
    }

    return Plugin_Handled;
}

Action Cmd_Noclip(int iClient, int iArgs) {
    if (iClient <= 0)             return Plugin_Handled;
    if (!IsClientInGame(iClient)) return Plugin_Handled;

    if (GetEntityMoveType(iClient) != MOVETYPE_NOCLIP) {
        SetEntityMoveType(iClient, MOVETYPE_NOCLIP);
        CPrintToChat(iClient, "{green}[{default}Practiceogl{green}] {blue}NoClip Enabled!");
    } else {
        SetEntityMoveType(iClient, MOVETYPE_WALK);
        CPrintToChat(iClient, "{green}[{default}Practiceogl{green}] {red}NoClip Disabled!");
    }

    return Plugin_Handled;
}

stock void ReturnPlayerToSaferoom(int iClient) {
    int iWarpFlags = GetCommandFlags("warp_to_start_area");
    int iGiveFlags = GetCommandFlags("give");
    SetCommandFlags("warp_to_start_area", iWarpFlags & ~FCVAR_CHEAT);
    SetCommandFlags("give",               iGiveFlags & ~FCVAR_CHEAT);
    FakeClientCommand(iClient, "give health");
    FakeClientCommand(iClient, "warp_to_start_area");
    SetCommandFlags("warp_to_start_area", iWarpFlags);
    SetCommandFlags("give",               iGiveFlags);
}

stock int GetZombieClass(int iClient) {
    return GetEntProp(iClient, Prop_Send, "m_zombieClass");
}