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
#if defined  _pause_included_
        #endinput
#endif
#define _pause_included_

/**
 * Returns if the game is currently paused from this pause plugin.
 * This can't tell you if it is paused from another plugin on manual pause
 *
 * @return  Current pause state
 */
native bool IsInPause();

/**
 * Forces game to pause.
 * @return true if game was paused
 */
native bool ForcePause(int iClient = 0, bool bForce);

/**
 * Forces game to unpause.
 * @return true if game was unpaused
 */
native bool ForceUnpause(int iClient = 0);

/**
 * Called when a pause starts
 * If delayed pauses are on this will be called when the delay ends and the
 * pause actually begins
 */
forward void OnPause();

/**
 * Called when the pause ends and the round goes live
 */
forward void OnUnpause();

public SharedPlugin __pl_pause =
{
    name = "pause",
    file = "pause.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

public void __pl_pause_SetNTVOptional()
{
    MarkNativeAsOptional("IsInPause");
}

// vim: ft=sourcepawn et sw=8
