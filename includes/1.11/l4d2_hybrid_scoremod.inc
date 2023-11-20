#if defined _l4d2_hybrid_scoremod
    #endinput
#endif
#define _l4d2_hybrid_scoremod

/**
 * Get the current health bonus.
 * @return int
 */
native int SMPlus_GetHealthBonus();

/**
 * Get the current damage bonus.
 * @return int
 */
native int SMPlus_GetDamageBonus();

/**
 * Get the current pills bonus.
 * @return int
 */
native int SMPlus_GetPillsBonus();

/**
 * Get the max health bonus.
 * @return int
 */
native int SMPlus_GetMaxHealthBonus();

/**
 * Get the max damage bonus.
 * @return int
 */
native int SMPlus_GetMaxDamageBonus();

/**
 * Get the max pills bonus.
 * @return int
 */
native int SMPlus_GetMaxPillsBonus();

public SharedPlugin __pl_l4d2_hybrid_scoremod =
{
    name = "l4d2_hybrid_scoremod",
    file = "l4d2_hybrid_scoremod.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2_hybrid_scoremod_SetNTVOptional()
{
    MarkNativeAsOptional("SMPlus_GetHealthBonus");
    MarkNativeAsOptional("SMPlus_GetDamageBonus");
    MarkNativeAsOptional("SMPlus_GetPillsBonus");
    MarkNativeAsOptional("SMPlus_GetMaxHealthBonus");
    MarkNativeAsOptional("SMPlus_GetMaxDamageBonus");
    MarkNativeAsOptional("SMPlus_GetMaxPillsBonus");
}
#endif