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
#include <sdktools>

#define RGBA_INT(%0,%1,%2,%3) (((%0)<<24) + ((%1)<<16) + ((%2)<<8) + (%3))

static const int NULL_ALARMARRAY[eAlarmArraySize] = {
    INVALID_ENT_REFERENCE,
    INVALID_ENT_REFERENCE,
    false,
    INVALID_ENT_REFERENCE,
    0
};

StringMap g_smCarNameMap;
ArrayList g_arrAlarm;
ConVar    g_cvStartDisabled;
ConVar    g_cvDebug;

enum /* eAlarmArray */ {
    ENTRY_RELAY_ON,
    ENTRY_RELAY_OFF,
    ENTRY_START_STATE,
    ENTRY_ALARM_CAR,
    ENTRY_COLOR,
    eAlarmArraySize
}

bool g_bRoundIsLive;
bool g_bIsSecondHalf;

static const int g_iOffColors[] = {
//            R,   G,   B,   A
    RGBA_INT(99,  135, 157, 255),
    RGBA_INT(173, 186, 172, 255),
    RGBA_INT(52,  70,  114, 255),
    RGBA_INT(9,   41,  138, 255),
    RGBA_INT(68,  91,  183, 255),
    RGBA_INT(212, 158, 70,  255),
    RGBA_INT(84,  101, 144, 255),
    RGBA_INT(253, 251, 203, 255)
};

public Plugin myinfo = {
    name        = "L4D2 Equalise Alarm Cars",
    author      = "Jahze, Forgetest",
    version     = "3.8.1",
    description = "Make the alarmed car and its color spawns the same for each team in versus",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

public void OnPluginStart() {
    g_cvStartDisabled = CreateConVar(
    "l4d_equalise_alarm_start_disabled", "1",
    "Makes alarmed cars spawn disabled before game goes live.",
    FCVAR_NOTIFY, true, 0.0, true, 1.0);

    g_cvDebug = CreateConVar(
    "l4d_equalise_alarm_debug", "0",
    "Debug info for alarm stuff.",
    FCVAR_HIDDEN|FCVAR_SPONLY|FCVAR_CHEAT|FCVAR_NOTIFY, true, 0.0, true, 1.0);

    g_smCarNameMap = new StringMap();
    g_arrAlarm     = new ArrayList(eAlarmArraySize);

    HookEvent("round_start",           Event_RoundStart);
    HookEvent("player_left_safe_area", Event_PlayerLeftSafeArea);
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bRoundIsLive = false;
    CreateTimer(0.1, Timer_RoundStartDelay, _, TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(5.0, Timer_InitiateCars,    _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_RoundStartDelay(Handle hTimer) {
    g_bIsSecondHalf = view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"));

    if (!g_bIsSecondHalf) {
        g_smCarNameMap.Clear();
        g_arrAlarm.Clear();
    }

    char szKey[64], szName[128];
    int  iEnt = MaxClients + 1;

    while ((iEnt = FindEntityByClassname(iEnt, "prop_car_alarm")) != INVALID_ENT_REFERENCE) {
        GetEntityName(iEnt, szName, sizeof(szName));
        if (ExtractCarName(szName, "caralarm_car1", szKey, sizeof(szKey)) != 0) {
            int iIdx = -1;
            if (!g_smCarNameMap.GetValue(szKey, iIdx)) {
                // creates a new alarm set
                iIdx = g_arrAlarm.PushArray(NULL_ALARMARRAY[0], sizeof(NULL_ALARMARRAY));
                g_smCarNameMap.SetValue(szKey, iIdx);
                g_arrAlarm.Set(iIdx, EntIndexToEntRef(iEnt), ENTRY_ALARM_CAR);
            } else {
                // updates the alarm car index
                g_arrAlarm.Set(iIdx, EntIndexToEntRef(iEnt), ENTRY_ALARM_CAR);
            }

            float vPos[3];
            GetEntPropVector(iEnt, Prop_Data, "m_vecAbsOrigin", vPos);
            PrintDebug("\x05(ALARM) #%i: caralarm_car1 [%s] [%.0f %.0f %.0f]", iIdx, szKey, vPos[0], vPos[1], vPos[2]);
        }
    }

    iEnt = MaxClients + 1;
    while ((iEnt = FindEntityByClassname(iEnt, "logic_relay")) != INVALID_ENT_REFERENCE) {
        GetEntityName(iEnt, szName, sizeof(szName));

        bool bIsAlarm = false;
        int  iEntry;
        EntityOutput eFunc;

        if (ExtractCarName(szName, "relay_caralarm_on", szKey, sizeof(szKey)) != 0) {
            bIsAlarm = true;
            iEntry = ENTRY_RELAY_ON;
            eFunc = EntO_AlarmRelayOnTriggered;
        } else if (ExtractCarName(szName, "relay_caralarm_off", szKey, sizeof(szKey)) != 0) {
            bIsAlarm = true;
            iEntry = ENTRY_RELAY_OFF;
            eFunc = EntO_AlarmRelayOffTriggered;
        }

        if (bIsAlarm) {
            int iIdx = -1;
            if (g_smCarNameMap.GetValue(szKey, iIdx)) {
                g_arrAlarm.Set(iIdx, iEnt, iEntry);
                HookSingleEntityOutput(iEnt, "OnTrigger", eFunc);
            }

            PrintDebug("\x05(ALARM) #%i: %s [%s]", iIdx, iEntry == ENTRY_RELAY_ON ? "relay_caralarm_on" : "relay_caralarm_off", szKey);
        }
    }

    iEnt = MaxClients + 1;
    while ((iEnt = FindEntityByClassname(iEnt, "logic_case")) != INVALID_ENT_REFERENCE) {
        GetEntityName(iEnt, szName, sizeof(szName));
        if (ExtractCarName(szName, "case_car_color_off", szKey, sizeof(szKey)) != 0) {
            int iEntry = -1;
            if (g_smCarNameMap.GetValue(szKey, iEntry))
                RemoveEntity(iEnt);
        }
    }

    CreateTimer(g_bIsSecondHalf ? 3.0 : 20.0, Timer_DebugPrints, _, TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Stop;
}

Action Timer_InitiateCars(Handle hTimer) {
    if (g_bIsSecondHalf)              return Plugin_Stop;
    if (!g_cvStartDisabled.BoolValue) return Plugin_Stop;
    DisableCars();
    return Plugin_Stop;
}

void EntO_AlarmRelayOnTriggered(const char[] szOutput, int iCaller, int iActivator, float fDelay) {
    int iEntry = g_arrAlarm.FindValue(iCaller, ENTRY_RELAY_ON);
    if (iEntry == -1) {
        ThrowEntryError(ENTRY_RELAY_ON, iCaller); // this should not happen...
        return;
    }
    PrintDebug("\x03(ALARM) #%i: relay_on [activator: %i | delay: %.2f]", iEntry, iActivator, fDelay);
    if (IsValidEntity(iActivator) && !iActivator) {
        RequestFrame(ResetCarColor, iEntry);
        return;
    }
    if (!g_bIsSecondHalf) {
        // first half, record
        g_arrAlarm.Set(iEntry, true, ENTRY_START_STATE);
        RequestFrame(RecordCarColor, iEntry);
    } else if (!g_arrAlarm.Get(iEntry, ENTRY_START_STATE) || (g_cvStartDisabled.BoolValue && !g_bRoundIsLive)) {
        // second half, but differs from first half / needs start disabled
        CreateTimer(fDelay + 0.1, Timer_DisableCar, iEntry, TIMER_FLAG_NO_MAPCHANGE);
    } else {
        // second half, the same as first half
        RequestFrame(ResetCarColor, iEntry);
    }
}

void EntO_AlarmRelayOffTriggered(const char[] szOutput, int iCaller, int iActivator, float fDelay) {
    int iEntry = g_arrAlarm.FindValue(iCaller, ENTRY_RELAY_OFF);
    if (iEntry == -1) {
        ThrowEntryError(ENTRY_RELAY_OFF, iCaller); // this should not happen...
        return;
    }
    PrintDebug("\x05(ALARM) #%i: relay_off [activator: %i | delay: %.2f]", iEntry, iActivator, fDelay);
    // If a car is turned off because of a tank punch or because it was
    // triggered the activator is the car itself. When the cars get
    // randomised the activator is the player who entered the trigger area.
    if (IsValidEntity(iActivator) && (!iActivator || iActivator > MaxClients)) {
        RequestFrame(ResetCarColor, iEntry);
        return;
    }
    if (!g_bIsSecondHalf) {
        // first half, record
        g_arrAlarm.Set(iEntry, false, ENTRY_START_STATE);
        g_arrAlarm.Set(iEntry, GetRandomOffColor(), ENTRY_COLOR);
        RequestFrame(ResetCarColor, iEntry);
    } else if (g_arrAlarm.Get(iEntry, ENTRY_START_STATE) && (!g_cvStartDisabled.BoolValue || g_bRoundIsLive)) {
        CreateTimer(fDelay + 0.1, Timer_EnableCar, iEntry, TIMER_FLAG_NO_MAPCHANGE);
    } else {
        // second half, the same as first half
        RequestFrame(ResetCarColor, iEntry);
    }
}

void RecordCarColor(int iEntry) {
    int iAlarmCar = EntRefToEntIndex(g_arrAlarm.Get(iEntry, ENTRY_ALARM_CAR));
    if (iAlarmCar == -1) return;
    g_arrAlarm.Set(iEntry, GetEntityRenderColorEx(iAlarmCar), ENTRY_COLOR);
}

void ResetCarColor(int iEntry) {
    int iAlarmCar = EntRefToEntIndex(g_arrAlarm.Get(iEntry, ENTRY_ALARM_CAR));
    if (iAlarmCar == -1) return;
    SetEntityRenderColorEx(iAlarmCar, g_arrAlarm.Get(iEntry, ENTRY_COLOR));
}

void SafeRelayTrigger(int iRelay) {
    if (!IsValidEntity(iRelay)) return;
    AcceptEntityInput(iRelay, "Trigger", 0);
}

void Event_PlayerLeftSafeArea(Event event, const char[] name, bool dontBroadcast) {
    if (g_bRoundIsLive) return;
    g_bRoundIsLive = true;
    EnableCars();
}

void EnableCars() {
    for (int i = 0; i < g_arrAlarm.Length; ++i) {
        if (g_arrAlarm.Get(i, ENTRY_START_STATE))
            Timer_EnableCar(null, i);
    }
}

void DisableCars() {
    for (int i = 0; i < g_arrAlarm.Length; ++i) {
        if (g_arrAlarm.Get(i, ENTRY_START_STATE))
            Timer_DisableCar(null, i);
    }
}

Action Timer_EnableCar(Handle hTimer, int iEntry) {
    // if there's no way back...
    if (!IsValidEntity(g_arrAlarm.Get(iEntry, ENTRY_RELAY_OFF)))
        return Plugin_Stop;
    SafeRelayTrigger(g_arrAlarm.Get(iEntry, ENTRY_RELAY_ON));
    return Plugin_Stop;
}

Action Timer_DisableCar(Handle hTimer, int iEntry) {
    // if there's no way back...
    if (!IsValidEntity(g_arrAlarm.Get(iEntry, ENTRY_RELAY_ON)))
        return Plugin_Stop;
    SafeRelayTrigger(g_arrAlarm.Get(iEntry, ENTRY_RELAY_OFF));
    return Plugin_Stop;
}

int ExtractCarName(const char[] szName, const char[] szCompare, char[] szBuffer, int iSize) {
    int iIdx = StrContains(szName, szCompare);
    // Identifier for alarm members doesn't exist.
    if (iIdx == -1) return 0;

    /**
        Formats of alarm car names:
        -
        1. {szName}-{szCompare}
        2. {szCompare}-{szName}
        3. {szCompare}
    **/

    // Format 1:
    if (iIdx > 0) {
        int iNameLen = iIdx-1;

        // Not formatted, but should not happen.
        if (szName[iNameLen] != '-')
            return 0;

        // Compare string is after spilt delimiter.
        strcopy(szBuffer, iSize < iNameLen ? iSize : iNameLen + 1, szName);
        return -1;
    }

    // Format 2:
    int iIdentLen = strlen(szCompare);
    if (szName[iIdentLen] == '-') {
        // Compare string is before spilt delimiter.
        strcopy(szBuffer, iSize, szName[iIdentLen + 1]);
        return 1;
    }

    // Format 3:
    strcopy(szBuffer, iSize, "<DUDE>");
    return 2;
}

void GetEntityName(int iEntity, char[] szBuffer, int iMaxLen) {
    GetEntPropString(iEntity, Prop_Data, "m_iName", szBuffer, iMaxLen);
}

int GetEntityRenderColorEx(int iEntity) {
    int r, g, b, a;
    GetEntityRenderColor(iEntity, r, g, b, a);
    return (r << 24) + (g << 16) + (b << 8) + a;
}

void SetEntityRenderColorEx(int iEntity, int iColor) {
    int r, g, b, a;
    ExtractColorBytes(iColor, r, g, b, a);
    SetEntityRenderColor(iEntity, r, g, b, a);
}

Action Timer_DebugPrints(Handle timer) {
    StringMapSnapshot ss = g_smCarNameMap.Snapshot();
    char szName[128];
    int  iEntry;
    for (int i = 0; i < ss.Length; ++i) {
        ss.GetKey(i, szName, sizeof(szName));
        g_smCarNameMap.GetValue(szName, iEntry);
        int r, g, b, a;
        ExtractColorBytes(g_arrAlarm.Get(iEntry, ENTRY_COLOR), r, g, b, a);
        PrintDebug("\x04(ALARM) #%i [ %s | %s | %s | %s | %i %i %i ]", iEntry,
                                                                       g_arrAlarm.Get(iEntry, ENTRY_RELAY_ON)  == -1 ? "null" : "valid",
                                                                       g_arrAlarm.Get(iEntry, ENTRY_RELAY_OFF) == -1 ? "null" : "valid",
                                                                       g_arrAlarm.Get(iEntry, ENTRY_START_STATE)     ? "On"   : "Off",
                                                                       g_arrAlarm.Get(iEntry, ENTRY_ALARM_CAR) == -1 ? "null" : "valid",
                                                                       r, g, b);
    }
    delete ss;
    return Plugin_Stop;
}

void PrintDebug(const char[] szFormat, any ...) {
    if (!g_cvDebug.BoolValue)
        return;
    char szMsg[256];
    VFormat(szMsg, sizeof(szMsg), szFormat, 2);
    PrintToChatAll("%s", szMsg);
}

stock void ExtractColorBytes(int iColor, int &r, int &g, int &b, int &a) {
    r = (iColor >> 24) & 0xFF;
    g = (iColor >> 16) & 0xFF;
    b = (iColor >>  8) & 0xFF;
    a = (iColor >>  0) & 0xFF;
}

int GetRandomOffColor() {
    return g_iOffColors[GetRandomInt(0, sizeof(g_iOffColors) - 1)];
}

stock void ThrowEntryError(int eEntry, int iEntity) {
    char szName[128];
    GetEntityName(iEntity, szName, sizeof(szName));
    // ThrowError("Fatal: Could not find entry (#%i) for %s", eEntry, szName);
    PrintDebug("Fatal: Could not find entry (#%i) for %s", eEntry, szName);
}