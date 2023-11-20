/**
 * HLstatsX - SourceMod plugin to display ingame messages
 * http://www.hlstatsx.com/
 * Copyright (C) 2007-2009 TTS Oetzel & Goerz GmbH
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */
#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <solaris/chat>

#include "modules/ConVars.sp"
#include "modules/ServerCmds.sp"
#include "modules/Stocks.sp"

public Plugin myinfo = {
    name        = "HLstatsX Plugin",
    author      = "TTS Oetzel & Goerz GmbH",
    description = "HLstatsX Ingame Plugin",
    version     = "2.8",
    url         = "http://www.hlstatsx.com"
};

public void OnPluginStart() {
    ConVars_OnModuleStart();
    ServerCmds_OnModuleStart();
}

public void OnMapStart() {
    GetTeams();
}

public Action SolarisChat_OnChatMessage(int iClient, int iArgs, int iTeam, bool bTeamChat, ArrayList aRecipients, char[] szTagColor, char[] szTag, char[] szNameColor, char[] szName, char[] szMsgColor, char[] szMsg) {
    int iStartIdx = 0;
    int iLength   = strlen(szMsg);
    if (iLength) {
        if (szMsg[0] == '\"') {
            iStartIdx = 1;
            if (szMsg[iLength - 1] == '\"') szMsg[iLength - 1] = 0;
        }
        if (szMsg[iStartIdx] == '/' || szMsg[iStartIdx] == '!')
            iStartIdx++;
        if (bBlockChatCommands) {
            bool bCmdBlocked = IsCommandBlocked(szMsg[iStartIdx]);
            if (bCmdBlocked) {
                LogPlayerEvent(iClient, bTeamChat ? "say_team" : "say", szMsg[iStartIdx]);
                return Plugin_Stop;
            }
        }
    }
    return Plugin_Continue;
}