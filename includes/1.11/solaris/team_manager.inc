#if defined  _solaris_team_manager_included_
        #endinput
#endif
#define _solaris_team_manager_included_

/**
 * Returns whether all players are loaded
 * if there are players in loading state
 * @return false
 * after two minutes or when all players are loaded
 * @return true
 */
native bool TM_IsFinishedLoading();

/**
 * Returns amount of time to wait loading players (in sec.)
 * @return  int
 */
native int TM_LoadingTimeRemaining();

/**
 * Returns whether player is respeccing
 * @return bool
 */
native bool TM_IsPlayerRespectating(int client);

/**
 * Returns count of loading players when slots are protected from stealing
 * if there are players in loading state
 * @return total amount of them
 * otherwise
 * @return 0
 */
native int TM_GetPlayersInLoad();

/**
 * Returns total amount of players when slots are protected from stealing
 * @return int
 */
native int TM_GetRememberedHumanCountInTeam(int team);

/**
 * Rewrites KeyValues of remembered players making it opposite
 * If you are supposed to move players to another team
 * You have to use ChangeClientTeam(int client, int team) in addition
 */
native void TM_SwapTeams();

/**
 * Rewrites KeyValues of remembered player
 * If you are supposed to move player to another team
 * You have to use ChangeClientTeam(int client, int team) in addition
 */
native void TM_SetPlayerTeam(int client, int team);

/**
 * Returns whether spectator is caster
 * @return bool
 */
native bool TM_IsClientCaster(int client);

/**
 * Returns whether slots are reserved
 * @return bool
 */
native bool TM_IsReserved();

/**
 * Callback for when a Captains Mode has been started.
 */
forward void OnMixStarted();

/**
 * Callback for when Teams are picked.
 */
forward void OnMixStopped();

/**
 * Callback for when All players loaded.
 */
forward void OnEveryPlayerLoaded();

/**
 * Callback for when a player used jointeam cmd.
 */
forward Action OnJoinTeamCmd(const int iClient, const int iTeam);

public SharedPlugin __pl_solaris_team_manager =
{
    name = "solaris_team_manager",
    file = "solaris_team_manager.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

public void __pl_solaris_team_manager_SetNTVOptional()
{
    MarkNativeAsOptional("TM_IsFinishedLoading");
    MarkNativeAsOptional("TM_LoadingTimeRemaining");
    MarkNativeAsOptional("TM_IsPlayerRespectating");
    MarkNativeAsOptional("TM_GetPlayersInLoad");
    MarkNativeAsOptional("TM_GetRememberedHumanCountInTeam");
    MarkNativeAsOptional("TM_SwapTeams");
    MarkNativeAsOptional("TM_SetPlayerTeam");
    MarkNativeAsOptional("TM_ForceCaptains");
    MarkNativeAsOptional("TM_ForceShuffle");
}