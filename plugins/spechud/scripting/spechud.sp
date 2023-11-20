#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <left4dhooks>
#include <readyup>
#include <pause>
#include <l4d2util/weapons>

#include <solaris/votes>
#include <solaris/team_manager>
#include <solaris/stocks>

#undef REQUIRE_PLUGIN
#include <bosspercent>
#include <confogl>
#include <l4d_tank_damage_announce>
#include <l4d2_hybrid_scoremod>
#include <l4d2_nobhaps>
#include <l4d2_scoremod>
#include <l4d2_tank_attack_control>
#include <witch_and_tankifier>
#define REQUIRE_PLUGIN

#define ZOMBIECLASS_NAME(%0) (L4D2SI_Names[(%0)])

enum L4D2SI {
    ZC_None,
    ZC_Smoker,
    ZC_Boomer,
    ZC_Hunter,
    ZC_Spitter,
    ZC_Jockey,
    ZC_Charger,
    ZC_Witch,
    ZC_Tank
};

char L4D2SI_Names[][] = {
    "None",
    "Smoker",
    "Boomer",
    "Hunter",
    "Spitter",
    "Jockey",
    "Charger",
    "Witch",
    "Tank"
};

ConVar g_cvSpecHudAllow;
bool   g_bSpecHudAllow;

ConVar g_cvSurvivorLimit;
int    g_iSurvivorLimit;

ConVar g_cvInfectedLimit;
int    g_iInfectedLimit;

ConVar g_cvGameMode;
bool   g_bIsVersus;
bool   g_bIsScavenge;

ConVar g_cvPainPillsDecayRate;
float  g_fPainPillsDecayRate;

ConVar g_cvServerMainName;
char   g_szMainName[64];

ConVar g_cvReadyCfgName;
char   g_szReadyCfgName[64];

ConVar g_cvBlockJumpRock;
bool   g_bBlockJumpRock;

KeyValues g_kvServerName;

bool g_bSpecHudActive    [MAXPLAYERS + 1];
bool g_bSpecHudHintShown [MAXPLAYERS + 1];
bool g_bTankHudActive    [MAXPLAYERS + 1];
bool g_bTankHudHintShown [MAXPLAYERS + 1];

bool g_bIsTankAlive;
bool g_bTankSelection;

char g_szGameModeName[64];

int g_iTankClient;
int g_iOffsetAmmo;
int g_iPrimaryAmmoType;

float g_fMaxTankHealth;

bool g_bBossPctAvailable;
bool g_bTankDmgAnnounceAvailable;
bool g_bTankAttackControlAvailable;
bool g_bHybridScoreModAvailable;
bool g_bScoreModAvailable;
bool g_bNoBhapsAvailable;
bool g_bIsWitchAndTankifierAvailable;
bool g_bIsConfoglEnabled;

public Plugin myinfo = {
    name        = "Hyper-V HUD Manager",
    author      = "Visor, Forgetest",
    description = "Provides different HUDs for spectators",
    version     = "3.4.8b",
    url         = "https://github.com/Attano/smplugins"
};

public void OnPluginStart() {
    char szFilePath[64];
    g_kvServerName = new KeyValues("GameMods");
    BuildPath(Path_SM, szFilePath, sizeof(szFilePath), "configs/server_namer.txt");
    if (!g_kvServerName.ImportFromFile(szFilePath)) SetFailState("configs/server_namer.txt not found!");

    g_cvSpecHudAllow = CreateConVar(
    "sm_spechud_allow", "1",
    "Allow spechud",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bSpecHudAllow = g_cvSpecHudAllow.BoolValue;
    g_cvSpecHudAllow.AddChangeHook(ConVarChanged_SpecHudAllow);

    g_cvSurvivorLimit = FindConVar("survivor_limit");
    g_iSurvivorLimit  = g_cvSurvivorLimit.IntValue;
    g_cvSurvivorLimit.AddChangeHook(ConVarChanged_SurvivorLimit);

    g_cvInfectedLimit = FindConVar("z_max_player_zombies");
    g_iInfectedLimit  = g_cvInfectedLimit.IntValue;
    g_cvInfectedLimit.AddChangeHook(ConVarChanged_InfectedLimit);

    g_cvPainPillsDecayRate = FindConVar("pain_pills_decay_rate");
    g_fPainPillsDecayRate  = g_cvPainPillsDecayRate.FloatValue;
    g_cvPainPillsDecayRate.AddChangeHook(ConVarChanged_PainPillsDecayRate);

    g_cvGameMode = FindConVar("mp_gamemode");
    g_cvGameMode.AddChangeHook(ConVarChanged_GameMode);

    RegConsoleCmd("sm_spechud", ToggleSpecHudCmd);
    RegConsoleCmd("sm_tankhud", ToggleTankHudCmd);
    RegConsoleCmd("sm_th",      ToggleTankHudCmd);

    HookEvent("tank_spawn",   Event_TankSpawn);
    HookEvent("player_death", Event_PlayerKilled);
    HookEvent("round_start",  Event_RoundStart, EventHookMode_PostNoCopy);

    // Offsets to setting reserve ammo
    g_iOffsetAmmo      = FindSendPropInfo("CTerrorPlayer",     "m_iAmmo");
    g_iPrimaryAmmoType = FindSendPropInfo("CBaseCombatWeapon", "m_iPrimaryAmmoType");
}

public void OnAllPluginsLoaded() {
    g_bBossPctAvailable             = LibraryExists("l4d_boss_percent");
    g_bTankDmgAnnounceAvailable     = LibraryExists("l4d_tank_damage_announce");
    g_bTankAttackControlAvailable   = LibraryExists("l4d2_tank_attack_control");
    g_bHybridScoreModAvailable      = LibraryExists("l4d2_hybrid_scoremod");
    g_bScoreModAvailable            = LibraryExists("l4d2_scoremod");
    g_bNoBhapsAvailable             = LibraryExists("l4d2_nobhaps");
    g_bIsWitchAndTankifierAvailable = LibraryExists("witch_and_tankifier");

    g_cvServerMainName = FindConVar("sn_main_name");
    if (g_cvServerMainName != null) g_cvServerMainName.AddChangeHook(ConVarChanged_ServerMainName);

    g_cvReadyCfgName = FindConVar("l4d_ready_cfg_name");
    if (g_cvReadyCfgName != null) g_cvReadyCfgName.AddChangeHook(ConVarChanged_ReadyCfgName);

    g_cvBlockJumpRock = FindConVar("l4d2_block_jump_rock");
    if (g_cvBlockJumpRock != null) g_cvBlockJumpRock.AddChangeHook(ConVarChanged_BlockJumpRock);
}

public void OnLibraryAdded(const char[] szName) {
    if (strcmp(szName, "l4d_boss_percent") == 0)
        g_bBossPctAvailable = true;

    if (strcmp(szName, "l4d_tank_damage_announce") == 0)
        g_bTankDmgAnnounceAvailable = true;

    if (strcmp(szName, "l4d2_tank_attack_control") == 0)
        g_bTankAttackControlAvailable = true;

    if (strcmp(szName, "l4d2_hybrid_scoremod") == 0)
        g_bHybridScoreModAvailable = true;

    if (strcmp(szName, "l4d2_scoremod") == 0)
        g_bScoreModAvailable = true;

    if (strcmp(szName, "l4d2_nobhaps") == 0)
        g_bNoBhapsAvailable = true;

    if (strcmp(szName, "witch_and_tankifier") == 0)
        g_bIsWitchAndTankifierAvailable = true;
}

public void OnLibraryRemoved(const char[] szName) {
    if (strcmp(szName, "l4d_boss_percent") == 0)
        g_bBossPctAvailable = false;

    if (strcmp(szName, "l4d_tank_damage_announce") == 0)
        g_bTankDmgAnnounceAvailable = false;

    if (strcmp(szName, "l4d2_tank_attack_control") == 0)
        g_bTankAttackControlAvailable = false;

    if (strcmp(szName, "l4d2_hybrid_scoremod") == 0)
        g_bHybridScoreModAvailable = false;

    if (strcmp(szName, "l4d2_scoremod") == 0)
        g_bScoreModAvailable = false;

    if (strcmp(szName, "l4d2_nobhaps") == 0)
        g_bNoBhapsAvailable = false;

    if (strcmp(szName, "witch_and_tankifier") == 0)
        g_bIsWitchAndTankifierAvailable = false;
}

public void OnConfigsExecuted() {
    g_bIsVersus   = SDK_IsVersus();
    g_bIsScavenge = SDK_IsScavenge();

    char szGamemode[32];
    g_cvGameMode.GetString(szGamemode, sizeof(szGamemode));

    g_kvServerName.Rewind();
    if (g_kvServerName.JumpToKey(szGamemode)) g_kvServerName.GetString("szName", g_szGameModeName, sizeof(g_szGameModeName));
    else                                      Format(g_szGameModeName, sizeof(g_szGameModeName), szGamemode);

    if (g_cvBlockJumpRock != null) g_bBlockJumpRock = g_cvBlockJumpRock.BoolValue;
    else                           g_bBlockJumpRock = false;

    if (g_cvServerMainName != null) g_cvServerMainName.GetString(g_szMainName, sizeof(g_szMainName));
    if (g_cvReadyCfgName   != null) g_cvReadyCfgName.GetString(g_szReadyCfgName, sizeof(g_szReadyCfgName));
}

void ConVarChanged_SpecHudAllow(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bSpecHudAllow = g_cvSpecHudAllow.BoolValue;
}

void ConVarChanged_PainPillsDecayRate(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fPainPillsDecayRate = g_cvPainPillsDecayRate.FloatValue;
}

void ConVarChanged_GameMode(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bIsVersus   = SDK_IsVersus();
    g_bIsScavenge = SDK_IsScavenge();
    char szGamemode[32];
    g_cvGameMode.GetString(szGamemode, sizeof(szGamemode));
    g_kvServerName.Rewind();
    if (g_kvServerName.JumpToKey(szGamemode)) g_kvServerName.GetString("szName", g_szGameModeName, sizeof(g_szGameModeName));
    else                                      Format(g_szGameModeName, sizeof(g_szGameModeName), szGamemode);
}

void ConVarChanged_SurvivorLimit(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iSurvivorLimit = g_cvSurvivorLimit.IntValue;
}

void ConVarChanged_InfectedLimit(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iInfectedLimit = g_cvInfectedLimit.IntValue;
}

void ConVarChanged_ServerMainName(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    if (g_cvServerMainName != null) g_cvServerMainName.GetString(g_szMainName, sizeof(g_szMainName));
}

void ConVarChanged_ReadyCfgName(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    if (g_cvReadyCfgName != null) g_cvReadyCfgName.GetString(g_szReadyCfgName, sizeof(g_szReadyCfgName));
}

void ConVarChanged_BlockJumpRock(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    if (g_cvBlockJumpRock != null) g_bBlockJumpRock = g_cvBlockJumpRock.BoolValue;
}

public void OnMapStart() {
    g_bIsTankAlive = false;
    CreateTimer(1.0, HudDrawTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

void Event_PlayerKilled(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!g_bIsTankAlive)
        return;

    int iVictim = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iVictim != g_iTankClient)
        return;

    CreateTimer(0.1, Timer_CheckTank, iVictim);
}

public void OnClientDisconnect_Post(int iClient) {
    if (!g_bIsTankAlive)
        return;

    if (iClient != g_iTankClient)
        return;

    CreateTimer(0.1, Timer_CheckTank, iClient);
}

void Event_TankSpawn(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient      = GetClientOfUserId(eEvent.GetInt("userid"));
    int iEntity      = eEvent.GetInt("tankid");
    g_fMaxTankHealth = float(GetEntProp(iEntity, Prop_Send, "m_iHealth", 4, 0));
    g_iTankClient    = iClient;
    if (!g_bIsTankAlive) g_bIsTankAlive = true;
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    // Reset everything to make sure we don't run into issues when a map is restarted (as GameTime resets)
    g_iTankClient  = 0;
    g_bIsTankAlive = false;
}

Action Timer_CheckTank(Handle hTimer, any aOldTank) {
    if (g_iTankClient != aOldTank)
        return Plugin_Stop;

    int iTankClient = FindTank();
    if (iTankClient && iTankClient != aOldTank) {
        g_iTankClient = iTankClient;
        return Plugin_Stop;
    }

    g_bIsTankAlive = false;
    return Plugin_Stop;
}

public void OnClientAuthorized(int iClient, const char[] szAuth) {
    g_bSpecHudActive    [iClient] = false;
    g_bSpecHudHintShown [iClient] = false;
    g_bTankHudActive    [iClient] = true;
    g_bTankHudHintShown [iClient] = false;
}

Action ToggleSpecHudCmd(int iClient, int iArgs) {
    if (!g_bSpecHudAllow)
        return Plugin_Continue;

    g_bSpecHudActive[iClient] = !g_bSpecHudActive[iClient];
    CPrintToChat(iClient, "{green}[{default}HUD{green}]{default} Spectator HUD is now %s.", (g_bSpecHudActive[iClient] ? "{blue}on{default}" : "{red}off{default}"));
    return Plugin_Handled;
}

Action ToggleTankHudCmd(int iClient, int iArgs) {
    if (!g_bSpecHudAllow)
        return Plugin_Continue;

    if (g_bBossPctAvailable && BossPercent_TankEnabled()) {
        g_bTankHudActive[iClient] = !g_bTankHudActive[iClient];
        CPrintToChat(iClient, "{green}[{default}HUD{green}]{default} Tank HUD is now %s.", (g_bTankHudActive[iClient] ? "{blue}on{default}" : "{red}off{default}"));
    }

    return Plugin_Handled;
}

Action HudDrawTimer(Handle hTimer) {
    if (!g_bSpecHudAllow || IsInReady() || IsInPause())
        return Plugin_Handled;

    bool bSpecsOnServer = false;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsSpectator(i)) {
            bSpecsOnServer = true;
            break;
        }
    }

    if (bSpecsOnServer) {
        Panel mPanel = new Panel();
        FillHeaderInfo(mPanel);
        FillSurvivorInfo(mPanel);
        if (g_bIsVersus || g_bIsScavenge) {
            FillInfectedInfo(mPanel);
            FillTankInfo(mPanel);
            FillGameInfo(mPanel);
        }

        for (int i = 1; i <= MaxClients; i++) {
            if (!g_bSpecHudActive[i] || !IsSpectator(i) || IsFakeClient(i))
                continue;

            mPanel.Send(i, DummySpecHudHandler, 3);
            if (!g_bSpecHudHintShown[i]) {
                g_bSpecHudHintShown[i] = true;
                CPrintToChat(i, "{green}[{default}HUD{green}]{default} Type {green}!spechud{default} into chat to toggle the {blue}Spectator HUD{default}.");
            }
        }
        delete mPanel;
    }

    Panel mTankHud = new Panel();
    if (FillTankInfo(mTankHud, true)) {
        for (int i = 1; i <= MaxClients; i++) {
            if (!g_bTankHudActive[i] || !IsClientInGame(i) || IsFakeClient(i) || IsSurvivor(i) || (g_bSpecHudActive[i] && IsSpectator(i)) || (SolarisVotes_IsVoteInProgress() && SolarisVotes_IsClientInVotePool(i)))
                continue;

            mTankHud.Send(i, DummyTankHudHandler, 3);
            if (!g_bTankHudHintShown[i]) {
                g_bTankHudHintShown[i] = true;
                CPrintToChat(i, "{green}[{default}HUD{green}]{default} Type {green}!tankhud{default} or {green}!th{default} into chat to toggle the {red}Tank HUD{default}.");
            }
        }
    }
    delete mTankHud;
    return Plugin_Continue;
}

int DummySpecHudHandler(Menu mMenu, MenuAction maAction, int iClient, int iParam2) {
    /* Doesn't matter */
    return 0;
}

int DummyTankHudHandler(Menu mMenu, MenuAction maAction, int iClient, int iParam2) {
    /* Doesn't matter */
    return 0;
}

void FillHeaderInfo(Panel mPanel) {
    char szBuffer[128];
    Format(szBuffer, sizeof(szBuffer), "%s :: Spectator HUD", g_szMainName);
    mPanel.DrawText(szBuffer);
    Format(szBuffer, sizeof(szBuffer), "Slots %i/%i | Tickrate %i", GetRealClientCount(), FindConVar("sv_maxplayers").IntValue, RoundToNearest(1.0 / GetTickInterval()));
    mPanel.DrawText(szBuffer);
}

void GetWeaponInfo(int iClient, char[] szInfo, int iLength) {
    int  iActiveWep    = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
    int  wActiveWepId  = IdentifyWeapon(iActiveWep);
    int  iPrimaryWep   = GetPlayerWeaponSlot(iClient, view_as<int>(L4D2WeaponSlot_Primary));
    int  wPrimaryWepId = IdentifyWeapon(iPrimaryWep);
    char szBuffer[32];

    // Let's begin with what player is holding,
    // but cares only pistols if holding secondary.
    switch (wActiveWepId) {
        case WEPID_PISTOL, WEPID_PISTOL_MAGNUM: {
            if (wActiveWepId == WEPID_PISTOL && GetEntProp(iActiveWep, Prop_Send, "m_isDualWielding")) {
                // Dual Pistols Scenario
                // Straight use the szPrefix since full szName is a bit long.
                Format(szBuffer, sizeof(szBuffer), "DP");
            } else {
                GetLongWeaponName(wActiveWepId, szBuffer, sizeof(szBuffer));
            }
            Format(szInfo, iLength, "%s %i", szBuffer, GetWeaponClipAmmo(iActiveWep));
        }
        default: {
            GetLongWeaponName(wPrimaryWepId, szBuffer, sizeof(szBuffer));
            Format(szInfo, iLength, "%s %i/%i", szBuffer, GetWeaponClipAmmo(iPrimaryWep), GetWeaponExtraAmmo(iClient, iActiveWep));
        }
    }

    // Format our result szInfo
    if (iPrimaryWep == -1) {
        // In case with no primary,
        // show the melee full szName.
        if (wActiveWepId == WEPID_MELEE || wActiveWepId == WEPID_CHAINSAW) {
            int iMeleeWepId = IdentifyMeleeWeapon(iActiveWep);
            GetLongMeleeWeaponName(iMeleeWepId, szInfo, iLength);
        }
    } else {
        // Default display -> [Primary <In Detail> | Secondary <Prefix>]
        // Holding melee included in this way
        // i.e. [Chrome 8/56 | M]
        if (GetSlotFromWeaponId(wActiveWepId) != 1 || wActiveWepId == WEPID_MELEE || wActiveWepId == WEPID_CHAINSAW) {
            GetMeleePrefix(iClient, szBuffer, sizeof(szBuffer));
            Format(szInfo, iLength, "%s | %s", szInfo, szBuffer);
        } else {
            // Secondary active -> [Secondary <In Detail> | Primary <Ammo Sum>]
            // i.e. [Deagle 8 | Mac 700]
            GetLongWeaponName(wPrimaryWepId, szBuffer, sizeof(szBuffer));
            Format(szInfo, iLength, "%s | %s %i", szInfo, szBuffer, GetWeaponClipAmmo(iPrimaryWep) + GetWeaponExtraAmmo(iClient, iActiveWep));
        }
    }
}

void GetMeleePrefix(int iClient, char[] szPrefix, int iLength) {
    int iSecondary    = GetPlayerWeaponSlot(iClient, view_as<int>(L4D2WeaponSlot_Secondary));
    int wSecondaryWep = IdentifyWeapon(iSecondary);

    char szBuffer[4];
    switch (wSecondaryWep) {
        case WEPID_NONE: {
            szBuffer = "N";
        }
        case WEPID_PISTOL: {
            szBuffer = (GetEntProp(iSecondary, Prop_Send, "m_isDualWielding") ? "DP" : "P");
        }
        case WEPID_MELEE: {
            szBuffer = "M";
        }
        case WEPID_PISTOL_MAGNUM: {
            szBuffer = "DE";
        }
        default: {
            szBuffer = "?";
        }
    }
    strcopy(szPrefix, iLength, szBuffer);
}

void FillSurvivorInfo(Panel mPanel) {
    char szInfo[100];
    char szName[MAX_NAME_LENGTH];

    int SurvivorTeamIndex = AreTeamsFlipped();
    if (g_bIsScavenge) {
        int iScore = GetScavengeMatchScore(SurvivorTeamIndex);
        Format(szInfo, sizeof szInfo, "->1. Survivors [%d of %d]", iScore, FindConVar("mp_roundlimit").IntValue);
    } else if (g_bIsVersus) {
        Format(szInfo, sizeof(szInfo), "->1. Survivors [%d]", L4D2Direct_GetVSCampaignScore(SurvivorTeamIndex) + GetVersusProgressDistance(SurvivorTeamIndex));
    }

    mPanel.DrawText(" ");
    mPanel.DrawText(szInfo);

    int iSurvivorCount;
    for (int i = 1; i <= MaxClients && iSurvivorCount < g_iSurvivorLimit; i++) {
        if (!IsSurvivor(i))
            continue;

        GetClientFixedName(i, szName, sizeof(szName));
        if (!IsPlayerAlive(i)) {
            Format(szInfo, sizeof(szInfo), "%s: Dead", szName);
        } else {
            if (IsSurvivorHanging(i)) {
                // Nick: <300HP@Hanging>
                Format(szInfo, sizeof(szInfo), "%s: <%iHP@Hanging>", szName, GetClientHealth(i));
            } else if (IsIncapacitated(i)) {
                // Nick: <300HP@1st> [Deagle 8]
                int iActiveWep = GetEntPropEnt(i, Prop_Send, "m_hActiveWeapon");
                GetLongWeaponName(IdentifyWeapon(iActiveWep), szInfo, sizeof(szInfo));
                Format(szInfo, sizeof(szInfo), "%s: <%iHP@%s> [%s %i]", szName, GetClientHealth(i), (GetSurvivorIncapCount(i) == 1 ? "2nd" : "1st"), szInfo, GetWeaponClipAmmo(iActiveWep));
            } else {
                int iTmpHealth  = GetSurvivorTemporaryHealth(i);
                int iHealth     = GetClientHealth(i) + iTmpHealth;
                int iIncapCount = GetSurvivorIncapCount(i);
                GetWeaponInfo(i, szInfo, sizeof(szInfo));
                if (iIncapCount == 0) {
                    // "#" indicates that player is bleeding.
                    // Nick: 99HP# [Chrome 8/72]
                    Format(szInfo, sizeof(szInfo), "%s: %iHP%s [%s]", szName, iHealth, (iTmpHealth > 0 ? "#" : ""), szInfo);
                } else {
                    // Player ever incapped should always be bleeding.
                    // Nick: 99HP (#1st) [Chrome 8/72]
                    Format(szInfo, sizeof(szInfo), "%s: %iHP (#%s) [%s]", szName, iHealth, (iIncapCount == 2 ? "2nd" : "1st"), szInfo);
                }
            }
        }
        iSurvivorCount++;
        mPanel.DrawText(szInfo);
    }

    if (g_bHybridScoreModAvailable) {
        int iHealthBonus    = SMPlus_GetHealthBonus();
        int iMaxHealthBonus = SMPlus_GetMaxHealthBonus();

        int iDamageBonus    = SMPlus_GetDamageBonus();
        int iMaxDamageBonus = SMPlus_GetMaxDamageBonus();

        int iPillsBonus     = SMPlus_GetPillsBonus();
        int iMaxPillsBonus  = SMPlus_GetMaxPillsBonus();

        int iTotalBonus     = SMPlus_GetHealthBonus() + SMPlus_GetDamageBonus() + SMPlus_GetPillsBonus();
        int iMaxTotalBonus  = SMPlus_GetMaxHealthBonus() + SMPlus_GetMaxDamageBonus() + SMPlus_GetMaxPillsBonus();

        char szHealthBonus[64];
        char szDamageBonus[64];
        char szPillsBonus[64];
        char szTotalBonus[64];

        mPanel.DrawText(" ");

        Format(szHealthBonus, sizeof(szHealthBonus), "HB: %i/%i <%.1f%%>",    iHealthBonus, iMaxHealthBonus, ToPercent(iHealthBonus, iMaxHealthBonus));
        Format(szDamageBonus, sizeof(szDamageBonus), "DB: %i/%i <%.1f%%>",    iDamageBonus, iMaxDamageBonus, ToPercent(iDamageBonus, iMaxDamageBonus));
        Format(szPillsBonus,  sizeof(szPillsBonus),  "PB: %i/%i <%.1f%%>",    iPillsBonus,  iMaxPillsBonus,  ToPercent(iPillsBonus,  iMaxPillsBonus));
        Format(szTotalBonus,  sizeof(szTotalBonus),  "Total: %i/%i <%.1f%%>", iTotalBonus,  iMaxTotalBonus,  ToPercent(iTotalBonus,  iMaxTotalBonus));

        mPanel.DrawText(szHealthBonus);
        mPanel.DrawText(szDamageBonus);
        mPanel.DrawText(szPillsBonus);
        mPanel.DrawText(szTotalBonus);
    }

    if (g_bScoreModAvailable) {
        char szHealthBonus[64];
        char szAvgHealth[64];

        mPanel.DrawText(" ");

        Format(szHealthBonus, sizeof(szHealthBonus), "Health Bonus: %i",      SM_HealthBonus());
        Format(szAvgHealth,   sizeof(szAvgHealth),   "Average Health: %.02f", SM_AvgHealth());

        mPanel.DrawText(szHealthBonus);
        mPanel.DrawText(szAvgHealth);
    }
}

void FillInfectedInfo(Panel mPanel) {
    char szInfo[80];
    char szBuffer[16];
    char szName[MAX_NAME_LENGTH];

    int iInfectedTeamIndex = !AreTeamsFlipped();

    if (g_bIsScavenge) {
        int iScore = GetScavengeMatchScore(iInfectedTeamIndex);
        Format(szInfo, sizeof szInfo, "->2. Infected [%d of %d]", iScore, FindConVar("mp_roundlimit").IntValue);
    } else if (g_bIsVersus) {
        Format(szInfo, sizeof szInfo, "->2. Infected [%d]", L4D2Direct_GetVSCampaignScore(iInfectedTeamIndex));
    }

    mPanel.DrawText(" ");
    mPanel.DrawText(szInfo);

    int iInfectedCount;
    for (int i = 1; i <= MaxClients && iInfectedCount < g_iInfectedLimit; i++) {
        if (!IsInfected(i))
            continue;

        GetClientFixedName(i, szName, sizeof(szName));
        if (!IsPlayerAlive(i)) {
            CountdownTimer cSpawnTimer = L4D2Direct_GetSpawnTimer(i);
            float fTimeLeft = -1.0;
            if (cSpawnTimer != CTimer_Null)
                fTimeLeft = CTimer_GetRemainingTime(cSpawnTimer);

            if (fTimeLeft < 0.0) {
                Format(szInfo, sizeof(szInfo), "%s: Dead", szName);
            } else {
                Format(szBuffer, sizeof(szBuffer), "%is", RoundToNearest(fTimeLeft));
                Format(szInfo,   sizeof(szInfo), "%s: Dead (%s)", szName, (RoundToNearest(fTimeLeft) ? szBuffer : "Spawning..."));
            }
        } else {
            L4D2SI zClass = GetInfectedClass(i);
            if (zClass == ZC_Tank)
                continue;

            int iHP    = GetClientHealth(i);
            int iMaxHP = GetEntProp(i, Prop_Send, "m_iMaxHealth");
            if (IsInfectedGhost(i)) {
                // DONE: Handle a case of respawning chipped SI, show the ghost's health
                if (iHP < iMaxHP) {
                    // verygood: Charger (Ghost@1HP)
                    Format(szInfo, sizeof(szInfo), "%s: %s (Ghost@%iHP)", szName, ZOMBIECLASS_NAME(zClass), iHP);
                } else {
                    // verygood: Charger (Ghost)
                    Format(szInfo, sizeof(szInfo), "%s: %s (Ghost)", szName, ZOMBIECLASS_NAME(zClass));
                }
            } else {
                int iCooldown   = RoundToCeil(GetAbilityCooldown(i));
                float fDuration = GetAbilityCooldownDuration(i);
                if (iCooldown > 0 && fDuration > 1.0 && !HasAbilityVictim(i, zClass)) {
                    Format(szBuffer, sizeof(szBuffer), " [%is]", iCooldown);
                } else {
                    szBuffer[0] = '\0';
                }

                if (GetEntityFlags(i) & FL_ONFIRE) {
                    // verygood: Charger (1HP) [On Fire] [6s]
                    Format(szInfo, sizeof(szInfo), "%s: %s (%iHP) [On Fire]%s", szName, ZOMBIECLASS_NAME(zClass), iHP, szBuffer);
                } else {
                    // verygood: Charger (1HP) [6s]
                    Format(szInfo, sizeof(szInfo), "%s: %s (%iHP)%s", szName, ZOMBIECLASS_NAME(zClass), iHP, szBuffer);
                }
            }
        }
        iInfectedCount++;
        mPanel.DrawText(szInfo);
    }

    if (!iInfectedCount) mPanel.DrawText("There is no any SI at this moment.");
}

bool FillTankInfo(Panel mPanel, bool bTankHUD = false) {
    if (!g_bBossPctAvailable)
        return false;

    if (!BossPercent_TankEnabled())
        return false;

    int iTank = FindTank();
    if (iTank == -1)
        return false;

    char szInfo[128];
    if (bTankHUD) {
        Format(szInfo, sizeof(szInfo), g_bIsConfoglEnabled ? g_szReadyCfgName : g_szMainName);
        Format(szInfo, sizeof(szInfo), "%s :: Tank HUD", szInfo);
        mPanel.DrawText(szInfo);
        mPanel.DrawText("‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒");
        if (g_bTankDmgAnnounceAvailable) {
            Format(szInfo, sizeof(szInfo), "⠀Punches: %d | Rocks: %d | Props: %d", TFA_Punches(iTank), TFA_Rocks(iTank), TFA_Hittables(iTank));
            mPanel.DrawText(szInfo);
            Format(szInfo, sizeof(szInfo), "⠀⠀⠀⠀⠀⠀⠀⠀Total Damage: %d", TFA_TotalDmg(iTank));
            mPanel.DrawText(szInfo);
            mPanel.DrawText("‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒");
        }
    } else {
        mPanel.DrawText(" ");
        mPanel.DrawText("->3. Tank");
    }

    int iPassCount = L4D2Direct_GetTankPassedCount();
    switch (iPassCount) {
        case 0: {
            Format(szInfo, sizeof(szInfo), "native");
        }
        case 1: {
            Format(szInfo, sizeof(szInfo), "%ist", iPassCount);
        }
        case 2: {
            Format(szInfo, sizeof(szInfo), "%ind", iPassCount);
        }
        case 3: {
            Format(szInfo, sizeof(szInfo), "%ird", iPassCount);
        }
        default: {
            Format(szInfo, sizeof(szInfo), "%ith", iPassCount);
        }
    }

    if (!IsFakeClient(iTank)) {
        char szName[MAX_NAME_LENGTH];
        GetClientFixedName(iTank, szName, sizeof(szName));
        Format(szInfo, sizeof(szInfo), "Control : %s (%s)", szName, szInfo);
    } else {
        Format(szInfo, sizeof(szInfo), "Control : AI (%s)", szInfo);
    }

    mPanel.DrawText(szInfo);

    int iHealth = GetClientHealth(iTank);
    if (iHealth <= 0 || IsIncapacitated(iTank) || !IsPlayerAlive(iTank)) {
        szInfo = "Health  : Dead";
    } else {
        int iHealthPercent = RoundFloat(iHealth / g_fMaxTankHealth * 100.0);
        Format(szInfo, sizeof(szInfo), "Health  : %i / %i%%", iHealth, ((iHealthPercent < 1) ? 1 : iHealthPercent));
    }

    mPanel.DrawText(szInfo);

    char szBuffer[16];
    if (g_bTankDmgAnnounceAvailable) {
        int iDuration = (TFA_UpTime(iTank) < 0) ? 0 : TFA_UpTime(iTank);
        int iSeconds  = (iDuration % 60);
        int iMinutes  = (iDuration < 60) ? 0 : (iDuration / 60);
        Format(szBuffer, sizeof(szBuffer), " (%s%d:%s%d)", (iMinutes < 10 ? "0" : ""), iMinutes, (iSeconds < 10 ? "0" : ""), iSeconds);
    }
    if (!IsFakeClient(iTank)) {
        Format(szInfo, sizeof(szInfo), "Frustr.  : %d%%%s", GetTankFrustration(iTank), szBuffer);
    } else {
        Format(szInfo, sizeof(szInfo), "Frustr.  : AI %s", szBuffer);
    }

    mPanel.DrawText(szInfo);

    if (GetEntityFlags(iTank) & FL_ONFIRE) {
        int iTimeLeft = RoundToCeil(iHealth / 80.0);
        Format(szInfo, sizeof(szInfo), "On Fire : %is", iTimeLeft);
        mPanel.DrawText(szInfo);
    }

    if (g_bTankAttackControlAvailable) {
        if ((g_bNoBhapsAvailable && !IsClientBlockedBH(iTank)) && !g_bBlockJumpRock || !g_bNoBhapsAvailable && !g_bBlockJumpRock) {
            char szJumpRock[32];
            if (L4D2_GetTankCoolDownTime(iTank) <= 0) {
                Format(szJumpRock, sizeof(szJumpRock), "Jump Rock : READY!");
            } else {
                Format(szJumpRock, sizeof(szJumpRock), "Jump Rock : %s%is", L4D2_GetTankCoolDownTime(iTank) < 10 ? "0" : "", L4D2_GetTankCoolDownTime(iTank));
            }
            mPanel.DrawText(szJumpRock);
        }
    }

    return true;
}

void FillGameInfo(Panel mPanel) {
    int iTank = FindTank();
    if (iTank != -1)
        return;

    // Turns out too much szInfo actually CAN be bad, funny ikr
    char szInfo[64];
    if (g_bIsScavenge) {
        mPanel.DrawText(" ");

        Format(szInfo, sizeof(szInfo), "->3. %s (R#%i)", g_bIsConfoglEnabled ? g_szReadyCfgName : g_szGameModeName, GetScavengeRoundNumber());
        mPanel.DrawText(" ");
        mPanel.DrawText(szInfo);
        Format(szInfo, sizeof szInfo, "Best of %i", FindConVar("mp_roundlimit").IntValue);
        mPanel.DrawText(szInfo);
    } else if (g_bIsVersus) {
        mPanel.DrawText(" ");

        Format(szInfo, sizeof(szInfo), "->3. %s (R#%s)", g_bIsConfoglEnabled ? g_szReadyCfgName : g_szGameModeName, (InSecondHalfOfRound() ? "2" : "1"));
        mPanel.DrawText(szInfo);

        if (!g_bBossPctAvailable)
            return;

        static bool bTankEnabled;
        bTankEnabled = BossPercent_TankEnabled();

        static bool bWitchEnabled;
        bWitchEnabled = BossPercent_WitchEnabled();

        static int iTankFlow;
        iTankFlow = BossPercent_TankPercent();

        static int iWitchFlow;
        iWitchFlow = BossPercent_WitchPercent();

        if (bTankEnabled && bWitchEnabled) {
            if (iTankFlow && iWitchFlow) {
                Format(szInfo, sizeof(szInfo), "Tank: %i%% | Witch: %i%%", iTankFlow, iWitchFlow);
                mPanel.DrawText(szInfo);
                Format(szInfo, sizeof(szInfo), "Current: %i%%", BossPercent_CurrentPercent());
                mPanel.DrawText(szInfo);
            } else if (iTankFlow) {
                Format(szInfo, sizeof(szInfo), "Tank: %i%% | Witch: %s", iTankFlow, IsStaticWitch() ? "Static" : "None");
                mPanel.DrawText(szInfo);
                Format(szInfo, sizeof(szInfo), "Current: %i%%", BossPercent_CurrentPercent());
                mPanel.DrawText(szInfo);
            } else if (iWitchFlow) {
                Format(szInfo, sizeof(szInfo), "Tank: %s | Witch: %i%%", IsStaticTank() ? "Static" : "None", iWitchFlow);
                mPanel.DrawText(szInfo);
                Format(szInfo, sizeof(szInfo), "Current: %i%%", BossPercent_CurrentPercent());
                mPanel.DrawText(szInfo);
            } else {
                Format(szInfo, sizeof(szInfo), "Tank: %s | Witch: %s", IsStaticTank() ? "Static" : "None", IsStaticWitch() ? "Static" : "None");
                mPanel.DrawText(szInfo);
                Format(szInfo, sizeof(szInfo), "Current: %i%%", BossPercent_CurrentPercent());
                mPanel.DrawText(szInfo);
            }
        } else if (bTankEnabled) {
            if (iTankFlow) {
                Format(szInfo, sizeof(szInfo), "Tank: %i%%", iTankFlow);
                mPanel.DrawText(szInfo);
                Format(szInfo, sizeof(szInfo), "Current: %i%%", BossPercent_CurrentPercent());
                mPanel.DrawText(szInfo);
            } else {
                Format(szInfo, sizeof(szInfo), "Tank: %s", IsStaticTank() ? "Static" : "None");
                mPanel.DrawText(szInfo);
                Format(szInfo, sizeof(szInfo), "Current: %i%%", BossPercent_CurrentPercent());
                mPanel.DrawText(szInfo);
            }
        } else if (bWitchEnabled) {
            if (iWitchFlow) {
                Format(szInfo, sizeof(szInfo), "Witch: %i%%", iWitchFlow);
                mPanel.DrawText(szInfo);
                Format(szInfo, sizeof(szInfo), "Current: %i%%", BossPercent_CurrentPercent());
                mPanel.DrawText(szInfo);
            } else {
                Format(szInfo, sizeof(szInfo), "Witch: %s", IsStaticWitch() ? "Static" : "None");
                mPanel.DrawText(szInfo);
                Format(szInfo, sizeof(szInfo), "Current: %i%%", BossPercent_CurrentPercent());
                mPanel.DrawText(szInfo);
            }
        }

        if (bTankEnabled) {
            int iTankClient;
            FindTankSelection();
            // tank selection
            if (g_bTankSelection) {
                iTankClient = TankControlEQ_GetTank();
                if (iTankClient > 0 && IsClientInGame(iTankClient)) {
                    Format(szInfo, sizeof(szInfo), "Tank Control: %N", iTankClient);
                    mPanel.DrawText(szInfo);
                }
            }
        }
    }
}

public void LGO_OnMatchModeLoaded() {
    g_bIsConfoglEnabled = true;
}

public void LGO_OnMatchModeUnloaded() {
    g_bIsConfoglEnabled = false;
}

/**
 *  Stocks
**/

stock float GetAbilityCooldownDuration(int iClient) {
    int iAbility = GetInfectedCustomAbility(iClient);
    if (iAbility != -1 && GetEntProp(iAbility, Prop_Send, "m_hasBeenUsed"))
        return GetCountdownDuration(iAbility);
    return 0.0;
}

stock float GetAbilityCooldown(int iClient) {
    int iAbility = GetInfectedCustomAbility(iClient);
    if (iAbility != -1 && GetEntProp(iAbility, Prop_Send, "m_hasBeenUsed")) {
        if (GetCountdownDuration(iAbility) != 3600.0)
            return GetCountdownTimestamp(iAbility) - GetGameTime();
    }

    return 0.0;
}

stock float GetCountdownDuration(int iEntity) {
    return GetEntPropFloat(iEntity, Prop_Send, "m_duration");
}

stock float GetCountdownTimestamp(int iEntity) {
    return GetEntPropFloat(iEntity, Prop_Send, "m_timestamp");
}

stock int GetInfectedCustomAbility(int iClient) {
    if (HasEntProp(iClient, Prop_Send, "m_customAbility"))
        return GetEntPropEnt(iClient, Prop_Send, "m_customAbility");

    return -1;
}

stock bool HasAbilityVictim(int iClient, L4D2SI zClass) {
    switch (zClass) {
        case ZC_Smoker  : return GetEntPropEnt(iClient, Prop_Send, "m_tongueVictim") > 0;
        case ZC_Hunter  : return GetEntPropEnt(iClient, Prop_Send, "m_pounceVictim") > 0;
        case ZC_Jockey  : return GetEntPropEnt(iClient, Prop_Send, "m_jockeyVictim") > 0;
        case ZC_Charger : return GetEntPropEnt(iClient, Prop_Send, "m_pummelVictim") > 0 || GetEntPropEnt(iClient, Prop_Send, "m_carryVictim") > 0;
    }

    return false;
}

stock void FindTankSelection() {
    g_bTankSelection = (GetFeatureStatus(FeatureType_Native, "TankControlEQ_GetTank") != FeatureStatus_Unknown);
}

// m_iAmmo
stock int GetWeaponExtraAmmo(int iClient, int iWeapon) {
    // Thanks to "Root" or whoever for this method of not hard-coding offsets: https://github.com/zadroot/AmmoManager/blob/master/scripting/ammo_manager.sp
    if (iWeapon <= 0)
        return 0;

    int iOffset = GetEntData(iWeapon, g_iPrimaryAmmoType) * 4;
    if (iOffset <= 0)
        return 0;

    return GetEntData(iClient, g_iOffsetAmmo + iOffset);
}

stock int GetWeaponClipAmmo(int iWeapon) {
    return (iWeapon > 0 ? GetEntProp(iWeapon, Prop_Send, "m_iClip1") : -1);
}

stock void GetClientFixedName(int iClient, char[] szName, int iLength) {
    GetClientName(iClient, szName, iLength);
    if (szName[0] == '[') {
        char szTemp[MAX_NAME_LENGTH];
        strcopy(szTemp, sizeof(szTemp), szName);
        szTemp[sizeof(szTemp) - 2] = 0;
        strcopy(szName[1], iLength - 1, szTemp);
        szName[0] = ' ';
    }

    if (strlen(szName) > 15) {
        szName[13] = szName[14] = szName[15] = '.';
        szName[15] = 0;
    }
}

stock int GetRealClientCount() {
    int iClients = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientConnected(i) && !IsFakeClient(i))
            iClients++;
    }

    return iClients;
}

stock int InSecondHalfOfRound() {
    return GameRules_GetProp("m_bInSecondHalfOfRound");
}

stock int GetScavengeRoundNumber() {
    return GameRules_GetProp("m_nRoundNumber");
}

stock int GetScavengeMatchScore(int iTeamIndex) {
    return GameRules_GetProp("m_iScavengeMatchScore", _, iTeamIndex);
}

stock bool AreTeamsFlipped() {
    return view_as<bool>(GameRules_GetProp("m_bAreTeamsFlipped"));
}

stock int GetVersusProgressDistance(int iTeamIndex) {
    int iDistance = 0;
    for (int i = 0; i < 4; i++) {
        iDistance += GameRules_GetProp("m_iVersusDistancePerSurvivor", _, i + 4 * iTeamIndex);
    }

    return iDistance;
}

stock bool IsSpectator(int iClient) {
    return iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient) && GetClientTeam(iClient) == 1;
}

stock bool IsSurvivor(int iClient) {
    return iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient) && GetClientTeam(iClient) == 2;
}

stock bool IsInfected(int iClient) {
    return iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient) && GetClientTeam(iClient) == 3 && !TM_IsPlayerRespectating(iClient);
}

stock bool IsInfectedGhost(int iClient) {
    return view_as<bool>(GetEntProp(iClient, Prop_Send, "m_isGhost"));
}

stock bool IsIncapacitated(int iClient) {
    return view_as<bool>(GetEntProp(iClient, Prop_Send, "m_isIncapacitated"));
}

stock bool IsSurvivorHanging(int iClient) {
    return view_as<bool>(GetEntProp(iClient, Prop_Send, "m_isHangingFromLedge") | GetEntProp(iClient, Prop_Send, "m_isFallingFromLedge"));
}

stock L4D2SI GetInfectedClass(int iClient) {
    return IsInfected(iClient) ? (view_as<L4D2SI>(GetEntProp(iClient, Prop_Send, "m_zombieClass"))) : ZC_None;
}

stock int GetTankFrustration(int iTank) {
    return (100 - GetEntProp(iTank, Prop_Send, "m_frustration"));
}

stock int GetSurvivorIncapCount(int iClient) {
    return GetEntProp(iClient, Prop_Send, "m_currentReviveCount");
}

stock int GetSurvivorTemporaryHealth(int iClient) {
    int iTempHP = RoundToCeil(GetEntPropFloat(iClient, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(iClient, Prop_Send, "m_healthBufferTime")) * g_fPainPillsDecayRate)) - 1;
    return (iTempHP > 0 ? iTempHP : 0);
}

stock int FindTank() {
    for (int i = 1; i <= MaxClients; i++) {
        if (GetInfectedClass(i) == ZC_Tank && IsPlayerAlive(i))
            return i;
    }

    return -1;
}

stock float ToPercent(int iScore, int iMaxBonus) {
    float fPercent;
    if (iScore < 1) fPercent = 0.0;
    else            fPercent = float(iScore) / float(iMaxBonus) * 100.0;
    return fPercent;
}

stock bool IsStaticTank() {
    if (!g_bIsWitchAndTankifierAvailable)
        return false;

    return IsStaticTankMap();
}

stock bool IsStaticWitch() {
    if (!g_bIsWitchAndTankifierAvailable)
        return false;

    return IsStaticWitchMap();
}