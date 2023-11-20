#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <l4d2util>

ConVar g_cvReplaceMagnum;
bool   g_bHasDeagle[MAXPLAYERS + 1];

public Plugin myinfo = {
    name        = "Magnum incap remover",
    author      = "robex, Sir",
    description = "Replace magnum with regular pistols when incapped.",
    version     = "0.4",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart() {
    g_cvReplaceMagnum = CreateConVar(
    "l4d2_replace_magnum_incap", "1.0",
    "0 = Disable, 1 = Replace magnum with single when incapacitated, 2 = Replace magnum with double pistols when incapacitated.",
    FCVAR_NONE, true, 0.0, true, 2.0);

    HookEvent("round_start",          Event_RoundStart);
    HookEvent("bot_player_replace",   Event_BotPlayerReplace);
    HookEvent("player_bot_replace",   Event_PlayerBotReplace);
    HookEvent("player_incapacitated", Event_PlayerIncap);
    HookEvent("revive_success",       Event_ReviveSuccess);
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    for (int i = 0; i <= MaxClients; i++) {
        g_bHasDeagle[i] = false;
    }
}

void Event_BotPlayerReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    HandlePlayerReplace(GetClientOfUserId(eEvent.GetInt("player")), GetClientOfUserId(eEvent.GetInt("bot")));
}

void Event_PlayerBotReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    HandlePlayerReplace(GetClientOfUserId(eEvent.GetInt("bot")), GetClientOfUserId(eEvent.GetInt("player")));
}

void HandlePlayerReplace(int iReplacer, int iReplacee) {
    g_bHasDeagle[iReplacer] = g_bHasDeagle[iReplacee];
    g_bHasDeagle[iReplacee] = false;
}

void Event_PlayerIncap(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!g_cvReplaceMagnum.BoolValue)
        return;

    int iClient    = GetClientOfUserId(eEvent.GetInt("userid"));
    int iWeaponIdx = GetPlayerWeaponSlot(iClient, L4D2WeaponSlot_Secondary);

    int iWeapId = IdentifyWeapon(iWeaponIdx);
    if (iWeapId == WEPID_PISTOL_MAGNUM) {
        RemovePlayerItem(iClient, iWeaponIdx);
        RemoveEntity(iWeaponIdx);

        GivePlayerItem(iClient, "weapon_pistol");
        if (g_cvReplaceMagnum.IntValue == 2)
            GivePlayerItem(iClient, "weapon_pistol");

        g_bHasDeagle[iClient] = true;
        return;
    }

    g_bHasDeagle[iClient] = false;
}

void Event_ReviveSuccess(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!g_cvReplaceMagnum.BoolValue)
        return;

    int iClient = GetClientOfUserId(eEvent.GetInt("subject"));
    if (g_bHasDeagle[iClient]) {
        int iWeaponIdx = GetPlayerWeaponSlot(iClient, L4D2WeaponSlot_Secondary);

        RemovePlayerItem(iClient, iWeaponIdx);
        RemoveEntity(iWeaponIdx);

        GivePlayerItem(iClient, "weapon_pistol_magnum");
        g_bHasDeagle[iClient] = false;
    }
}