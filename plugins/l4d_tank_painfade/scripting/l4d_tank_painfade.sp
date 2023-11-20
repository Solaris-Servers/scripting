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

#define FADE_COLOR_R     128
#define FADE_COLOR_G     0
#define FADE_COLOR_B     0
#define FADE_ALPHA_LEVEL 128

#define FLAG_NONE    (0<<0)
#define FLAG_UZI     (1<<1)
#define FLAG_SHOTGUN (1<<2)
#define FLAG_SNIPER  (1<<3)
#define FLAG_MELEE   (1<<4)

#define ZC_TANK 8

StringMap g_WeaponsTrie;

enum eStrWeaponType {
    eWeaponTypeUzi,
    eWeaponTypeShotgun,
    eWeaponTypeSniper,
    eWeaponTypeMelee
};

ConVar g_cvEnabled;
bool g_bEnabled;

ConVar g_cvFadeDuration;
int    g_iFadeDuration;

ConVar g_cvWeaponFlags;
int    g_iWeaponFlags;

public Plugin myinfo = {
    name        = "L4D Tank Pain Fade",
    author      = "Visor",
    version     = "1.1",
    description = "Tank's screen fades into red when taking damage",
    url         = "https://github.com/Attano/Equilibrium"
};

public void OnPluginStart() {
    g_cvEnabled = CreateConVar(
    "l4d_tank_painfade", "1",
    "Enable/disable plugin",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bEnabled = g_cvEnabled.BoolValue;
    g_cvEnabled.AddChangeHook(ConVarChange);

    g_cvFadeDuration = CreateConVar("l4d_tank_painfade_duration", "150",
    "Fade duration in ticks",
    FCVAR_NONE, true, 0.0, true, 300.0);
    g_iFadeDuration = g_cvFadeDuration.IntValue;
    g_cvFadeDuration.AddChangeHook(ConVarChange);

    g_cvWeaponFlags = CreateConVar(
    "l4d_tank_painfade_flags", "8",
    "What kind of weapons will cause the fade effect(1:Uzi,2:Shotgun,4:Sniper,8:Melee)",
    FCVAR_NONE, true, 1.0, true, 15.0);
    g_iWeaponFlags = g_cvWeaponFlags.IntValue;
    g_cvWeaponFlags.AddChangeHook(ConVarChange);

    g_WeaponsTrie = new StringMap();
    // FLAG_UZI (1<<1)
    g_WeaponsTrie.SetValue("smg",              eWeaponTypeUzi);
    g_WeaponsTrie.SetValue("smg_silenced",     eWeaponTypeUzi);
    g_WeaponsTrie.SetValue("smg_mp5",          eWeaponTypeUzi);
    // FLAG_SHOTGUN (1<<2)
    g_WeaponsTrie.SetValue("pumpshotgun",      eWeaponTypeShotgun);
    g_WeaponsTrie.SetValue("shotgun_chrome",   eWeaponTypeShotgun);
    g_WeaponsTrie.SetValue("autoshotgun",      eWeaponTypeShotgun);
    g_WeaponsTrie.SetValue("shotgun_spas",     eWeaponTypeShotgun);
    // FLAG_SNIPER (1<<3)
    g_WeaponsTrie.SetValue("hunting_rifle",    eWeaponTypeSniper);
    g_WeaponsTrie.SetValue("sniper_military",  eWeaponTypeSniper);
    g_WeaponsTrie.SetValue("sniper_awp",       eWeaponTypeSniper);
    g_WeaponsTrie.SetValue("sniper_scout",     eWeaponTypeSniper);
    // FLAG_MELEE (1<<4)
    g_WeaponsTrie.SetValue("fireaxe",          eWeaponTypeMelee);
    g_WeaponsTrie.SetValue("frying_pan",       eWeaponTypeMelee);
    g_WeaponsTrie.SetValue("machete",          eWeaponTypeMelee);
    g_WeaponsTrie.SetValue("baseball_bat",     eWeaponTypeMelee);
    g_WeaponsTrie.SetValue("crowbar",          eWeaponTypeMelee);
    g_WeaponsTrie.SetValue("cricket_bat",      eWeaponTypeMelee);
    g_WeaponsTrie.SetValue("tonfa",            eWeaponTypeMelee);
    g_WeaponsTrie.SetValue("katana",           eWeaponTypeMelee);
    g_WeaponsTrie.SetValue("knife",            eWeaponTypeMelee);
    g_WeaponsTrie.SetValue("golfclub",         eWeaponTypeMelee);
    g_WeaponsTrie.SetValue("shovel",           eWeaponTypeMelee);
    g_WeaponsTrie.SetValue("pitchfork",        eWeaponTypeMelee);

    HookEvent("player_hurt", PlayerHurt);
}

void ConVarChange(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bEnabled      = g_cvEnabled.BoolValue;
    g_iFadeDuration = g_cvFadeDuration.IntValue;
    g_iWeaponFlags  = g_cvWeaponFlags.IntValue;
}

void PlayerHurt(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!g_bEnabled || g_iFadeDuration == 0 || g_iWeaponFlags == FLAG_NONE)
        return;
    char szWeapon[16];
    eEvent.GetString("weapon", szWeapon, sizeof(szWeapon));
    int iVictim = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iVictim < 1 || !IsClientInGame(iVictim) || IsFakeClient(iVictim) || GetClientTeam(iVictim) != 3)
        return;
    if (GetEntProp(iVictim, Prop_Send, "m_zombieClass") != ZC_TANK)
        return;
    if (g_iWeaponFlags & IdentifyWeapon(szWeapon))
        UTIL_ScreenFade(iVictim, 1, g_iFadeDuration, 0, FADE_COLOR_R, FADE_COLOR_G, FADE_COLOR_B, FADE_ALPHA_LEVEL);
}

int IdentifyWeapon(const char[] szWeapon) {
    eStrWeaponType eWeaponType;
    if (g_WeaponsTrie.GetValue(szWeapon, eWeaponType)) {
        if (eWeaponType == eWeaponTypeUzi) {
            return FLAG_UZI;
        } else if (eWeaponType == eWeaponTypeShotgun) {
            return FLAG_SHOTGUN;
        } else if (eWeaponType == eWeaponTypeSniper) {
            return FLAG_SNIPER;
        } else if (eWeaponType == eWeaponTypeMelee) {
            return FLAG_MELEE;
        }
    }
    return FLAG_NONE;
}

/**
 * Fade a player's screen to a specified color.
 *
 * @note Refer to https://developer.valvesoftware.com/wiki/UTIL_ScreenFade for the list of flags and more info
 *
 * @param iClient        Client id whose screen we need faded
 * @param iDuration      Time(in engine ticks) the fade holds for
 * @param iTime          Time(in engine ticks) it takes to fade
 * @param iFlags         Flags to apply to the fade effect
 * @param iRed           Amount of red
 * @param iGreen         Amount of green
 * @param iBlue          Amount of blue
 * @param iAlpha         Alpha level
 * @noreturn
 */
stock void UTIL_ScreenFade(int iClient, int iDuration, int iTime, int iFlags, int iRed, int iGreen, int iBlue, int iAlpha) {
    int iClients[1];
    Handle hMessage;
    iClients[0] = iClient;
    hMessage = StartMessage("Fade", iClients, 1);
    BfWriteShort(hMessage, iDuration);
    BfWriteShort(hMessage, iTime);
    BfWriteShort(hMessage, iFlags);
    BfWriteByte(hMessage,  iRed);
    BfWriteByte(hMessage,  iGreen);
    BfWriteByte(hMessage,  iBlue);
    BfWriteByte(hMessage,  iAlpha);
    EndMessage();
}