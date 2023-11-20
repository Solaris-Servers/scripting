#if defined _readyup_setup_included
    #endinput
#endif
#define _readyup_setup_included

// Default sound samples
#include "sound.sp"

void SetupNatives() {
    CreateNative("IsReady",          Native_IsReady);
    CreateNative("IsInReady",        Native_IsInReady);
    CreateNative("ToggleReadyPanel", Native_ToggleReadyPanel);
}

void SetupForwards() {
    g_fwdPreInitiate = new GlobalForward(
    "OnReadyUpInitiatePre", ET_Ignore);

    g_fwdInitiate = new GlobalForward(
    "OnReadyUpInitiate", ET_Ignore);

    g_fwdPreCountdown = new GlobalForward(
    "OnRoundLiveCountdownPre", ET_Ignore);

    g_fwdCountdown = new GlobalForward(
    "OnRoundLiveCountdown", ET_Ignore);

    g_fwdPreLive = new GlobalForward(
    "OnRoundIsLivePre", ET_Ignore);

    g_fwdLive = new GlobalForward(
    "OnRoundIsLive", ET_Ignore);

    g_fwdCountdownCancelled = new GlobalForward(
    "OnReadyCountdownCancelled", ET_Ignore, Param_Cell, Param_String);

    g_fwdPlayerReady = new GlobalForward(
    "OnPlayerReady", ET_Ignore, Param_Cell);

    g_fwdTeamReady = new GlobalForward(
    "OnTeamReady", ET_Ignore, Param_Cell);

    g_fwdPlayerUnready = new GlobalForward(
    "OnPlayerUnready", ET_Ignore, Param_Cell);

    g_fwdTeamUnready = new GlobalForward(
    "OnTeamUnready", ET_Ignore, Param_Cell);
}

void SetupConVars() {
    // Basic
    g_cvReadyEnabled = CreateConVar(
    "l4d_ready_enabled", "1",
    "Enable this plugin. (Values: 0 = Disabled, 1 = Manual ready, 2 = Team ready, 3 = Loading)",
    FCVAR_NOTIFY, true, 0.0, true, 3.0);

    g_cvReadyCfgName = CreateConVar(
    "l4d_ready_cfg_name", "",
    "Configname to display on the ready-up panel",
    FCVAR_NOTIFY|FCVAR_PRINTABLEONLY, false, 0.0, false, 0.0);

    g_cvReadyServerName = CreateConVar(
    "l4d_ready_server_name", "sn_main_name",
    "ConVar to retrieve the server name for displaying on the ready-up panel",
    FCVAR_NOTIFY|FCVAR_PRINTABLEONLY, false, 0.0, false, 0.0);

    g_cvReadyServerNum = CreateConVar(
    "l4d_ready_server_num", "sn_host_num",
    "ConVar to retrieve the server num for displaying on the ready-up panel",
    FCVAR_NOTIFY|FCVAR_PRINTABLEONLY, false, 0.0, false, 0.0);

    // Game
    g_cvReadyDisableSpawns = CreateConVar(
    "l4d_ready_disable_spawns", "0",
    "Prevent SI from having spawns during ready-up",
    FCVAR_NOTIFY, true, 0.0, true, 1.0);

    g_cvReadySurvivorFreeze = CreateConVar(
    "l4d_ready_survivor_freeze", "0",
    "Freeze the survivors during ready-up.  When unfrozen they are unable to leave the saferoom but can move freely inside",
    FCVAR_NOTIFY, true, 0.0, true, 1.0);

    // Sound
    g_cvReadyEnableSound = CreateConVar(
    "l4d_ready_enable_sound", "1",
    "Enable sounds played to clients",
    FCVAR_NOTIFY, true, 0.0, true, 1.0);

    g_cvReadyNotifySound = CreateConVar(
    "l4d_ready_notify_sound", DEFAULT_NOTIFY_SOUND,
    "The sound that plays when a round goes on countdown",
    FCVAR_NONE, false, 0.0, false, 0.0);

    g_cvReadyCountdownSound = CreateConVar(
    "l4d_ready_countdown_sound", DEFAULT_COUNTDOWN_SOUND,
    "The sound that plays when a round goes on countdown",
    FCVAR_NONE, false, 0.0, false, 0.0);

    g_cvReadyLiveSound = CreateConVar(
    "l4d_ready_live_sound", DEFAULT_LIVE_SOUND,
    "The sound that plays when a round goes live",
    FCVAR_NONE, false, 0.0, false, 0.0);

    g_cvReadyChuckle = CreateConVar(
    "l4d_ready_chuckle", "0",
    "Enable random moustachio chuckle during countdown",
    FCVAR_NONE, true, 0.0, true, 1.0);

    g_cvReadySecret = CreateConVar(
    "l4d_ready_secret", "1",
    "Play something good",
    FCVAR_NONE, true, 0.0, true, 1.0);

    // Action
    g_cvReadyDelay = CreateConVar(
    "l4d_ready_delay", "3",
    "Number of seconds to count down before the round goes live.",
    FCVAR_NOTIFY, true, 0.0, false, 0.0);

    g_cvReadyForceExtra = CreateConVar(
    "l4d_ready_force_extra", "2",
    "Number of seconds added to the duration of live count down.",
    FCVAR_NOTIFY, true, 0.0, false, 0.0);

    g_cvReadyUnbalancedStart = CreateConVar(
    "l4d_ready_unbalanced_start", "0",
    "Allow game to go live when teams are not full.",
    FCVAR_NOTIFY, true, 0.0, true, 1.0);

    g_cvReadyUnbalancedMin = CreateConVar(
    "l4d_ready_unbalanced_min", "2",
    "Minimum of players in each team to allow a unbalanced start.",
    FCVAR_NOTIFY, true, 0.0, false, 0.0);

    // Game ConVars
    g_cvDirectorNoSpecials = FindConVar("director_no_specials");
    g_cvDirectorNoBosses   = FindConVar("director_no_bosses");
    g_cvGod                = FindConVar("god");
    g_cvSurvivorBotStop    = FindConVar("sb_stop");
    g_cvSurvivorLimit      = FindConVar("survivor_limit");
    g_cvInfectedLimit      = FindConVar("z_max_player_zombies");
    g_cvInfiniteAmmo       = FindConVar("sv_infinite_ammo");
}

void SetupCommands() {
    // Ready Commands
    RegConsoleCmd("sm_ready",       Cmd_Ready,       "Mark yourself as ready for the round to go live");
    RegConsoleCmd("sm_r",           Cmd_Ready,       "Mark yourself as ready for the round to go live");
    RegConsoleCmd("sm_toggleready", Cmd_ToggleReady, "Toggle your ready status");
    RegConsoleCmd("sm_unready",     Cmd_Unready,     "Mark yourself as not ready if you have set yourself as ready");
    RegConsoleCmd("sm_nr",          Cmd_Unready,     "Mark yourself as not ready if you have set yourself as ready");
    // Admin Commands
    RegAdminCmd("sm_forcestart",    Cmd_ForceStart, ADMFLAG_BAN, "Forces the round to start regardless of player ready status.");
    RegAdminCmd("sm_fs",            Cmd_ForceStart, ADMFLAG_BAN, "Forces the round to start regardless of player ready status.");
    // Player Commands
    RegConsoleCmd("sm_hide",        Cmd_Hide,   "Hides the ready-up panel so other menus can be seen");
    RegConsoleCmd("sm_show",        Cmd_Show,   "Shows a hidden ready-up panel");
    RegConsoleCmd("sm_return",      Cmd_Return, "Return to a valid saferoom spawn if you get stuck during an unfrozen ready-up period");
    // Footer Server Commands
    RegServerCmd("sm_addcommand",   Cmd_AddCmd,   "Add a Cmd in the Footer");
    RegServerCmd("sm_resetcommand", Cmd_ResetCmd, "Resets Cmds in the Footer.");
}