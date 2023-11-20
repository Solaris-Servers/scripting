/**
 * vim: set ts=4 :
 * =============================================================================
 * Zombie Character Select 0.9.6-L4D2 by XBetaAlpha
 *
 * Allows a player on the infected team to change their infected class.
 * Complete rewrite based on the Infected Character Select idea by Crimson_Fox.
 *
 * SourceMod (C)2004-2016 AlliedModders LLC.  All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */

#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <left4dhooks>
#include <l4d2util>
#include <colors>

bool g_bInformed[MAXPLAYERS + 1];

public Plugin myinfo = {
    name        = "[L4D2] Zombie Character Select: Simplified",
    author      = "XBetaAlpha",
    description = "Allows infected team players to change their class in ghost mode. (Simplified version for Practicogle config)",
    version     = "1.0.0",
    url         = "http://dev.andrewx.net/sm/zcs"
}

public void OnClientPutInServer(int iClient) {
    g_bInformed[iClient] = false;
}

public void OnClientDisconnect(int iClient) {
    g_bInformed[iClient] = false;
}

public void OnPlayerRunCmdPost(int iClient, int iButtons) {
    static bool bInAttack2[MAXPLAYERS + 1];
    static int  iZombieClass;
    if (!IsValidInfected(iClient)) return;
    if (!IsInfectedGhost(iClient)) return;
    // Player was holding m2, and now isn't. (Released)
    if (!(iButtons & IN_ATTACK2) && bInAttack2[iClient]) {
        bInAttack2[iClient] = false;
        return;
    }
    // Player was not holding m2, and now is. (Pressed)
    if ((iButtons & IN_ATTACK2) && !bInAttack2[iClient]) {
        bInAttack2[iClient] = true;
        iZombieClass = GetInfectedClass(iClient);
        if (iZombieClass == L4D2Infected_Tank) {
            iZombieClass = L4D2Infected_Smoker;
            L4D_SetClass(iClient, iZombieClass);
            return;
        }
        iZombieClass++;
        if (iZombieClass == L4D2Infected_Witch)
            iZombieClass++;
        L4D_SetClass(iClient, iZombieClass);
    }
}

public void L4D_OnEnterGhostState(int iClient) {
    if (g_bInformed[iClient]) return;
    g_bInformed[iClient] = true;
    CPrintToChat(iClient, "{green}[{default}Info{green}]{default} Press the {olive}MOUSE 2{default} as ghost to change zombie class.");
}