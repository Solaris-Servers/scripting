#if defined __solaris_votes_included
    #endinput
#endif
#define __solaris_votes_included

#include <solaris/votes/types>

/**
 * Returns current VoteState
 * @return  VoteState
 */
native VotingState SolarisVotes_GetCurrentVotingState();

/**
 * Returns true if there is currently a vote in progress
 * @return  bool
 */
native bool SolarisVotes_IsVoteInProgress();

/**
 * Returns true if specified client is in current vote pool
 * @note                    Always false if vote is not in progress
 * @param   iClient         Client
 * @return  bool
 */
native bool SolarisVotes_IsClientInVotePool(int iClient);