#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include <dhooks>

// Fixed issues:
// - It's possible to get a second melee from same spawner with empty counter before it is removed from the game (same should work with other spawners)

#define GAMEDATA_FILE "weapon_spawn_duplicate_fix"

Handle     g_hCWeaponSpawn_GiveItem;
ArrayStack g_hItems;

public Plugin myinfo = {
    name        = "[L4D2] Weapon Duplicate Fix",
    author      = "shqke",
    description = "Prevents a weapon to be taken from weapon spawn if its item counter has hit a zero",
    version     = "1.1",
    url         = "https://github.com/shqke/sp_public"
};

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    if (GetEngineVersion() == Engine_Left4Dead2)
        return APLRes_Success;
    strcopy(szError, iErrMax, "Plugin only supports Left 4 Dead 2.");
    return APLRes_SilentFailure;
}

public void OnPluginStart() {
    LoadGameConfigOrFail();
    g_hItems = new ArrayStack();
    int iEntity = INVALID_ENT_REFERENCE;
    while ((iEntity = FindEntityByClassname(iEntity, "weapon_*")) != INVALID_ENT_REFERENCE) {
        CheckClassAndHook(iEntity);
    }
}

void LoadGameConfigOrFail() {
    GameData gmData = new GameData(GAMEDATA_FILE);
    if (gmData == null) SetFailState("Failed to load gamedata file \"%s.txt\"", GAMEDATA_FILE);
    int iOffset = gmData.GetOffset("CWeaponSpawn::GiveItem");
    delete gmData;
    if (iOffset == -1) SetFailState("Unable to get offset for \"CWeaponSpawn::GiveItem\" from game config (file: \"%s.txt\")", GAMEDATA_FILE);
    g_hCWeaponSpawn_GiveItem = DHookCreate(iOffset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity, Handler_CWeaponSpawn_GiveItem);
    if (g_hCWeaponSpawn_GiveItem == null) SetFailState("Unable to hook \"CWeaponSpawn::GiveItem\" (given offset: %d)", iOffset);
    DHookAddParam(g_hCWeaponSpawn_GiveItem, HookParamType_CBaseEntity);
    DHookAddParam(g_hCWeaponSpawn_GiveItem, HookParamType_Int);
}

public MRESReturn Handler_CWeaponSpawn_GiveItem(int iSpawner, Handle hReturn) {
    if (GetEntProp(iSpawner, Prop_Data, "m_itemCount") == 0) {
        DHookSetReturn(hReturn, false);
        return MRES_Supercede;
    }
    return MRES_Ignored;
}

void CheckClassAndHook(int iEntity) {
    char szClassName[64];
    if (!GetEntityNetClass(iEntity, szClassName, sizeof(szClassName)))
        return;
    if (strcmp(szClassName, "CWeaponSpawn") != 0)
        return;
    // Remember to unhook later
    g_hItems.Push(DHookEntity(g_hCWeaponSpawn_GiveItem, false, iEntity));
}

public void OnEntityCreated(int iEntity, const char[] szClassName) {
    if (strncmp(szClassName, "weapon_", 7, false) != 0)
        return;
    CheckClassAndHook(iEntity);
}

public void OnMapEnd() {
    // Unhook entities
    while (!g_hItems.Empty) {
        DHookRemoveHookID(g_hItems.Pop());
    }
}