#if defined  _solaris_info_included_
        #endinput
#endif
#define _solaris_info_included_

/**
 * Returns player's rank
 * @return int
 */
native int Solaris_GetRank(int client);

/**
 * Returns player's lerp
 * @return float
 */
native float Solaris_GetLerp(int client);

/**
 * Returns player's hours in the game
 * @return float
 */
native float Solaris_GetHours(int client);

/**
 * Writes player's country code in the buffer
 * @return void
 */
native void Solaris_GetCountry(int client, char[] buffer, int len);

/**
 * Writes player's city in the buffer
 * @return void
 */
native void Solaris_GetCity(int client, char[] buffer, int len);

/**
 * Returns player's loading time
 * @return in
 */
native float Solaris_GetLoadingTime(int client);

/**
 * Callback for when a player changed lerp.
 */
forward void OnPlayerLerpChanged(const int iClient, const float newLerp, const float lastLerp);

public SharedPlugin __pl_solaris_info =
{
    name = "solaris_info",
    file = "solaris_info.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

public void __pl_solaris_info_SetNTVOptional()
{
    MarkNativeAsOptional("Solaris_GetRank");
    MarkNativeAsOptional("Solaris_GetLerp");
    MarkNativeAsOptional("Solaris_GetHours");
    MarkNativeAsOptional("Solaris_GetCountry");
    MarkNativeAsOptional("Solaris_GetCity");
    MarkNativeAsOptional("Solaris_GetLoadingTime");
}