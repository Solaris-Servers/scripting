#if defined _solaris_included
    #endinput
#endif
#define _solaris_included

// set slots count
native void Sol_Slots_Set(int iSlots);

// get lower amount of slots that can be set
native int Sol_Slots_GetLowerLimit();

// kick all non-admin spectators
native void Sol_Slots_KickSpec();

public SharedPlugin __pl_solaris =
{
    name = "solaris",
    file = "solaris.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

public void __pl_solaris_SetNTVOptional()
{
    MarkNativeAsOptional("Sol_Slots_Set");
    MarkNativeAsOptional("Sol_Slots_GetLowerLimit");
    MarkNativeAsOptional("Sol_Slots_KickSpec");
}
