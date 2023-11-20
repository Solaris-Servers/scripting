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
#include <sdkhooks>

bool      g_bLateLoad;
float     g_fWitchDmg;
ArrayList g_arrDeadWitches;
ArrayList g_arrEngagedWitches;

public Plugin myinfo = {
    name        = "Smooth witch damage",
    author      = "Darkid",
    description = "Smooths out the damage taken from a witch while incapped.",
    version     = "1.7",
    url         = "https://github.com/jacob404/Pro-Mod-4.0/releases/latest"
}

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    g_bLateLoad = bLate;
    return APLRes_Success;
}

public void OnPluginStart() {
    if (g_bLateLoad) {
        for (int i = 1; i <= MaxClients; i++) {
            if (!IsClientInGame(i))
                continue;
            OnClientPostAdminCheck(i);
        }
    }

    char szWitchDmg[64];
    FindConVar("z_witch_damage_per_kill_hit").GetString(szWitchDmg, sizeof(szWitchDmg));
    FindConVar("z_witch_damage_per_kill_hit").AddChangeHook(ConVarChanged_WitchDamage);
    g_fWitchDmg = 1.0 * StringToInt(szWitchDmg);

    g_arrDeadWitches    = new ArrayList(64);
    g_arrEngagedWitches = new ArrayList(64);

    HookEvent("round_start",  Event_RoundStart);
    HookEvent("witch_killed", Event_WitchKilled);
}

void ConVarChanged_WitchDamage(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fWitchDmg = 1.0 * StringToInt(szNewVal);
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_arrDeadWitches.Clear();
    g_arrEngagedWitches.Clear();
}

void Event_WitchKilled(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iWitch = eEvent.GetInt("witchid");
    g_arrDeadWitches.Push(EntIndexToEntRef(iWitch));
}

public void OnClientPostAdminCheck(int iClient) {
    SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &fDmg, int &iDmgType) {
    // Check if our victim is valid
    if (iVictim <= 0)             return Plugin_Continue;
    if (iVictim > MaxClients)     return Plugin_Continue;
    if (!IsClientInGame(iVictim)) return Plugin_Continue;

    // Check if attacker is a witch
    if (!IsWitch(iAttacker)) return Plugin_Continue;

    int iWitchRef = EntIndexToEntRef(iAttacker);

    // A hack. We assume the first scratch isn't the same damage as an incap scratch.
    // It's also worth noting that this prevents infinite recursion, since WitchScratch reduces the damage dealt.
    if (fDmg != g_fWitchDmg) return Plugin_Continue;

    if (g_arrEngagedWitches.FindValue(iWitchRef) != -1)
        return Plugin_Stop;

    g_arrEngagedWitches.Push(iWitchRef);

    DataPack dp;
    // The witch scratch animation is every 1/4 second. Repeat until survivor DIES.
    CreateDataTimer(0.25, Timer_WitchScratch, dp, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    dp.WriteCell(GetClientUserId(iVictim));
    dp.WriteCell(iWitchRef);
    dp.WriteCell(iInflictor);
    dp.WriteCell(iDmgType);

    fDmg = g_fWitchDmg / 2.5;
    return Plugin_Continue;
}

Action Timer_WitchScratch(Handle timer, DataPack dp) {
    dp.Reset();
    int iVictim = GetClientOfUserId(dp.ReadCell());

    if (iVictim <= 0)             return Plugin_Stop;
    if (!IsClientInGame(iVictim)) return Plugin_Stop;

    // If defibrillator_use_time is less than .25, this may bug out.
    int iWitchRef = dp.ReadCell();

    if (!IsPlayerAlive(iVictim)) {
        int iIdx = g_arrEngagedWitches.FindValue(iWitchRef);
        if (iIdx != -1) g_arrEngagedWitches.Erase(iIdx);
        return Plugin_Stop;
    }

    int iIdx = g_arrDeadWitches.FindValue(iWitchRef);

    if (iIdx != -1) {
        g_arrDeadWitches.Erase(iIdx);
        iIdx = g_arrEngagedWitches.FindValue(iWitchRef);
        if (iIdx != -1) g_arrEngagedWitches.Erase(iIdx);
        return Plugin_Stop;
    }

    int iWitch = EntRefToEntIndex(iWitchRef);
    if (iWitch <= 0) return Plugin_Stop;

    int iInflictor = dp.ReadCell();
    int iDmgType   = dp.ReadCell();
    SDKHooks_TakeDamage(iVictim, iWitch, iInflictor, g_fWitchDmg / 2.5, iDmgType);
    return Plugin_Continue;
}

stock bool IsWitch(int iEnt) {
    if (iEnt > 0 && IsValidEntity(iEnt)) {
        char szClsName[64];
        GetEdictClassname(iEnt, szClsName, sizeof(szClsName));
        return strcmp(szClsName, "witch") == 0;
    }
    return false;
}