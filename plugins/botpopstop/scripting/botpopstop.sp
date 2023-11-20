#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define WP_PAIN_PILLS 15
#define WP_ADRENALINE 23

#define PILL_INDEX    0
#define ADREN_INDEX   1

int g_iBotUsedCount[2][MAXPLAYERS + 1];

public Plugin myinfo = {
    name        = "Simplified Bot Pop Stop",
    author      = "Stabby & CanadaRox",
    description = "Removes pills from bots if they try to use them and restores them when a human takes over.",
    version     = "1.3",
    url         = "no url"
}

public void OnPluginStart() {
    HookEvent("weapon_fire",        Event_WeaponFire);
    HookEvent("bot_player_replace", Event_PlayerJoined);
    HookEvent("round_start",        Event_RoundStart, EventHookMode_PostNoCopy);
}

// Take pills from the bot before they get used
void Event_WeaponFire(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient   = GetClientOfUserId(eEvent.GetInt("userid"));
    int iWeaponId = eEvent.GetInt("weaponid");
    if (!IsFakeClient(iClient)) return;
    if (iWeaponId == WP_PAIN_PILLS) {
        g_iBotUsedCount[PILL_INDEX][iClient]++;
        RemovePlayerItem(iClient, GetPlayerWeaponSlot(iClient, 4));
    } else if (iWeaponId == WP_ADRENALINE) {
        g_iBotUsedCount[ADREN_INDEX][iClient]++;
        RemovePlayerItem(iClient, GetPlayerWeaponSlot(iClient, 4));
    }
}

// Give the human player the pills back when they join
void Event_PlayerJoined(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iBot = GetClientOfUserId(eEvent.GetInt("bot"));
    if (g_iBotUsedCount[PILL_INDEX][iBot] > 0 || g_iBotUsedCount[ADREN_INDEX][iBot] > 0) {
        RestoreItems(GetClientOfUserId(eEvent.GetInt("player")), iBot);
        g_iBotUsedCount[PILL_INDEX] [iBot] = 0;
        g_iBotUsedCount[ADREN_INDEX][iBot] = 0;
    }
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    for (int i = 1; i <= MaxClients; i++) {
        for (int e = 0; e < 2; e++) {
            g_iBotUsedCount[e][i] = 0;
        }
    }
}

void RestoreItems(int iClient, int iBot) {
    int iCurrentWeapon = GetPlayerWeaponSlot(iClient, 4);
    for (int i = 0; i < 2; i++) {
        for (int j = g_iBotUsedCount[i][iBot]; j > 0; j--) {
            if (iCurrentWeapon == -1) GivePlayerItem(iClient, i == PILL_INDEX ? "weapon_pain_pills" : "weapon_adrenaline");
        }
    }
}