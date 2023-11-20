#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <sourcescramble>
#include <l4d2util>
#include <colors>

#undef REQUIRE_PLUGIN
#include <bosspercent>
#include <witch_and_tankifier>
#define REQUIRE_PLUGIN

#define GAMEDATA                 "coop_boss_spawning"
#define PATCH_NO_DIRECTOR_BOSS   "CDirector::OnThreatEncountered::Block"
#define PATCH_COOP_VERSUS_BOSS   "CDirectorVersusMode::UpdateNonVirtual::IsVersusMode"
#define PATCH_BLOCK_MARKERSTIMER "CDirectorVersusMode::UpdateNonVirtual::UpdateMarkersTimer"

ConVar g_cvTankEnabled;
bool   g_bTankEnabled;

ConVar g_cvWitchEnabled;
bool   g_bWitchEnabled;

bool g_bIsLive;
bool g_bBossPctAvailable;
bool g_bIsWitchAndTankifierAvailable;

public Plugin myinfo = {
    name        = "Coop Boss Spawning",
    author      = "sorallll",
    description = "Patches boss spawning behavior",
    version     = "1.0.4",
    url         = "https://github.com/umlka/l4d2"
};

void InitGameData() {
    GameData gmConf = new GameData(GAMEDATA);
    if (!gmConf) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

    Patch(gmConf, PATCH_NO_DIRECTOR_BOSS);
    Patch(gmConf, PATCH_COOP_VERSUS_BOSS);
    Patch(gmConf, PATCH_BLOCK_MARKERSTIMER);

    delete gmConf;
}

void Patch(GameData gmConf = null, const char[] szName) {
    MemoryPatch patch = MemoryPatch.CreateFromConf(gmConf, szName);
    if (!patch.Validate())
        SetFailState("Failed to verify patch: \"%s\"", szName);
    else if (patch.Enable())
        PrintToServer("Enabled patch: \"%s\"", szName);
}

public void OnPluginStart() {
    InitGameData();

    g_cvTankEnabled = CreateConVar(
    "flow_tank_enable", "1",
    "Enable tanks to spawn",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bTankEnabled = g_cvTankEnabled.BoolValue;
    g_cvTankEnabled.AddChangeHook(ConVarChanged_TankEnabled);

    g_cvWitchEnabled = CreateConVar(
    "flow_witch_enable", "1",
    "Enable witches to spawn",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bWitchEnabled = g_cvWitchEnabled.BoolValue;
    g_cvWitchEnabled.AddChangeHook(ConVarChanged_WitchEnabled);

    RegConsoleCmd("sm_toggletank",  Cmd_ToggleTank,  "Toggle flow tank spawn");
    RegConsoleCmd("sm_togglewitch", Cmd_ToggleWitch, "Toggle flow witch spawn");

    RegConsoleCmd("sm_tank",    Cmd_Boss, "Shows boss flow.");
    RegConsoleCmd("sm_boss",    Cmd_Boss, "Shows boss flow.");
    RegConsoleCmd("sm_witch",   Cmd_Boss, "Shows boss flow.");
    RegConsoleCmd("sm_cur",     Cmd_Boss, "Shows boss flow.");
    RegConsoleCmd("sm_current", Cmd_Boss, "Shows boss flow.");

    HookEvent("round_start",           Event_RoundStart,         EventHookMode_PostNoCopy);
    HookEvent("player_left_safe_area", Evemt_PlayerLeftSafeArea, EventHookMode_PostNoCopy);
}

// ======================================
// Third Party Plugins Tracking
// ======================================

public void OnAllPluginsLoaded() {
    g_bBossPctAvailable             = LibraryExists("l4d_boss_percent");
    g_bIsWitchAndTankifierAvailable = LibraryExists("witch_and_tankifier");
}

public void OnLibraryAdded(const char[] szName) {
    if (strcmp(szName, "l4d_boss_percent") == 0)
        g_bBossPctAvailable = true;

    if (strcmp(szName, "witch_and_tankifier") == 0)
        g_bIsWitchAndTankifierAvailable = true;
}

public void OnLibraryRemoved(const char[] szName) {
    if (strcmp(szName, "l4d_boss_percent") == 0)
        g_bBossPctAvailable = false;

    if (strcmp(szName, "witch_and_tankifier") == 0)
        g_bIsWitchAndTankifierAvailable = false;
}

// ======================================
// ConVars Tracking
// ======================================

void ConVarChanged_TankEnabled(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bTankEnabled = g_cvTankEnabled.BoolValue;
}

void ConVarChanged_WitchEnabled(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bWitchEnabled = g_cvWitchEnabled.BoolValue;
}

// ======================================
// Events
// ======================================

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bIsLive = false;
}

void Evemt_PlayerLeftSafeArea(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bIsLive = true;
    PrintBossPercents();
}

// ======================================
// Cmds
// ======================================

Action Cmd_ToggleTank(int iClient, int iArgs) {
    if (g_bIsLive) {
        CPrintToChat(iClient, "{green}[{default}Gauntlet{green}]{default} This command can only be used before the round start");
        return Plugin_Handled;
    }

    if (!IsSurvivor(iClient)) {
        CPrintToChat(iClient, "{green}[{default}Gauntlet{green}]{default} You do not have access to this command");
        return Plugin_Handled;
    }

    g_cvTankEnabled.BoolValue = !g_cvTankEnabled.BoolValue;
    CPrintToChatAll("{green}[{default}Gauntlet{green}]{default} Flow tank has been %s", g_cvTankEnabled.BoolValue ? "{olive}enabled" : "{green}disabled");

    return Plugin_Handled;
}

Action Cmd_ToggleWitch(int iClient, int iArgs) {
    if (g_bIsLive) {
        CPrintToChat(iClient, "{green}[{default}Gauntlet{green}]{default} This command can only be used before the round start");
        return Plugin_Handled;
    }

    if (!IsSurvivor(iClient)) {
        CPrintToChat(iClient, "{green}[{default}Gauntlet{green}]{default} You do not have access to this command");
        return Plugin_Handled;
    }

    g_cvWitchEnabled.BoolValue = !g_cvWitchEnabled.BoolValue;
    CPrintToChatAll("{green}[{default}Gauntlet{green}]{default} Flow tank has been %s", g_cvWitchEnabled.BoolValue ? "{olive}enabled" : "{green}disabled");

    return Plugin_Handled;
}

Action Cmd_Boss(int iClient, int iArgs) {
    if (!g_bIsLive)
        return Plugin_Handled;

    if (!g_bBossPctAvailable)
        return Plugin_Handled;

    PrintBossPercents(iClient);
    PrintCurrentToClient(iClient);
    return Plugin_Handled;
}

// ======================================
// Print Boss Flow
// ======================================

void PrintBossPercents(int iClient = -1) {
    static int iTankFlow;
    iTankFlow = g_bTankEnabled ? BossPercent_TankPercent() : 0;

    static int iWitchFlow;
    iWitchFlow = g_bWitchEnabled ? BossPercent_WitchPercent() : 0;

    if (iClient == -1) {
        if (iTankFlow)
            CPrintToChatAll("Tank: {blue}%d%%", iTankFlow);
        else
            CPrintToChatAll("Tank: {blue}%s", IsStaticTank() ? "Static" : "None");

        if (iWitchFlow)
            CPrintToChatAll("Witch: {blue}%d%%", iWitchFlow);
        else
            CPrintToChatAll("Witch: {blue}%s", IsStaticWitch() ? "Static" : "None");
    } else {
        if (iTankFlow)
            CPrintToChat(iClient, "Tank: {blue}%d%%", iTankFlow);
        else
            CPrintToChat(iClient, "Tank: {blue}%s", IsStaticTank() ? "Static" : "None");

        if (iWitchFlow)
            CPrintToChat(iClient, "Witch: {blue}%d%%", iWitchFlow);
        else
            CPrintToChat(iClient, "Witch: {blue}%s", IsStaticWitch() ? "Static" : "None");
    }
}

// ======================================
// Print Current Flow
// ======================================

void PrintCurrentToClient(int iClient) {
    CPrintToChat(iClient, "Current: {blue}%d%%", BossPercent_CurrentPercent());
}

// ======================================
// Boss Spawn Control
// ======================================

public Action L4D_OnSpawnTank(const float vPos[3], const float vAng[3]) {
    return g_bTankEnabled ? Plugin_Continue : Plugin_Handled;
}

public Action L4D_OnSpawnWitch(const float vPos[3], const float vAng[3]) {
    return g_bWitchEnabled ? Plugin_Continue : Plugin_Handled;
}

public Action L4D2_OnSpawnWitchBride(const float vPos[3], const float vAng[3]) {
    return g_bWitchEnabled ? Plugin_Continue : Plugin_Handled;
}

// ======================================
// Misc
// ======================================

stock bool IsStaticTank() {
    if (!g_bIsWitchAndTankifierAvailable)
        return false;
    if (!g_bTankEnabled)
        return false;
    return IsStaticTankMap();
}

stock bool IsStaticWitch() {
    if (!g_bIsWitchAndTankifierAvailable)
        return false;
    if (!g_bWitchEnabled)
        return false;
    return IsStaticWitchMap();
}