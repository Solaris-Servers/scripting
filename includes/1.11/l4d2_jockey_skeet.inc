#if defined  _l4d2_jockey_skeet_included_
        #endinput
#endif
#define _l4d2_jockey_skeet_included_

/**
 *  Called whenever a true skeet with shotgun is done.
 *
 *  @param  int     iSurvivor    the survivor client that performed the feat
 *  @param  int     iJockey      the infected client that underwent it
 */
forward void OnJockeySkeet(int iSurvivor, int iJockey);

public SharedPlugin __pl_l4d2_jockey_skeet =
{
    name = "l4d2_jockey_skeet",
    file = "l4d2_jockey_skeet.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};