/*
    SourcePawn is Copyright (C) 2006-2015 AlliedModders LLC.  All rights reserved.
    SourceMod is Copyright (C) 2006-2015 AlliedModders LLC.  All rights reserved.
    Pawn and SMALL are Copyright (C) 1997-2015 ITB CompuPhase.
    Source is Copyright (C) Valve Corporation.
    All trademarks are property of their respective owners.

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the
    Free Software Foundation, either version 3 of the License, or (at your
    option) any later version.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

// Force %0 to be between %1 and %2.
#define CLAMP(%0,%1,%2) (((%0) > (%2)) ? (%2) : (((%0) < (%1)) ? (%1) : (%0)))
// Linear fScale %0 between %1 and %2.
#define SCALE(%0,%1,%2) CLAMP((%0-%1)/(%2-%1), 0.0, 1.0)
// Quadratic fScale %0 between %1 and %2
#define SCALE2(%0,%1,%2) SCALE(%0*%0, %1*%1, %2*%2)

#define SURVIVOR_RUNSPEED      220.0
#define SURVIVOR_WATERSPEED_VS 170.0

ConVar g_cvSlowdownGunfireSI;
float  g_fSlowdownGunfireSI;

ConVar g_cvSlowdownGunfireTank;
float  g_fSlowdownGunfireTank;

ConVar g_cvSlowdownInWaterTank;
float  g_fSlowdownInWaterTank;

ConVar g_cvSlowdownInWaterSurvivor;
float  g_fSlowdownInWaterSurvivor;

ConVar g_cvSlowdownInWaterDuringTank;
float  g_fSlowdownInWaterDuringTank;

ConVar g_cvSlowdownPistol;
float  g_fSlowdownPistol;

ConVar g_cvSlowdownDeagle;
float  g_fSlowdownDeagle;

ConVar g_cvSlowdownUzi;
float  g_fSlowdownUzi;

ConVar g_cvSlowdownMac;
float  g_fSlowdownMac;

ConVar g_cvSlowdownAk;
float  g_fSlowdownAk;

ConVar g_cvSlowdownM4;
float  g_fSlowdownM4;

ConVar g_cvSlowdownScar;
float  g_fSlowdownScar;

ConVar g_cvSlowdownPump;
float  g_fSlowdownPump;

ConVar g_cvSlowdownChrome;
float  g_fSlowdownChrome;

ConVar g_cvSlowdownAuto;
float  g_fSlowdownAuto;

ConVar g_cvSlowdownRifle;
float  g_fSlowdownRifle;

ConVar g_cvSlowdownScout;
float  g_fSlowdownScout;

ConVar g_cvSlowdownMilitary;
float  g_fSlowdownMilitary;

ConVar g_cvSurvivorLimpspeed;
int    g_iSurvivorLimpspeed;

ConVar g_cvTankSpeedVS;
float  g_fTankSpeedVS;

ConVar g_cvCrouchSpeed;
float  g_fCrouchSpeed;

ConVar g_cvPillsDecayRate;
float  g_fPillsDecayRate;

bool  g_bFoundCrouchTrigger;
bool  g_bPlayerInCrouchTrigger[MAXPLAYERS + 1];

public Plugin myinfo = {
    name        = "L4D2 Slowdown Control",
    author      = "Visor, Sir, darkid, Forgetest, A1m`, Derpduck",
    version     = "2.6.7",
    description = "Manages the water/gunfire slowdown for both teams",
    url         = "https://github.com/ConfoglTeam/ProMod"
};

public void OnPluginStart() {
    g_cvSlowdownGunfireSI = CreateConVar(
    "l4d2_slowdown_gunfire_si", "0.0",
    "Maximum slowdown from gunfire for SI (-1: native slowdown; 0.0: No slowdown, 0.01-1.0: 1%%-100%% slowdown)",
    FCVAR_NONE, true, -1.0, true, 1.0);
    g_fSlowdownGunfireSI = g_cvSlowdownGunfireSI.FloatValue;
    g_cvSlowdownGunfireSI.AddChangeHook(ConVarChanged_SlowdownGunfireSI);

    g_cvSlowdownGunfireTank = CreateConVar(
    "l4d2_slowdown_gunfire_tank", "0.0",
    "Maximum slowdown from gunfire for the Tank (-1: native slowdown; 0.0: No slowdown, 0.01-1.0: 1%%-100%% slowdown)",
    FCVAR_NONE, true, -1.0, true, 1.0);
    g_fSlowdownGunfireTank = g_cvSlowdownGunfireTank.FloatValue;
    g_cvSlowdownGunfireTank.AddChangeHook(ConVarChanged_SlowdownGunfireTank);

    g_cvSlowdownInWaterTank = CreateConVar(
    "l4d2_slowdown_water_tank", "-1",
    "Maximum tank speed in the water (-1: ignore setting; 0: default; 210: default Tank Speed)",
    FCVAR_NONE, true, -1.0, false, 0.0);
    g_fSlowdownInWaterTank = g_cvSlowdownInWaterTank.FloatValue;
    g_cvSlowdownInWaterTank.AddChangeHook(ConVarChanged_SlowdownInWaterTank);

    g_cvSlowdownInWaterSurvivor = CreateConVar(
    "l4d2_slowdown_water_survivors", "-1",
    "Maximum survivor speed in the water outside of Tank fights (-1: ignore setting; 0: default; 220: default Survivor speed)",
    FCVAR_NONE, true, -1.0, false, 0.0);
    g_fSlowdownInWaterSurvivor = g_cvSlowdownInWaterSurvivor.FloatValue;
    g_cvSlowdownInWaterSurvivor.AddChangeHook(ConVarChanged_SlowdownInWaterSurvivor);

    g_cvSlowdownInWaterDuringTank = CreateConVar(
    "l4d2_slowdown_water_survivors_during_tank", "0",
    "Maximum survivor speed in the water during Tank fights (0: ignore setting; 220: default Survivor speed)",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_fSlowdownInWaterDuringTank = g_cvSlowdownInWaterDuringTank.FloatValue;
    g_cvSlowdownInWaterDuringTank.AddChangeHook(ConVarChanged_SlowdownInWaterDuringTank);

    g_cvCrouchSpeed = CreateConVar(
    "l4d2_slowdown_crouch_speed_mod", "1.0",
    "Modifier of player crouch speed when inside a designated trigger, 75 is the defualt for everyone (1: default speed)",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_fCrouchSpeed = g_cvCrouchSpeed.FloatValue;
    g_cvCrouchSpeed.AddChangeHook(ConVarChanged_CrouchSpeed);

    g_cvSlowdownPistol = CreateConVar(
    "l4d2_slowdown_pistol_percent", "0.0",
    "Pistols cause this much slowdown * l4d2_slowdown_gunfire at maximum damage.",
    FCVAR_NONE, true, -1.0, true, 1.0);
    g_fSlowdownPistol = g_cvSlowdownPistol.FloatValue;
    g_cvSlowdownPistol.AddChangeHook(ConVarChanged_SlowdownPistol);

    g_cvSlowdownDeagle = CreateConVar(
    "l4d2_slowdown_deagle_percent", "0.1",
    "Deagles cause this much slowdown * l4d2_slowdown_gunfire at maximum damage.",
    FCVAR_NONE, true, -1.0, true, 1.0);
    g_fSlowdownDeagle = g_cvSlowdownDeagle.FloatValue;
    g_cvSlowdownDeagle.AddChangeHook(ConVarChanged_SlowdownDeagle);

    g_cvSlowdownUzi = CreateConVar(
    "l4d2_slowdown_uzi_percent", "0.8",
    "Unsilenced uzis cause this much slowdown * l4d2_slowdown_gunfire at maximum damage.",
    FCVAR_NONE, true, -1.0, true, 1.0);
    g_fSlowdownUzi = g_cvSlowdownUzi.FloatValue;
    g_cvSlowdownUzi.AddChangeHook(ConVarChanged_SlowdownUzi);

    g_cvSlowdownMac = CreateConVar(
    "l4d2_slowdown_mac_percent", "0.8",
    "Silenced Uzis cause this much slowdown * l4d2_slowdown_gunfire at maximum damage.",
    FCVAR_NONE, true, -1.0, true, 1.0);
    g_fSlowdownMac = g_cvSlowdownMac.FloatValue;
    g_cvSlowdownMac.AddChangeHook(ConVarChanged_SlowdownMac);

    g_cvSlowdownAk = CreateConVar(
    "l4d2_slowdown_ak_percent", "0.8",
    "AKs cause this much slowdown * l4d2_slowdown_gunfire at maximum damage.",
    FCVAR_NONE, true, -1.0, true, 1.0);
    g_fSlowdownAk = g_cvSlowdownAk.FloatValue;
    g_cvSlowdownAk.AddChangeHook(ConVarChanged_SlowdownAk);

    g_cvSlowdownM4 = CreateConVar(
    "l4d2_slowdown_m4_percent", "0.8",
    "M4s cause this much slowdown * l4d2_slowdown_gunfire at maximum damage.",
    FCVAR_NONE, true, -1.0, true, 1.0);
    g_fSlowdownM4 = g_cvSlowdownM4.FloatValue;
    g_cvSlowdownM4.AddChangeHook(ConVarChanged_SlowdownM4);

    g_cvSlowdownScar = CreateConVar(
    "l4d2_slowdown_scar_percent", "0.8",
    "Scars cause this much slowdown * l4d2_slowdown_gunfire at maximum damage.",
    FCVAR_NONE, true, -1.0, true, 1.0);
    g_fSlowdownScar = g_cvSlowdownScar.FloatValue;
    g_cvSlowdownScar.AddChangeHook(ConVarChanged_SlowdownScar);

    g_cvSlowdownPump = CreateConVar(
    "l4d2_slowdown_pump_percent", "0.5",
    "Pump Shotguns cause this much slowdown * l4d2_slowdown_gunfire at maximum damage.",
    FCVAR_NONE, true, -1.0, true, 1.0);
    g_fSlowdownPump = g_cvSlowdownPump.FloatValue;
    g_cvSlowdownPump.AddChangeHook(ConVarChanged_SlowdownPump);

    g_cvSlowdownChrome = CreateConVar(
    "l4d2_slowdown_chrome_percent", "0.5",
    "Chrome Shotguns cause this much slowdown * l4d2_slowdown_gunfire at maximum damage.",
    FCVAR_NONE, true, -1.0, true, 1.0);
    g_fSlowdownChrome = g_cvSlowdownChrome.FloatValue;
    g_cvSlowdownChrome.AddChangeHook(ConVarChanged_SlowdownChrome);

    g_cvSlowdownAuto = CreateConVar(
    "l4d2_slowdown_auto_percent", "0.5",
    "Auto Shotguns cause this much slowdown * l4d2_slowdown_gunfire at maximum damage.",
    FCVAR_NONE, true, -1.0, true, 1.0);
    g_fSlowdownAuto = g_cvSlowdownAuto.FloatValue;
    g_cvSlowdownAuto.AddChangeHook(ConVarChanged_SlowdownAuto);

    g_cvSlowdownRifle = CreateConVar(
    "l4d2_slowdown_rifle_percent", "0.1",
    "Hunting Rifles cause this much slowdown * l4d2_slowdown_gunfire at maximum damage.",
    FCVAR_NONE, true, -1.0, true, 1.0);
    g_fSlowdownRifle = g_cvSlowdownRifle.FloatValue;
    g_cvSlowdownRifle.AddChangeHook(ConVarChanged_SlowdownRifle);

    g_cvSlowdownScout = CreateConVar(
    "l4d2_slowdown_scout_percent", "0.1",
    "Scouts cause this much slowdown * l4d2_slowdown_gunfire at maximum damage.",
    FCVAR_NONE, true, -1.0, true, 1.0);
    g_fSlowdownScout = g_cvSlowdownScout.FloatValue;
    g_cvSlowdownScout.AddChangeHook(ConVarChanged_SlowdownScout);

    g_cvSlowdownMilitary = CreateConVar(
    "l4d2_slowdown_military_percent", "0.1",
    "Military Rifles cause this much slowdown * l4d2_slowdown_gunfire at maximum damage.",
    FCVAR_NONE, true, -1.0, true, 1.0);
    g_fSlowdownMilitary = g_cvSlowdownMilitary.FloatValue;
    g_cvSlowdownMilitary.AddChangeHook(ConVarChanged_SlowdownMilitary);

    g_cvSurvivorLimpspeed = FindConVar("survivor_limp_health");
    g_iSurvivorLimpspeed  = g_cvSurvivorLimpspeed.IntValue;
    g_cvSurvivorLimpspeed.AddChangeHook(ConVarChanged_SurvivorLimpspeed);

    g_cvTankSpeedVS = FindConVar("z_tank_speed_vs");
    g_fTankSpeedVS  = g_cvTankSpeedVS.FloatValue;
    g_cvTankSpeedVS.AddChangeHook(ConVarChanged_TankSpeedVS);

    g_cvPillsDecayRate = FindConVar("pain_pills_decay_rate");
    g_fPillsDecayRate  = g_cvPillsDecayRate.FloatValue;
    g_cvPillsDecayRate.AddChangeHook(ConVarChanged_PillsDecayRate);

    HookEvent("round_start",  Event_RoundStart);
    HookEvent("player_hurt",  Event_PlayerHurt);
}

void ConVarChanged_SlowdownGunfireSI(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fSlowdownGunfireSI = cv.FloatValue;
}
void ConVarChanged_SlowdownGunfireTank(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fSlowdownGunfireTank = cv.FloatValue;
}
void ConVarChanged_SlowdownInWaterTank(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fSlowdownInWaterTank = cv.FloatValue;
}
void ConVarChanged_SlowdownInWaterSurvivor(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fSlowdownInWaterSurvivor = cv.FloatValue;
}
void ConVarChanged_SlowdownInWaterDuringTank(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fSlowdownInWaterDuringTank = cv.FloatValue;
}
void ConVarChanged_CrouchSpeed(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fCrouchSpeed = cv.FloatValue;
}

void ConVarChanged_SlowdownPistol(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fSlowdownPistol = cv.FloatValue;
}
void ConVarChanged_SlowdownDeagle(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fSlowdownDeagle = cv.FloatValue;
}
void ConVarChanged_SlowdownUzi(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fSlowdownUzi = cv.FloatValue;
}
void ConVarChanged_SlowdownMac(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fSlowdownMac = cv.FloatValue;
}
void ConVarChanged_SlowdownAk(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fSlowdownAk = cv.FloatValue;
}
void ConVarChanged_SlowdownM4(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fSlowdownM4 = cv.FloatValue;
}
void ConVarChanged_SlowdownScar(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fSlowdownScar = cv.FloatValue;
}
void ConVarChanged_SlowdownPump(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fSlowdownPump = cv.FloatValue;
}
void ConVarChanged_SlowdownChrome(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fSlowdownChrome = cv.FloatValue;
}
void ConVarChanged_SlowdownAuto(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fSlowdownAuto = cv.FloatValue;
}
void ConVarChanged_SlowdownRifle(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fSlowdownRifle = cv.FloatValue;
}
void ConVarChanged_SlowdownScout(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fSlowdownScout = cv.FloatValue;
}
void ConVarChanged_SlowdownMilitary(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fSlowdownMilitary = cv.FloatValue;
}

void ConVarChanged_SurvivorLimpspeed(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iSurvivorLimpspeed = cv.IntValue;
}
void ConVarChanged_TankSpeedVS(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fTankSpeedVS = cv.FloatValue;
}
void ConVarChanged_PillsDecayRate(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fPillsDecayRate = cv.FloatValue;
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    HookCrouchTriggers();
}

void HookCrouchTriggers() {
    g_bFoundCrouchTrigger = false;
    // Hook trigger_multiple entities that are named "l4d2_slowdown_crouch_speed"
    if (g_fCrouchSpeed != 1.0) {
        // Reset array
        for (int i = 1; i <= MaxClients; i++) {
            g_bPlayerInCrouchTrigger[i] = false;
        }
        int iEntity = -1;
        char szTargetName[128];
        while ((iEntity = FindEntityByClassname(iEntity, "trigger_multiple")) != -1) {
            GetEntPropString(iEntity, Prop_Data, "m_iName", szTargetName, sizeof(szTargetName));
            if (StrEqual(szTargetName, "l4d2_slowdown_crouch_speed", false)) {
                HookSingleEntityOutput(iEntity, "OnStartTouch", CrouchSpeedStartTouch);
                HookSingleEntityOutput(iEntity, "OnEndTouch",   CrouchSpeedEndTouch);
                g_bFoundCrouchTrigger = true;
            }
        }
    }
}

void CrouchSpeedStartTouch(const char[] szOutput, int iCaller, int iActivator, float fDelay) {
    if (iActivator && iActivator <= MaxClients && IsClientInGame(iActivator)) {
        g_bPlayerInCrouchTrigger[iActivator] = true;
    }
}

void CrouchSpeedEndTouch(const char[] szOutput, int iCaller, int iActivator, float fDelay) {
    if (iActivator && iActivator <= MaxClients && IsClientInGame(iActivator)) {
        g_bPlayerInCrouchTrigger[iActivator] = false;
    }
}

/**
 *
 * Slowdown from gunfire: Tank & SI
 *
**/

void Event_PlayerHurt(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (IsInfected(iClient)) {
        float fSlowDown = IsTank(iClient) ? GetActualValue(g_fSlowdownGunfireTank) : GetActualValue(g_fSlowdownGunfireSI);
        if (fSlowDown == 1.0) {
            ApplySlowdown(iClient, fSlowDown);
        } else if (fSlowDown > 0.0) {
            int iDamage = eEvent.GetInt("dmg_health");
            static char szWeapon[64];
            eEvent.GetString("szWeapon", szWeapon, sizeof(szWeapon));
            float fScale;
            float fModifier;
            GetScaleAndModifier(fScale, fModifier, szWeapon, iDamage);
            ApplySlowdown(iClient, 1 - fModifier * fScale * fSlowDown);
        }
    }
}

/**
 *
 * Slowdown from water: Tank & Survivors
 *
**/

public Action L4D_OnGetRunTopSpeed(int iClient, float &fRetVal) {
    if (!IsClientInGame(iClient))
        return Plugin_Continue;

    bool bInWater = (GetEntityFlags(iClient) & FL_INWATER) ? true : false;
    if (IsSurvivor(iClient)) {
        // Adrenaline = Don't care, don't mess with it.
        // Limping = 260 speed (both in water and on the ground)
        // Healthy = 260 speed (both in water and on the ground)
        bool bAdrenaline = GetEntProp(iClient, Prop_Send, "m_bAdrenalineActive") ? true : false;
        if (bAdrenaline)
            return Plugin_Continue;

        // Only bother if survivor is in water and healthy
        if (bInWater && !IsLimping(iClient)) {
            // speed of survivors in water during Tank fights
            if (L4D2_IsTankInPlay()) {
                if (g_fSlowdownInWaterDuringTank == 0.0) {
                    return Plugin_Continue; // Vanilla YEEEEEEEEEEEEEEEs
                } else {
                    fRetVal = g_fSlowdownInWaterDuringTank;
                    return Plugin_Handled;
                }
            } else if (g_fSlowdownInWaterSurvivor != -1.0) {
                // speed of survivors in water outside of Tank fights
                if (g_fSlowdownInWaterSurvivor == 0.0) {
                    // slowdown off
                    fRetVal = SURVIVOR_RUNSPEED;
                    return Plugin_Handled;
                } else {
                    // specific speed
                    fRetVal = g_fSlowdownInWaterSurvivor;
                    return Plugin_Handled;
                }
            }
        }
    } else if (IsInfected(iClient) && IsTank(iClient)) {
        // Only bother the actual speed if player is a tank moving in water
        if (bInWater && g_fSlowdownInWaterTank != -1.0) {
            if (g_fSlowdownInWaterTank == 0.0) {
                // slowdown off
                fRetVal = g_fTankSpeedVS;
                return Plugin_Handled;
            } else {
                // specific speed
                fRetVal = g_fSlowdownInWaterTank;
                return Plugin_Handled;
            }
        }
    }
    return Plugin_Continue;
}

/**
 *
 * Slowdown from crouching: All players
 *
**/
public Action L4D_OnGetCrouchTopSpeed(int iClient, float &fRetVal) {
    if (g_fCrouchSpeed == 1.0 || !g_bFoundCrouchTrigger || !IsClientInGame(iClient)) {
        return Plugin_Continue;
    }
    if (IsPlayerInCrouchTrigger(iClient)) {
        bool bCrouched = (GetEntityFlags(iClient) & FL_DUCKING && GetEntityFlags(iClient) & FL_ONGROUND) ? true : false;
        if (bCrouched) {
            fRetVal = fRetVal * g_fCrouchSpeed; // 75 * fModifier
            return Plugin_Handled;
        }
    }
    return Plugin_Continue;
}

// The old slowdown plugin's cvars weren't quite intuitive, so I'll try to fix it this time
float GetActualValue(float fValue) {
    // native slowdown
    if (fValue == -1.0)
        return -1.0;
    // slowdown off
    if (fValue == 0.0)
        return 1.0;
    // slowdown multiplier
    return CLAMP(fValue, 0.01, 2.0);
}

void ApplySlowdown(int iClient, float fValue) {
    if (fValue == -1.0)
        return;
    SetEntPropFloat(iClient, Prop_Send, "m_flVelocityModifier", fValue);
}

stock int FindTankClient() {
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsInfected(i) || !IsTank(i) || !IsPlayerAlive(i))
            continue;
        // Found tank, return
        return i;
    }
    return 0;
}

bool IsSurvivor(int iClient) {
    return iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient) && GetClientTeam(iClient) == 2;
}

bool IsInfected(int iClient) {
    return iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient) && GetClientTeam(iClient) == 3;
}

bool IsTank(int iClient) {
    return GetEntProp(iClient, Prop_Send, "m_zombieClass") == 8;
}

bool IsLimping(int iClient) {
    // Assume Clientchecks and the like have been done already
    int iPermHealth   = GetClientHealth(iClient);
    float fBuffer     = GetEntPropFloat(iClient, Prop_Send, "m_healthBuffer");
    float fBleedTime  = GetGameTime() - GetEntPropFloat(iClient, Prop_Send, "m_healthBufferTime");
    float fTempHealth = CLAMP(fBuffer - (fBleedTime * g_fPillsDecayRate), 0.0, 100.0); // buffer may be negative, also if pills bleed out then bleedTime may be too large.
    return RoundToFloor(iPermHealth + fTempHealth) < g_iSurvivorLimpspeed;
}

void GetScaleAndModifier(float &fScale, float &fModifier, const char[] szWeapon, int iDamage) {
    // If max slowdown is 20%, and tank takes 10 damage from a chrome shotgun shell, they recieve:
    //// 1 - .5 * 0.434 * .2 = 0.9566 -> 95.6% base speed, or 4.4% slowdown.
    // If max slowdown is 20%, and tank takes 6 damage from a silenced uzi bullet, they recieve:
    //// 1 - .8 * 0.0625 * .2 = 0.99 -> 99% base speed, or 1% slowdown.

    // Weapon  | Max | Min
    // Pistol  | 32  | 9
    // Deagle  | 78  | 19
    // Uzi     | 19  | 9
    // Mac     | 24  | 0 <- Deals no damage at long range.
    // AK      | 57  | 0 <- Deals no damage at long range.
    // M4      | 32  | 0
    // Scar    | 43  | 1
    // Pump    | 13  | 2
    // Chrome  | 15  | 2
    // Auto    | 19  | 2
    // Spas    | 23  | 3
    // HR      | 90  | 90 <- No fall-off
    // Scout   | 90  | 90 <- No fall-off
    // Military| 90  | 90 <- No fall-off
    // SMGs and Shotguns are using quadratic scaling, meaning that shooting long ranged is punished more harshly.
    if (strcmp(szWeapon, "melee") == 0) {
        // Melee damage scales with tank health, so don't bother handling it here.
        fScale = 1.0;
        fModifier = 0.0;
    } else if (strcmp(szWeapon, "pistol") == 0) {
        fScale = SCALE(iDamage, 9.0, 32.0);
        fModifier = g_fSlowdownPistol;
    } else if (strcmp(szWeapon, "pistol_magnum") == 0) {
        fScale = SCALE(iDamage, 19.0, 78.0);
        fModifier = g_fSlowdownDeagle;
    } else if (strcmp(szWeapon, "smg") == 0) {
        fScale = SCALE2(iDamage, 9.0, 19.0);
        fModifier = g_fSlowdownUzi;
    } else if (strcmp(szWeapon, "smg_silenced") == 0) {
        fScale = SCALE2(iDamage, 0.0, 24.0);
        fModifier = g_fSlowdownMac;
    } else if (strcmp(szWeapon, "rifle_ak47") == 0) {
        fScale = SCALE2(iDamage, 0.0, 57.0);
        fModifier = g_fSlowdownAk;
    } else if (strcmp(szWeapon, "rifle") == 0) {
        fScale = SCALE2(iDamage, 0.0, 32.0);
        fModifier = g_fSlowdownM4;
    } else if (strcmp(szWeapon, "rifle_desert") == 0) {
        fScale = SCALE2(iDamage, 1.0, 43.0);
        fModifier = g_fSlowdownScar;
    } else if (strcmp(szWeapon, "pumpshotgun") == 0) {
        fScale = SCALE2(iDamage, 2.0, 13.0);
        fModifier = g_fSlowdownPump;
    } else if (strcmp(szWeapon, "shotgun_chrome") == 0) {
        fScale = SCALE2(iDamage, 2.0, 15.0);
        fModifier = g_fSlowdownChrome;
    } else if (strcmp(szWeapon, "autoshotgun") == 0) {
        fScale = SCALE2(iDamage, 2.0, 19.0);
        fModifier = g_fSlowdownAuto;
    } else if (strcmp(szWeapon, "shotgun_spas") == 0) {
        fScale = SCALE2(iDamage, 3.0, 23.0);
        fModifier = g_fSlowdownAuto;
    } else if (strcmp(szWeapon, "hunting_rifle") == 0) {
        fScale = SCALE(iDamage, 90.0, 90.0);
        fModifier = g_fSlowdownRifle;
    } else if (strcmp(szWeapon, "sniper_scout") == 0) {
        fScale = SCALE(iDamage, 90.0, 90.0);
        fModifier = g_fSlowdownScout;
    } else if (strcmp(szWeapon, "sniper_military") == 0) {
        fScale = SCALE(iDamage, 90.0, 90.0);
        fModifier = g_fSlowdownMilitary;
    } else {
        fScale = 1.0;
        fModifier = 0.0;
    }
}

bool IsPlayerInCrouchTrigger(int iClient) {
    if (iClient && iClient <= MaxClients && IsClientInGame(iClient) && IsPlayerAlive(iClient))
        return g_bPlayerInCrouchTrigger[iClient];
    return false;
}