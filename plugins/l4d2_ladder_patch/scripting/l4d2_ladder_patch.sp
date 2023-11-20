/*
*   [L4D2] Ladder Server Crash - Patch Fix
*   Copyright (C) 2022 Silvers
*
*   This program is free software: you can redistribute it and/or modify
*   it under the terms of the GNU General Public License as published by
*   the Free Software Foundation, either version 3 of the License, or
*   (at your option) any later version.
*
*   This program is distributed in the hope that it will be useful,
*   but WITHOUT ANY WARRANTY; without even the implied warranty of
*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*   GNU General Public License for more details.
*
*   You should have received a copy of the GNU General Public License
*   along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

/*======================================================================================
    Plugin Info:

*   Name    :   [L4D2] Ladder Server Crash - Patch Fix
*   Author  :   SilverShot
*   Descrp  :   Fixes a server crash from NavLadder::GetPosAtHeight. Patches out AvoidNeighbors.
*   Link    :   https://forums.alliedmods.net/showthread.php?t=336298
*   Plugins :   https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
    Change Log:

1.1 (12-Feb-2022)
    - Detour method scrapped in favour of patching out calls to 'AvoidNeighbors' function.
    - Plugin and GameData file updated.

1.0 (10-Feb-2022)
    - Official release.

0.4 (21-Jan-2022)
    - Added debugging log when an error is detected. Saved to "logs/ladder_patch.log" printing map and position of ladder.

0.3 (21-Jan-2022)
    - Beta release checking the problem offset. Thanks to "Dragokas" for reporting.

0.2 (21-Jan-2022)
    - Beta release with MemoryEx support.

0.1 (21-Jan-2022)
    - Initial beta release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define GAMEDATA "l4d2_ladder_patch"

public Plugin myinfo = {
    name        = "[L4D2] Ladder Server Crash - Patch Fix",
    author      = "SilverShot and Peace-Maker",
    description = "Fixes a server crash from NavLadder::GetPosAtHeight. Patches out AvoidNeighbors.",
    version     = "1.1",
    url         = "https://forums.alliedmods.net/showthread.php?t=336298"
}

public void OnPluginStart() {
    char szPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, szPath, sizeof(szPath), "gamedata/%s.txt", GAMEDATA);
    if (!FileExists(szPath)) SetFailState("\n==========\nMissing required file: \"%s\".\nRead installation instructions again.\n==========", szPath);
    GameData gmData = new GameData(GAMEDATA);
    if (gmData == null) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);
    int iByte;
    int iOffset;
    Address aPatch;
    // Patch 1
    iOffset = gmData.GetOffset("Patch_ChaseVictim");
    aPatch  = gmData.GetAddress("ChaseVictim::Update");
    if (!aPatch)
        SetFailState("Error finding the \"ChaseVictim::Update\" signature.");
    iByte = LoadFromAddress(aPatch + view_as<Address>(iOffset), NumberType_Int8);
    if (iByte == 0xE8) {
        for (int i = 0; i < 5; i++) {
            StoreToAddress(aPatch + view_as<Address>(iOffset + i), 0x90, NumberType_Int8);
        }
    } else if (iByte != 0x90) {
        SetFailState("Error: the \"Patch_ChaseVictim\" offset %d is incorrect.", iOffset);
    }
    // Patch 2
    iOffset = gmData.GetOffset("Patch_InfectedFlee");
    aPatch  = gmData.GetAddress("InfectedFlee::Update");
    if (!aPatch)
        SetFailState("Error finding the \"InfectedFlee::Update\" signature.");
    iByte = LoadFromAddress(aPatch + view_as<Address>(iOffset), NumberType_Int8);
    if (iByte == 0xE8) {
        for (int i = 0; i < 5; i++) {
            StoreToAddress(aPatch + view_as<Address>(iOffset + i), 0x90, NumberType_Int8);
        }
    } else if (iByte != 0x90) {
        SetFailState("Error: the \"Patch_InfectedFlee\" offset %d is incorrect.", iOffset);
    }
    delete gmData;
}