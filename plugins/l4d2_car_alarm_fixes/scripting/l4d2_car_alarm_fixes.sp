#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define GAMEDATA "l4d2_car_alarm_fixes"
#define MAX_BYTES 33

int     g_iByteCount;
int     g_iByteMatch;
int     g_iByteSaved[MAX_BYTES];
Address g_pAddress;

ConVar g_cvCarAlarmSettings;
int    g_iCarAlarmSettings;

ConVar g_cvCarTouchCapped;
bool   g_bCarTouchCapped;

ConVar g_cvCarAI;
bool   g_bCarAI;

int FLAGS[3] = {
    1 << 0, // Trigger Car Alarm on Survivor Touch
    1 << 1, // Trigger Car Alarm disabled when hit by another Hittable.
};

// ====================================================================================================
//                  PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo = {
    name        = "L4D2 Car Alarm Fixes",
    author      = "Sir & Silvers (Gamedata and general idea from l4d2_car_alarm_bots)",
    description = "Disables the Car Alarm when a Tank hittable hits the alarmed car and makes sure the Car Alarm triggers whenever a Survivor touches it",
    version     = "1.2",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart() {
    // ====================================================================================================
    // GAMEDATA
    // ====================================================================================================
    GameData gmData = new GameData(GAMEDATA);
    if (gmData == null) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

    g_pAddress = gmData.GetAddress("CCarProp::InputSurvivorStandingOnCar");
    if (!g_pAddress) SetFailState("Failed to load \"CCarProp::InputSurvivorStandingOnCar\" address.");

    int iOffset = gmData.GetOffset("InputSurvivorStandingOnCar_Offset");
    if (iOffset == -1) SetFailState("Failed to load \"InputSurvivorStandingOnCar_Offset\" offset.");

    g_iByteMatch = gmData.GetOffset("InputSurvivorStandingOnCar_Byte");
    if (g_iByteMatch == -1) SetFailState("Failed to load \"InputSurvivorStandingOnCar_Byte\" byte.");

    g_iByteCount = gmData.GetOffset("InputSurvivorStandingOnCar_Count");
    if (g_iByteCount == -1) SetFailState("Failed to load \"InputSurvivorStandingOnCar_Count\" count.");

    if (g_iByteCount > MAX_BYTES) SetFailState("Error: byte count exceeds scripts defined value (%d/%d).", g_iByteCount, MAX_BYTES);

    g_pAddress += view_as<Address>(iOffset);

    for (int i = 0; i < g_iByteCount; i++) {
        g_iByteSaved[i] = LoadFromAddress(g_pAddress + view_as<Address>(i), NumberType_Int8);
    }

    if (g_iByteSaved[0] != g_iByteMatch) SetFailState("Failed to load, byte mis-match. %d (0x%02X != 0x%02X)", iOffset, g_iByteSaved[0], g_iByteMatch);

    delete gmData;

    // =================================================================================================
    // CONVARS
    // =================================================================================================
    g_cvCarAlarmSettings = CreateConVar(
    "l4d2_car_alarm_settings", "3",
    "Bitmask: 1-Trigger Alarm on Survivor Touch/ 2-Disable Alarm when a Hittable hits the Alarm Car",
    FCVAR_NONE, true, 0.0, true, 3.0);
    g_iCarAlarmSettings = g_cvCarAlarmSettings.IntValue;
    g_cvCarAlarmSettings.AddChangeHook(ChangedConVars);

    g_cvCarTouchCapped = CreateConVar(
    "l4d2_car_alarm_touch_capped", "1",
    "Only add the additional car alarm trigger when the Survivor is capped by an Infected when touching the car? (Requires bitmask settings)",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bCarTouchCapped = g_cvCarTouchCapped.BoolValue;
    g_cvCarTouchCapped.AddChangeHook(ChangedConVars);

    g_cvCarAI = CreateConVar("l4d2_car_alarm_touch_ai", "0",
    "Care about AI Survivors touching the car? (Default vanilla = 0) Requires bitmask settings",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bCarAI = g_cvCarAI.BoolValue;
    g_cvCarAI.AddChangeHook(ChangedConVars);
}

public void OnPluginEnd() {
    PatchAddress(false);
}

// ====================================================================================================
//                  PATCH / HOOK
// ====================================================================================================
void PatchAddress(bool bPatch) {
    static bool bPatched;
    if (!bPatched && bPatch) {
        bPatched = true;
        for (int i = 0; i < g_iByteCount; i++) {
            StoreToAddress(g_pAddress + view_as<Address>(i), g_iByteMatch == 0x0F ? 0x90 : 0xEB, NumberType_Int8);
        }
    } else if (bPatched && !bPatch) {
        bPatched = false;
        for (int i = 0; i < g_iByteCount; i++) {
            StoreToAddress(g_pAddress + view_as<Address>(i), g_iByteSaved[i], NumberType_Int8);
        }
    }
}

// ====================================================================================================
//                  EVENTS
// ====================================================================================================
public void OnEntityCreated(int iEnt, const char[] szClsName) {
    if (strcmp(szClsName, "prop_car_alarm") != 0) return;
    SDKHook(iEnt, SDKHook_Touch, OnTouch);
}

public void OnTouch(int iEnt, int iOther) {
    // Is the other entity a Survivor?
    if ((g_iCarAlarmSettings & FLAGS[0]) && iOther >= 1 && iOther <= MaxClients && GetClientTeam(iOther) == 2) {
        // We don't want the AI to trigger the car alarm.
        if (!g_bCarAI && IsFakeClient(iOther))
            return;
        // We only care about capped players touching the car.
        if (g_bCarTouchCapped && !IsPlayerCapped(iOther))
            return;
        PatchAddress(true);
        AcceptEntityInput(iEnt, "SurvivorStandingOnCar", iOther, iOther);
        PatchAddress(false);
        // Unhook car, we don't need it anymore.
        SDKUnhook(iEnt, SDKHook_Touch, OnTouch);
    }
    // Is the other entity a Hittable car?
    else if ((g_iCarAlarmSettings & FLAGS[1]) && IsTankHittable(iOther)) {
        // This returns 1 on every hittable at all times.
        if (GetEntProp(iOther, Prop_Send, "m_hasTankGlow") > 0) {
            // Disable the Car Alarm
            AcceptEntityInput(iEnt, "Disable");
            // Fake damage to Car to stop the glass from still blinking, delay it to prevent issues.
            CreateTimer(0.3, Timer_DisableAlarm, EntIndexToEntRef(iEnt), TIMER_FLAG_NO_MAPCHANGE);
            // Unhook car, we don't need it anymore.
            SDKUnhook(iEnt, SDKHook_Touch, OnTouch);
        }
    }
}

Action Timer_DisableAlarm(Handle timer, int iRef) {
    int iEnt = EntRefToEntIndex(iRef);
    if (iEnt > 0 && IsValidEntity(iEnt)) {
        int iTank = -1;
        for (int i = 1; i <= MaxClients; i++) {
            if (!IsValidTank(i)) continue;
            iTank = i;
            break;
        }
        if (iTank != -1) SDKHooks_TakeDamage(iEnt, iTank, iTank, 0.0);
    }
    return Plugin_Stop;
}

// ====================================================================================================
//                  STOCKS
// ====================================================================================================
stock bool IsValidTank(int iClient) {
    if (iClient <= 0 || iClient > MaxClients) return false;
    return (IsClientInGame(iClient) && GetClientTeam(iClient) == 3 && GetEntProp(iClient, Prop_Send, "m_zombieClass") == 8);
}

stock bool IsTankHittable(int iEnt) {
    if (!IsValidEntity(iEnt)) return false;
    char szClsName[64];
    GetEdictClassname(iEnt, szClsName, sizeof(szClsName));
    if (strcmp(szClsName, "prop_physics") == 0) {
        if (GetEntProp(iEnt, Prop_Send, "m_hasTankGlow", 1))
            return true;
    } else if (strcmp(szClsName, "prop_car_alarm") == 0) {
        return true;
    }
    return false;
}

stock bool IsPlayerCapped(int iClient) {
    return GetEntPropEnt(iClient, Prop_Send, "m_jockeyAttacker") > 0 || GetEntPropEnt(iClient, Prop_Send, "m_tongueOwner") > 0 || GetEntPropEnt(iClient, Prop_Send, "m_carryAttacker") > 0;
}

void ChangedConVars(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iCarAlarmSettings = g_cvCarAlarmSettings.IntValue;
    g_bCarTouchCapped   = g_cvCarTouchCapped.BoolValue;
    g_bCarAI            = g_cvCarAI.BoolValue;
}