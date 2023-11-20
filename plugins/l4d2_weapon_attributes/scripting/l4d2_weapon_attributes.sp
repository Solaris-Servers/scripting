#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <left4dhooks>
#include <dhooks>
#include <colors>

#define GAMEDATA_FILE               "l4d2_weapon_attributes"

#define TEAM_INFECTED               3
#define TANK_ZOMBIE_CLASS           8

#define INT_WEAPON_MAX_ATTRS        sizeof(iIntWeaponAttributes)
#define FLOAT_WEAPON_MAX_ATTRS      sizeof(iFloatWeaponAttributes)

#define GAME_WEAPON_MAX_ATTRS       (INT_WEAPON_MAX_ATTRS + FLOAT_WEAPON_MAX_ATTRS)
#define PLUGIN_WEAPON_MAX_ATTRS     (GAME_WEAPON_MAX_ATTRS + 2) // Including: tankdamagemult(Tank damage multiplier), reloaddurationmult(Reload duration multiplier), the plugin is responsible for these attributes

#define INT_MELEE_MAX_ATTRS         sizeof(iIntMeleeAttributes)
#define BOOL_MELEE_MAX_ATTRS        sizeof(iBoolMeleeAttributes)
#define FLOAT_MELEE_MAX_ATTRS       sizeof(iFloatMeleeAttributes)

#define GAME_MELEE_MAX_ATTRS        (INT_MELEE_MAX_ATTRS + BOOL_MELEE_MAX_ATTRS + FLOAT_MELEE_MAX_ATTRS)
#define PLUGIN_MELEE_MAX_ATTRS      (GAME_MELEE_MAX_ATTRS + 1) // Including: tankdamagemult(Tank damage multiplier), the plugin is responsible for this attribute

#define MAX_ATTRS_NAME_LENGTH       32
#define MAX_WEAPON_NAME_LENGTH      64
#define MAX_ATTRS_VALUE_LENGTH      32

enum {
    eDisableCommand = 0,
    eShowToOnlyAdmin,
    eShowToEveryone,
};

enum MessageTypeFlag {
    eServerPrint  = (1 << 0),
    ePrintChatAll = (1 << 1),
    eLogError     = (1 << 2)
};

enum struct Resetable {
    any defVal;
    any curVal;
}

static const L4D2IntWeaponAttributes iIntWeaponAttributes[] = {
    L4D2IWA_Damage,
    L4D2IWA_Bullets,
    L4D2IWA_ClipSize,
    L4D2IWA_Bucket,
    L4D2IWA_Tier // L4D2 only
};

static const L4D2FloatWeaponAttributes iFloatWeaponAttributes[] = {
    L4D2FWA_MaxPlayerSpeed,
    L4D2FWA_SpreadPerShot,
    L4D2FWA_MaxSpread,
    L4D2FWA_SpreadDecay,
    L4D2FWA_MinDuckingSpread,
    L4D2FWA_MinStandingSpread,
    L4D2FWA_MinInAirSpread,
    L4D2FWA_MaxMovementSpread,
    L4D2FWA_PenetrationNumLayers,
    L4D2FWA_PenetrationPower,
    L4D2FWA_PenetrationMaxDist,
    L4D2FWA_CharPenetrationMaxDist,
    L4D2FWA_Range,
    L4D2FWA_RangeModifier,
    L4D2FWA_CycleTime,
    L4D2FWA_PelletScatterPitch,
    L4D2FWA_PelletScatterYaw,
    L4D2FWA_VerticalPunch,
    L4D2FWA_HorizontalPunch, // Requires "z_gun_horiz_punch" cvar changed to "1".
    L4D2FWA_GainRange,
    L4D2FWA_ReloadDuration
};

static const char g_szWeaponAttrNames[PLUGIN_WEAPON_MAX_ATTRS][MAX_ATTRS_NAME_LENGTH] = {
    "Damage",
    "Bullets",
    "Clip Size",
    "Bucket",
    "Tier",
    "Max player speed",
    "Spread per shot",
    "Max spread",
    "Spread decay",
    "Min ducking spread",
    "Min standing spread",
    "Min in air spread",
    "Max movement spread",
    "Penetration num layers",
    "Penetration power",
    "Penetration max dist",
    "Char penetration max dist",
    "Range",
    "Range modifier",
    "Cycle time",
    "Pellet scatter pitch",
    "Pellet scatter yaw",
    "Vertical punch",
    "Horizontal punch",
    "Gain range",
    "Reload duration",
    "Tank damage multiplier",    // the plugin is responsible for this attribute
    "Reload duration multiplier" // the plugin is responsible for this attribute
};

static const char g_szWeaponAttrShortName[PLUGIN_WEAPON_MAX_ATTRS][MAX_ATTRS_NAME_LENGTH] = {
    "damage",
    "bullets",
    "clipsize",
    "bucket",
    "tier",
    "speed",
    "spreadpershot",
    "maxspread",
    "spreaddecay",
    "minduckspread",
    "minstandspread",
    "minairspread",
    "maxmovespread",
    "penlayers",
    "penpower",
    "penmaxdist",
    "charpenmaxdist",
    "range",
    "rangemod",
    "cycletime",
    "scatterpitch",
    "scatteryaw",
    "verticalpunch",
    "horizpunch",
    "gainrange",
    "reloadduration",
    "tankdamagemult",    // the plugin is responsible for this attribute
    "reloaddurationmult" // the plugin is responsible for this attribute
};

static const L4D2IntMeleeWeaponAttributes iIntMeleeAttributes[] = {
    L4D2IMWA_DamageFlags,
    L4D2IMWA_RumbleEffect
};

static const L4D2BoolMeleeWeaponAttributes iBoolMeleeAttributes[] = {
    L4D2BMWA_Decapitates
};

static const L4D2FloatMeleeWeaponAttributes iFloatMeleeAttributes[] = {
    L4D2FMWA_Damage,
    L4D2FMWA_RefireDelay,
    L4D2FMWA_WeaponIdleTime
};

static const char g_szMeleeAttrNames[PLUGIN_MELEE_MAX_ATTRS][MAX_ATTRS_NAME_LENGTH] = {
    "Damage flags",
    "Rumble effect",
    "Decapitates",
    "Damage",
    "Refire delay",
    "Weapon idle time",
    "Tank damage multiplier" // the plugin is responsible for this attribute
};

static const char g_szMeleeAttrShortName[PLUGIN_MELEE_MAX_ATTRS][MAX_ATTRS_NAME_LENGTH] = {
    "damageflags",
    "rumbleeffect",
    "decapitates",
    "damage",
    "refiredelay",
    "weaponidletime",
    "tankdamagemult" // the plugin is responsible for this attribute
};

ConVar g_cvHideWeaponAttr;

bool g_bTankDamageEnableAttr     = false;
bool g_bReloadDurationEnableAttr = false;

StringMap g_smTankDamageAttr;
StringMap g_smReloadDurationAttr;
StringMap g_smDefaultWeaponAttr[GAME_WEAPON_MAX_ATTRS] = {null, ...};
StringMap g_smDefaultMeleeAttr [GAME_MELEE_MAX_ATTRS]  = {null, ...};

DynamicDetour
    g_hReloadDurationDetour;

public Plugin myinfo = {
    name        = "L4D2 Weapon Attributes",
    author      = "Jahze, A1m`, Forgetest",
    version     = "3.0.1",
    description = "Allowing tweaking of the attributes of all weapons",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart() {
    GameData gmConf = new GameData(GAMEDATA_FILE);
    if (!gmConf)
        SetFailState("Missing gamedata \""...GAMEDATA_FILE..."\"");

    g_hReloadDurationDetour = DynamicDetour.FromConf(gmConf, "CBaseShotgun::GetReloadDurationModifier");
    if (!g_hReloadDurationDetour)
        SetFailState("Missing detour setup \"CBaseShotgun::GetReloadDurationModifier\"");

    delete gmConf;

    g_cvHideWeaponAttr = CreateConVar(
    "sm_weapon_hide_attributes", "2",
    "Allows to customize the command 'sm_weapon_attributes'. 0 - disable command, 1 - show weapons attribute to admin only. 2 - show weapon attributes to everyone.",
    FCVAR_NONE, true, 0.0, true, 2.0);

    g_smTankDamageAttr     = new StringMap();
    g_smReloadDurationAttr = new StringMap();

    for (int iAtrriIndex = 0; iAtrriIndex < GAME_WEAPON_MAX_ATTRS; iAtrriIndex++) {
        g_smDefaultWeaponAttr[iAtrriIndex] = new StringMap();
    }

    for (int iAtrriIndex = 0; iAtrriIndex < GAME_MELEE_MAX_ATTRS; iAtrriIndex++) {
        g_smDefaultMeleeAttr[iAtrriIndex] = new StringMap();
    }

    RegServerCmd("sm_weapon",                  Cmd_Weapon);
    RegServerCmd("sm_weapon_attributes_reset", Cmd_WeaponAttributesReset);

    RegConsoleCmd("sm_weaponstats",            Cmd_WeaponAttributes);
    RegConsoleCmd("sm_weapon_attributes",      Cmd_WeaponAttributes);
}

public void OnPluginEnd() {
    ResetWeaponAttributes(true);
    ResetMeleeAttributes(true);
}

public void OnClientPutInServer(int iClient) {
    if (!g_bTankDamageEnableAttr)
        return;
    SDKHook(iClient, SDKHook_OnTakeDamage, SDK_OnTakeDamage);
}

public void OnConfigsExecuted() {
    // Weapon info may get reloaded, and supported melees
    // are different between campaigns.
    // Here we are reloading all the attributes set by our own.
    ResetWeaponAttributes(false);
    ResetMeleeAttributes(false);
}

void OnTankDamageEnableAttriChanged(bool bNewVal) {
    if (g_bTankDamageEnableAttr != bNewVal) {
        for (int i = 1; i <= MaxClients; i++) {
            if (!IsClientInGame(i))
                continue;
            bNewVal ? SDKHook(i, SDKHook_OnTakeDamage, SDK_OnTakeDamage) : SDKUnhook(i, SDKHook_OnTakeDamage, SDK_OnTakeDamage);
        }

        g_bTankDamageEnableAttr = bNewVal;
    }
}

void OnReloadDurationEnableAttriChanged(bool bNewVal) {
    if (g_bReloadDurationEnableAttr != bNewVal) {
        if (!(bNewVal ? g_hReloadDurationDetour.Enable(Hook_Pre, DTR_CBaseShotgun__GetReloadDurationModifier) : g_hReloadDurationDetour.Disable(Hook_Pre, DTR_CBaseShotgun__GetReloadDurationModifier)))
            SetFailState("Failed to detour \"CBaseShotgun::GetReloadDurationModifier__skip_constant\"");
        g_bReloadDurationEnableAttr = bNewVal;
    }
}

Action Cmd_Weapon(int iArgs) {
    if (iArgs < 3) {
        PrintDebug(eLogError|eServerPrint, "Syntax: sm_weapon <weapon> <attr> <value>.");
        return Plugin_Handled;
    }

    char szWeaponName[MAX_WEAPON_NAME_LENGTH];
    GetCmdArg(1, szWeaponName, sizeof(szWeaponName));

    if (strncmp(szWeaponName, "weapon_", 7) == 0)
        strcopy(szWeaponName, sizeof(szWeaponName), szWeaponName[7]);

    char szAttrName[MAX_ATTRS_NAME_LENGTH];
    GetCmdArg(2, szAttrName, sizeof(szAttrName));

    char szAttrValue[MAX_ATTRS_VALUE_LENGTH];
    GetCmdArg(3, szAttrValue, sizeof(szAttrValue));

    if (IsSupportedMelee(szWeaponName)) {
        int iAttrIdx = GetMeleeAttributeIndex(szAttrName);

        if (iAttrIdx == -1) {
            PrintDebug(eLogError|eServerPrint, "Bad attribute name: %s.", szAttrName);
            return Plugin_Handled;
        }

        if (iAttrIdx < INT_MELEE_MAX_ATTRS) {
            int iValue = StringToInt(szAttrValue);
            SetMeleeAttributeInt(szWeaponName, iAttrIdx, iValue);
            PrintDebug(eServerPrint, "%s for %s set to %d.", g_szMeleeAttrNames[iAttrIdx], szWeaponName, iValue);
        } else if (iAttrIdx < INT_MELEE_MAX_ATTRS + BOOL_MELEE_MAX_ATTRS) {
            bool bValue = StringToBool(szAttrValue);
            SetMeleeAttributeBool(szWeaponName, iAttrIdx, bValue);
            PrintDebug(eServerPrint, "%s for %s set to %s.", g_szMeleeAttrNames[iAttrIdx], szWeaponName, bValue ? "true" : "false");
        } else {
            float fValue = StringToFloat(szAttrValue);
            if (iAttrIdx < GAME_MELEE_MAX_ATTRS) {
                SetMeleeAttributeFloat(szWeaponName, iAttrIdx, fValue);
                PrintDebug(eServerPrint, "%s for %s set to %.2f.", g_szMeleeAttrNames[iAttrIdx], szWeaponName, fValue);
            } else {
                if (fValue <= 0.0) {
                    if (!g_smTankDamageAttr.Remove(szWeaponName)) {
                        PrintDebug(eLogError|eServerPrint, "Сheck melee attribute '%s' value, cannot be set below zero or zero. Set the value: %f!", szAttrName, fValue);
                        return Plugin_Handled;
                    }

                    PrintDebug(eServerPrint, "Tank Damage Multiplier (tankdamagemult) attribute reset for %s melee!", szWeaponName);
                    OnTankDamageEnableAttriChanged(g_smTankDamageAttr.Size != 0);
                    return Plugin_Handled;
                }

                OnTankDamageEnableAttriChanged(true);
                g_smTankDamageAttr.SetValue(szWeaponName, fValue);
                PrintDebug(eServerPrint, "%s for %s set to %.2f", g_szMeleeAttrNames[iAttrIdx], szWeaponName, fValue);
            }
        }
    } else if (L4D2_IsValidWeapon(szWeaponName)) {
        int iAttrIdx = GetWeaponAttributeIndex(szAttrName);

        if (iAttrIdx == -1) {
            PrintDebug(eLogError|eServerPrint, "Bad attribute name: %s.", szAttrName);
            return Plugin_Handled;
        }

        if (iAttrIdx < INT_WEAPON_MAX_ATTRS) {
            int iValue = StringToInt(szAttrValue);
            SetWeaponAttributeInt(szWeaponName, iAttrIdx, iValue);
            PrintDebug(eServerPrint, "%s for %s set to %d.", g_szWeaponAttrNames[iAttrIdx], szWeaponName, iValue);
        } else {
            float fValue = StringToFloat(szAttrValue);
            if (iAttrIdx < GAME_WEAPON_MAX_ATTRS) {
                SetWeaponAttributeFloat(szWeaponName, iAttrIdx, fValue);
                PrintDebug(eServerPrint, "%s for %s set to %.2f.", g_szWeaponAttrNames[iAttrIdx], szWeaponName, fValue);
            } else if (iAttrIdx < PLUGIN_WEAPON_MAX_ATTRS - 1) {
                if (fValue <= 0.0) {
                    if (!g_smTankDamageAttr.Remove(szWeaponName)) {
                        PrintDebug(eLogError|eServerPrint, "Сheck weapon attribute '%s' value, cannot be set below zero or zero. Set the value: %f!", szAttrName, fValue);
                        return Plugin_Handled;
                    }

                    PrintDebug(eServerPrint, "Tank Damage Multiplier (tankdamagemult) attribute reset for %s weapon!", szWeaponName);
                    OnTankDamageEnableAttriChanged(g_smTankDamageAttr.Size != 0);
                    return Plugin_Handled;
                }

                OnTankDamageEnableAttriChanged(true);
                g_smTankDamageAttr.SetValue(szWeaponName, fValue);
                PrintDebug(eServerPrint, "%s for %s set to %.2f", g_szWeaponAttrNames[iAttrIdx], szWeaponName, fValue);
            } else {
                if (StrContains(szWeaponName, "shotgun", false) == -1) {
                    PrintDebug(eLogError|eServerPrint, "Non-shotgun weapon '%s' encountered when setting Reload Duration Multiplier (reloaddurationmult).", szWeaponName);
                    return Plugin_Handled;
                }

                if (fValue <= 0.0) {
                    if (!g_smReloadDurationAttr.Remove(szWeaponName)) {
                        PrintDebug(eLogError|eServerPrint, "Сheck weapon attribute '%s' value, cannot be set below zero or zero. Set the value: %f!", szAttrName, fValue);
                        return Plugin_Handled;
                    }

                    PrintDebug(eServerPrint, "Reload Duration Multiplier (reloaddurationmult) attribute reset for %s weapon!", szWeaponName);
                    OnReloadDurationEnableAttriChanged(g_smReloadDurationAttr.Size != 0);
                    return Plugin_Handled;
                }

                OnReloadDurationEnableAttriChanged(true);
                g_smReloadDurationAttr.SetValue(szWeaponName, fValue);
                PrintDebug(eServerPrint, "%s for %s set to %.2f", g_szWeaponAttrNames[iAttrIdx], szWeaponName, fValue);
            }
        }
    } else {
        PrintDebug(eLogError|eServerPrint, "Bad weapon name: %s.", szWeaponName);
    }

    return Plugin_Handled;
}

Action Cmd_WeaponAttributes(int iClient, int iArgs) {
    int iCvarValue = g_cvHideWeaponAttr.IntValue;

    if (iCvarValue == eDisableCommand || (iCvarValue == eShowToOnlyAdmin && iClient != 0 && GetUserAdmin(iClient) == INVALID_ADMIN_ID)) {
        ReplyToCommand(iClient, "This command is not available to you!");
        return Plugin_Handled;
    }

    if (iArgs > 1) {
        ReplyToCommand(iClient, "Syntax: sm_weapon_attributes [weapon].");
        return Plugin_Handled;
    }

    char szWeaponName[MAX_WEAPON_NAME_LENGTH];
    if (iArgs == 1) {
        GetCmdArg(1, szWeaponName, sizeof(szWeaponName));
    } else if (iClient > 0) {
        int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
        if (iWeapon != -1) {
            GetEdictClassname(iWeapon, szWeaponName, sizeof(szWeaponName));
            if (strcmp(szWeaponName, "weapon_melee") == 0) {
                GetEntPropString(iWeapon, Prop_Data, "m_strMapSetScriptName", szWeaponName, sizeof(szWeaponName));
            }
        }
    }

    if (strncmp(szWeaponName, "weapon_", 7) == 0)
        strcopy(szWeaponName, sizeof(szWeaponName), szWeaponName[7]);

    if (IsSupportedMelee(szWeaponName)) {
        CReplyToCommand(iClient, "{blue}[{default}Melee stats for {green}%s{blue}]", szWeaponName);

        for (int iAtrriIndex = 0; iAtrriIndex < GAME_MELEE_MAX_ATTRS; iAtrriIndex++) {
            if (iAtrriIndex < INT_MELEE_MAX_ATTRS) {
                int iValue = GetMeleeAttributeInt(szWeaponName, iAtrriIndex);
                CReplyToCommand(iClient, "- {lightgreen}%s{default}: {olive}%d", g_szMeleeAttrNames[iAtrriIndex], iValue);
            } else if (iAtrriIndex < INT_MELEE_MAX_ATTRS + BOOL_MELEE_MAX_ATTRS) {
                bool bValue = GetMeleeAttributeBool(szWeaponName, iAtrriIndex);
                CReplyToCommand(iClient, "- {lightgreen}%s{default}: {olive}%s", g_szMeleeAttrNames[iAtrriIndex], bValue ? "true" : "false");
            } else {
                float fValue = GetMeleeAttributeFloat(szWeaponName, iAtrriIndex);
                CReplyToCommand(iClient, "- {lightgreen}%s{default}: {olive}%.2f", g_szMeleeAttrNames[iAtrriIndex], fValue);
            }
        }

        float fBuff = 0.0;
        if (g_smTankDamageAttr.GetValue(szWeaponName, fBuff))
            CReplyToCommand(iClient, "- {lightgreen}%s{default}: {olive}%.2f", g_szMeleeAttrNames[GAME_MELEE_MAX_ATTRS], fBuff);
    } else if (L4D2_IsValidWeapon(szWeaponName)) {
        CReplyToCommand(iClient, "{blue}[{default}Weapon stats for {green}%s{blue}]", szWeaponName);

        for (int iAtrriIndex = 0; iAtrriIndex < GAME_WEAPON_MAX_ATTRS; iAtrriIndex++) {
            if (iAtrriIndex < INT_WEAPON_MAX_ATTRS) {
                int iValue = GetWeaponAttributeInt(szWeaponName, iAtrriIndex);
                CReplyToCommand(iClient, "- {lightgreen}%s{default}: {olive}%d", g_szWeaponAttrNames[iAtrriIndex], iValue);
            } else {
                float fValue = GetWeaponAttributeFloat(szWeaponName, iAtrriIndex);
                CReplyToCommand(iClient, "- {lightgreen}%s{default}: {olive}%.2f", g_szWeaponAttrNames[iAtrriIndex], fValue);
            }
        }

        float fBuff = 0.0;
        if (g_smTankDamageAttr.GetValue(szWeaponName, fBuff))
            CReplyToCommand(iClient, "- {lightgreen}%s{default}: {olive}%.2f", g_szWeaponAttrNames[GAME_WEAPON_MAX_ATTRS], fBuff);

        fBuff = 0.0;
        if (g_smReloadDurationAttr.GetValue(szWeaponName, fBuff))
            CReplyToCommand(iClient, "- {lightgreen}%s{default}: {olive}%.2f", g_szWeaponAttrNames[GAME_WEAPON_MAX_ATTRS+1], fBuff);
    } else {
        ReplyToCommand(iClient, "Bad weapon name: %s.", szWeaponName);
        return Plugin_Handled;
    }

    return Plugin_Handled;
}

Action Cmd_WeaponAttributesReset(int iArgs) {
    OnTankDamageEnableAttriChanged(false);

    bool bIsReset = (g_smTankDamageAttr.Size > 0);
    g_smTankDamageAttr.Clear();

    if (bIsReset)
        PrintDebug(eServerPrint, "Tank Damage Multiplier (tankdamagemult) attribute reset for all weapons!");

    bIsReset = (g_smReloadDurationAttr.Size > 0);
    g_smReloadDurationAttr.Clear();

    if (bIsReset)
        PrintDebug(eServerPrint, "Reload Duration Multiplier (reloaddurationmult) attribute reset for all shotguns!");

    int iWeaponAttrCount = ResetWeaponAttributes(true);
    if (iWeaponAttrCount == 0)
        PrintDebug(eServerPrint, "Weapon attributes were not reset, because no weapon attributes were saved!");

    int iMeleeAttrCount = ResetMeleeAttributes(true);
    if (iMeleeAttrCount == 0)
        PrintDebug(eServerPrint, "Melee attributes were not reset, because no melee attributes were saved!");

    if (iWeaponAttrCount || iMeleeAttrCount)
        PrintDebug(eServerPrint, "The weapon attributes for all saved weapons have been reset successfully. Number of reset weapon attributes: %d!", iWeaponAttrCount + iMeleeAttrCount);

    return Plugin_Handled;
}

Action SDK_OnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &fDmg, int &iDmgType) {
    if (!(iDmgType & DMG_BULLET) && !(iDmgType & DMG_CLUB))
        return Plugin_Continue;

    if (!IsValidClient(iAttacker) || !IsTank(iVictim))
        return Plugin_Continue;

    char szWeaponName[MAX_WEAPON_NAME_LENGTH];
    GetClientWeapon(iAttacker, szWeaponName, sizeof(szWeaponName));

    if (strncmp(szWeaponName, "weapon_", 7) == 0) {
        if (strcmp(szWeaponName[7], "melee") == 0) {
            GetEntPropString(iInflictor, Prop_Data, "m_strMapSetScriptName", szWeaponName, sizeof(szWeaponName));
        } else {
            strcopy(szWeaponName, sizeof(szWeaponName), szWeaponName[7]);
        }
    }

    float fBuff = 0.0;
    if (g_smTankDamageAttr.GetValue(szWeaponName, fBuff)) {
        fDmg *= fBuff;
        return Plugin_Changed;
    }

    return Plugin_Continue;
}

MRESReturn DTR_CBaseShotgun__GetReloadDurationModifier(int iWeapon, DHookReturn hReturn) {
    char szWeaponName[MAX_WEAPON_NAME_LENGTH];
    GetEdictClassname(iWeapon, szWeaponName, sizeof(szWeaponName));

    if (strncmp(szWeaponName, "weapon_", 7) == 0)
        strcopy(szWeaponName, sizeof(szWeaponName), szWeaponName[7]);

    float fBuff = 0.0;
    if (!g_smReloadDurationAttr.GetValue(szWeaponName, fBuff))
        return MRES_Ignored;

    hReturn.Value = fBuff;
    return MRES_Override;
}

int GetWeaponAttributeIndex(const char[] szAttrName) {
    for (int i = 0; i < PLUGIN_WEAPON_MAX_ATTRS; i++) {
        if (strcmp(szAttrName, g_szWeaponAttrShortName[i]) != 0)
            continue;

        return i;
    }

    return -1;
}

int GetMeleeAttributeIndex(const char[] szAttrName) {
    for (int i = 0; i < PLUGIN_MELEE_MAX_ATTRS; i++) {
        if (strcmp(szAttrName, g_szMeleeAttrShortName[i]) != 0)
            continue;

        return i;
    }

    return -1;
}

int GetWeaponAttributeInt(const char[] szWeaponName, int iAtrrIdx) {
    return L4D2_GetIntWeaponAttribute(szWeaponName, iIntWeaponAttributes[iAtrrIdx]);
}

float GetWeaponAttributeFloat(const char[] szWeaponName, int iAtrrIdx) {
    return L4D2_GetFloatWeaponAttribute(szWeaponName, iFloatWeaponAttributes[iAtrrIdx - INT_WEAPON_MAX_ATTRS]);
}

void SetWeaponAttributeInt(const char[] szWeaponName, int iAtrrIdx, int iSetValue, bool bIsSaveDefValue = true) {
    Resetable eValue;
    if (!g_smDefaultWeaponAttr[iAtrrIdx].GetArray(szWeaponName, eValue, sizeof(eValue))) {
        if (bIsSaveDefValue) eValue.defVal = GetWeaponAttributeInt(szWeaponName, iAtrrIdx);
    }

    L4D2_SetIntWeaponAttribute(szWeaponName, iIntWeaponAttributes[iAtrrIdx], iSetValue);

    eValue.curVal = iSetValue;
    g_smDefaultWeaponAttr[iAtrrIdx].SetArray(szWeaponName, eValue, sizeof(eValue), true);
}

void SetWeaponAttributeFloat(const char[] szWeaponName, int iAtrrIdx, float fSetValue, bool bIsSaveDefValue = true) {
    Resetable eValue;
    if (!g_smDefaultWeaponAttr[iAtrrIdx].GetArray(szWeaponName, eValue, sizeof(eValue))) {
        if (bIsSaveDefValue) eValue.defVal = GetWeaponAttributeFloat(szWeaponName, iAtrrIdx);
    }

    L4D2_SetFloatWeaponAttribute(szWeaponName, iFloatWeaponAttributes[iAtrrIdx - INT_WEAPON_MAX_ATTRS], fSetValue);

    eValue.curVal = fSetValue;
    g_smDefaultWeaponAttr[iAtrrIdx].SetArray(szWeaponName, eValue, sizeof(eValue), true);
}

int GetMeleeAttributeInt(const char[] szMeleeName, int iAtrrIdx) {
    int iIdx = L4D2_GetMeleeWeaponIndex(szMeleeName);
    if (iIdx != -1) return L4D2_GetIntMeleeAttribute(iIdx, iIntMeleeAttributes[iAtrrIdx]);

    Resetable eValue;
    if (g_smDefaultMeleeAttr[iAtrrIdx].GetArray(szMeleeName, eValue, sizeof(eValue))) {
        // do something ...
    }

    return eValue.curVal;
}

bool GetMeleeAttributeBool(const char[] szMeleeName, int iAtrrIdx) {
    int iIdx = L4D2_GetMeleeWeaponIndex(szMeleeName);
    if (iIdx != -1) return L4D2_GetBoolMeleeAttribute(iIdx, iBoolMeleeAttributes[iAtrrIdx - INT_MELEE_MAX_ATTRS]);

    Resetable eValue;
    if (g_smDefaultMeleeAttr[iAtrrIdx].GetArray(szMeleeName, eValue, sizeof(eValue))) {
        // do something ...
    }

    return eValue.curVal;
}

float GetMeleeAttributeFloat(const char[] szMeleeName, int iAtrrIdx) {
    int iIdx = L4D2_GetMeleeWeaponIndex(szMeleeName);
    if (iIdx != -1) {
        return L4D2_GetFloatMeleeAttribute(iIdx, iFloatMeleeAttributes[iAtrrIdx - BOOL_MELEE_MAX_ATTRS - INT_MELEE_MAX_ATTRS]);
    }

    Resetable eValue;
    if (g_smDefaultMeleeAttr[iAtrrIdx].GetArray(szMeleeName, eValue, sizeof(eValue))) {
        // do something ...
    }

    return eValue.curVal;
}

void SetMeleeAttributeInt(const char[] szMeleeName, int iAtrrIdx, int iSetValue, bool bIsSaveDefValue = true) {
    Resetable eValue;
    if (!g_smDefaultMeleeAttr[iAtrrIdx].GetArray(szMeleeName, eValue, sizeof(eValue))) {
        if (bIsSaveDefValue) eValue.defVal = GetMeleeAttributeInt(szMeleeName, iAtrrIdx);
    }

    int iIdx = L4D2_GetMeleeWeaponIndex(szMeleeName);
    if (iIdx != -1) L4D2_SetIntMeleeAttribute(iIdx, iIntMeleeAttributes[iAtrrIdx], iSetValue);

    eValue.curVal = iSetValue;
    g_smDefaultMeleeAttr[iAtrrIdx].SetArray(szMeleeName, eValue, sizeof(eValue), true);
}

void SetMeleeAttributeBool(const char[] szMeleeName, int iAtrrIdx, bool bSetValue, bool bIsSaveDefValue = true) {
    Resetable eValue;
    if (!g_smDefaultMeleeAttr[iAtrrIdx].GetArray(szMeleeName, eValue, sizeof(eValue))) {
        if (bIsSaveDefValue) eValue.defVal = GetMeleeAttributeBool(szMeleeName, iAtrrIdx);
    }

    int iIdx = L4D2_GetMeleeWeaponIndex(szMeleeName);
    if (iIdx != -1) L4D2_SetBoolMeleeAttribute(iIdx, iBoolMeleeAttributes[iAtrrIdx - INT_MELEE_MAX_ATTRS], bSetValue);

    eValue.curVal = bSetValue;
    g_smDefaultMeleeAttr[iAtrrIdx].SetArray(szMeleeName, eValue, sizeof(eValue), true);
}

void SetMeleeAttributeFloat(const char[] szMeleeName, int iAtrrIdx, float fSetValue, bool bIsSaveDefValue = true) {
    Resetable eValue;
    if (!g_smDefaultMeleeAttr[iAtrrIdx].GetArray(szMeleeName, eValue, sizeof(eValue))) {
        if (bIsSaveDefValue) eValue.defVal = GetMeleeAttributeFloat(szMeleeName, iAtrrIdx);
    }

    int iIdx = L4D2_GetMeleeWeaponIndex(szMeleeName);
    if (iIdx != -1) L4D2_SetFloatMeleeAttribute(iIdx, iFloatMeleeAttributes[iAtrrIdx - BOOL_MELEE_MAX_ATTRS - INT_MELEE_MAX_ATTRS], fSetValue);

    eValue.curVal = fSetValue;
    g_smDefaultMeleeAttr[iAtrrIdx].SetArray(szMeleeName, eValue, sizeof(eValue), true);
}

int ResetWeaponAttributes(bool bResetDefault = false) {
    float fDefValue = 0.0;
    float fCurValue = 0.0;
    int   iDefValue = 0;
    int   iCurValue = 0;

    Resetable eValue;

    char szWeaponName[MAX_WEAPON_NAME_LENGTH];
    StringMapSnapshot smSnapshot = null;
    int iCount = 0;
    int iSize  = 0;

    for (int iAtrrIdx = 0; iAtrrIdx < GAME_WEAPON_MAX_ATTRS; iAtrrIdx++) {
        smSnapshot = g_smDefaultWeaponAttr[iAtrrIdx].Snapshot();
        iSize = smSnapshot.Length;

        for (int i = 0; i < iSize; i++) {
            smSnapshot.GetKey(i, szWeaponName, sizeof(szWeaponName));
            if (iAtrrIdx < INT_WEAPON_MAX_ATTRS) {
                g_smDefaultWeaponAttr[iAtrrIdx].GetArray(szWeaponName, eValue, sizeof(eValue));

                iCurValue = GetWeaponAttributeInt(szWeaponName, iAtrrIdx);
                iDefValue = bResetDefault ? eValue.defVal : eValue.curVal;
                if (iCurValue != iDefValue) {
                    SetWeaponAttributeInt(szWeaponName, iAtrrIdx, iDefValue, false);
                    iCount++;
                }
            } else {
                g_smDefaultWeaponAttr[iAtrrIdx].GetArray(szWeaponName, eValue, sizeof(eValue));

                fCurValue = GetWeaponAttributeFloat(szWeaponName, iAtrrIdx);
                fDefValue = bResetDefault ? eValue.defVal : eValue.curVal;
                if (fCurValue != fDefValue) {
                    SetWeaponAttributeFloat(szWeaponName, iAtrrIdx, fDefValue, false);
                    iCount++;
                }
            }
        }

        delete smSnapshot;
        smSnapshot = null;
    }

    return iCount;
}

int ResetMeleeAttributes(bool bResetDefault = false) {
    float fDefValue = 0.0;
    float fCurValue = 0.0;
    bool  bDefValue = false;
    bool  bCurValue = false;
    int   iDefValue = 0;
    int   iCurValue = 0;

    Resetable eValue;

    char szMeleeName[MAX_WEAPON_NAME_LENGTH];
    StringMapSnapshot smSnapshot = null;
    int iCount = 0, iSize = 0;

    for (int iAtrriIndex = 0; iAtrriIndex < GAME_MELEE_MAX_ATTRS; iAtrriIndex++) {
        smSnapshot = g_smDefaultMeleeAttr[iAtrriIndex].Snapshot();
        iSize = smSnapshot.Length;

        for (int i = 0; i < iSize; i++) {
            smSnapshot.GetKey(i, szMeleeName, sizeof(szMeleeName));
            if (iAtrriIndex < INT_MELEE_MAX_ATTRS) {
                g_smDefaultMeleeAttr[iAtrriIndex].GetArray(szMeleeName, eValue, sizeof(eValue));

                iCurValue = GetMeleeAttributeInt(szMeleeName, iAtrriIndex);
                iDefValue = bResetDefault ? eValue.defVal : eValue.curVal;
                if (iCurValue != iDefValue) {
                    SetMeleeAttributeInt(szMeleeName, iAtrriIndex, iDefValue, false);
                    iCount++;
                }
            } else if (iAtrriIndex < INT_MELEE_MAX_ATTRS + BOOL_MELEE_MAX_ATTRS) {
                g_smDefaultMeleeAttr[iAtrriIndex].GetArray(szMeleeName, eValue, sizeof(eValue));

                bCurValue = GetMeleeAttributeBool(szMeleeName, iAtrriIndex);
                bDefValue = bResetDefault ? eValue.defVal : eValue.curVal;
                if (bCurValue != bDefValue) {
                    SetMeleeAttributeBool(szMeleeName, iAtrriIndex, bDefValue, false);
                    iCount++;
                }
            } else {
                g_smDefaultMeleeAttr[iAtrriIndex].GetArray(szMeleeName, eValue, sizeof(eValue));

                fCurValue = GetMeleeAttributeFloat(szMeleeName, iAtrriIndex);
                fDefValue = bResetDefault ? eValue.defVal : eValue.curVal;
                if (fCurValue != fDefValue) {
                    SetMeleeAttributeFloat(szMeleeName, iAtrriIndex, fDefValue, false);
                    iCount++;
                }
            }
        }

        delete smSnapshot;
        smSnapshot = null;
    }

    return iCount;
}

bool IsSupportedMelee(const char[] szMeleeName) {
    static const char szOfficialMeleeWeaponNames[][] = {
        "knife",
        "baseball_bat",
        "chainsaw",
        "cricket_bat",
        "crowbar",
        "didgeridoo",
        "electric_guitar",
        "fireaxe",
        "frying_pan",
        "golfclub",
        "katana",
        "machete",
        "riotshield",
        "tonfa",
        "shovel",
        "pitchfork"
    };

    for (int i = 0; i < sizeof(szOfficialMeleeWeaponNames); i++) {
        if (strcmp(szMeleeName, szOfficialMeleeWeaponNames[i]) != 0)
            continue;
        return true;
    }

    return false;
}

bool IsValidClient(int iClient) {
    return (iClient > 0 && iClient <= MaxClients);
}

bool IsTank(int iClient) {
    return (IsValidClient(iClient) && IsClientInGame(iClient) && GetClientTeam(iClient) == TEAM_INFECTED && GetEntProp(iClient, Prop_Send, "m_zombieClass") == TANK_ZOMBIE_CLASS && IsPlayerAlive(iClient));
}

stock bool StringToBool(const char[] szBuffer) {
    int iNum;
    if (StringToIntEx(szBuffer, iNum)) {
        return iNum != 0;
    } else if (strcmp(szBuffer, "true", false) == 0) {
        return true;
    }

    return false;
}

void PrintDebug(MessageTypeFlag iType, const char[] szMessage, any ...) {
    char szDebugBuff[256];
    VFormat(szDebugBuff, sizeof(szDebugBuff), szMessage, 3);

    if (iType & eServerPrint)
        PrintToServer(szDebugBuff);

    if (iType & ePrintChatAll)
        PrintToChatAll(szDebugBuff);

    if (iType & eLogError)
        LogError(szDebugBuff);
}