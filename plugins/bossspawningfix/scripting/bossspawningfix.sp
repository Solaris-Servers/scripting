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
#include <sdktools>
#include <left4dhooks>

ConVar g_cvEnabled;
ConVar g_cvSkipStaticMaps;

public Plugin myinfo = {
    name        = "Versus Boss Spawn Persuasion",
    author      = "ProdigySim",
    description = "Makes Versus Boss Spawns obey cvars",
    version     = "1.2",
    url         = "http://compl4d2.com/"
}

public void OnPluginStart() {
    g_cvEnabled = CreateConVar(
    "l4d_obey_boss_spawn_cvars", "1",
    "Enable forcing boss spawns to obey boss spawn cvars");

    g_cvSkipStaticMaps = CreateConVar(
    "l4d_obey_boss_spawn_except_static", "1",
    "Don't override boss spawning rules on Static Tank Spawn maps (c7m1, c13m2)");
}

public Action L4D_OnGetScriptValueInt(const char[] szKey, int &iRetVal) {
    if (g_cvEnabled.BoolValue) {
        if (strcmp(szKey, "DisallowThreatType") == 0) {
            // Stop allowing threat types!
            iRetVal = 0;
            return Plugin_Handled;
        }
        if (strcmp(szKey, "ProhibitBosses") == 0) {
            // Fuck that!
            iRetVal = 0;
            return Plugin_Handled;
        }
    }
    return Plugin_Continue;
}

public Action L4D_OnGetMissionVSBossSpawning(float &fSpawnPosMin, float &fSpawnPosMax, float &fTankChance, float &fWitchChance) {
    if (g_cvEnabled.BoolValue) {
        if (g_cvSkipStaticMaps.BoolValue) {
            char szMapName[32];
            GetCurrentMap(szMapName, sizeof(szMapName));
            if (strcmp(szMapName, "c7m1_docks") == 0 || strcmp(szMapName, "c13m2_southpinestream") == 0)
                return Plugin_Continue;
        }
        return Plugin_Handled;
    }
    return Plugin_Continue;
}