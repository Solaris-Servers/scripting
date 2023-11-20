#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <vip_core>
#include <solaris/stocks>

#undef REQUIRE_PLUGIN
#include <confogl>
#define REQUIRE_PLUGIN

ArrayList g_aMeleeWeapons;
ArrayList g_aTier1Weapons;
ArrayList g_aTier2Weapons;
ArrayList g_aTier2WeaponsName;
ArrayList g_aVipWeapons;
ArrayList g_aVipWeaponsName;

ConVar    g_cvNoLimit;
bool      g_bNoLimit;

ConVar    g_cvMaxWeapons;
int       g_iMaxWeapons;

ConVar    g_cvMaxVipWeapons;
int       g_iMaxVipWeapons;

ConVar    g_cvGameMode;
bool      g_bIsSurvival;

StringMap g_WeaponsTrie;
StringMap g_PlayersTrie;
StringMap g_VipPlayersTrie;

KeyValues g_kvWeapons;

bool      g_bVipAvailable;
bool      g_bIsConfoglEnabled;
bool      g_bIsRoundLive;
bool      g_bIsMapStarted;

public Plugin myinfo = {
    name        = "L4D2 Startup weapons",
    author      = "Shine",
    description = "Provide a weapon menu at round start",
    version     = "0.6.1",
    url         = "http://pills-here.org"
}

public void OnPluginStart() {
    g_cvNoLimit = CreateConVar(
    "l4d2_sw_practice_enabled", "0",
    "Practicogl config enabled or not.",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bNoLimit = g_cvNoLimit.BoolValue;
    g_cvNoLimit.AddChangeHook(ConVarChanged);

    g_cvMaxWeapons = CreateConVar(
    "l4d2_sw_max_weapons", "4",
    "Count of the weapons that user can receive per round.",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_iMaxWeapons = g_cvMaxWeapons.IntValue;
    g_cvMaxWeapons.AddChangeHook(ConVarChanged);

    g_cvMaxVipWeapons = CreateConVar(
    "l4d2_sw_max_vip_weapons", "2",
    "Count of the VIP weapons that user can receive per round.",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_iMaxVipWeapons = g_cvMaxVipWeapons.IntValue;
    g_cvMaxVipWeapons.AddChangeHook(ConVarChanged);

    g_cvGameMode = FindConVar("mp_gamemode");
    g_cvGameMode.AddChangeHook(ConVarChanged);

    g_kvWeapons = new KeyValues("Start_Weapons");

    char szDataFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, szDataFile, sizeof(szDataFile), "data/l4d2_start_weapons.txt");
    g_kvWeapons.ImportFromFile(szDataFile);

    if (!g_kvWeapons.GotoFirstSubKey())
        return;

    g_WeaponsTrie       = new StringMap();
    g_PlayersTrie       = new StringMap();
    g_VipPlayersTrie    = new StringMap();
    g_aMeleeWeapons     = new ArrayList(32);
    g_aTier1Weapons     = new ArrayList(32);
    g_aTier2Weapons     = new ArrayList(32);
    g_aTier2WeaponsName = new ArrayList(32);
    g_aVipWeapons       = new ArrayList(32);
    g_aVipWeaponsName   = new ArrayList(32);

    char szTmp[32];
    char szWeaponTitle[32];
    char szWeaponName[32];
    char szCmd[32];

    do {
        g_kvWeapons.GetSectionName(szTmp, sizeof(szTmp));
        if (g_kvWeapons.GotoFirstSubKey(false)) {
            do {
                g_kvWeapons.GetSectionName(szWeaponTitle, sizeof(szWeaponTitle));
                g_kvWeapons.GetString("name", szWeaponName, sizeof(szWeaponName));
                Format(szCmd, sizeof(szCmd), "sm_%s", szWeaponTitle);
                g_WeaponsTrie.SetString(szCmd, szWeaponName);
                RegConsoleCmd(szCmd, Action_WeaponCmd);
                if (strcmp(szTmp, "melee") == 0) {
                    g_aMeleeWeapons.PushString(szWeaponTitle);
                } else if (strcmp(szTmp, "tier1") == 0) {
                    g_aTier1Weapons.PushString(szWeaponTitle);
                } else if (strcmp(szTmp, "tier2") == 0) {
                    g_aTier2Weapons.PushString(szWeaponTitle);
                    g_aTier2WeaponsName.PushString(szWeaponName);
                } else if (strcmp(szTmp, "vip_weapons") == 0) {
                    g_aVipWeapons.PushString(szWeaponTitle);
                    g_aVipWeaponsName.PushString(szWeaponName);
                }
            } while (g_kvWeapons.GotoNextKey());
            g_kvWeapons.GoBack();
        }
    } while (g_kvWeapons.GotoNextKey());

    RegConsoleCmd("sm_melee",       Action_Melee);
    RegConsoleCmd("sm_m",           Action_Melee);

    RegConsoleCmd("sm_tier1",       Action_Tier1Weapon);
    RegConsoleCmd("sm_t1",          Action_Tier1Weapon);

    RegConsoleCmd("sm_tier2",       Action_Tier2Weapon);
    RegConsoleCmd("sm_t2",          Action_Tier2Weapon);

    RegConsoleCmd("sm_vip_weapons", Action_VipWeaponMenu);
    RegConsoleCmd("sm_vip_w",       Action_VipWeaponMenu);

    RegConsoleCmd("sm_weapon",      Action_WeaponMenu);
    RegConsoleCmd("sm_w",           Action_WeaponMenu);

    HookEvent("round_start",           Event_RoundStart,          EventHookMode_PostNoCopy);
    HookEvent("player_left_safe_area", Event_RoundIsLive,         EventHookMode_PostNoCopy);
    HookEvent("survival_round_start",  Event_SurvivalRoundIsLive, EventHookMode_PostNoCopy);

    if (VIP_IsVIPLoaded())
        VIP_OnVIPLoaded();

    LoadTranslations("l4d2_start_weapons.phrases");
}

public void VIP_OnVIPLoaded() {
    VIP_RegisterFeature("WEAPONS", BOOL, SELECTABLE, OnSelectItem);
}

public void OnAllPluginsLoaded() {
    g_bVipAvailable  = LibraryExists("vip_core");
}

public void OnLibraryAdded(const char[] szName) {
    if (strcmp(szName, "vip_core") != 0)
        return;

    g_bVipAvailable = true;
}

public void OnLibraryRemoved(const char[] szName) {
    if (strcmp(szName, "vip_core") != 0)
        return;

    g_bVipAvailable = false;
}

public void OnPluginEnd() {
    if (!g_bVipAvailable)
        return;

    VIP_UnregisterMe();
}

public void OnMapStart() {
    g_bIsMapStarted = true;
}

public void OnMapEnd() {
    g_bIsMapStarted = false;
}

public void OnConfigsExecuted() {
    if (!g_bIsMapStarted)
        return;

    g_bIsSurvival = SDK_IsSurvival();
}

void ConVarChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    if (g_bIsMapStarted) g_bIsSurvival = SDK_IsSurvival();
    g_bNoLimit       = g_cvNoLimit.BoolValue;
    g_iMaxWeapons    = g_cvMaxWeapons.IntValue;
    g_iMaxVipWeapons = g_cvMaxVipWeapons.IntValue;
}

public bool OnSelectItem(int iClient, const char[] sFeatureName) {
    ShowWeaponsMenu("vip_weapons", iClient);
    return false;
}

int MainMenu_Handler(Menu mMenu, MenuAction maAction, int iClient, int iParam2) {
    switch (maAction) {
        case MenuAction_End: {
            delete mMenu;
        }
        case MenuAction_Select: {
            char szInfo[32];
            if (mMenu.GetItem(iParam2, szInfo, sizeof(szInfo)))
                ShowWeaponsMenu(szInfo, iClient);
        }
    }
    return 0;
}

int WeaponMenu_Handler(Menu mWeaponMenu, MenuAction maAction, int iClient, int iParam2) {
    switch (maAction) {
        case MenuAction_End: {
            delete mWeaponMenu;
        }
        case MenuAction_Cancel: {
            if (iParam2 == MenuCancel_ExitBack)
                Action_WeaponMenu(iClient, 0);
        }
        case MenuAction_Select: {
            char szInfo[16];
            if (mWeaponMenu.GetItem(iParam2, szInfo, sizeof(szInfo))) {
                if (strcmp(szInfo, "sm_vip") == 0 || strcmp(szInfo, "sm_w") == 0) {
                    FakeClientCommand(iClient, szInfo);
                    return 0;
                }
            }
            char szWeaponName[32];
            char szCmd[32];
            bool bFound = mWeaponMenu.GetItem(iParam2, szWeaponName, sizeof(szWeaponName));
            if (bFound) {
                if (IsClientInGame(iClient) && !IsFakeClient(iClient)) {
                    Format(szCmd, sizeof(szCmd), "sm_%s", szWeaponName);
                    FakeClientCommand(iClient, szCmd);
                }
            }
        }
    }
    return 0;
}

stock void ShowWeaponsMenu(const char szType[32], any iClient) {
    if (!IsClientInGame(iClient))
        return;

    Menu mWeaponMenu = new Menu(WeaponMenu_Handler);
    char szMainMenuTitle[64];
    Format(szMainMenuTitle, sizeof(szMainMenuTitle), "%t\n ", "ChooseWeaponMenuTitle");
    mWeaponMenu.SetTitle(szMainMenuTitle);

    char szMenuItemKey  [32] = "";
    char szMenuItemTitle[32] = "";

    if (strcmp(szType, "melee") == 0) {
        for (int i = 0; i < g_aMeleeWeapons.Length; i++) {
            g_aMeleeWeapons.GetString(i, szMenuItemKey, sizeof(szMenuItemKey));
            Format(szMenuItemTitle, sizeof(szMenuItemTitle), "%t (!%s)", szMenuItemKey, szMenuItemKey);
            mWeaponMenu.AddItem(szMenuItemKey, szMenuItemTitle);
        }
        mWeaponMenu.ExitBackButton = true;
    } else if (strcmp(szType, "tier1") == 0) {
        for (int i = 0; i < g_aTier1Weapons.Length; i++) {
            g_aTier1Weapons.GetString(i, szMenuItemKey, sizeof(szMenuItemKey));
            Format(szMenuItemTitle, sizeof(szMenuItemTitle), "%t (!%s)", szMenuItemKey, szMenuItemKey);
            mWeaponMenu.AddItem(szMenuItemKey, szMenuItemTitle);
        }
        mWeaponMenu.ExitBackButton = true;
    } else if (strcmp(szType, "tier2") == 0) {
        for (int i = 0; i < g_aTier2Weapons.Length; i++) {
            g_aTier2Weapons.GetString(i, szMenuItemKey, sizeof(szMenuItemKey));
            Format(szMenuItemTitle, sizeof(szMenuItemTitle), "%t (!%s)", szMenuItemKey, szMenuItemKey);
            mWeaponMenu.AddItem(szMenuItemKey, szMenuItemTitle);
        }
        mWeaponMenu.ExitBackButton = true;
    } else if (strcmp(szType, "vip_weapons") == 0) {
        for (int i = 0; i < g_aVipWeapons.Length; i++) {
            g_aVipWeapons.GetString(i, szMenuItemKey, sizeof(szMenuItemKey));
            Format(szMenuItemTitle, sizeof(szMenuItemTitle), "%t (!%s)", szMenuItemKey, szMenuItemKey);
            mWeaponMenu.AddItem(szMenuItemKey, szMenuItemTitle);
        }
        mWeaponMenu.AddItem("sm_vip", "Back to VIP Menu");
        mWeaponMenu.AddItem("sm_w", "Back to Weapons Menu");
        mWeaponMenu.ExitBackButton = false;
    }
    mWeaponMenu.Display(iClient, MENU_TIME_FOREVER);
}

Action Action_WeaponCmd(int iClient, int iArgs) {
    char szCmd[32];
    char szWeaponName[32];
    if (!IsClientInGame(iClient))
        return Plugin_Handled;

    if (!IsValidSurvivor(iClient) || IsPlayerIncap(iClient)) {
        CPrintToChat(iClient, "%t", "OnlyLiveSurvivor");
        return Plugin_Handled;
    }

    if (g_bIsRoundLive && !g_bNoLimit) {
        CPrintToChat(iClient, "%t", "TheRoundIsLive");
        return Plugin_Handled;
    }

    int  iWeaponsCount;
    char szSteamId[MAX_NAME_LENGTH];
    GetClientAuthId(iClient, AuthId_Steam2, szSteamId, sizeof(szSteamId), true);
    g_PlayersTrie.GetValue(szSteamId, iWeaponsCount);

    if (iWeaponsCount == g_iMaxWeapons) {
        CPrintToChat(iClient, "%t", "YourWeaponsLimitExcited", iWeaponsCount, g_iMaxWeapons);
        return Plugin_Handled;
    }

    GetCmdArg(0, szCmd, sizeof(szCmd));
    g_WeaponsTrie.GetString(szCmd, szWeaponName, sizeof(szWeaponName));

    if (GiveSomething(iClient, szWeaponName, szSteamId)) {
        iWeaponsCount++;
        g_PlayersTrie.SetValue(szSteamId, iWeaponsCount);
        CPrintToChat(iClient, "%t", "YourCurrentWeaponLimit", iWeaponsCount, g_iMaxWeapons);
    }

    return Plugin_Handled;
}

Action Action_WeaponMenu(int iClient, int iArgs) {
    if (iClient <= 0 || !IsClientInGame(iClient))
        return Plugin_Handled;
    Menu mMenu = new Menu(MainMenu_Handler);
    char szMenuTitle[64];
    Format(szMenuTitle, sizeof(szMenuTitle), "%t\n ", "MainMenuTitle");
    mMenu.SetTitle(szMenuTitle);
    mMenu.AddItem("melee", "Melee (!melee)");
    mMenu.AddItem("tier1", "Tier1 (!t1)");
    if (g_bIsSurvival && !g_bIsConfoglEnabled) mMenu.AddItem("tier2", "Tier2 (!t2)");
    mMenu.AddItem("vip_weapons", "VIP Weapons (!vip_weapons)", (VIP_IsClientVIP(iClient) && VIP_IsClientFeatureUse(iClient, "WEAPONS")) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    mMenu.Display(iClient, MENU_TIME_FOREVER);
    return Plugin_Handled;
}

Action Action_Melee(int iClient, int iArgs) {
    ShowWeaponsMenu("melee", iClient);
    return Plugin_Handled;
}

Action Action_Tier1Weapon(int iClient, int iArgs) {
    ShowWeaponsMenu("tier1", iClient);
    return Plugin_Handled;
}

Action Action_Tier2Weapon(int iClient, int iArgs) {
    if (g_bIsSurvival)
        ShowWeaponsMenu("tier2", iClient);
    return Plugin_Handled;
}

Action Action_VipWeaponMenu(int iClient, int iArgs) {
    if (VIP_IsClientVIP(iClient) && VIP_IsClientFeatureUse(iClient, "WEAPONS"))
        ShowWeaponsMenu("vip_weapons", iClient);
    return Plugin_Handled;
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_PlayersTrie.Clear();
    g_VipPlayersTrie.Clear();
    g_bIsRoundLive = false;
}

void Event_RoundIsLive(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (g_bIsSurvival)
        return;

    g_bIsRoundLive = true;
}

void Event_SurvivalRoundIsLive(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bIsRoundLive = true;
}

bool GiveSomething(int iClient, char[] szWhat, const char[] szSteamId) {
    if (IsWeaponNameInVipArray(szWhat) && VIP_IsClientVIP(iClient) && VIP_IsClientFeatureUse(iClient, "WEAPONS")) {
        int iVipWeaponsCount;
        g_VipPlayersTrie.GetValue(szSteamId, iVipWeaponsCount);

        if (iVipWeaponsCount == g_iMaxVipWeapons) {
            CPrintToChat(iClient, "%t", "YourVipWeaponsLimitExcited", iVipWeaponsCount, g_iMaxVipWeapons);
            return false;
        }

        int iFlagsGive = GetCommandFlags("give");
        SetCommandFlags("give", iFlagsGive & ~FCVAR_CHEAT);
        FakeClientCommand(iClient, "give %s", szWhat);
        SetCommandFlags("give", iFlagsGive|FCVAR_CHEAT);
        iVipWeaponsCount++;
        g_VipPlayersTrie.SetValue(szSteamId, iVipWeaponsCount);
        return true;
    }

    if (IsWeaponNameInTier2Array(szWhat)) {
        if (!g_bIsSurvival)
            return false;

        int iFlagsGive = GetCommandFlags("give");
        SetCommandFlags("give", iFlagsGive & ~FCVAR_CHEAT);
        FakeClientCommand(iClient, "give %s", szWhat);
        SetCommandFlags("give", iFlagsGive|FCVAR_CHEAT);
        return true;
    }

    int iFlagsGive = GetCommandFlags("give");
    SetCommandFlags("give", iFlagsGive & ~FCVAR_CHEAT);
    FakeClientCommand(iClient, "give %s", szWhat);
    SetCommandFlags("give", iFlagsGive|FCVAR_CHEAT);
    return true;
}

public void LGO_OnMatchModeLoaded() {
    g_bIsConfoglEnabled = true;
}

public void LGO_OnMatchModeUnloaded() {
    g_bIsConfoglEnabled = false;
}

bool IsValidSurvivor(int iClient) {
    if (GetClientTeam(iClient) != 2 || !IsPlayerAlive(iClient))
        return false;
    return true;
}

bool IsPlayerIncap(int iClient) {
    return view_as<bool>(GetEntProp(iClient, Prop_Send, "m_isIncapacitated"));
}

bool IsWeaponNameInVipArray(char[] szWeaponName) {
    return g_aVipWeaponsName.FindString(szWeaponName) != -1;
}

bool IsWeaponNameInTier2Array(char[] szWeaponName) {
    return g_aTier2WeaponsName.FindString(szWeaponName) != -1;
}