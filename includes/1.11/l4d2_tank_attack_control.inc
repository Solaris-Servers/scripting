/**
 * @brief Retrieves Jump Rock cooldown.
 *
 * @param client    Client id of the Tank
 *
 * @return          Jump rock cooldown time (in seconds).
 */
native int L4D2_GetTankCoolDownTime(int client);

public SharedPlugin __pl_l4d2_tank_attack_control =
{
    name = "l4d2_tank_attack_control",
    file = "l4d2_tank_attack_control.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

public void __pl_l4d2_tank_attack_control_SetNTVOptional()
{
    MarkNativeAsOptional("L4D2_GetTankCoolDownTime");
}
