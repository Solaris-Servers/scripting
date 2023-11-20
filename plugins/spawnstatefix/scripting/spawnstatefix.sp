/*
        Finale Can't Spawn Glitch Fix (C) 2014 Michael Busby
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

// Offset of the prop we're looking for from m_ghostSpawnState,
// since its relative offset should be more stable than other stuff...
#define OFFS_FROM_SPAWNSTATE 0x26

// Spawn State - These look like flags, but get used like static values quite often.
// These names were pulled from reversing client.dll--specifically CHudGhostPanel::OnTick()'s uses of the "#L4D_Zombie_UI_*" strings
#define SPAWN_OK             0
#define SPAWN_DISABLED       1  // "Spawning has been disabled..." (e.g. director_no_specials 1)
#define WAIT_FOR_SAFE_AREA   2  // "Waiting for the Survivors to leave the safe area..."
#define WAIT_FOR_FINALE      4  // "Waiting for the finale to begin..."
#define WAIT_FOR_TANK        8  // "Waiting for Tank battle conclusion..."
#define SURVIVOR_ESCAPED    16  // "The Survivors have escaped..."
#define DIRECTOR_TIMEOUT    32  // "The Director has called a time-out..." (lol wat)
#define WAIT_FOR_STAMPEDE   64  // "Waiting for the next stampede of Infected..."
#define CAN_BE_SEEN        128  // "Can't spawn here" "You can be seen by the Survivors"
#define TOO_CLOSE          256  // "Can't spawn here" "You are too close to the Survivors"
#define RESTRICTED_AREA    512  // "Can't spawn here" "This is a restricted area"
#define INSIDE_ENTITY     1024  // "Can't spawn here" "Something is blocking this spot"

int g_SawSurvivorsOutsideBattlefieldOffset;
bool g_bAutoFixThisMap = false;

public Plugin myinfo = {
    name        = "Finale Can't Spawn Glitch Fix",
    author      = "ProdigySim",
    description = "Fixing Waiting For Survivors To Start The Finale or w/e",
    version     = "1.1",
    url         = "https://github.com/ConfoglTeam/ProMod"
}

public void OnPluginStart() {
    g_SawSurvivorsOutsideBattlefieldOffset = FindSendPropInfo("CTerrorPlayer", "m_ghostSpawnState") + OFFS_FROM_SPAWNSTATE;
    RegAdminCmd("sm_fix_wff", AdminFixWaitingForFinale, ADMFLAG_GENERIC, "Manually fix the 'Waiting for finale to start' issue for all infected.");
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

public void OnMapStart() {
    char szMapName[200];
    GetCurrentMap(szMapName, sizeof(szMapName));
    g_bAutoFixThisMap = (strcmp("uf4_airfield", szMapName) == 0);
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    CreateTimer(1.0, Timer_FixAllInfected, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_FixAllInfected(Handle hTimer) {
    if (g_bAutoFixThisMap) FixAllInfected();
    return Plugin_Stop;
}

void FixAllInfected() {
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))    continue;
        if (GetClientTeam(i) != 3) continue;
        SetSeenSurvivorsState(i, true);
        // This part shouldn't be necessary, but just for good measure:
        // Remove the "WAIT_FOR_FINALE" spawn flag
        SetSpawnFlags(i, GetSpawnFlags(i) & ~WAIT_FOR_FINALE);
    }
}


Action AdminFixWaitingForFinale(int client, int args) {
    FixAllInfected();
    return Plugin_Handled;
}

// Spawn State - These look like flags, but get used like static values quite often.
// These names were pulled from reversing client.dll--specifically CHudGhostPanel::OnTick()'s uses of the "#L4D_Zombie_UI_*" strings
//
// SPAWN_OK             0
// SPAWN_DISABLED       1  "Spawning has been disabled..." (e.g. director_no_specials 1)
// WAIT_FOR_SAFE_AREA   2  "Waiting for the Survivors to leave the safe area..."
// WAIT_FOR_FINALE      4  "Waiting for the finale to begin..."
// WAIT_FOR_TANK        8  "Waiting for Tank battle conclusion..."
// SURVIVOR_ESCAPED    16  "The Survivors have escaped..."
// DIRECTOR_TIMEOUT    32  "The Director has called a time-out..." (lol wat)
// WAIT_FOR_STAMPEDE   64  "Waiting for the next stampede of Infected..."
// CAN_BE_SEEN        128  "Can't spawn here" "You can be seen by the Survivors"
// TOO_CLOSE          256  "Can't spawn here" "You are too close to the Survivors"
// RESTRICTED_AREA    512  "Can't spawn here" "This is a restricted area"
// INSIDE_ENTITY     1024  "Can't spawn here" "Something is blocking this spot"

stock void SetSpawnFlags(int iEnt, int iFlags) {
    SetEntProp(iEnt, Prop_Send, "m_ghostSpawnState", iFlags);
}

stock int GetSpawnFlags(int iEnt) {
    return GetEntProp(iEnt, Prop_Send, "m_ghostSpawnState");
}

stock bool GetSeenSurvivorsState(int iEnt) {
    return view_as<bool>(GetEntData(iEnt, g_SawSurvivorsOutsideBattlefieldOffset, 1));
}

stock void SetSeenSurvivorsState(int iEnt, bool bSeen) {
    SetEntData(iEnt, g_SawSurvivorsOutsideBattlefieldOffset, bSeen ? 1: 0, 1);
}