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
#include <l4d2util/infected>

ConVar g_cvBotKickDelay;

public Plugin myinfo = {
    name        = "L4D2 No Second Chances",
    author      = "Visor, Jacob, A1m`",
    description = "Previously human-controlled SI bots with a cap won't die",
    version     = "1.4",
    url         = "https://github.com/Attano/Equilibrium"
};

public void OnPluginStart() {
    g_cvBotKickDelay = CreateConVar(
    "bot_kick_delay", "0.0",
    "How long should we wait before kicking infected bots?",
    FCVAR_NONE, true, 0.0, true, 30.0);
    HookEvent("player_bot_replace", Event_PlayerBotReplace);
}

void Event_PlayerBotReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int   iBot   = GetClientOfUserId(eEvent.GetInt("bot"));
    float fDelay = g_cvBotKickDelay.FloatValue;
    if (iBot <= 0)                                   return;
    if (!IsClientInGame(iBot))                       return;
    if (GetClientTeam(iBot) != 3)                    return;
    if (!IsFakeClient(iBot))                         return;
    if (GetInfectedClass(iBot) == L4D2Infected_Tank) return;
    if (fDelay > 0.0) {
        CreateTimer(fDelay, KillBot, GetClientUserId(iBot), TIMER_FLAG_NO_MAPCHANGE);
        return;
    }
    RequestFrame(OnNextFrame, GetClientUserId(iBot));
}

void OnNextFrame(any iUserId) {
    int iBot = GetClientOfUserId(iUserId);
    if (iBot <= 0)                                   return;
    if (!IsClientInGame(iBot))                       return;
    if (GetClientTeam(iBot) != 3)                    return;
    if (!IsFakeClient(iBot))                         return;
    if (GetInfectedVictim(iBot) > 0)                 return;
    if (GetInfectedClass(iBot) == L4D2Infected_Tank) return;
    ForcePlayerSuicide(iBot);
}

Action KillBot(Handle hTimer, any iUserId) {
    int iBot = GetClientOfUserId(iUserId);
    if (iBot <= 0)                                   return Plugin_Stop;
    if (!IsClientInGame(iBot))                       return Plugin_Stop;
    if (GetClientTeam(iBot) != 3)                    return Plugin_Stop;
    if (!IsFakeClient(iBot))                         return Plugin_Stop;
    if (GetInfectedVictim(iBot) > 0)                 return Plugin_Stop;
    if (GetInfectedClass(iBot) == L4D2Infected_Tank) return Plugin_Stop;
    ForcePlayerSuicide(iBot);
    return Plugin_Stop;
}