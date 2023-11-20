#if defined _l4d2_changelevel_included
    #endinput
#endif
#define _l4d2_changelevel_included

/**
*   @param  szMap                   Map String without .bsp
*   @param  bClear                  Clear transition info
*   @noreturn
*/
native void L4D2_ChangeLevel(const char[] szMap, bool bClear = true);

/**
*   @param  szMission               Map String without .bsp
*   @noreturn
*/
native void L4D2_ChangeMission(const char[] szMission);

public SharedPlugin __pl_l4d2_changelevel =
{
    name = "l4d2_changelevel",
    file = "l4d2_changelevel.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2_changelevel_SetNTVOptional()
{
    MarkNativeAsOptional("L4D2_ChangeLevel");
    MarkNativeAsOptional("L4D2_ChangeMission");
}
#endif