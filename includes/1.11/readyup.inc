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
#if defined  _readyup_included_
 #endinput
#endif
#define _readyup_included_

/**
 * Called when a player marks ready.
 */
forward void OnPlayerReady(int client);

/**
 * Called when a player marks unready.
 */
forward void OnPlayerUnready(int client);

/**
 * Called when a team marks ready.
 */
forward void OnTeamReady(int team);

/**
 * Called when a team marks unready.
 */
forward void OnTeamUnready(int team);

/**
 * Called before ready up is initiated
 */
forward void OnReadyUpInitiatePre();

/**
 * Called when ready up is initiated
 */
forward void OnReadyUpInitiate();

/**
 * Called before the live countdown starts
 */
forward void OnRoundLiveCountdownPre();

/**
 * Called when the live countdown starts
 */
forward void OnRoundLiveCountdown();

/**
 * Called when the live countdown is cancelled
 *
 * @param client        Player cancelled the countdown
 * @param reason        The reason for cancel
 */
forward void OnReadyCountdownCancelled(int client, const char[] reason);

/**
 * Called before the live countdown ends and the round goes live
 */
forward void OnRoundIsLivePre();

/**
 * Called when the live countdown ends and the round goes live
 */
forward void OnRoundIsLive();

/**
 * Whether or not the player is currently readied up
 *
 * @param client    Client to check.
 * @return          True if the game is currently in the ready-up phase.
 */
native bool IsReady(int client);

/**
 * Whether or not the game is currently waiting for players to ready up.
 *
 * @return          True if the game is currently in the ready-up phase.
 */
native bool IsInReady();

/**
 * @brief Toggle ready panel of one target or all clients.
 * @remarks Always return false if currently not in ready-up phase.
 *
 * @return          True if no target if specified, or previous ready panel state of target.
 */
native bool ToggleReadyPanel(bool show, int target = 0);

public SharedPlugin __pl_readyup =
{
    name = "readyup",
    file = "readyup.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_readyup_SetNTVOptional()
{
    MarkNativeAsOptional("GetFooterStringAtIndex");
    MarkNativeAsOptional("FindIndexOfFooterString");
    MarkNativeAsOptional("EditFooterStringAtIndex");
    MarkNativeAsOptional("AddStringToReadyFooter");
    MarkNativeAsOptional("IsInReady");
    MarkNativeAsOptional("ToggleReadyPanel");
}
#endif