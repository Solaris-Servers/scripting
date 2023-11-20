#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <readyup>
#define REQUIRE_PLUGIN

#define MAX_ITEM_STRING_LEN 64

ConVar g_cvItemList;
bool   g_bRounIsLive;

public Plugin myinfo = {
    name        = "Starting Items",
    author      = "CircleSquared, Jacob, A1m`, Forgetest",
    description = "Gives health items and throwables to survivors at the start of each round",
    version     = "3.1.1",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

public void OnPluginStart() {
    g_cvItemList = CreateConVar(
    "starting_item_list", "health,pain_pills,first_aid_kit,smg_silenced,katana", "Item names to give on leaving the saferoom (via \"give\" command, separated by \",\"",
    FCVAR_NONE, false, 0.0, false, 0.0);
    HookEvent("round_start",           Event_RoundStart,         EventHookMode_PostNoCopy);
    HookEvent("player_left_safe_area", Event_PlayerLeftSafeArea, EventHookMode_PostNoCopy);
}

public void OnRoundIsLive() {
    if (g_bRounIsLive) return;
    g_bRounIsLive = true;
    DetermineItems();
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bRounIsLive = false;
}

void Event_PlayerLeftSafeArea(Event eEvent, const char[] szName, bool bDontBroadcast) {
    OnRoundIsLive();
}

void DetermineItems() {
    char szItemString[256];
    g_cvItemList.GetString(szItemString, sizeof(szItemString));
    int iLength = strlen(szItemString);
    if (iLength + 1 > sizeof(szItemString)) { // overflow
        g_cvItemList.GetName(szItemString, sizeof(szItemString));
        ThrowError("Could not hold value of \"%s\" because it's too long.", szItemString);
    }
    szItemString[iLength] = ','; // take care of remainder
    szItemString[iLength + 1] = '\0';
    char szBuffer[MAX_ITEM_STRING_LEN];
    ArrayList arrItemString = new ArrayList(ByteCountToCells(MAX_ITEM_STRING_LEN));
    for (int i = 0, j = 0; (j = FindCharInString(szItemString[i], ',') + 1) != 0; i += j) {
        // overflow
        if (j > sizeof(szBuffer)) ThrowError("Could not hold value of \"%s\" containing invalid string.", szItemString);
        strcopy(szBuffer, j/* C strncpy */, szItemString[i]);
        szBuffer[j] = '\0';
        arrItemString.PushString(szBuffer);
    }
    GiveStartingItems(arrItemString);
    delete arrItemString;
}

void GiveStartingItems(ArrayList arrItemString) {
    int iMaxLength = arrItemString.BlockSize;
    char[] szBuffer = new char[iMaxLength];
    int iSize = arrItemString.Length;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i)) {
            for (int j = 0; j < iSize; j++) {
                arrItemString.GetString(j, szBuffer, iMaxLength);
                GivePlayerWeaponByName(i, szBuffer);
            }
        }
    }
}

void GivePlayerWeaponByName(int iClient, const char[] szWeaponName) {
    // NOTE:
    // Campaigns have customized supported melees configured by "meleeweapons",
    // if trying to give unsupported melees, they won't spawn.
    // Fixed only in the latest version of sourcemod 1.11
    if (GivePlayerItem(iClient, szWeaponName) == -1) LogMessage("Attempt to give invalid item (%s)", szWeaponName);
}