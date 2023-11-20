/*
*   Console Spam Patches
*   Copyright (C) 2021 Silvers
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

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define GAMEDATA   "l4d_console_spam"
#define MAX_PATCHES 50

public Plugin myinfo = {
    name        = "[L4D & L4D2] Console Spam Patches",
    author      = "SilverShot",
    description = "Prevents certain errors/warnings from being displayed in the server console.",
    version     = "1.3b",
    url         = "https://forums.alliedmods.net/showthread.php?t=316612"
}

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    EngineVersion evGame = GetEngineVersion();
    if (evGame != Engine_Left4Dead && evGame != Engine_Left4Dead2) {
        strcopy(szError, iErrMax, "Plugin only supports Left 4 Dead 1 & 2.");
        return APLRes_SilentFailure;
    }
    return APLRes_Success;
}

public void OnPluginStart() {
    GameData gmData = new GameData("l4d_console_spam");
    if (gmData == null) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);
    Address aPatch;
    char    szTemp[32];
    int     iLoop = 1;
    int     iDone = 0;
    while (iLoop <= MAX_PATCHES) {
        Format(szTemp, sizeof(szTemp), "SpamPatch_Sig%d", iLoop);
        aPatch = GameConfGetAddress(gmData, szTemp);
        if (aPatch) {
            StoreToAddress(aPatch, 0x00, NumberType_Int8);
            iDone++;
        }
        iLoop++;
    }
    PrintToServer("[Console Spam] patched %d entries.", iDone);
    delete gmData;
}