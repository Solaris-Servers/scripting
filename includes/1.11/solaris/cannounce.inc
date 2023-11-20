/**
 *  Called whenever a player has joined,
 *
 *  @param  int     iClient     player that joined the game
 *  @param  int     iRank       player's rank from hlstatsx
 *  @param  char    szLocation  player's country and city
 *  @param  float   fHours      player's total hours
 */
forward void OnPlayerJoined(int iClient, int iRank, const char[] szLocation, float fHours);

public SharedPlugin __pl_solaris_cannounce =
{
    name = "solaris_cannounce",
    file = "solaris_cannounce.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};