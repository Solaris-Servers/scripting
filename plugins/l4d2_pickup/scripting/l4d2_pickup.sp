/*
//-------------------------------------------------------------------------------------------------------------------
// Version 1: Prevents Survivors from picking up Players in the following situations:
//-------------------------------------------------------------------------------------------------------------------
// - Incapped Player is taking Spit Damage.
// - Players doing the pick-up gets hit by the Tank (Punch or Rock)
//
//-------------------------------------------------------------------------------------------------------------------
// Version 1.1: Prevents Survivors from switching from their current item to another without client requesting so:
//-------------------------------------------------------------------------------------------------------------------
// - Player no longer switches to pills when a teammate passes them pills through "M2".
// - Player picks up a Secondary Weapon while not on their Secondary Weapon. (Dual Pistol will force a switch though)
// - Added CVars for Pick-ups/Switching Item
//
//-------------------------------------------------------------------------------------------------------------------
// Version 1.2: Added Client-side Flags so that players can choose whether or not to make use of the Server's flags.
//-------------------------------------------------------------------------------------------------------------------
// - Welp, there's only one change.. so yeah. Enjoy!
//
//-------------------------------------------------------------------------------------------------------------------
// Version 2.0: Added way to detect Dual Pistol pick-up and block so.
//-------------------------------------------------------------------------------------------------------------------
// - Via hacky memory patch.
//
//-------------------------------------------------------------------------------------------------------------------
// Version 3.0: General rework and dualies patch review
//-------------------------------------------------------------------------------------------------------------------
// - Should be perfect now? (hurray)
//
//-------------------------------------------------------------------------------------------------------------------
// Version 4.0: No switch to primary as well
//-------------------------------------------------------------------------------------------------------------------
// - Behave like a modern.
//
//-------------------------------------------------------------------------------------------------------------------
// Version 4.1: Fix some L4D1 issues
//-------------------------------------------------------------------------------------------------------------------
// - Big thanks to "l4d_display_equipment" by Marttt and HarryPotter (@fbef0102) for helping on L4D1.
//
//-------------------------------------------------------------------------------------------------------------------
// Version 4.2: Fix unexpected preference override
//-------------------------------------------------------------------------------------------------------------------
// - Client preference is now saved only when command is used, won't be overridden with default setting ever.
//
//-------------------------------------------------------------------------------------------------------------------
// DONE:
//-------------------------------------------------------------------------------------------------------------------
// - Be a nice guy and less lazy, allow the plugin to work flawlessly with other's peoples needs.. It doesn't require much attention.
// - Find cleaner methods to detect and handle functions.
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <l4d2util>
#include <colors>
#include <dhooks>
#include <sourcescramble>
#include <left4dhooks>
#include <clientprefs>

#define GAMEDATA_FILE    "l4d2_pickup"
#define COOKIE_NAME      "l4d2_pickup_switch_cookie"
#define KEY_FUNCTION     "CTerrorGun::EquipSecondWeapon"
#define KEY_FUNCTION_2   "CTerrorGun::RemoveSecondWeapon"
#define KEY_FUNCTION_3   "CBaseCombatWeapon::SetViewModel"
#define KEY_PATCH_SURFIX "__SkipWeaponDeploy"

#define FLAGS_SWITCH_MELEE    1
#define FLAGS_SWITCH_PILLS    2

#define FLAGS_INCAP_SPIT      1
#define FLAGS_INCAP_TANKPUNCH 2
#define FLAGS_INCAP_TANKROCK  4

#define TEAM_SURVIVOR         2
#define TEAM_INFECTED         3

#define DMG_TYPE_SPIT (DMG_RADIATION|DMG_ENERGYBEAM)

bool g_bCantSwitchDropped  [MAXPLAYERS + 1];
bool g_bCantSwitchGun      [MAXPLAYERS + 1];
bool g_bContinueValveSwitch[MAXPLAYERS + 1];
bool g_bSwitchOnPickup     [MAXPLAYERS + 1];

int  g_iSwitchFlags;
int  g_iIncapFlags;

bool g_bLeft4Dead2;
bool g_bLateLoad;

MemoryPatch g_mPatch;
Cookie      g_cSwitch;

public Plugin myinfo = {
    name        = "[L4D & 2] Pick-up Changes",
    author      = "Sir, Forgetest", // Update syntax A1m`
    description = "Alters a few things regarding picking up/giving items and incapped Players.",
    version     = "4.2",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

void LoadSDK() {
    GameData gmData = new GameData(GAMEDATA_FILE);
    if (gmData == null) SetFailState("Missing gamedata \"" ... GAMEDATA_FILE ..."\"");
    DynamicDetour dDetour = DynamicDetour.FromConf(gmData, KEY_FUNCTION);
    if (!dDetour) SetFailState("Missing detour setup \""...KEY_FUNCTION..."\"");
    if (!dDetour.Enable(Hook_Pre, DTR_OnEquipSecondWeapon))
        SetFailState("Failed to pre-detour \""...KEY_FUNCTION..."\"");
    if (!dDetour.Enable(Hook_Post, DTR_OnEquipSecondWeapon_Post))
        SetFailState("Failed to post-detour \""...KEY_FUNCTION..."\"");
    delete dDetour;

    dDetour = DynamicDetour.FromConf(gmData, KEY_FUNCTION_2);
    if (!dDetour)
        SetFailState("Missing detour setup \""...KEY_FUNCTION_2..."\"");
    if (g_bLeft4Dead2) {
        if (!dDetour.Enable(Hook_Pre, DTR_OnRemoveSecondWeapon_Eb))
            SetFailState("Failed to pre-detour \""...KEY_FUNCTION_2..."\"");
    } else {
        if (!dDetour.Enable(Hook_Pre, DTR_OnRemoveSecondWeapon_Ev))
            SetFailState("Failed to pre-detour \""...KEY_FUNCTION_2..."\"");
    }
    delete dDetour;

    dDetour = DynamicDetour.FromConf(gmData, KEY_FUNCTION_3);
    if (!dDetour)
        SetFailState("Missing detour setup \""...KEY_FUNCTION_3..."\"");
    if (!dDetour.Enable(Hook_Pre, DTR_OnSetViewModel))
        SetFailState("Failed to pre-detour \""...KEY_FUNCTION_3..."\"");
    delete dDetour;

    g_mPatch = MemoryPatch.CreateFromConf(gmData, KEY_FUNCTION...KEY_PATCH_SURFIX);
    if (!g_mPatch.Validate()) SetFailState("Failed to validate memory patch \""...KEY_FUNCTION...KEY_PATCH_SURFIX..."\"");
    delete gmData;
}

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    switch (GetEngineVersion()) {
        case Engine_Left4Dead:  g_bLeft4Dead2 = false;
        case Engine_Left4Dead2: g_bLeft4Dead2 = true;
        default: {
            strcopy(szError, iErrMax, "Plugin supports only Left 4 Dead & 2");
            return APLRes_SilentFailure;
        }
    }
    g_bLateLoad = bLate;
    return APLRes_Success;
}

public void OnPluginStart() {
    LoadSDK();

    ConVar cv = CreateConVar(
    "pickup_switch_flags", "2",
    "Flags for Switching from current item (1:Weapons, 2: Passed Pills)",
    FCVAR_NONE, true, 0.0, true, 3.0);
    SwitchCVarChanged(cv, "", "");
    cv.AddChangeHook(SwitchCVarChanged);

    RegConsoleCmd("sm_secondary", ChangeSecondaryFlags);

    if (g_bLeft4Dead2) {
        cv = CreateConVar(
        "pickup_incap_flags", "2",
        "Flags for Stopping Pick-up progress on Incapped Survivors (1:Spit Damage, 2:TankPunch, 4:TankRock",
        FCVAR_NONE, true, 0.0, true, 7.0);
        IncapCVarChanged(cv, "", "");
        cv.AddChangeHook(IncapCVarChanged);
        HookEvent("player_hurt", Event_PlayerHurt);
    }

    InitSwitchCookie();
    LateLoad();
}

public void OnPluginEnd() {
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i)) continue;
        OnClientDisconnect(i);
    }
}

void LateLoad() {
    if (!g_bLateLoad) return;
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i)) continue;
        OnClientPutInServer(i);
    }
}


/* ---------------------------------
//                                 |
//       Standard Client Stuff     |
//                                 |
// -------------------------------*/
public void OnClientPutInServer(int iClient) {
    HookValidClient(iClient, true);
    if (!QuerySwitchCookie(iClient, g_bSwitchOnPickup[iClient]))
        g_bSwitchOnPickup[iClient] = ((g_iSwitchFlags & FLAGS_SWITCH_MELEE) ? false : true);
}

public void OnClientDisconnect(int iClient) {
    HookValidClient(iClient, false);
}

Action ChangeSecondaryFlags(int iClient, int iArgs) {
    if (iClient && IsClientInGame(iClient)) {
        bool bTemp = !g_bSwitchOnPickup[iClient];
        g_bSwitchOnPickup[iClient] = bTemp;
        SetSwitchCookie(iClient, bTemp);
        CPrintToChat(iClient, "%t", bTemp ? "{blue}[{default}ItemSwitch{blue}] {default}Switch to Weapon on pick-up: {blue}ON" : "{blue}[{default}ItemSwitch{blue}] {default}Switch to Weapon on pick-up: {blue}OFF");
    }
    return Plugin_Handled;
}


/* ---------------------------------
//                                 |
//       Yucky Timer Method~       |
//                                 |
// -------------------------------*/
void DelaySwitchDropped(any iClient) {
    g_bCantSwitchDropped[iClient] = false;
}

void DelaySwitchGun(any iClient) {
    g_bCantSwitchGun[iClient] = false;
}

void DelayValveSwitch(any iClient) {
    g_bContinueValveSwitch[iClient] = false;
}


/* ---------------------------------
//                                 |
//          Incap Pickups          |
//                                 |
// -------------------------------*/
void Event_PlayerHurt(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient   = GetClientOfUserId(eEvent.GetInt("userid"));
    int iAttacker = GetClientOfUserId(eEvent.GetInt("attacker"));

    if (iClient <= 0)             return;
    if (!IsClientInGame(iClient)) return;
    if (iAttacker <= 0)           return;

    char szWeapon[64];
    eEvent.GetString("weapon", szWeapon, sizeof(szWeapon));

    // Spitter damaging player that's being picked up.
    // Read the damage input differently, forcing the pick-up to end with every damage tick. (NOTE: Bots still bypass this)
    if ((g_iIncapFlags & FLAGS_INCAP_SPIT) && L4D_IsPlayerIncapacitated(iClient)) {
        int iType = eEvent.GetInt("type");
        if ((iType & DMG_TYPE_SPIT) == DMG_TYPE_SPIT) {
            if (strcmp(szWeapon, "insect_swarm") == 0) {
                L4D_StopReviveAction(iClient);
            }
        }
    }
    // Tank Rock or Punch.
    else if (IsTank(iAttacker)) {
        if (strcmp(szWeapon, "tank_rock") == 0) {
            if (g_iIncapFlags & FLAGS_INCAP_TANKROCK) {
                L4D_StopReviveAction(iClient);
            }
        } else if (g_iIncapFlags & FLAGS_INCAP_TANKPUNCH) {
            L4D_StopReviveAction(iClient);
        }
    }
}


/* ---------------------------------
//                                 |
//         Weapon Switches         |
//                                 |
// -------------------------------*/
Action SDK_OnWeaponCanSwitchTo(int iClient, int iWeapon) {
    int iWep = IdentifyWeapon(iWeapon);
    if (iWep == WEPID_NONE) return Plugin_Continue;
    int iWepSlot = GetSlotFromWeaponId(iWep);
    if (iWepSlot == -1) return Plugin_Continue;
    // Health Items.
    if ((g_iSwitchFlags & FLAGS_SWITCH_PILLS) && (iWepSlot == L4D2WeaponSlot_LightHealthItem) && g_bCantSwitchDropped[iClient])
        return Plugin_Stop;
    // Weapons.
    if (!g_bSwitchOnPickup[iClient] && (iWepSlot == L4D2WeaponSlot_Primary || iWepSlot == L4D2WeaponSlot_Secondary) && g_bCantSwitchGun[iClient])
        return Plugin_Stop;
    return Plugin_Continue;
}

Action SDK_OnWeaponEquip(int iClient, int iWeapon) {
    // New Weapon
    int iWep = IdentifyWeapon(iWeapon);
    if (iWep == WEPID_NONE) return Plugin_Continue;
    int iSlot = GetSlotFromWeaponId(iWep);
    if (iSlot == -1) return Plugin_Continue;
    // Weapon Currently Using
    int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
    int iActiveWep    = IdentifyWeapon(iActiveWeapon);
    if (iActiveWep == WEPID_NONE) return Plugin_Continue;
    // Also Check if Survivor is incapped to make sure no issues occur (Melee players get given a pistol for example)
    if (!L4D_IsPlayerIncapacitated(iClient) && !g_bContinueValveSwitch[iClient] && iSlot != GetSlotFromWeaponId(iActiveWep)) {
        if (GetDropTarget(iWeapon) == iClient) {
            g_bCantSwitchDropped[iClient] = true;
            RequestFrame(DelaySwitchDropped, iClient);
            return Plugin_Continue;
        }
        g_bCantSwitchGun[iClient] = true;
        RequestFrame(DelaySwitchGun, iClient);
        if (!g_bLeft4Dead2) SDKHook(iClient, SDKHook_PostThinkPost, SDK_OnPostThink_Post);
    }
    return Plugin_Continue;
}

Action SDK_OnWeaponDrop(int iClient, int iWeapon) {
    int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
    // Check if Player is Alive/Incapped and just dropped his secondary for a different one
    if (!L4D_IsPlayerIncapacitated(iClient) && IsPlayerAlive(iClient)) {
        if (iWeapon == iActiveWeapon) {
            g_bContinueValveSwitch[iClient] = true;
            RequestFrame(DelayValveSwitch, iClient);
        }
    }
    return Plugin_Continue;
}


/* ---------------------------------
//                                 |
//       L4D1 Holster Model        |
//                                 |
// -------------------------------*/
// Big thanks to "l4d_display_equipment" by Marttt and HarryPotter (@fbef0102) for helping on L4D1
#define AddonBits_L4D1_Slot1 (1 << 4)
void SDK_OnPostThink_Post(int iClient) {
    if (IsClientInGame(iClient) && GetClientTeam(iClient) == TEAM_SURVIVOR && IsPlayerAlive(iClient)) {
        // Unmark primary addon bit so on next think the game will update
        int iBits = GetEntProp(iClient, Prop_Send, "m_iAddonBits");
        SetEntProp(iClient, Prop_Send, "m_iAddonBits", iBits & ~AddonBits_L4D1_Slot1);
    }
    SDKUnhook(iClient, SDKHook_PostThinkPost, SDK_OnPostThink_Post);
}


/* ---------------------------------
//                                 |
//       Dualies Workaround        |
//                                 |
// -------------------------------*/
bool IsSwitchingToDualCase(int iClient, int iWeapon) {
    if (!IsValidEdict(iWeapon)) return false;
    static char szClsName[64];
    if (!GetEdictClassname(iWeapon, szClsName, sizeof szClsName))
        return false;
    if (szClsName[0] != 'w')
        return false;
    if (strcmp(szClsName[6], "_spawn") == 0) {
        if (GetEntProp(iWeapon, Prop_Send, "m_weaponID") != 1) // WEPID_PISTOL
            return false;
    }
    else if (strncmp(szClsName[6], "_pistol", 7) != 0) {
        return false;
    }
    int iSecondary = GetPlayerWeaponSlot(iClient, 1);
    if (iSecondary == -1) return false;
    if (!GetEdictClassname(iSecondary, szClsName, sizeof szClsName))
        return false;
    return strcmp(szClsName, "weapon_pistol") == 0 && !GetEntProp(iSecondary, Prop_Send, "m_hasDualWeapons");
}

MRESReturn DTR_OnEquipSecondWeapon(int iWeapon, DHookReturn hReturn) {
    int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwner");
    if (iClient == -1 || !IsClientInGame(iClient))
        return MRES_Ignored;
    if (g_bSwitchOnPickup[iClient])
        return MRES_Ignored;
    if (!IsSwitchingToDualCase(iClient, iWeapon))
        return MRES_Ignored;
    g_mPatch.Enable();
    return MRES_Ignored;
}

MRESReturn DTR_OnEquipSecondWeapon_Post(int iWeapon, DHookReturn hReturn) {
    g_mPatch.Disable();
    return MRES_Ignored;
}

// prevent setting viewmodel and next attack time
MRESReturn DTR_OnRemoveSecondWeapon_Ev(int iWeapon, DHookReturn hReturn) {
    if (!GetEntProp(iWeapon, Prop_Send, "m_hasDualWeapons"))
        return MRES_Ignored;
    int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwner");
    if (iClient == -1 || !IsClientInGame(iClient))
        return MRES_Ignored;
    int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
    if (iActiveWeapon == -1 || iActiveWeapon == iWeapon)
        return MRES_Ignored;
    if (g_bSwitchOnPickup[iClient])
        return MRES_Ignored;
    SetEntProp(iWeapon, Prop_Send, "m_isDualWielding", 0);
    SetEntProp(iWeapon, Prop_Send, "m_hasDualWeapons", 0);
    int iClip = GetEntProp(iWeapon, Prop_Send, "m_iClip1");
    SetEntProp(iWeapon, Prop_Send, "m_iClip1", iClip / 2);
    hReturn.Value = 1;
    return MRES_Supercede;
}

MRESReturn DTR_OnRemoveSecondWeapon_Eb(int iWeapon, DHookReturn hReturn, DHookParam hParams) {
    bool bForce = hParams.Get(1);
    if (!bForce) return MRES_Ignored;
    return DTR_OnRemoveSecondWeapon_Ev(iWeapon, hReturn);
}


/* ---------------------------------
//                                 |
//         Skins Workaround        |
//                                 |
// -------------------------------*/
MRESReturn DTR_OnSetViewModel(int iWeapon) {
    int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwner");
    if (iClient == -1)            return MRES_Ignored;
    if (!IsClientInGame(iClient)) return MRES_Ignored;
    if (GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon") == iWeapon)
        return MRES_Ignored;
    return MRES_Supercede;
}


/* ---------------------------------
//                                 |
//          Client Cookie          |
//                                 |
// -------------------------------*/
void InitSwitchCookie() {
    if ((g_cSwitch = Cookie.Find(COOKIE_NAME)) == null)
        g_cSwitch = new Cookie(COOKIE_NAME, "Flags for Switching from current item for every client.", CookieAccess_Public);
}

bool QuerySwitchCookie(int iClient, bool &bVal) {
    char szBuffer[8] = "";
    g_cSwitch.Get(iClient, szBuffer, sizeof(szBuffer));
    int iTemp = 0;
    if (StringToIntEx(szBuffer, iTemp)) {
        bVal = (iTemp == 1 ? true : false);
        return true;
    }
    return false;
}

void SetSwitchCookie(int iClient, bool bVal) {
    char szBuffer[8];
    IntToString(bVal, szBuffer, sizeof(szBuffer));
    g_cSwitch.Set(iClient, szBuffer);
}


/* ---------------------------------
//                                 |
//        Stocks, Functions        |
//                                 |
// -------------------------------*/
void HookValidClient(int iClient, bool bHook) {
    if (bHook) {
        SDKHook(iClient, SDKHook_WeaponCanSwitchTo, SDK_OnWeaponCanSwitchTo);
        SDKHook(iClient, SDKHook_WeaponEquip,       SDK_OnWeaponEquip);
        SDKHook(iClient, SDKHook_WeaponDrop,        SDK_OnWeaponDrop);
    } else {
        SDKUnhook(iClient, SDKHook_WeaponCanSwitchTo, SDK_OnWeaponCanSwitchTo);
        SDKUnhook(iClient, SDKHook_WeaponEquip,       SDK_OnWeaponEquip);
        SDKUnhook(iClient, SDKHook_WeaponDrop,        SDK_OnWeaponDrop);
    }
}

int GetDropTarget(int iWeapon) {
    static int iOffs_m_hDropTarget = -1;
    static int iOffs_m_dropTimer   = -1;
    if (iOffs_m_hDropTarget == -1) {
        iOffs_m_hDropTarget = FindSendPropInfo("CTerrorWeapon", "m_swingTimer") + 576 - view_as<int>(g_bLeft4Dead2) * 4;
        iOffs_m_dropTimer = iOffs_m_hDropTarget + 4;
    }
    if (GetGameTime() >= GetEntDataFloat(iWeapon, iOffs_m_dropTimer + 8))
        return -1;
    return GetEntDataEnt2(iWeapon, iOffs_m_hDropTarget);
}

/* ---------------------------------
//                                 |
//          Cvar Changes!          |
//                                 |
// -------------------------------*/
void SwitchCVarChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iSwitchFlags = cv.IntValue;
}

void IncapCVarChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iIncapFlags = cv.IntValue;
}