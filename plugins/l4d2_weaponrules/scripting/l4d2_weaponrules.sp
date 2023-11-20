/*
    SourcePawn is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
    SourceMod is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
    Pawn and SMALL are Copyright (C) 1997-2008 ITB CompuPhase.
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
#include <l4d2util>

int g_iGlobalWeaponRules[WEPID_SIZE] = {-1, ...};

public Plugin myinfo = {
    name        = "L4D2 Weapon Rules",
    author      = "ProdigySim",
    version     = "1.0.2",
    description = "^",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart() {
    RegServerCmd("l4d2_addweaponrule",    Cmd_AddWeaponRule);
    RegServerCmd("l4d2_resetweaponrules", Cmd_ResetWeaponRules);

    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

    ResetWeaponRules();
}

Action Cmd_AddWeaponRule(int iArgs) {
    if (iArgs < 2) {
        PrintToServer("Usage: l4d2_addweaponrule <match> <replace>");
        return Plugin_Handled;
    }

    char szWeaponBuf[64];
    GetCmdArg(1, szWeaponBuf, sizeof(szWeaponBuf));

    int iMatch = WeaponNameToId2(szWeaponBuf);
    GetCmdArg(2, szWeaponBuf, sizeof(szWeaponBuf));

    int iReplace = WeaponNameToId2(szWeaponBuf);
    AddWeaponRule(iMatch, iReplace);
    return Plugin_Handled;
}

void AddWeaponRule(int iMatch, int iReplace) {
    if (IsValidWeaponId(iMatch) && (iReplace == -1 || IsValidWeaponId(iReplace)))
        g_iGlobalWeaponRules[iMatch] = iReplace;
}

Action Cmd_ResetWeaponRules(int iArgs) {
    ResetWeaponRules();
    return Plugin_Handled;
}

void ResetWeaponRules() {
    for (int i = 0; i < WEPID_SIZE; i++) {
        g_iGlobalWeaponRules[i] = -1;
    }
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    CreateTimer(0.3, Timer_RoundStart, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_RoundStart(Handle hTimer) {
    WeaponSearchLoop();
    return Plugin_Stop;
}

void WeaponSearchLoop() {
    int iEntityCount = GetEntityCount();
    for (int i = 1; i <= iEntityCount; i++) {
        int iSource = IdentifyWeapon(i);
        if (iSource > WEPID_NONE && g_iGlobalWeaponRules[iSource] != -1) {
            if (g_iGlobalWeaponRules[iSource] == WEPID_NONE) {
                RemoveEntity(i);
            } else {
                ConvertWeaponSpawn(i, g_iGlobalWeaponRules[iSource]);
            }
        }
    }
}

// Tries the given weapon name directly, and upon failure,
// tries prepending "weapon_" to the given name
stock int WeaponNameToId2(const char[] szName) {
    static char szNameBuf[64] = "weapon_";
    int iWepId = WeaponNameToId(szName);
    if (iWepId == WEPID_NONE) {
        strcopy(szNameBuf[7], sizeof(szNameBuf) - 7, szName);
        iWepId = WeaponNameToId(szNameBuf);
    }
    return iWepId;
}