/*
  Includes for Penalty bonus system (l4d2_penalty_bonus)
  ------------------------------------------------------
*/

#if defined _l4d2_penalty_bonus_included_
    #endinput
#endif
#define _l4d2_penalty_bonus_included_

/**
 *  Called when a round is about to end.
 *  The update value is passed by reference and increased by any plugin using this forward
 *  before the next. Do an update += <update value> and return the new update.
 *  PBonus will apply the last value of that update to the round's penalty bonus (without reporting).
 *
 *  @param  int     update              (by reference) the value of the cumulative update PBonus needs to know
 *  @return int     the update value to add to the round's bonus
 */
forward int PB_RequestFinalUpdate(int &update);


// Adds points to the bonus for the current round
native void PB_AddRoundBonus(int bonus);

// Set the bonus for the current round
native void PB_SetRoundBonus(int bonus);

// Get the bonus for the current round
//    returns int
native int PB_GetRoundBonus();

public SharedPlugin __pl_l4d2_penalty_bonus =
{
    name = "l4d2_penalty_bonus",
    file = "l4d2_penalty_bonus.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2_penalty_bonus_SetNTVOptional()
{
    MarkNativeAsOptional("PB_AddRoundBonus");
    MarkNativeAsOptional("PB_SetRoundBonus");
    MarkNativeAsOptional("PB_GetRoundBonus");
}
#endif