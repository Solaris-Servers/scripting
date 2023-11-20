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

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <l4d2util/constants>

enum {
    DoorsTypeTracked_None = -1,
    DoorsTypeTracked_Prop_Door_Rotating = 0,
    DoorsTypeTracked_Prop_Door_Rotating_Checkpoint = 1
};

static const char g_szDoors_Type_Tracked[][ENTITY_MAX_NAME_LENGTH] = {
    "prop_door_rotating",
    "prop_door_rotating_checkpoint"
};

enum struct DoorsData {
    int   DoorsData_Type;
    float DoorsData_Speed;
    bool  DoorsData_ForceClose;
}

DoorsData g_ddDoors[MAX_EDICTS];

ConVar g_cvDoorSpeed;
float  g_fDoorSpeed;

public Plugin myinfo = {
    name        = "Tickrate Fixes",
    author      = "Sir, Griffin, A1m`",
    description = "Fixes a handful of silly Tickrate bugs",
    version     = "1.4",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
}

public void OnPluginStart() {
    // Slow Doors
    g_cvDoorSpeed = CreateConVar(
    "tick_door_speed", "1.3",
    "Sets the speed of all prop_door entities on a map. 1.05 means = 105% speed",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_fDoorSpeed = g_cvDoorSpeed.FloatValue;
    g_cvDoorSpeed.AddChangeHook(ConVarChanged_DoorSpeed);

    Door_ClearSettingsAll();
    Door_GetSettingsAll();
    Door_SetSettingsAll();

    // Gravity
    ConVar cv = FindConVar("sv_gravity");
    cv.SetInt(765, true, false);
}

void ConVarChanged_DoorSpeed(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fDoorSpeed = cv.FloatValue;
    Door_SetSettingsAll();
}

public void OnPluginEnd() {
    ConVar cv = FindConVar("sv_gravity");
    cv.RestoreDefault();
    Door_ResetSettingsAll();
}

public void OnEntityCreated(int iEnt, const char[] szClsName) {
    if (szClsName[0] != 'p') return;
    for (int i = 0; i < sizeof(g_szDoors_Type_Tracked); i++) {
        if (strcmp(szClsName, g_szDoors_Type_Tracked[i], false) != 0)
            continue;
        SDKHook(iEnt, SDKHook_SpawnPost, Hook_DoorSpawnPost);
    }
}

void Hook_DoorSpawnPost(int iEnt) {
    if (!IsValidEntity(iEnt)) return;

    char szClsName[ENTITY_MAX_NAME_LENGTH];
    GetEntityClassname(iEnt, szClsName, sizeof(szClsName));

    // Save Original Settings.
    for (int i = 0; i < sizeof(g_szDoors_Type_Tracked); i++) {
        if (strcmp(szClsName, g_szDoors_Type_Tracked[i], false) != 0)
            continue;
        Door_GetSettings(iEnt, i);
    }
    // Set Settings.
    Door_SetSettings(iEnt);
}

void Door_SetSettingsAll() {
    int iEnt = -1;
    for (int i = 0; i < sizeof(g_szDoors_Type_Tracked); i++) {
        while ((iEnt = FindEntityByClassname(iEnt, g_szDoors_Type_Tracked[i])) != INVALID_ENT_REFERENCE) {
            Door_SetSettings(iEnt);
            SetEntProp(iEnt, Prop_Data, "m_bForceClosed", false);
        }
        iEnt = -1;
    }
}

void Door_SetSettings(int iEnt) {
    float fSpeed = g_ddDoors[iEnt].DoorsData_Speed * g_fDoorSpeed;
    SetEntPropFloat(iEnt, Prop_Data, "m_flSpeed", fSpeed);
}

void Door_ResetSettingsAll() {
    int iEnt = -1;
    for (int i = 0; i < sizeof(g_szDoors_Type_Tracked); i++) {
        while ((iEnt = FindEntityByClassname(iEnt, g_szDoors_Type_Tracked[i])) != INVALID_ENT_REFERENCE) {
            Door_ResetSettings(iEnt);
        }
        iEnt = -1;
    }
}

void Door_ResetSettings(int iEnt) {
    float fSpeed = g_ddDoors[iEnt].DoorsData_Speed;
    SetEntPropFloat(iEnt, Prop_Data, "m_flSpeed", fSpeed);
}

void Door_GetSettingsAll() {
    int iEnt = -1;
    for (int i = 0; i < sizeof(g_szDoors_Type_Tracked); i++) {
        while ((iEnt = FindEntityByClassname(iEnt, g_szDoors_Type_Tracked[i])) != INVALID_ENT_REFERENCE) {
            Door_GetSettings(iEnt, i);
        }
        iEnt = -1;
    }
}

void Door_GetSettings(int iEnt, int iDoorType) {
    g_ddDoors[iEnt].DoorsData_Type = iDoorType;
    g_ddDoors[iEnt].DoorsData_Speed = GetEntPropFloat(iEnt, Prop_Data, "m_flSpeed");
    g_ddDoors[iEnt].DoorsData_ForceClose = view_as<bool>(GetEntProp(iEnt, Prop_Data, "m_bForceClosed"));
}

void Door_ClearSettingsAll() {
    for (int i = 0; i < MAX_EDICTS; i++) {
        g_ddDoors[i].DoorsData_Type = DoorsTypeTracked_None;
        g_ddDoors[i].DoorsData_Speed = 0.0;
        g_ddDoors[i].DoorsData_ForceClose = false;
    }
}