#if defined _l4d2_scoremod_included_
    #endinput
#endif
#define _l4d2_scoremod_included_

/**
 * Get the current health bonus.
 * @return int
 */
native int SM_HealthBonus();

/**
 * Get the current average health.
 * @return int
 */
native int SM_AvgHealth();

public SharedPlugin __pl_l4d2_scoremod =
{
    name = "l4d2_scoremod",
    file = "l4d2_scoremod.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2_scoremod_SetNTVOptional()
{
    MarkNativeAsOptional("SM_HealthBonus");
    MarkNativeAsOptional("SM_AvgHealth");
}
#endif