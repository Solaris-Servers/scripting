#if defined  _solaris_versus_manager_included_
        #endinput
#endif
#define _solaris_versus_manager_included_

/**
 * Returns whether punch rocks are blocked
 * @return bool
 */
native bool Solaris_BlockPunchRock();

/**
 * Returns whether jump rocks are blocked
 * @return bool
 */
native bool Solaris_BlockJumpRock();

public SharedPlugin __pl_solaris_versus_manager =
{
    name = "solaris_versus_manager",
    file = "solaris_versus_manager.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

public void __pl_solaris_versus_manager_SetNTVOptional()
{
    MarkNativeAsOptional("Solaris_BlockPunchRock");
    MarkNativeAsOptional("Solaris_BlockJumpRock");
}