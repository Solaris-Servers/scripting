/*
*    Fixes for gamebreaking bugs and stupid gameplay aspects
*    Copyright (C) 2019  LuxLuma        acceliacat@gmail.com
*
*    This program is free software: you can redistribute it and/or modify
*    it under the terms of the GNU General Public License as published by
*    the Free Software Foundation, either version 3 of the License, or
*    (at your option) any later version.
*
*    This program is distributed in the hope that it will be useful,
*    but WITHOUT ANY WARRANTY; without even the implied warranty of
*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*    GNU General Public License for more details.
*
*    You should have received a copy of the GNU General Public License
*    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define GAMEDATA "hunter_pounce_alignment_fix"

#define MAX_PATCH_SIZE     16 // highest amount of patch bytes needed
#define LINUX_PATCH_SIZE   16
#define WINDOWS_PATCH_SIZE 12

Address
    g_pOriginalAddress;
int g_iOriginalBytes[MAX_PATCH_SIZE];

Handle g_hSetAbsOrigin;
Handle g_hSetAbsVelocity;

enum OS_Type {
    OS_Windows,
    OS_Linux
};

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    if (GetEngineVersion() != Engine_Left4Dead2) {
        strcopy(szError, iErrMax, "Plugin only supports Left 4 Dead 2");
        return APLRes_SilentFailure;
    }

    return APLRes_Success;
}

public Plugin myinfo = {
    name        = "[L4D2 ]Hunter pounce alignment fix",
    author      = "Lux",
    description = "Restores l4d1 style hunter alignment.",
    version     = "2.0",
    url         = "https://github.com/LuxLuma/Left-4-fix/tree/master/left%204%20fix/hunter/Hunter_pounce_alignment_fix"
};

public void OnPluginStart() {
    GameData gmConf = new GameData(GAMEDATA);
    if (!gmConf) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

    StartPrepSDKCall(SDKCall_Entity);
    if (!PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, "CBaseEntity::SetAbsOrigin"))
        SetFailState("Error finding the 'CBaseEntity::SetAbsOrigin' signature.");
    PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
    g_hSetAbsOrigin = EndPrepSDKCall();
    if (g_hSetAbsOrigin == null) SetFailState("Unable to prep SDKCall 'CBaseEntity::SetAbsOrigin'");

    StartPrepSDKCall(SDKCall_Entity);
    if (!PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, "CBaseEntity::SetAbsVelocity"))
        SetFailState("Error finding the 'CBaseEntity::SetAbsVelocity' signature.");
    PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
    g_hSetAbsVelocity = EndPrepSDKCall();
    if (g_hSetAbsVelocity == null) SetFailState("Unable to prep SDKCall 'CBaseEntity::SetAbsVelocity'");

    // nop it :)
    UpdatePounce_Patch(gmConf);
    delete gmConf;
}

void UpdatePounce_Patch(GameData &GameConf) {
    OS_Type os = view_as<OS_Type>(GameConf.GetOffset("OS"));
    g_pOriginalAddress = GameConf.GetAddress("CTerrorPlayer::UpdatePounce::SetAbsVelocity");

    if (g_pOriginalAddress == Address_Null) {
        LogError("Failed to find address 'CTerrorPlayer::UpdatePounce::SetAbsVelocity'");
        return;
    }

    switch (os) {
        case OS_Windows: {
            for (int i = 0; i < WINDOWS_PATCH_SIZE; i++) {
                g_iOriginalBytes[i] = LoadFromAddress(g_pOriginalAddress + view_as<Address>(i), NumberType_Int8);
                StoreToAddress(g_pOriginalAddress + view_as<Address>(i), 0x90, NumberType_Int8);
            }
        }
        case OS_Linux: {
            for (int i = 0; i < LINUX_PATCH_SIZE; i++) {
                g_iOriginalBytes[i] = LoadFromAddress(g_pOriginalAddress + view_as<Address>(i), NumberType_Int8);
                StoreToAddress(g_pOriginalAddress + view_as<Address>(i), 0x90, NumberType_Int8);
            }
        }
    }
}

public void OnPluginEnd() {
    if (g_pOriginalAddress != Address_Null) {
        for (int i = 0; i < MAX_PATCH_SIZE; i++) {
            StoreToAddress(g_pOriginalAddress + view_as<Address>(i), g_iOriginalBytes[i], NumberType_Int8);
        }
    }
}

public void OnEntityCreated(int iEnt, const char[] szEntCls) {
    if (szEntCls[0] == 'h' && strcmp(szEntCls, "hunter", false) == 0)
        SDKHook(iEnt, SDKHook_PostThink, OnPostThink);
}

public void OnClientPutInServer(int iClient) {
    if (!IsFakeClient(iClient))
        SDKHook(iClient, SDKHook_PostThink, OnPostThink);
}

void OnPostThink(int iClient) {
    if (!IsPlayerAlive(iClient) || GetClientTeam(iClient) != 3)
        return;

    int iPounceVictim = GetEntPropEnt(iClient, Prop_Send, "m_pounceVictim");
    if (iPounceVictim <= 0 || !IsPlayerAlive(iPounceVictim) || GetEntPropEnt(iPounceVictim, Prop_Send, "m_pounceAttacker") != iClient) // just incase
        return;

    // copy all the victims origin and velocity data so velocity interpolation can happen clientside
    // and lagcomp is as correct as it can be
    static float vPos[3];
    GetEntPropVector(iPounceVictim, Prop_Data, "m_vecAbsOrigin", vPos); // worldspace origin

    static float vVel[3];
    GetEntPropVector(iPounceVictim, Prop_Data, "m_vecAbsVelocity", vVel);

    // TeleportEntity seems to make the hunter's outline flash to avoid this don't use it :P
    SDKCall(g_hSetAbsOrigin,   iClient, vPos);
    SDKCall(g_hSetAbsVelocity, iClient, vVel);
}