#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <adminmenu>
#define REQUIRE_PLUGIN

/* TopMenu Handle */
TopMenu g_mAdminMenu;

/* ConVar Handle */
ConVar g_cvAmmoAssaultRifleMax;
ConVar g_cvAmmoSmgMax;
ConVar g_cvAmmoShotgunMax;
ConVar g_cvAmmoAutoShotgunMax;
ConVar g_cvAmmoHuntingRifleMax;
ConVar g_cvAmmoSniperRifleMax;
ConVar g_cvAmmoGrenadeLauncherMax;

char g_szChosenWeapon[MAXPLAYERS + 1][56];
char g_szChosenMenu  [MAXPLAYERS + 1][56];

float g_vPos[3];

public Plugin myinfo = {
    name        = "[L4D2] Weapon/Zombie Spawner",
    author      = "Zuko & McFlurry",
    description = "Spawns weapons/zombies where your looking or give weapons to players.",
    version     = "1.0.0",
    url         = "http://zuko.steamunpowered.eu"
}

public void OnPluginStart() {
    /* Admin Commands */
    RegAdminCmd("sm_spawnweapon", Cmd_SpawnWeapon, ADMFLAG_SLAY, "Spawn weapon where you are looking.");
    RegAdminCmd("sm_giveweapon",  Cmd_GiveWeapon,  ADMFLAG_SLAY, "Gives weapon to player.");
    RegAdminCmd("sm_zspawn",      Cmd_SpawnZombie, ADMFLAG_SLAY, "Spawns special zombie where you are looking.");

    /* Minugun Commands */
    RegAdminCmd("sm_spawnmachinegun",  Cmd_SpawnMinigun,  ADMFLAG_SLAY, "Spawns Machine Gun.");
    RegAdminCmd("sm_removemachinegun", Cmd_RemoveMinigun, ADMFLAG_SLAY, "Remove Machine Gun.");

    /* Weapons ammo */
    g_cvAmmoAssaultRifleMax    = FindConVar("ammo_assaultrifle_max");
    g_cvAmmoSmgMax             = FindConVar("ammo_smg_max");
    g_cvAmmoShotgunMax         = FindConVar("ammo_shotgun_max");
    g_cvAmmoAutoShotgunMax     = FindConVar("ammo_autoshotgun_max");
    g_cvAmmoHuntingRifleMax    = FindConVar("ammo_huntingrifle_max");
    g_cvAmmoSniperRifleMax     = FindConVar("ammo_sniperrifle_max");
    g_cvAmmoGrenadeLauncherMax = FindConVar("ammo_grenadelauncher_max");

    /* Menu Handler */
    TopMenu mTopMenu = GetAdminTopMenu();
    if (LibraryExists("adminmenu") && mTopMenu != null)
        OnAdminMenuReady(mTopMenu);

    /* Load translations */
    LoadTranslations("common.phrases");
}

public void OnMapStart() {
    /* Precache Models */
    PrecacheModel("models/v_models/v_rif_sg552.mdl",               true);
    PrecacheModel("models/w_models/weapons/w_rifle_sg552.mdl",     true);
    PrecacheModel("models/v_models/v_snip_awp.mdl",                true);
    PrecacheModel("models/w_models/weapons/w_sniper_awp.mdl",      true);
    PrecacheModel("models/v_models/v_snip_scout.mdl",              true);
    PrecacheModel("models/w_models/weapons/w_sniper_scout.mdl",    true);
    PrecacheModel("models/v_models/v_smg_mp5.mdl",                 true);
    PrecacheModel("models/w_models/weapons/w_smg_mp5.mdl",         true);
    PrecacheModel("models/w_models/weapons/50cal.mdl",             true);
    PrecacheModel("models/w_models/v_rif_m60.mdl",                 true);
    PrecacheModel("models/w_models/weapons/w_m60.mdl",             true);
    PrecacheModel("models/v_models/v_m60.mdl",                     true);
    PrecacheModel("models/infected/witch_bride.mdl",               true);
    PrecacheModel("models/props_industrial/barrel_fuel.mdl",       true);
    PrecacheModel("models/props_industrial/barrel_fuel_partb.mdl", true);
    PrecacheModel("models/props_industrial/barrel_fuel_parta.mdl", true);
    PrecacheModel("models/w_models/weapons/w_minigun.mdl",         true);
    PrecacheModel("models/w_models/weapons/50cal.mdl",             true);
}

/* Spawn Weapon */
Action Cmd_SpawnWeapon(int iClient, int iArgs) {
    if (iClient == 0) return Plugin_Handled;

    char szWeapon[40];
    char szArg1  [40];
    char szArg2  [5];

    int iAmount;
    if (iArgs == 2) {
        GetCmdArg(1, szArg1, sizeof(szArg1));
        GetCmdArg(2, szArg2, sizeof(szArg2));
        FormatEx(szWeapon, sizeof(szWeapon), "weapon_%s", szArg1);
        iAmount = StringToInt(szArg2);
    } else if (iArgs == 1) {
        GetCmdArg(1, szArg1, sizeof(szArg1));
        FormatEx(szWeapon, sizeof(szWeapon), "weapon_%s", szArg1);
        iAmount = 1;
    } else {
        ReplyToCommand(iClient, "Usage: sm_spawnweapon [weapon_name] <amount>");
        return Plugin_Handled;
    }

    if (!SetTeleportEndPoint(iClient)) {
        ReplyToCommand(iClient, "Could not find spawn point.");
        return Plugin_Handled;
    }

    int iMaxAmmo = 0;
    if (strcmp(szWeapon, "rifle") == 0 || strcmp(szWeapon, "rifle_ak47") == 0 || strcmp(szWeapon, "rifle_desert") == 0 || strcmp(szWeapon, "rifle_sg552") == 0) {
        iMaxAmmo = g_cvAmmoAssaultRifleMax.IntValue;
    } else if (strcmp(szWeapon, "smg") == 0 || strcmp(szWeapon, "smg_silenced") == 0 || strcmp(szWeapon, "smg_mp5") == 0) {
        iMaxAmmo = g_cvAmmoSmgMax.IntValue;
    } else if (strcmp(szWeapon, "pumpshotgun") == 0 || strcmp(szWeapon, "shotgun_chrome") == 0) {
        iMaxAmmo = g_cvAmmoShotgunMax.IntValue;
    } else if (strcmp(szWeapon, "autoshotgun") == 0 || strcmp(szWeapon, "shotgun_spas") == 0) {
        iMaxAmmo = g_cvAmmoAutoShotgunMax.IntValue;
    } else if (strcmp(szWeapon, "hunting_rifle") == 0) {
        iMaxAmmo = g_cvAmmoHuntingRifleMax.IntValue;
    } else if (strcmp(szWeapon, "sniper_military") == 0 || strcmp(szWeapon, "sniper_scout") == 0 || strcmp(szWeapon, "sniper_awp") == 0) {
        iMaxAmmo = g_cvAmmoSniperRifleMax.IntValue;
    } else if (strcmp(szWeapon, "grenade_launcher") == 0) {
        iMaxAmmo = g_cvAmmoGrenadeLauncherMax.IntValue;
    }

    int i = 0;
    while (++i <= iAmount) {
        if (strcmp(szWeapon, "weapon_explosive_barrel") == 0) {
            int iEnt = CreateEntityByName("prop_fuel_barrel");
            DispatchKeyValue(iEnt, "model", "models/props_industrial/barrel_fuel.mdl");
            DispatchKeyValue(iEnt, "BasePiece", "models/props_industrial/barrel_fuel_partb.mdl");
            DispatchKeyValue(iEnt, "FlyingPiece01", "models/props_industrial/barrel_fuel_parta.mdl");
            DispatchKeyValue(iEnt, "DetonateParticles", "weapon_pipebomb");
            DispatchKeyValue(iEnt, "FlyingParticles", "barrel_fly");
            DispatchKeyValue(iEnt, "DetonateSound", "BaseGrenade.Explode");
            DispatchSpawn(iEnt);
            g_vPos[2] -= 10.0 - (i * 2);
            TeleportEntity(iEnt, g_vPos, NULL_VECTOR, NULL_VECTOR); //Teleport spawned weapon
        } else if (strcmp(szWeapon, "weapon_laser_sight") == 0) {
            char szPos[64];
            int  iEnt = CreateEntityByName("upgrade_spawn");
            DispatchKeyValue(iEnt, "count", "1");
            DispatchKeyValue(iEnt, "laser_sight", "1");
            Format(szPos, sizeof(szPos), "%1.1f %1.1f %1.1f", g_vPos[0], g_vPos[1], g_vPos[2] -= 10.0 - (i * 2));
            DispatchKeyValue(iEnt, "origin", szPos);
            DispatchKeyValue(iEnt, "classname", "upgrade_spawn");
            DispatchSpawn(iEnt);
        } else {
            int iWeapon = CreateEntityByName(szWeapon);
            if (IsValidEntity(iWeapon)) {
                // Spawn weapon (entity)
                DispatchSpawn(iWeapon);
                if (strcmp(szWeapon, "weapon_ammo_spawn") != 0)
                    if (iMaxAmmo) SetEntProp(iWeapon, Prop_Send, "m_iExtraPrimaryAmmo", iMaxAmmo, 4); // Adds max ammo for weapon
                g_vPos[2] -= 10.0-(i * 2);
                TeleportEntity(iWeapon, g_vPos, NULL_VECTOR, NULL_VECTOR); // Teleport spawned weapon
            }
        }
    }
    return Plugin_Handled;
}

/* Give Weapon */
Action Cmd_GiveWeapon(int iClient, int iArgs) {
    if (iClient == 0) return Plugin_Handled;

    if (iArgs < 2) {
        ReplyToCommand(iClient, "Usage: sm_giveweapon <#userid|name> [weapon_name]");
        return Plugin_Handled;
    }

    char szArg[65];
    GetCmdArg(1, szArg, sizeof(szArg));

    char szWeapon[65];
    GetCmdArg(2, szWeapon, sizeof(szWeapon));

    char szTargetName[MAX_TARGET_LENGTH];
    int  iTargetCount;
    bool bTnIsMl;
    int[] iTargetList = new int[MaxClients + 1];

    if ((iTargetCount = ProcessTargetString(szArg, iClient, iTargetList, MaxClients + 1, COMMAND_FILTER_ALIVE, szTargetName, sizeof(szTargetName), bTnIsMl)) <= 0) {
        ReplyToTargetError(iClient, iTargetCount);
        return Plugin_Handled;
    }
    for (int i = 0; i < iTargetCount; i++) {
        if ((strcmp(szWeapon, "laser_sight") == 0) || (strcmp(szWeapon, "explosive_ammo") == 0) || (strcmp(szWeapon, "incendiary_ammo") == 0)) {
            int iFlags = GetCommandFlags("upgrade_add");
            SetCommandFlags("upgrade_add", iFlags & ~FCVAR_CHEAT);
            if (IsClientInGame(iTargetList[i])) FakeClientCommand(iTargetList[i], "upgrade_add %s", szWeapon);
            SetCommandFlags("upgrade_add", iFlags|FCVAR_CHEAT);
            LogAction(iClient, iTargetList[i], "\"%L\" give weapon (weapon: \"%s\") to \"%s\")", iClient, szWeapon, iTargetList[i]);
        } else {
            int iFlags = GetCommandFlags("give");
            SetCommandFlags("give", iFlags & ~FCVAR_CHEAT);
            if (IsClientInGame(iTargetList[i])) FakeClientCommand(iTargetList[i], "give %s", szWeapon);
            SetCommandFlags("give", iFlags|FCVAR_CHEAT);
            LogAction(iClient, iTargetList[i], "\"%L\" give weapon (weapon: \"%s\") to \"%s\")", iClient, szWeapon, iTargetList[i]);
        }
    }
    return Plugin_Handled;
}

/* Spawn Zombie */
Action Cmd_SpawnZombie(int iClient, int iArgs) {
    if (iClient == 0) return Plugin_Handled;

    char szZombie[56];
    char szAmount[5];

    int iAmount;
    if (iArgs == 2) {
        GetCmdArg(1, szZombie, sizeof(szZombie));
        GetCmdArg(2, szAmount, sizeof(szAmount));
        iAmount = StringToInt(szAmount);
    } else if (iArgs == 1) {
        GetCmdArg(1, szZombie, sizeof(szZombie));
        iAmount = 1;
    } else {
        ReplyToCommand(iClient, "Usage: sm_zspawn [zombie_name] <amount>");
        return Plugin_Handled;
    }

    int i = 0;
    while (++i <= iAmount) {
        int iFlags = GetCommandFlags("z_spawn");
        SetCommandFlags("z_spawn", iFlags & ~FCVAR_CHEAT);
        FakeClientCommand(iClient, "z_spawn %s", szZombie);
        SetCommandFlags("z_spawn", iFlags|FCVAR_CHEAT);
        LogAction(iClient, -1, "\"%L\" spawned zombie (\"%s\")", iClient, szZombie);
    }
    return Plugin_Handled;
}

/* Minigun */
Action Cmd_SpawnMinigun(int iClient, int iArgs) {
    if (iClient == 0) return Plugin_Handled;

    if (iArgs == 1) {
        char szArg[40];
        GetCmdArg(1, szArg, sizeof(szArg));
        switch (StringToInt(szArg)) {
            case 1: SpawnMiniGun(iClient, 1);
            case 2: SpawnMiniGun(iClient, 2);
        }
    } else {
        ReplyToCommand(iClient, "Usage: sm_spawnmachinegun 1 or 2. 1 = Spawn .50 Cal, 2 = Spawn MiniGun");
        return Plugin_Handled;
    }
    return Plugin_Handled;
}

void SpawnMiniGun(int iClient, int iType) {
    int iMiniGun;
    switch (iType) {
        case 1: {
            iMiniGun = CreateEntityByName("prop_minigun");
            if (iMiniGun == -1) ReplyToCommand(iClient, "Failed to create Machine Gun.");
            DispatchKeyValue(iMiniGun, "model", "models/w_models/weapons/50cal.mdl");
            LogAction(iClient, -1, "\"%L\" spawn minigun \"50cal\"", iClient);
        }
        case 2: {
            iMiniGun = CreateEntityByName("prop_minigun_l4d1");
            if (iMiniGun == -1) ReplyToCommand(iClient, "Failed to create Machine Gun.");
            DispatchKeyValue(iMiniGun, "model", "models/w_models/weapons/w_minigun.mdl");
            LogAction(iClient, -1, "\"%L\" spawn minigun \"minigun_l4d1\"", iClient);
        }
    }

    DispatchKeyValueFloat(iMiniGun, "MaxPitch",  360.00);
    DispatchKeyValueFloat(iMiniGun, "MinPitch", -360.00);
    DispatchKeyValueFloat(iMiniGun, "MaxYaw",     90.00);
    DispatchSpawn(iMiniGun);

    float vOrigin[3];
    GetClientAbsOrigin(iClient, vOrigin);
    float vAngles[3];
    GetClientEyeAngles(iClient, vAngles);
    float vDirection[3];
    GetAngleVectors(vAngles, vDirection, NULL_VECTOR, NULL_VECTOR);

    vOrigin[0] += vDirection[0] * 32;
    vOrigin[1] += vDirection[1] * 32;
    vOrigin[2] += vDirection[2] * 1;
    vAngles[0] = 0.0;
    vAngles[2] = 0.0;

    DispatchKeyValueVector(iMiniGun, "Angles", vAngles);
    DispatchSpawn(iMiniGun);
    TeleportEntity(iMiniGun, vOrigin, NULL_VECTOR, NULL_VECTOR);
}

Action Cmd_RemoveMinigun(int iClient, int iArgs) {
    if (iClient == 0) return Plugin_Handled;
    RemoveMiniGun(iClient);
    return Plugin_Handled;
}

void RemoveMiniGun(int iClient) {
    int iMiniGun = GetClientAimTarget(iClient, false);
    if (iMiniGun == -1 || !IsValidEntity (iMiniGun)) {
        ReplyToCommand(iClient, "You are not looking at any entity or entity is not valid.");
        return;
    }
    char szClsName[128];
    GetEdictClassname(iMiniGun, szClsName, sizeof(szClsName));
    if (strcmp(szClsName, "prop_minigun") == 0 || strcmp(szClsName, "prop_minigun_l4d1") == 0 || strcmp(szClsName, "prop_mounted_machine_gun") == 0) {
        RemoveEdict(iMiniGun);
    } else {
        ReplyToCommand(iClient, "This is not a Machine Gun.");
    }
}

/* Menu */
public void OnAdminMenuReady(Handle hTopMenu) {
    TopMenu mTopMenu = TopMenu.FromHandle(hTopMenu);
    if (mTopMenu == g_mAdminMenu) return;
    g_mAdminMenu = mTopMenu;
    TopMenuObject mCategory = g_mAdminMenu.AddCategory("sm_ws_topmenu", Handle_Category, "sm_ws_topmenu", ADMFLAG_SLAY, "Weapon Spawner");
    if (mCategory != INVALID_TOPMENUOBJECT) {
        g_mAdminMenu.AddItem("sm_sw_menu",    AdminMenu_WeaponSpawner,       mCategory, "sm_sw_menu",    ADMFLAG_SLAY, "Spawn Weapon");
        g_mAdminMenu.AddItem("sm_gw_menu",    AdminMenu_WeaponGive,          mCategory, "sm_gw_menu",    ADMFLAG_SLAY, "Give Weapon");
        g_mAdminMenu.AddItem("sm_spawn_menu", AdminMenu_ZombieSpawnMenu,     mCategory, "sm_spawn_menu", ADMFLAG_SLAY, "Spawn Infected");
        g_mAdminMenu.AddItem("sm_smg_menu",   AdminMenu_MachineGunSpawnMenu, mCategory, "sm_smg_menu",   ADMFLAG_SLAY, "Spawn MiniGun");
    }
}

int Handle_Category(TopMenu mTopMenu, TopMenuAction mAction, TopMenuObject mObjectId, int iClient, char[] szBuffer, int iMaxLength) {
    switch (mAction) {
        case TopMenuAction_DisplayTitle  : Format(szBuffer, iMaxLength, "What do you want?");
        case TopMenuAction_DisplayOption : Format(szBuffer, iMaxLength, "Weapon Spawner");
    }
    return 0;
}

/* Weapon Spawn Menu */
int AdminMenu_WeaponSpawner(TopMenu mTopMenu, TopMenuAction mAction, TopMenuObject mObjectId, int iClient, char[] szBuffer, int iMaxLength) {
    switch (mAction) {
        case TopMenuAction_DisplayOption : Format(szBuffer, iMaxLength, "Spawn Weapon");
        case TopMenuAction_SelectOption  : DisplayWeaponMenu(iClient);
    }
    return 0;
}

void DisplayWeaponMenu(int iClient) {
    Menu mMenu = new Menu(MenuHandler_Weapons);
    mMenu.ExitBackButton = true;
    mMenu.SetTitle("Spawn Weapon:");
    mMenu.AddItem("0", "Melee Weapons");
    mMenu.AddItem("1", "Bullet Based");
    mMenu.AddItem("2", "Shell Based");
    mMenu.AddItem("3", "Explosive Based");
    mMenu.AddItem("4", "Health Related");
    mMenu.AddItem("5", "Misc");
    mMenu.Display(iClient, MENU_TIME_FOREVER);
}

int MenuHandler_Weapons(Menu mMenu, MenuAction mAction, int iClient, int iParam) {
    switch (mAction) {
        case MenuAction_End: {
            delete mMenu;
        }
        case MenuAction_Cancel: {
            if (iParam == MenuCancel_ExitBack && g_mAdminMenu != null)
                g_mAdminMenu.Display(iClient, TopMenuPosition_LastCategory);
        }
        case MenuAction_Select: {
            switch (iParam) {
                case 0: BuildMeleeMenu(iClient);
                case 1: BuildBulletBasedMenu(iClient);
                case 2: BuildShellBasedMenu(iClient);
                case 3: BuildExplosiveBasedMenu(iClient);
                case 4: BuildHealthMenu(iClient);
                case 5: BuildMiscMenu(iClient);
            }
        }
    }
    return 0;
}

void BuildMeleeMenu(int iClient, int iMenuPos = 0) {
    Menu mMenu = new Menu(MenuHandler_SpawnMelee);
    mMenu.SetTitle("Melee Weapons:");
    mMenu.AddItem("cricket_bat",     "Cricket Bat");
    mMenu.AddItem("crowbar",         "Crowbar");
    mMenu.AddItem("electric_guitar", "Electric Guitar");
    mMenu.AddItem("fireaxe",         "Fire Axe");
    mMenu.AddItem("frying_pan",      "Frying Pan");
    mMenu.AddItem("katana",          "Katana");
    mMenu.AddItem("machete",         "Machete");
    mMenu.AddItem("tonfa",           "Tonfa");
    mMenu.AddItem("baseball_bat",    "Baseball Bat");
    mMenu.AddItem("knife",           "Knife");
    mMenu.AddItem("shovel",          "Shovel");
    mMenu.AddItem("pitchfork",       "Pitchfork");
    mMenu.ExitBackButton = true;
    g_szChosenMenu[iClient] = "MeleeBasedSpawnMenu";
    mMenu.DisplayAt(iClient, iMenuPos, MENU_TIME_FOREVER);
}

void BuildBulletBasedMenu(int iClient, int iMenuPos = 0) {
    Menu mMenu = new Menu(MenuHandler_SpawnWeapon);
    mMenu.SetTitle("Bullet Based Weapons:");
    mMenu.AddItem("weapon_pistol",          "Pistol");
    mMenu.AddItem("weapon_pistol_magnum",   "Desert Eagle");
    mMenu.AddItem("weapon_smg",             "Submachine Gun");
    mMenu.AddItem("weapon_smg_silenced",    "Silenced Submachine Gun");
    mMenu.AddItem("weapon_smg_mp5",         "Submachine Gun MP5");
    mMenu.AddItem("weapon_rifle",           "Rifle M16");
    mMenu.AddItem("weapon_rifle_ak47",      "AK-47");
    mMenu.AddItem("weapon_rifle_desert",    "FN SCAR");
    mMenu.AddItem("weapon_rifle_sg552",     "SIG SG 550");
    mMenu.AddItem("weapon_hunting_rifle",   "Hunting Rifle");
    mMenu.AddItem("weapon_sniper_military", "Military Sniper");
    mMenu.AddItem("weapon_sniper_scout",    "Scout");
    mMenu.AddItem("weapon_sniper_awp",      "AWP");
    mMenu.AddItem("weapon_rifle_m60",       "Rifle M60");
    mMenu.ExitBackButton = true;
    g_szChosenMenu[iClient] = "BulletBasedSpawnMenu";
    mMenu.DisplayAt(iClient, iMenuPos, MENU_TIME_FOREVER);
}

void BuildShellBasedMenu(int iClient, int iMenuPos = 0) {
    Menu mMenu = new Menu(MenuHandler_SpawnWeapon);
    mMenu.SetTitle("Shell Based Weapons:");
    mMenu.AddItem("weapon_pumpshotgun",    "Pump Shotgun");
    mMenu.AddItem("weapon_shotgun_chrome", "Chrome Shotgun");
    mMenu.AddItem("weapon_autoshotgun",    "Auto Shotgun");
    mMenu.AddItem("weapon_shotgun_spas",   "Spas Shotgun");
    mMenu.ExitBackButton = true;
    g_szChosenMenu[iClient] = "ShellBasedSpawnMenu";
    mMenu.DisplayAt(iClient, iMenuPos, MENU_TIME_FOREVER);
}

void BuildExplosiveBasedMenu(int iClient, int iMenuPos = 0) {
    Menu mMenu = new Menu(MenuHandler_SpawnWeapon);
    mMenu.SetTitle("Explosive Based Weapons:");
    mMenu.AddItem("weapon_grenade_launcher", "Grenade Launcher");
    mMenu.AddItem("weapon_explosive_barrel", "Explosive Barrel");
    mMenu.AddItem("weapon_fireworkcrate",    "Fireworks Crate");
    mMenu.AddItem("weapon_gascan",           "Gascan");
    mMenu.AddItem("weapon_molotov",          "Molotov");
    mMenu.AddItem("weapon_oxygentank",       "Oxygen Tank");
    mMenu.AddItem("weapon_pipe_bomb",        "Pipe Bomb");
    mMenu.AddItem("weapon_propanetank",      "Propane Tank");
    mMenu.ExitBackButton = true;
    g_szChosenMenu[iClient] = "ExplosiveBasedSpawnMenu";
    mMenu.DisplayAt(iClient, iMenuPos, MENU_TIME_FOREVER);
}

void BuildHealthMenu(int iClient, int iMenuPos = 0) {
    Menu mMenu = new Menu(MenuHandler_SpawnWeapon);
    mMenu.SetTitle("Health Related:");
    mMenu.AddItem("weapon_adrenaline",    "Adrenaline");
    mMenu.AddItem("weapon_defibrillator", "Defibrillator");
    mMenu.AddItem("weapon_first_aid_kit", "First Aid Kit");
    mMenu.AddItem("weapon_pain_pills",    "Pain Pills");
    mMenu.ExitBackButton = true;
    g_szChosenMenu[iClient] = "HealthSpawnMenu";
    mMenu.DisplayAt(iClient, iMenuPos, MENU_TIME_FOREVER);
}

void BuildMiscMenu(int iClient, int iMenuPos = 0) {
    Menu mMenu = new Menu(MenuHandler_SpawnWeapon);
    mMenu.SetTitle("Misc Weapons:");
    mMenu.AddItem("weapon_chainsaw",               "Chain Saw");
    mMenu.AddItem("weapon_ammo_spawn",             "Ammo Stack");
    mMenu.AddItem("weapon_laser_sight",            "Laser Sight Box");
    mMenu.AddItem("weapon_upgradepack_explosive",  "Explosive Ammo Pack");
    mMenu.AddItem("weapon_upgradepack_incendiary", "Incendiary Ammo Pack");
    mMenu.AddItem("weapon_vomitjar",               "Vomit Jar");
    mMenu.AddItem("weapon_gnome",                  "Gnome");
    mMenu.AddItem("weapon_cola_bottles",           "Cola");
    mMenu.ExitBackButton = true;
    g_szChosenMenu[iClient] = "MiscSpawnMenu";
    mMenu.DisplayAt(iClient, iMenuPos, MENU_TIME_FOREVER);
}

int MenuHandler_SpawnMelee(Menu mMenu, MenuAction mAction, int iClient, int iParam) {
    switch (mAction) {
        case MenuAction_End: {
            delete mMenu;
        }
        case MenuAction_Cancel: {
            if (iParam == MenuCancel_ExitBack)
                DisplayWeaponMenu(iClient);
        }
        case MenuAction_Select: {
            char szWeapon[32];
            GetMenuItem(mMenu, iParam, szWeapon, sizeof(szWeapon));

            if (!SetTeleportEndPoint(iClient)) PrintToChat(iClient, "Could not find spawn point.");

            int iWeapon = CreateEntityByName("weapon_melee");
            if (IsValidEntity(iWeapon)) {
                DispatchKeyValue(iWeapon, "melee_script_name", szWeapon);
                DispatchSpawn(iWeapon); // Spawn weapon (entity)
                g_vPos[2] -= 10.0;
                TeleportEntity(iWeapon, g_vPos, NULL_VECTOR, NULL_VECTOR); // Teleport spawned weapon
                char szModelName[128];
                GetEntPropString(iWeapon, Prop_Data, "m_ModelName", szModelName, sizeof(szModelName));
            }
            LogAction(iClient, -1, "\"%L\" spawn weapon (weapon: \"%s\")", iClient, szWeapon);
            int iMenuPos = mMenu.Selection;
            ChosenMenuHistory(iClient, iMenuPos); // Redraw menu after item selection
        }
    }
    return 0;
}

int MenuHandler_SpawnWeapon(Menu mMenu, MenuAction mAction, int iClient, int iParam) {
    switch (mAction) {
        case MenuAction_End: {
            delete mMenu;
        }
        case MenuAction_Cancel: {
            if (iParam == MenuCancel_ExitBack)
                DisplayWeaponMenu(iClient);
        }
        case MenuAction_Select: {
            char szWeapon[32];
            GetMenuItem(mMenu, iParam, szWeapon, sizeof(szWeapon));

            if (!SetTeleportEndPoint(iClient)) PrintToChat(iClient, "Could not find spawn point.");

            int iMaxAmmo = 0;
            if (strcmp(szWeapon, "weapon_rifle") == 0 || strcmp(szWeapon, "weapon_rifle_ak47") == 0 || strcmp(szWeapon, "weapon_rifle_desert") == 0 || strcmp(szWeapon, "weapon_rifle_sg552") == 0) {
                iMaxAmmo = g_cvAmmoAssaultRifleMax.IntValue;
            } else if (strcmp(szWeapon, "weapon_smg") == 0 || strcmp(szWeapon, "weapon_smg_silenced") == 0 || strcmp(szWeapon, "weapon_smg_mp5") == 0) {
                iMaxAmmo = g_cvAmmoSmgMax.IntValue;
            } else if (strcmp(szWeapon, "weapon_pumpshotgun") == 0 || strcmp(szWeapon, "weapon_shotgun_chrome") == 0) {
                iMaxAmmo = g_cvAmmoShotgunMax.IntValue;
            } else if (strcmp(szWeapon, "weapon_autoshotgun") == 0 || strcmp(szWeapon, "weapon_shotgun_spas") == 0) {
                iMaxAmmo = g_cvAmmoAutoShotgunMax.IntValue;
            } else if (strcmp(szWeapon, "weapon_hunting_rifle") == 0) {
                iMaxAmmo = g_cvAmmoHuntingRifleMax.IntValue;
            } else if (strcmp(szWeapon, "weapon_sniper_military") == 0 || strcmp(szWeapon, "weapon_sniper_scout") == 0 || strcmp(szWeapon, "weapon_sniper_awp") == 0) {
                iMaxAmmo = g_cvAmmoSniperRifleMax.IntValue;
            } else if (strcmp(szWeapon, "weapon_grenade_launcher") == 0) {
                iMaxAmmo = g_cvAmmoGrenadeLauncherMax.IntValue;
            }

            if (strcmp(szWeapon, "weapon_explosive_barrel") == 0) {
                int iEnt = CreateEntityByName("prop_fuel_barrel");
                DispatchKeyValue(iEnt, "model", "models/props_industrial/barrel_fuel.mdl");
                DispatchKeyValue(iEnt, "BasePiece", "models/props_industrial/barrel_fuel_partb.mdl");
                DispatchKeyValue(iEnt, "FlyingPiece01", "models/props_industrial/barrel_fuel_parta.mdl");
                DispatchKeyValue(iEnt, "DetonateParticles", "weapon_pipebomb");
                DispatchKeyValue(iEnt, "FlyingParticles", "barrel_fly");
                DispatchKeyValue(iEnt, "DetonateSound", "BaseGrenade.Explode");
                DispatchSpawn(iEnt);
                g_vPos[2] -= 10.0;
                TeleportEntity(iEnt, g_vPos, NULL_VECTOR, NULL_VECTOR); // Teleport spawned weapon
            } else if (strcmp(szWeapon, "weapon_laser_sight") == 0) {
                char szPos[64];
                int  iEnt = CreateEntityByName("upgrade_spawn");
                DispatchKeyValue(iEnt, "count", "1");
                DispatchKeyValue(iEnt, "laser_sight", "1");
                Format(szPos, sizeof(szPos), "%1.1f %1.1f %1.1f", g_vPos[0], g_vPos[1], g_vPos[2] -= 10.0);
                DispatchKeyValue(iEnt, "origin", szPos);
                DispatchKeyValue(iEnt, "classname", "upgrade_spawn");
                DispatchSpawn(iEnt);
            } else {
                int iWeapon = CreateEntityByName(szWeapon);
                if (IsValidEntity(iWeapon)) {
                    DispatchSpawn(iWeapon); // Spawn weapon (entity)
                    if (strcmp(szWeapon, "weapon_ammo_spawn") != 0)
                        if (iMaxAmmo) SetEntProp(iWeapon, Prop_Send, "m_iExtraPrimaryAmmo", iMaxAmmo, 4); // Adds max ammo for weapon
                }
                g_vPos[2] -= 10.0;
                TeleportEntity(iWeapon, g_vPos, NULL_VECTOR, NULL_VECTOR); // Teleport spawned weapon
            }
            LogAction(iClient, -1, "\"%L\" spawn weapon (weapon: \"%s\")", iClient, szWeapon);
            int iMenuPos = mMenu.Selection;
            ChosenMenuHistory(iClient, iMenuPos); // Redraw menu after item selection
        }
    }
    return 0;
}

/* Weapon Give Menu */
int AdminMenu_WeaponGive(TopMenu mTopMenu, TopMenuAction mAction, TopMenuObject mObjectId, int iClient, char[] szBuffer, int iMaxLength) {
    switch (mAction) {
        case TopMenuAction_DisplayOption : Format(szBuffer, iMaxLength, "Give Weapon");
        case TopMenuAction_SelectOption  : DisplayWeaponGiveMenu(iClient);
    }
    return 0;
}

void DisplayWeaponGiveMenu(int iClient) {
    Menu mMenu = new Menu(MenuHandler_GiveWeapons);
    mMenu.SetTitle("Give Weapon:");
    mMenu.AddItem("0", "Melee Weapons");
    mMenu.AddItem("1", "Bullet Based");
    mMenu.AddItem("2", "Shell Based");
    mMenu.AddItem("3", "Explosive Based");
    mMenu.AddItem("4", "Health Related");
    mMenu.AddItem("5", "Misc");
    mMenu.ExitBackButton = true;
    mMenu.Display(iClient, MENU_TIME_FOREVER);
}

int MenuHandler_GiveWeapons(Menu mMenu, MenuAction mAction, int iClient, int iParam) {
    switch (mAction) {
        case MenuAction_End: {
            delete mMenu;
        }
        case MenuAction_Cancel: {
            if (iParam == MenuCancel_ExitBack && g_mAdminMenu != null)
                g_mAdminMenu.Display(iClient, TopMenuPosition_LastCategory);
        }
        case MenuAction_Select: {
            switch (iParam) {
                case 0: BuildMeleeGiveMenu(iClient);
                case 1: BuildBulletBasedGiveMenu(iClient);
                case 2: BuildShellBasedGiveMenu(iClient);
                case 3: BuildExplosiveBasedGiveMenu(iClient);
                case 4: BuildHealthGiveMenu(iClient);
                case 5: BuildMiscGiveMenu(iClient);
            }
        }
    }
    return 0;
}

void BuildMeleeGiveMenu(int iClient, int iMenuPos = 0) {
    Menu mMenu = new Menu(MenuHandler_GiveWeapon);
    mMenu.SetTitle("Melee Weapons:");
    mMenu.AddItem("cricket_bat",     "Cricket Bat");
    mMenu.AddItem("crowbar",         "Crowbar");
    mMenu.AddItem("electric_guitar", "Electric Guitar");
    mMenu.AddItem("fireaxe",         "Fire Axe");
    mMenu.AddItem("frying_pan",      "Frying Pan");
    mMenu.AddItem("katana",          "Katana");
    mMenu.AddItem("machete",         "Machete");
    mMenu.AddItem("tonfa",           "Tonfa");
    mMenu.AddItem("baseball_bat",    "Baseball Bat");
    mMenu.AddItem("knife",           "Knife");
    mMenu.AddItem("shovel",          "Shovel");
    mMenu.AddItem("pitchfork",       "Pitchfork");
    mMenu.ExitBackButton = true;
    g_szChosenMenu[iClient] = "MeleeGiveMenu";
    mMenu.DisplayAt(iClient, iMenuPos, MENU_TIME_FOREVER);
}

void BuildBulletBasedGiveMenu(int iClient, int iMenuPos = 0) {
    Menu mMenu = new Menu(MenuHandler_GiveWeapon);
    mMenu.SetTitle("Bullet Based Weapons:");
    mMenu.AddItem("pistol",          "Pistol");
    mMenu.AddItem("pistol_magnum",   "Desert Eagle");
    mMenu.AddItem("smg",             "Submachine Gun");
    mMenu.AddItem("smg_silenced",    "Silenced Submachine Gun");
    mMenu.AddItem("smg_mp5",         "Submachine Gun MP5");
    mMenu.AddItem("rifle",           "Rifle M16");
    mMenu.AddItem("rifle_ak47",      "AK-47");
    mMenu.AddItem("rifle_desert",    "FN SCAR");
    mMenu.AddItem("rifle_sg552",     "SIG SG 550");
    mMenu.AddItem("hunting_rifle",   "Hunting Rifle");
    mMenu.AddItem("sniper_military", "Military Sniper");
    mMenu.AddItem("sniper_scout",    "Scout");
    mMenu.AddItem("sniper_awp",      "AWP");
    mMenu.AddItem("rifle_m60",       "Rifle M60");
    mMenu.ExitBackButton = true;
    g_szChosenMenu[iClient] = "BulletBasedGiveMenu";
    mMenu.DisplayAt(iClient, iMenuPos, MENU_TIME_FOREVER);
}

void BuildShellBasedGiveMenu(int iClient, int iMenuPos = 0) {
    Menu mMenu = new Menu(MenuHandler_GiveWeapon);
    mMenu.SetTitle("Shell Based Weapons:");
    mMenu.AddItem("pumpshotgun",    "Pump Shotgun");
    mMenu.AddItem("shotgun_chrome", "Chrome Shotgun");
    mMenu.AddItem("autoshotgun",    "Auto Shotgun");
    mMenu.AddItem("shotgun_spas",   "Spas Shotgun");
    mMenu.ExitBackButton = true;
    g_szChosenMenu[iClient] = "ShellBasedGiveMenu";
    mMenu.DisplayAt(iClient, iMenuPos, MENU_TIME_FOREVER);
}

void BuildExplosiveBasedGiveMenu(int iClient, int iMenuPos = 0) {
    Menu mMenu = new Menu(MenuHandler_GiveWeapon);
    mMenu.SetTitle("Explosive Based Weapons:");
    mMenu.AddItem("grenade_launcher", "Grenade Launcher");
    mMenu.AddItem("fireworkcrate",    "Fireworks Crate");
    mMenu.AddItem("gascan",           "Gascan");
    mMenu.AddItem("molotov",          "Molotov");
    mMenu.AddItem("oxygentank",       "Oxygen Tank");
    mMenu.AddItem("pipe_bomb",        "Pipe Bomb");
    mMenu.AddItem("propanetank",      "Propane Tank");
    mMenu.ExitBackButton = true;
    g_szChosenMenu[iClient] = "ExplosiveBasedGiveMenu";
    mMenu.DisplayAt(iClient, iMenuPos, MENU_TIME_FOREVER);
}

void BuildHealthGiveMenu(int iClient, int iMenuPos = 0) {
    Menu mMenu = new Menu(MenuHandler_GiveWeapon);
    mMenu.SetTitle("Health Related:");
    mMenu.AddItem("health",        "Full Health");
    mMenu.AddItem("adrenaline",    "Adrenaline");
    mMenu.AddItem("defibrillator", "Defibrillator");
    mMenu.AddItem("first_aid_kit", "First Aid Kit");
    mMenu.AddItem("pain_pills",    "Pain Pills");
    mMenu.ExitBackButton = true;
    g_szChosenMenu[iClient] = "HealthGiveMenu";
    mMenu.DisplayAt(iClient, iMenuPos, MENU_TIME_FOREVER);
}

void BuildMiscGiveMenu(int iClient, int iMenuPos = 0) {
    Menu mMenu = new Menu(MenuHandler_GiveWeapon);
    mMenu.SetTitle("Misc Weapons:");
    mMenu.AddItem("chainsaw",               "Chain Saw");
    mMenu.AddItem("ammo",                   "Ammo");
    mMenu.AddItem("laser_sight",            "Laser Sight");
    mMenu.AddItem("explosive_ammo",         "Explosive Ammo");
    mMenu.AddItem("incendiary_ammo",        "Incendiary Ammo");
    mMenu.AddItem("upgradepack_explosive",  "Explosive Ammo Pack");
    mMenu.AddItem("upgradepack_incendiary", "Incendiary Ammo Pack");
    mMenu.AddItem("vomitjar",               "Vomit Jar");
    mMenu.AddItem("gnome",                  "Gnome");
    mMenu.AddItem("cola_bottles",           "Cola");
    mMenu.ExitBackButton = true;
    g_szChosenMenu[iClient] = "MiscGiveMenu";
    mMenu.DisplayAt(iClient, iMenuPos, MENU_TIME_FOREVER);
}

int MenuHandler_GiveWeapon(Menu mMenu, MenuAction mAction, int iClient, int iParam) {
    switch (mAction) {
        case MenuAction_End: {
            delete mMenu;
        }
        case MenuAction_Cancel: {
            if (iParam == MenuCancel_ExitBack)
                DisplayWeaponGiveMenu(iClient);
        }
        case MenuAction_Select: {
            char szInfo[32];
            GetMenuItem(mMenu, iParam, szInfo, sizeof(szInfo));
            /* Save chosen weapon */
            g_szChosenWeapon[iClient] = szInfo;
            DisplaySelectPlayerMenu(iClient);
        }
    }
    return 0;
}

void DisplaySelectPlayerMenu(int iClient) {
    Menu mMenu = new Menu(MenuHandler_PlayerSelect);
    mMenu.SetTitle("Select Player:");
    mMenu.ExitBackButton = true;
    AddTargetsToMenu2(mMenu, iClient, COMMAND_FILTER_NO_BOTS);
    mMenu.Display(iClient, MENU_TIME_FOREVER);
}

int MenuHandler_PlayerSelect(Menu mMenu, MenuAction mAction, int iClient, int iParam) {
    switch (mAction) {
        case MenuAction_End: {
            delete mMenu;
        }
        case MenuAction_Cancel: {
            if (iParam == MenuCancel_ExitBack)
                ChosenMenuHistory(iClient);
        }
        case MenuAction_Select: {
            char szInfo[56];
            GetMenuItem(mMenu, iParam, szInfo, sizeof(szInfo));
            int iTarget = GetClientOfUserId(StringToInt(szInfo));
            if (iTarget == 0) {
                PrintToChat(iClient, "Player no longer available");
                ChosenMenuHistory(iClient);
                return 0;
            } else if (!CanUserTarget(iClient, iTarget)) {
                PrintToChat(iClient, "Unable to target");
                ChosenMenuHistory(iClient);
                return 0;
            }
            if ((strcmp(g_szChosenWeapon[iClient], "laser_sight") == 0) || (strcmp(g_szChosenWeapon[iClient], "explosive_ammo") == 0) || (strcmp(g_szChosenWeapon[iClient], "incendiary_ammo") == 0)) {
                int iFlags = GetCommandFlags("upgrade_add");
                SetCommandFlags("upgrade_add", iFlags & ~FCVAR_CHEAT);
                if (IsClientInGame(iTarget)) FakeClientCommand(iTarget, "upgrade_add %s", g_szChosenWeapon[iClient]);
                LogAction(iClient, iTarget, "\"%L\" give weapon (weapon: \"%s\") to \"%L\")", iClient, g_szChosenWeapon[iClient], iTarget);
                SetCommandFlags("upgrade_add", iFlags|FCVAR_CHEAT);
                ChosenMenuHistory(iClient);
            } else {
                int iFlags = GetCommandFlags("give");
                SetCommandFlags("give", iFlags & ~FCVAR_CHEAT);
                if (IsClientInGame(iTarget)) FakeClientCommand(iTarget, "give %s", g_szChosenWeapon[iClient]);
                LogAction(iClient, iTarget, "\"%L\" give weapon (weapon: \"%s\") to \"%L\")", iClient, g_szChosenWeapon[iClient], iTarget);
                SetCommandFlags("give", iFlags|FCVAR_CHEAT);
                ChosenMenuHistory(iClient);
            }
        }
    }
    return 0;
}

/* Spawn Special Zombie Menu */
int AdminMenu_ZombieSpawnMenu(TopMenu mTopMenu, TopMenuAction mAction, TopMenuObject mObjectId, int iClient, char[] szBuffer, int iMaxLength) {
    switch (mAction) {
        case TopMenuAction_DisplayOption : Format(szBuffer, iMaxLength, "Spawn Special Zombie");
        case TopMenuAction_SelectOption  : DisplaySpecialZombieMenu(iClient);
    }
    return 0;
}

void DisplaySpecialZombieMenu(int iClient, int iMenuPos = 0) {
    Menu mMenu = new Menu(MenuHandler_SpecialZombie);
    mMenu.SetTitle("Spawn Special Zombie:");
    mMenu.AddItem("smoker",      "Smoker");
    mMenu.AddItem("boomer",      "Boomer");
    mMenu.AddItem("hunter",      "Hunter");
    mMenu.AddItem("spitter",     "Spitter");
    mMenu.AddItem("jockey",      "Jockey");
    mMenu.AddItem("charger",     "Charger");
    mMenu.AddItem("witch",       "Witch");
    mMenu.AddItem("witch_bride", "Bride Witch");
    mMenu.AddItem("tank",        "Tank");
    mMenu.AddItem("zombie",      "One Zombie");
    mMenu.AddItem("mob",         "Zombie Mob");
    mMenu.ExitBackButton = true;
    mMenu.DisplayAt(iClient, iMenuPos, MENU_TIME_FOREVER);
}

int MenuHandler_SpecialZombie(Menu mMenu, MenuAction mAction, int iClient, int iParam) {
    switch (mAction) {
        case MenuAction_End: {
            delete mMenu;
        }
        case MenuAction_Cancel: {
            if (iParam == MenuCancel_ExitBack && g_mAdminMenu != null)
                g_mAdminMenu.Display(iClient, TopMenuPosition_LastCategory);
        }
        case MenuAction_Select: {
            char szInfo[32];
            GetMenuItem(mMenu, iParam, szInfo, sizeof(szInfo));
            int iFlags = GetCommandFlags("z_spawn");
            SetCommandFlags("z_spawn", iFlags & ~FCVAR_CHEAT);
            FakeClientCommand(iClient, "z_spawn %s", szInfo);
            LogAction(iClient, -1, "\"%L\" spawned zombie (\"%s\")", iClient, szInfo);
            SetCommandFlags("z_spawn", iFlags|FCVAR_CHEAT);
            int iMenuPos = mMenu.Selection;
            DisplaySpecialZombieMenu(iClient, iMenuPos);
        }
    }
    return 0;
}

/* Minigun Menu */
int AdminMenu_MachineGunSpawnMenu(TopMenu mTopMenu, TopMenuAction mAction, TopMenuObject mObjectId, int iClient, char[] szBuffer, int iMaxLength) {
    switch (mAction) {
        case TopMenuAction_DisplayOption : Format(szBuffer, iMaxLength, "MiniGun Menu");
        case TopMenuAction_SelectOption  : DisplayMinigunMenu(iClient);
    }
    return 0;
}

void DisplayMinigunMenu(int iClient) {
    Menu mMenu = new Menu(MenuHandler_MiniGun);
    mMenu.SetTitle("MiniGun Menu:");
    mMenu.AddItem("spawnminigun",  "Spawn .50 Cal");
    mMenu.AddItem("spawnminigun2", "Spawn MiniGun");
    mMenu.AddItem("removeminigun", "Remove Machine Gun");
    mMenu.ExitBackButton = true;
    mMenu.Display(iClient, MENU_TIME_FOREVER);
}

int MenuHandler_MiniGun(Menu mMenu, MenuAction mAction, int iClient, int iParam) {
    switch (mAction) {
        case MenuAction_End: {
            delete mMenu;
        }
        case MenuAction_Cancel: {
            if (iParam == MenuCancel_ExitBack && g_mAdminMenu != null)
                g_mAdminMenu.Display(iClient, TopMenuPosition_LastCategory);
        }
        case MenuAction_Select: {
            char szInfo[32];
            GetMenuItem(mMenu, iParam, szInfo, sizeof(szInfo));
            if (strcmp(szInfo, "spawnminigun") == 0) {
                SpawnMiniGun(iClient, 1);
                DisplayMinigunMenu(iClient);
            } else if (strcmp(szInfo, "spawnminigun2") == 0) {
                SpawnMiniGun(iClient, 2);
                DisplayMinigunMenu(iClient);
            } else if (strcmp(szInfo, "removeminigun") == 0) {
                RemoveMiniGun(iClient);
                DisplayMinigunMenu(iClient);
            }
        }
    }
    return 0;
}

/* Teleport Entity */
bool SetTeleportEndPoint(int iClient) {
    float vOrigin[3];
    GetClientEyePosition(iClient, vOrigin);
    float vAngles[3];
    GetClientEyeAngles(iClient, vAngles);
    // get endpoint for teleport
    Handle hTrace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
    if (TR_DidHit(hTrace)) {
        float vStart[3];
        TR_GetEndPosition(vStart, hTrace);
        GetVectorDistance(vOrigin, vStart, false);
        float fDistance = -35.0;
        float vBuffer[3];
        GetAngleVectors(vAngles, vBuffer, NULL_VECTOR, NULL_VECTOR);
        g_vPos[0] = vStart[0] + (vBuffer[0] * fDistance);
        g_vPos[1] = vStart[1] + (vBuffer[1] * fDistance);
        g_vPos[2] = vStart[2] + (vBuffer[2] * fDistance);
    } else {
        delete hTrace;
        return false;
    }
    delete hTrace;
    return true;
}

stock bool TraceEntityFilterPlayer(int iEnt, int iContentsMask) {
    return iEnt > MaxClients || !iEnt;
}

stock void ChosenMenuHistory(int iClient, int iMenuPos = 0) {
    if (strcmp(g_szChosenMenu[iClient], "MeleeBasedSpawnMenu") == 0) {
        BuildMeleeMenu(iClient, iMenuPos);
    } else if (strcmp(g_szChosenMenu[iClient], "BulletBasedSpawnMenu") == 0) {
        BuildBulletBasedMenu(iClient, iMenuPos);
    } else if (strcmp(g_szChosenMenu[iClient], "ShellBasedSpawnMenu") == 0) {
        BuildShellBasedMenu(iClient, iMenuPos);
    } else if (strcmp(g_szChosenMenu[iClient], "ExplosiveBasedSpawnMenu") == 0) {
        BuildExplosiveBasedMenu(iClient, iMenuPos);
    } else if (strcmp(g_szChosenMenu[iClient], "HealthSpawnMenu") == 0) {
        BuildHealthMenu(iClient, iMenuPos);
    } else if (strcmp(g_szChosenMenu[iClient], "MiscSpawnMenu") == 0) {
        BuildMiscMenu(iClient, iMenuPos);
    } else if (strcmp(g_szChosenMenu[iClient], "MeleeGiveMenu") == 0) {
        BuildMeleeGiveMenu(iClient, iMenuPos);
    } else if (strcmp(g_szChosenMenu[iClient], "BulletBasedGiveMenu") == 0) {
        BuildBulletBasedGiveMenu(iClient, iMenuPos);
    } else if (strcmp(g_szChosenMenu[iClient], "ShellBasedGiveMenu") == 0) {
        BuildShellBasedGiveMenu(iClient, iMenuPos);
    } else if (strcmp(g_szChosenMenu[iClient], "ExplosiveBasedGiveMenu") == 0) {
        BuildExplosiveBasedGiveMenu(iClient, iMenuPos);
    } else if (strcmp(g_szChosenMenu[iClient], "HealthGiveMenu") == 0) {
        BuildHealthGiveMenu(iClient, iMenuPos);
    } else if (strcmp(g_szChosenMenu[iClient], "MiscGiveMenu") == 0) {
        BuildMiscGiveMenu(iClient, iMenuPos);
    }
}