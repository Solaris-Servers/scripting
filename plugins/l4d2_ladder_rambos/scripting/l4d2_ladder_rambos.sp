/*
*   Ladder Rambos Dhooks
*   Copyright (C) 2021 $atanic $pirit
*
*   This program is free software: you can redistribute it and/or modify
*   it under the terms of the GNU General Public License as published by
*   the Free Software Foundation, either version 3 of the License, or
*   (at your option) any later version.
*
*   This program is distributed in the hope that it will be useful,
*   but WITHOUT ANY WARRANTY; without even the implied warranty of
*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*   GNU General Public License for more details.
*
*   You should have received a copy of the GNU General Public License
*   along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

/*
// ====================================================================================================
//
// Special thanks to:
//
//  * Ilya 'Visor' Komarov  - Original creator of ladder rambos extension.
//  * Crasher_3637          - For providing the windows signature for CTerrorGun::Holster function.
//  * Lux                   - For providing the windows signature for CBaseShotgun::Reload function.
//  * Silver                - For providing the various signatures, being a very knowledgeable coder and plugin release format. Learned a lot from his work.
//
// ====================================================================================================
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>
#include <sourcescramble>

#define GAMEDATA "l4d2_ladderrambos"

// Setting up ConVar Handles
ConVar g_cvEnabled;
ConVar g_cvM2;
ConVar g_cvReload;
ConVar g_cvSgReload;
ConVar g_cvRecoil;
ConVar g_cvSwitch;

// ConVar Storage
bool g_bEnabled;
bool g_bM2;
bool g_bReload;
bool g_bSgReload;
bool g_bRecoil;
int  g_iSwitch;

// Detour Handles
Handle g_hDetourCanDeployFor;
Handle g_hDetourReload;
Handle g_hDetourShotgunReload;

// Patching from [l4d2_cs_ladders] credit to Lux
#define PLUGIN_NAME_KEY               "[cs_ladders]"
#define TERROR_CAN_DEPLOY_FOR_KEY     "CTerrorWeapon::CanDeployFor__movetype_patch"
#define TERROR_PRE_THINK_KEY          "CTerrorPlayer::PreThink__SafeDropLogic_patch"
#define TERROR_ON_LADDER_MOUNT_KEY    "CTerrorPlayer::OnLadderMount__WeaponHolster_patch"
#define TERROR_ON_LADDER_DISMOUNT_KEY "CTerrorPlayer::OnLadderDismount__WeaponDeploy_patch"

MemoryPatch g_mPatchCanDeployFor;
MemoryPatch g_mPatchPreThink;
MemoryPatch g_mPatchOnLadderMount;
MemoryPatch g_mPatchOnLadderDismount;

// Block shotgun reload
Handle g_hSDKCallAbortReload;
Handle g_hSDKCallPlayReloadAnim;

// Block empty-clip gun being pulled out
Handle g_hSDKCallHolster;

// Temp storage for shove time
float g_fSavedShoveTime[MAXPLAYERS + 1];

// Temp storage for block unwanted deploy
bool g_bLadderMounted[MAXPLAYERS + 1];
bool g_bBlockDeploy[MAXPLAYERS + 1];

// ====================================================================================================
// myinfo - Basic plugin information
// ====================================================================================================
public Plugin myinfo = {
    name        = "Ladder Rambos Dhooks [Merged]",
    author      = "$atanic $pirit, Lux, Forgetest",
    description = "Allows players to shoot from Ladders",
    version     = "4.2",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

// ====================================================================================================
// OnPluginStart - Setting CVARS and Configuring Hooks
// ====================================================================================================
public void OnPluginStart() {
    // Setup plugin ConVars
    g_cvEnabled = CreateConVar(
    "cssladders_enabled", "1",
    "Enable the Survivors to shoot from ladders? 1 = enable, 0 = disable.",
    FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0, true, 1.0);
    g_cvEnabled.AddChangeHook(OnEnableDisable);

    g_cvM2 = CreateConVar(
    "cssladders_allow_m2", "0",
    "Allow shoving whilst on a ladder? 1 = allow, 0 = block.",
    FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0, true, 1.0);
    g_cvM2.AddChangeHook(OnConVarChanged);

    g_cvReload = CreateConVar(
    "cssladders_allow_reload", "1",
    "Allow reloading whilst on a ladder? 1 = allow, 0 = block.",
    FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0, true, 1.0);
    g_cvReload.AddChangeHook(OnConVarChanged);

    g_cvSgReload = CreateConVar(
    "cssladders_allow_shotgun_reload", "0",
    "Allow shotgun reloading whilst on a ladder? 1 = allow, 0 = block.",
    FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0, true, 1.0);
    g_cvSgReload.AddChangeHook(OnConVarChanged);

    g_cvSwitch = CreateConVar(
    "cssladders_allow_switch", "0",
    "Allow switching to other inventory whilst on a ladder? 2 = allow all, 1 = allow only between guns, 0 = block.",
    FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0, true, 2.0);
    g_cvSwitch.AddChangeHook(OnConVarChanged);

    g_cvRecoil = CreateConVar(
    "cssladders_reduce_recoil", "0",
    "Allow reducing recoil whilst shooting on a ladder? 1 = allow, 0 = block.",
    FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0, true, 1.0);
    g_cvRecoil.AddChangeHook(OnConVarChanged);

    // ConVar Storage
    GetCvars();

    // Load the GameData file.
    GameData gmData = new GameData(GAMEDATA);
    if (gmData == null) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);
    SetupDetours(gmData);
    SetupSDKCalls(gmData);
    SetupMemPatches(gmData);
    delete gmData;

    // And a pre hook for CTerrorWeapon::CanDeployFor.
    if (!DHookEnableDetour(g_hDetourCanDeployFor, false, Detour_CanDeployFor))
        SetFailState("Failed to detour CTerrorWeapon::CanDeployFor.");
    // And a pre hook for CTerrorGun::Reload.
    if (!DHookEnableDetour(g_hDetourReload, false, Detour_Reload))
        SetFailState("Failed to detour CTerrorGun::Reload.");
    // And a pre hook for CBaseShotgun::Reload.
    if (!DHookEnableDetour(g_hDetourShotgunReload, false, Detour_ShotgunReload))
        SetFailState("Failed to detour CBaseShotgun::Reload.");
    // Apply our patch
    ApplyPatch((g_bEnabled = g_cvEnabled.BoolValue));
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

// ====================================================================================================
// OnPluginEnd - Remove our SafeDropPatch to avoid crashes
// ====================================================================================================
public void OnPluginEnd() {
    // Remove our patch
    ApplyPatch(false);
}

// ====================================================================================================
// OnConfigExecuted - Patch or unpatch
// ====================================================================================================
public void OnConfigsExecuted() {
    ApplyPatch(g_bEnabled);
}

// ====================================================================================================
// OnEnableDisable - Patch or unpatch
// ====================================================================================================
public void OnEnableDisable(ConVar cv, const char[] szOldValue, const char[] szNewValue) {
    ApplyPatch((g_bEnabled = g_cvEnabled.BoolValue));
}

// ====================================================================================================
// OnConVarChanged - Refresh ConVar storage
// ====================================================================================================
public void OnConVarChanged(ConVar cv, const char[] szOldValue, const char[] szNewValue) {
    GetCvars();
}

// ====================================================================================================
// GetCvars - Cache the values of ConVars to improve performance
// ====================================================================================================
void GetCvars() {
    g_bM2       = g_cvM2.BoolValue;
    g_bReload   = g_cvReload.BoolValue;
    g_bSgReload = g_cvSgReload.BoolValue;
    g_iSwitch   = g_cvSwitch.IntValue;
    g_bRecoil   = g_cvRecoil.BoolValue;
}

// ====================================================================================================
// OnClientPutInServer - Reset temp values
// ====================================================================================================
public void OnClientPutInServer(int iClient) {
    g_fSavedShoveTime[iClient] = 0.0;
    g_bLadderMounted [iClient] = false;
    g_bBlockDeploy   [iClient] = false;
}

// ====================================================================================================
// Event_RoundStart - Reset temp values
// ====================================================================================================
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
    for (int i = 1; i <= MaxClients; i++) {
        g_fSavedShoveTime[i] = 0.0;
        g_bLadderMounted [i] = false;
        g_bBlockDeploy   [i] = false;
    }
}

// ====================================================================================================
// Detour_CanDeployFor - Constantly called to check if player can pull out a weapon
// ====================================================================================================
public MRESReturn Detour_CanDeployFor(int pThis, Handle hReturn) {
    if (!g_bEnabled)
        return MRES_Ignored;
    int iClient = GetEntPropEnt(pThis, Prop_Send, "m_hOwner");
    if (iClient == -1 || !IsClientInGame(iClient))
        return MRES_Ignored;
    int  iFlags = GetEntityFlags(iClient);
    bool bIsOnLadder = GetEntityMoveType(iClient) == MOVETYPE_LADDER;
    if (!bIsOnLadder) {
        if (g_fSavedShoveTime[iClient] > 0.0) {
            SetEntPropFloat(iClient, Prop_Send, "m_flNextShoveTime", g_fSavedShoveTime[iClient]);
            g_fSavedShoveTime[iClient] = 0.0;
        }
        if (g_bLadderMounted[iClient]) g_bLadderMounted[iClient] = false;
        if (g_bBlockDeploy[iClient])   g_bBlockDeploy  [iClient] = false;
        if ((iFlags & FL_ONGROUND) && GetEntPropEnt(iClient, Prop_Send, "m_hGroundEntity") == -1)
            SetEntityFlags(iClient, iFlags & ~FL_ONGROUND);
        return MRES_Ignored;
    }
    // Infected triggers this though, will be blocked
    if (GetClientTeam(iClient) != 2) {
        DHookSetReturn(hReturn, 0);
        return MRES_Supercede;
    }
    if (g_bBlockDeploy[iClient]) {
        DHookSetReturn(hReturn, 0);
        return MRES_Supercede;
    }
    bool bFirstTimeOfMount = !g_bLadderMounted[iClient];
    if (bFirstTimeOfMount) g_bLadderMounted[iClient] = true;
    // v2.4: Forgot melees, block them
    // v2.5: Forgot other inventories :(
    // v4.2: Fixed carry items getting thrown out if switch == 1
    if (g_iSwitch < 2 && (Weapon_IsCarryItem(pThis) || Weapon_IsMelee(pThis) || !Weapon_IsGun(pThis))) {
        // Mimic how original ladder rambos performs
        if (bFirstTimeOfMount) g_bBlockDeploy[iClient] = true;
        DHookSetReturn(hReturn, 0);
        return MRES_Supercede;
    }

    int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
    if (iWeapon != pThis && g_iSwitch < 1) {
        DHookSetReturn(hReturn, 0);
        return MRES_Supercede;
    }
    if (!g_bM2) {
        if (g_fSavedShoveTime[iClient] == 0.0)
            g_fSavedShoveTime[iClient] = GetEntPropFloat(iClient, Prop_Send, "m_flNextShoveTime");
        SetEntPropFloat(iClient, Prop_Send, "m_flNextShoveTime", GetGameTime() + 0.2);
    }
    bool bIsShotgun = Weapon_IsShotgun(pThis);
    if (bIsShotgun ? (!g_bSgReload) : (!g_bReload)) {
        if (GetEntProp(pThis, Prop_Send, "m_bInReload")) {
            Weapon_AbortReload(pThis);
            // 1418 = L4D2_ACT_VM_RELOAD_END    (see left4dhooks_anim.inc)
            //    6 = ANIM_RELOAD_SHOTGUN_FINAL (see l4d2util_constants.inc)
            if (bIsShotgun)
                Shotgun_PlayReloadAnim(pThis, 1418, 6);
        }
        if (GetEntProp(pThis, Prop_Send, "m_iClip1") == 0) {
            // TODO: Weapon clip empty check.
            int iSecondary = GetPlayerWeaponSlot(iClient, 1);
            if (g_iSwitch == 0 || (g_iSwitch == 1 && (iSecondary == -1 || Weapon_IsMelee(iSecondary)))) {
                // Mimic how original ladder rambos performs
                Weapon_Holster(pThis);
                DHookSetReturn(hReturn, 0);
                return MRES_Supercede;
            }
        }
    }
    if (g_bRecoil && (~iFlags & FL_ONGROUND)) SetEntityFlags(iClient, iFlags | FL_ONGROUND);
    return MRES_Ignored;
}

// ====================================================================================================
// Detour_Reload - Block reload based on ConVar
// ====================================================================================================
public MRESReturn Detour_Reload(int pThis, Handle hReturn) {
    int  iClient     = GetEntPropEnt(pThis, Prop_Send, "m_hOwner");
    bool bIsOnLadder = GetEntityMoveType(iClient) == MOVETYPE_LADDER;
    if (bIsOnLadder && !g_bReload)
        return MRES_Supercede;
    return MRES_Ignored;
}

// ====================================================================================================
// Detour_ShotgunReload - Block reload based on ConVar
// ====================================================================================================
public MRESReturn Detour_ShotgunReload(int pThis, Handle hReturn) {
    int iClient = GetEntPropEnt(pThis, Prop_Send, "m_hOwner");
    if (GetEntityMoveType(iClient) == MOVETYPE_LADDER && !g_bSgReload)
        return MRES_Supercede;
    return MRES_Ignored;
}

// ====================================================================================================
// Weapon_IsCarryItem - Stock method to check if weapon is carried item
// ====================================================================================================
bool Weapon_IsCarryItem(int iWeapon) {
    static StringMap CarryItemsTrie = null;
    if (CarryItemsTrie == null) {
        CarryItemsTrie = new StringMap();
        CarryItemsTrie.SetValue("weapon_gascan",        1);
        CarryItemsTrie.SetValue("weapon_propanetank",   1);
        CarryItemsTrie.SetValue("weapon_oxygentank",    1);
        CarryItemsTrie.SetValue("weapon_fireworkcrate", 1);
        CarryItemsTrie.SetValue("weapon_gnome",         1);
        CarryItemsTrie.SetValue("weapon_cola_bottles",  1);
    }
    static char szClassName[64];
    if (GetEdictClassname(iWeapon, szClassName, sizeof(szClassName)))
        return CarryItemsTrie.GetValue(szClassName, iWeapon);
    return false;
}

// ====================================================================================================
// Weapon_IsMelee - Stock method to check if weapon is melee
// ====================================================================================================
bool Weapon_IsMelee(int iWeapon) {
    return HasEntProp(iWeapon, Prop_Send, "m_bInMeleeSwing") || HasEntProp(iWeapon, Prop_Send, "m_bHitting");
}

// ====================================================================================================
// Weapon_IsGun - Stock method to check if weapon is gun
// ====================================================================================================
bool Weapon_IsGun(int iWeapon) {
    return HasEntProp(iWeapon, Prop_Send, "m_isDualWielding");
}

// ====================================================================================================
// Weapon_IsShotgun - Stock method to check if weapon is shotgun
// ====================================================================================================
bool Weapon_IsShotgun(int iWeapon) {
    return HasEntProp(iWeapon, Prop_Send, "m_reloadNumShells");
}

// ====================================================================================================
// Shotgun_PlayReloadAnim - SDKCall to play specific shotgun reload animation
// ====================================================================================================
void Shotgun_PlayReloadAnim(int iWeapon, int iActivity, int iEvent) {
    SDKCall(g_hSDKCallPlayReloadAnim, iWeapon, iActivity, iEvent, 0);
}

// ====================================================================================================
// Weapon_AbortReload - SDKCall to abort weapon reload
// ====================================================================================================
void Weapon_AbortReload(int iWeapon) {
    SDKCall(g_hSDKCallAbortReload, iWeapon);
}

// ====================================================================================================
// Weapon_Holster - SDKCall to stop pulling out weapon
// ====================================================================================================
void Weapon_Holster(int iWeapon) {
    SDKCall(g_hSDKCallHolster, iWeapon, 0);
}

// ====================================================================================================
// Setup* - Setup everything
// ====================================================================================================
void SetupDetours(GameData gmData) {
    // Get signature for CanDeployFor.
    g_hDetourCanDeployFor = DHookCreateFromConf(gmData, "CTerrorWeapon::CanDeployFor");
    if (!g_hDetourCanDeployFor) SetFailState("Failed to setup detour for \"CBaseShotgun::Reload\"");
    // Get signature for reload weapon.
    g_hDetourReload = DHookCreateFromConf(gmData, "CTerrorGun::Reload");
    if (!g_hDetourReload) SetFailState("Failed to setup detour for \"CBaseShotgun::Reload\"");
    // Get signature for reload shotgun specific
    g_hDetourShotgunReload = DHookCreateFromConf(gmData, "CBaseShotgun::Reload");
    if (!g_hDetourShotgunReload) SetFailState("Failed to setup detour for \"CBaseShotgun::Reload\"");
}

void SetupSDKCalls(GameData gmData) {
    StartPrepSDKCall(SDKCall_Entity);
    if (!PrepSDKCall_SetFromConf(gmData, SDKConf_Virtual, "CBaseCombatWeapon::AbortReload")) {
        SetFailState("Failed to find offset \"CBaseCombatWeapon::AbortReload\"");
    } else {
        g_hSDKCallAbortReload = EndPrepSDKCall();
        if (g_hSDKCallAbortReload == null)
            SetFailState("Failed to setup SDKCall \"CBaseCombatWeapon::AbortReload\"");
    }
    StartPrepSDKCall(SDKCall_Entity);
    if (!PrepSDKCall_SetFromConf(gmData, SDKConf_Signature, "CBaseShotgun::PlayReloadAnim")) {
        SetFailState("Failed to find offset \"CBaseShotgun::PlayReloadAnim\"");
    } else {
        PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
        PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
        PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
        g_hSDKCallPlayReloadAnim = EndPrepSDKCall();
        if (g_hSDKCallPlayReloadAnim == null)
            SetFailState("Failed to setup SDKCall \"CBaseShotgun::PlayReloadAnim\"");
    }
    StartPrepSDKCall(SDKCall_Entity);
    if (!PrepSDKCall_SetFromConf(gmData, SDKConf_Virtual, "CBaseCombatWeapon::Holster")) {
        SetFailState("Failed to find offset \"CBaseCombatWeapon::Holster\"");
    } else {
        PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_ByValue);
        g_hSDKCallHolster = EndPrepSDKCall();
        if (g_hSDKCallHolster == null)
            SetFailState("Failed to setup SDKCall \"CBaseCombatWeapon::Holster\"");
    }
}

void SetupMemPatches(GameData gmData) {
    g_mPatchCanDeployFor = MemoryPatch.CreateFromConf(gmData, TERROR_CAN_DEPLOY_FOR_KEY);
    if (!g_mPatchCanDeployFor.Validate()) SetFailState("%s Failed to validate patch \"%s\"", PLUGIN_NAME_KEY, TERROR_CAN_DEPLOY_FOR_KEY);
    g_mPatchPreThink = MemoryPatch.CreateFromConf(gmData, TERROR_PRE_THINK_KEY);
    if (!g_mPatchPreThink.Validate()) SetFailState("%s Failed to validate patch \"%s\"", PLUGIN_NAME_KEY, TERROR_PRE_THINK_KEY);
    // not as important as first 2 patches, can still function enough to be good enough.
    g_mPatchOnLadderMount = MemoryPatch.CreateFromConf(gmData, TERROR_ON_LADDER_MOUNT_KEY);
    if (!g_mPatchOnLadderMount.Validate()) LogError("%s Failed to validate patch \"%s\"", PLUGIN_NAME_KEY, TERROR_ON_LADDER_MOUNT_KEY);
    g_mPatchOnLadderDismount = MemoryPatch.CreateFromConf(gmData, TERROR_ON_LADDER_DISMOUNT_KEY);
    if (!g_mPatchOnLadderDismount.Validate()) LogError("%s Failed to validate patch \"%s\"", PLUGIN_NAME_KEY, TERROR_ON_LADDER_DISMOUNT_KEY);
}

// ====================================================================================================
// SafeDropPatch - Patching/UnPatching the memory
// ====================================================================================================
stock void ApplyPatch(bool bPatch) {
    static bool bPatched = false;
    if (bPatch && !bPatched) {
        if (g_mPatchCanDeployFor.Enable())
            PrintToServer("%s Enabled \"%s\" patch", PLUGIN_NAME_KEY, TERROR_CAN_DEPLOY_FOR_KEY);
        if (g_mPatchPreThink.Enable())
            PrintToServer("%s Enabled \"%s\" patch", PLUGIN_NAME_KEY, TERROR_PRE_THINK_KEY);
        if (g_mPatchOnLadderMount.Enable())
            PrintToServer("%s Enabled \"%s\" patch", PLUGIN_NAME_KEY, TERROR_ON_LADDER_MOUNT_KEY);
        if (g_mPatchOnLadderDismount.Enable())
            PrintToServer("%s Enabled \"%s\" patch", PLUGIN_NAME_KEY, TERROR_ON_LADDER_DISMOUNT_KEY);
        bPatched = true;
    } else if (!bPatch && bPatched) {
        g_mPatchCanDeployFor.Disable();
        g_mPatchPreThink.Disable();
        g_mPatchOnLadderMount.Disable();
        g_mPatchOnLadderDismount.Disable();
        bPatched = false;
    }
}