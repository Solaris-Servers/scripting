#if defined  _bosspercent_included_
    #endinput
#endif
#define _bosspercent_included_

/**
 * Triggers a refresh of percent values which are displayed by the boss percent plugin.
 *
 * @note    To concord your custom boss percents with the ready-up footer, use a timer of ~5.5s in round_start
 * @return          True if no error occured during the refresh
 */
native bool BossPercent_UpdateBossPercents();

/**
 * Returns if tank flow is enabled
 */
native bool BossPercent_TankEnabled();

/**
 * Returns if witch flow is enabled
 */
native bool BossPercent_WitchEnabled();

/**
 * Returns Tank flow percent
 */
native int BossPercent_TankPercent();

/**
 * Returns Witch flow percent
 */
native int BossPercent_WitchPercent();

/**
 * Returns survivors current flow percent
 */
native int BossPercent_CurrentPercent();

// Tank Attack Control EQ
forward Action TankControlEQ_OnChooseTank();
forward void   TankControlEQ_OnTankGiven(const char[] steamId);
forward void   TankControlEQ_OnTankControlReset();

native  void   TankControlEQ_SetTank(const char[] steamId);
native  int    TankControlEQ_GetTank();
native  Handle TankControlEQ_GetWhosHadTank();
native  Handle TankControlEQ_GetWhosNotHadTank();
native  void   TankControlEQ_ClearWhosHadTank();
native  Handle TankControlEQ_GetTankPool();

public SharedPlugin __pl_bosspercent =
{
    name = "l4d_boss_percent",
    file = "l4d_boss_percent.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

public void __pl_bosspercent_SetNTVOptional()
{
    MarkNativeAsOptional("BossPercent_UpdateBossPercents");
    MarkNativeAsOptional("BossPercent_TankEnabled");
    MarkNativeAsOptional("BossPercent_WitchEnabled");
    MarkNativeAsOptional("BossPercent_TankPercent");
    MarkNativeAsOptional("BossPercent_WitchPercent");
    MarkNativeAsOptional("BossPercent_CurrentPercent");
    MarkNativeAsOptional("TankControlEQ_SetTank");
    MarkNativeAsOptional("TankControlEQ_GetTank");
    MarkNativeAsOptional("TankControlEQ_GetWhosHadTank");
    MarkNativeAsOptional("TankControlEQ_GetWhosNotHadTank");
    MarkNativeAsOptional("TankControlEQ_ClearWhosHadTank");
    MarkNativeAsOptional("TankControlEQ_GetTankPool");
}