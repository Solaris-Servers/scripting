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

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <solaris/stocks>

#include "modules/admin_commands.sp"
#include "modules/natives.sp"
#include "modules/fixes.sp"

public Plugin myinfo = {
    name        = "[L4D2] Change Level",
    author      = "Lux, IA/NanaNana, 0x0c",
    description = "Creates a clean way to change maps, sm_map causes leaks and other spooky stuff causing server perf to be worse over time.",
    version     = "2.0.0",
    url         = "https://forums.alliedmods.net/showthread.php?p=2669850"
};

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    return Natives_AskPluginLoad2(szError, iErrMax);
}

public void OnPluginStart() {
    AdminCmds_OnModulesStart();
}

public void OnMapStart() {
    Fixes_OnMapStart();
}

public void OnMapEnd() {
    Fixes_OnMapEnd();
}

bool Clear(bool bSet = false, bool bVal = false) {
    static bool bClear = false;

    if (bSet)
        bClear = bVal;

    return bClear;
}