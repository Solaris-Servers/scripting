#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <sourcescramble>
#include <solaris/stocks>

#define GAMEDATA_FILE "scavenge_no_starting_items"
#define PATCH_KEY     "CTerrorPlayer_GiveDefaultItem"

#define FLAGS_NONE           (0)
#define FALGS_PILLS          (1 << 0)
#define FLAGS_MEDKITS        (1 << 1)

bool        g_bSpawn = true;
ConVar      g_cvLootFlags;
int         g_iLootFlags;
MemoryPatch g_mPatch;

public void OnPluginStart() {
    GameData gmData = new GameData(GAMEDATA_FILE);
    if (gmData == null) SetFailState("Missing gamedata \"" ... GAMEDATA_FILE ... "\"");
    g_mPatch = MemoryPatch.CreateFromConf(gmData, PATCH_KEY);
    if (g_mPatch == null)     SetFailState("Failed to create MemoryPatch \"" ... PATCH_KEY ..."\"");
    if (!g_mPatch.Validate()) SetFailState("Failed to validate MemoryPatch \"" ... PATCH_KEY ..."\"");
    ApplyPatch(true);

    g_cvLootFlags = CreateConVar(
    "scavenge_loot_flags", "3",
    "Item flags to give on spawning  (0:Off, 1:Pills, 2:Medkit, 3:Pills and Medkit)",
    FCVAR_NONE, true, 0.0, true, 3.0);
    g_iLootFlags = g_cvLootFlags.IntValue;
    g_cvLootFlags.AddChangeHook(OnConVarChanged);

    HookEvent("player_spawn",         Event_PlayerSpawn);
    HookEvent("scavenge_round_start", Event_ScavengeRoundStart);
    HookEvent("round_end",            Event_RoundEnd);
}

public void OnPluginEnd() {
    ApplyPatch(false);
}

void OnConVarChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iLootFlags = g_cvLootFlags.IntValue;
}

public void OnMapStart() {
    g_bSpawn = true;
}

void Event_PlayerSpawn(Event eEvent, char[] szName, bool bDontBroadcast) {
    if (g_iLootFlags == FLAGS_NONE) return;
    if (!SDK_IsScavenge())          return;

    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)                return;
    if (!IsClientInGame(iClient))    return;
    if (GetClientTeam(iClient) != 2) return;
    if (!g_bSpawn)                   return;

    CreateTimer(1.2, GiveItems, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
}

Action GiveItems(Handle hTimer, any iUserId) {
    int iClient = GetClientOfUserId(iUserId);
    if (iClient <= 0)                return Plugin_Stop;
    if (!IsClientInGame(iClient))    return Plugin_Stop;
    if (GetClientTeam(iClient) != 2) return Plugin_Stop;
    if (!g_bSpawn)                   return Plugin_Stop;

    int iKit   = GetPlayerWeaponSlot(iClient, 3);
    int iPills = GetPlayerWeaponSlot(iClient, 4);
    if (g_iLootFlags & FLAGS_MEDKITS && iKit   == -1) GivePlayerItem(iClient, "weapon_first_aid_kit");
    if (g_iLootFlags & FALGS_PILLS   && iPills == -1) GivePlayerItem(iClient, "weapon_pain_pills");

    return Plugin_Stop;
}

void Event_ScavengeRoundStart(Event eEvent, char[] szName, bool bDontBroadcast) {
    g_bSpawn = false;
}

void Event_RoundEnd(Event eEvent, char[] szName, bool bDontBroadcast) {
    g_bSpawn = true;
}

void ApplyPatch(bool bPatch) {
    static bool bPatched = false;
    if (bPatch && !bPatched) {
        if (!g_mPatch.Enable())
            SetFailState("Failed to enable MemoryPatch \"" ... PATCH_KEY ..."\"");
        bPatched = true;
    } else if (!bPatch && bPatched) {
        g_mPatch.Disable();
        bPatched = false;
    }
}