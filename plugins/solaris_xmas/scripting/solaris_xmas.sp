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
#include <sdktools>
#include <sdkhooks>
#include <colors>
#include <ripext>
#include <readyup>
#include <solaris/votes>
#include <solaris/stocks>
#include <solaris/api/contests>

char g_szMapName[128];

#include "modules/convars.sp"
#include "modules/files.sp"
#include "modules/admincmds.sp"
#include "modules/clientcmds.sp"
#include "modules/contest.sp"
#include "modules/events.sp"
#include "modules/stripper.sp"
#include "modules/functions.sp"
#include "modules/stocks.sp"

public Plugin myinfo = {
    name        = "[Solaris] XMAS",
    author      = "???",
    description = "Happy Holidays",
    version     = "1.0.0",
    url         = "https://solaris-servers.ru/"
}

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    return IsHoliday() ? APLRes_Success : APLRes_SilentFailure;
}

public void OnPluginStart() {
    ConVars_OnModuleStart();
    AdminCmds_OnModuleStgart();
    ClientCmds_OnModuleStart();
    Events_OnModuleStart();
    Stripper_OnModuleStart();
    Contest_OnModuleStart();
}

public void OnConfigsExecuted() {
    ConVars_OnConfigsExecuted();
}

public void OnMapStart() {
    GetCurrentMap(g_szMapName, sizeof(g_szMapName));
    Files_OnMapStart();
}

// Round Is Live
public void OnRoundIsLive() {
    AllowJingle(true, false);

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        StopSound(i, SNDCHAN_AUTO, "music/flu/jukebox/all_i_want_for_xmas.wav");
    }
}