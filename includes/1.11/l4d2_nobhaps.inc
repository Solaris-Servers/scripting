native bool IsClientBlockedBH(int client);

public SharedPlugin __pl_l4d2_nobhaps =
{
    name = "l4d2_nobhaps",
    file = "l4d2_nobhaps.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

public void __pl_l4d2_nobhaps_SetNTVOptional()
{
    MarkNativeAsOptional("IsClientBlockedBH");
}