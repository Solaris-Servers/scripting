#if defined __WEAPONINFORMATION_MODULE__
    #endinput
#endif
#define __WEAPONINFORMATION_MODULE__

#define MODEL_PREFIX "models/w_models/weapons/w_"
#define MODEL_SURFIX ".mdl"
#define SPAWN_PREFIX "weapon_"
#define SPAWN_SURFIX "_spawn"

#define WEAPON_NUMBER_OF_START_KITS 4

//====================================================
// Map Info
//====================================================
bool  Weapon_bUpdateMapInfo = true;
float Weapon_fMapOrigin_Start[3];
float Weapon_fMapOrigin_End[3];
float Weapon_fMapDist_Start;
float Weapon_fMapDist_StartExtra;
float Weapon_fMapDist_End;

//====================================================
// Kit Protection
//====================================================
int Weapon_iKitEntity[WEAPON_NUMBER_OF_START_KITS];
int Weapon_iKitCount;

//====================================================
// Weapon Index & ID
//====================================================
const int WEAPON_REMOVE_INDEX           = -1;
const int WEAPON_NULL_INDEX             = 0;

const int WEAPON_SMG_ID                 = 2;
const int WEAPON_SMG_INDEX              = 1;
const int WEAPON_PUMPSHOTGUN_ID         = 3;
const int WEAPON_PUMPSHOTGUN_INDEX      = 2;

const int WEAPON_AUTOSHOTGUN_ID         = 4;
const int WEAPON_AUTOSHOTGUN_INDEX      = 3;
const int WEAPON_RIFLE_ID               = 5;
const int WEAPON_RIFLE_INDEX            = 4;

const int Weapon_cvUNTING_RIFLE_ID       = 6;
const int Weapon_cvUNTING_RIFLE_INDEX    = 5;
const int WEAPON_SMG_SILENCED_ID        = 7;
const int WEAPON_SMG_SILENCED_INDEX     = 6;

const int WEAPON_SHOTGUN_CHROME_ID      = 8;
const int WEAPON_SHOTGUN_CHROME_INDEX   = 7;
const int WEAPON_RIFLE_DESERT_ID        = 9;
const int WEAPON_RIFLE_DESERT_INDEX     = 8;

const int WEAPON_SNIPER_MILITARY_ID     = 10;
const int WEAPON_SNIPER_MILITARY_INDEX  = 9;
const int WEAPON_SHOTGUN_SPAS_ID        = 11;
const int WEAPON_SHOTGUN_SPAS_INDEX     = 10;

const int WEAPON_GRENADE_LAUNCHER_ID    = 21;
const int WEAPON_GRENADE_LAUNCHER_INDEX = 11;
const int WEAPON_RIFLE_AK47_ID          = 26;
const int WEAPON_RIFLE_AK47_INDEX       = 12;

const int WEAPON_RIFLE_M60_ID           = 37;
const int WEAPON_RIFLE_M60_INDEX        = 13;

const int WEAPON_SMG_MP5_ID             = 33;
const int WEAPON_SMG_MP5_INDEX          = 14;
const int WEAPON_RIFLE_SG552_ID         = 34;
const int WEAPON_RIFLE_SG552_INDEX      = 15;

const int WEAPON_SNIPER_AWP_ID          = 35;
const int WEAPON_SNIPER_AWP_INDEX       = 16;
const int WEAPON_SNIPER_SCOUT_ID        = 36;
const int WEAPON_SNIPER_SCOUT_INDEX     = 17;

const int WEAPON_CHAINSAW_INDEX         = 18;

const int WEAPON_PIPE_BOMB_INDEX        = 19;
const int WEAPON_MOLOTOV_INDEX          = 20;
const int WEAPON_VOMITJAR_INDEX         = 21;

const int WEAPON_FIRST_AID_KIT_INDEX    = 22;
const int WEAPON_DEFIBRILLATOR_INDEX    = 23;
const int WEAPON_UPG_EXPLOSIVE_INDEX    = 24;
const int WEAPON_UPG_INCENDIARY_INDEX   = 25;

const int WEAPON_PAIN_PILLS_INDEX       = 26;
const int WEAPON_ADRENALINE_INDEX       = 27;
//====================================================
const int NUM_OF_WEAPONS                = 28;

const int FIRST_WEAPON                  = 1;
const int LAST_WEAPON                   = 18;
const int FIRST_EXTRA                   = 19;
const int LAST_EXTRA                    = 27;

enum eWeaponAttributes {
    eWeaponID,
    eTier1EquivalentIndex,
    eReplacementIndex
}

static const int Weapon_Attributes[][] = {
    //====================================================
    // Weapons
    //====================================================
    // NULL
    {
        WEAPON_NULL_INDEX,
        WEAPON_NULL_INDEX,
        WEAPON_NULL_INDEX
    },
    // SMG
    {
        WEAPON_SMG_ID,
        WEAPON_NULL_INDEX,
        WEAPON_NULL_INDEX
    },
    // Pumpshotgun
    {
        WEAPON_PUMPSHOTGUN_ID,
        WEAPON_NULL_INDEX,
        WEAPON_NULL_INDEX
    },
    // Autoshotgun
    {
        WEAPON_AUTOSHOTGUN_ID,
        WEAPON_PUMPSHOTGUN_INDEX,
        WEAPON_NULL_INDEX
    },
    // Rifle
    {
        WEAPON_RIFLE_ID,
        WEAPON_SMG_INDEX,
        WEAPON_NULL_INDEX
    },
    // Hunting rifle
    {
        Weapon_cvUNTING_RIFLE_ID,
        WEAPON_NULL_INDEX,
        WEAPON_NULL_INDEX
    },
    // SMG silenced
    {
        WEAPON_SMG_SILENCED_ID,
        WEAPON_NULL_INDEX,
        WEAPON_NULL_INDEX
    },
    // Chrome shotgun
    {
        WEAPON_SHOTGUN_CHROME_ID,
        WEAPON_NULL_INDEX,
        WEAPON_NULL_INDEX
    },
    // Desert rifle
    {
        WEAPON_RIFLE_DESERT_ID,
        WEAPON_SMG_INDEX,
        WEAPON_NULL_INDEX
    },
    // Military sniper
    {
        WEAPON_SNIPER_MILITARY_ID,
        Weapon_cvUNTING_RIFLE_INDEX,
        WEAPON_NULL_INDEX
    },
    // Spas shotgun
    {
        WEAPON_SHOTGUN_SPAS_ID,
        WEAPON_SHOTGUN_CHROME_INDEX,
        WEAPON_NULL_INDEX
    },
    // Grenade launcher
    {
        WEAPON_GRENADE_LAUNCHER_ID,
        WEAPON_NULL_INDEX,
        WEAPON_REMOVE_INDEX
    },
    // AK47
    {
        WEAPON_RIFLE_AK47_ID,
        WEAPON_SMG_SILENCED_INDEX,
        WEAPON_NULL_INDEX
    },
    // M60
    {
        WEAPON_RIFLE_M60_ID,
        WEAPON_NULL_INDEX,
        WEAPON_REMOVE_INDEX,
    },
    // MP5
    {
        WEAPON_SMG_MP5_ID,
        WEAPON_NULL_INDEX,
        WEAPON_SMG_INDEX
    },
    // SG552
    {
        WEAPON_RIFLE_SG552_ID,
        WEAPON_SMG_MP5_INDEX,
        WEAPON_RIFLE_INDEX
    },
    // AWP
    {
        WEAPON_SNIPER_AWP_ID,
        WEAPON_SNIPER_SCOUT_INDEX,
        WEAPON_SNIPER_MILITARY_INDEX
    },
    // Scout
    {
        WEAPON_SNIPER_SCOUT_ID,
        WEAPON_NULL_INDEX,
        Weapon_cvUNTING_RIFLE_INDEX
    },
    //====================================================
    // Melee Weapons
    //====================================================
    // Chainsaw
    {
        WEAPON_NULL_INDEX,
        WEAPON_NULL_INDEX,
        WEAPON_REMOVE_INDEX
    },
    //====================================================
    // Extra Items
    //====================================================
    // Pipe Bomb
    {
        WEAPON_NULL_INDEX,
        WEAPON_NULL_INDEX,
        WEAPON_NULL_INDEX
    },
    // Molotov
    {
        WEAPON_NULL_INDEX,
        WEAPON_NULL_INDEX,
        WEAPON_NULL_INDEX
    },
    // Vomitjar
    {
        WEAPON_NULL_INDEX,
        WEAPON_NULL_INDEX,
        WEAPON_NULL_INDEX
    },
    // First Aid Kit
    {
        WEAPON_NULL_INDEX,
        WEAPON_NULL_INDEX,
        WEAPON_REMOVE_INDEX
    },
    // Defibrillator
    {
        WEAPON_NULL_INDEX,
        WEAPON_NULL_INDEX,
        WEAPON_REMOVE_INDEX
    },
    // Explosive Upgrade Pack
    {
        WEAPON_NULL_INDEX,
        WEAPON_NULL_INDEX,
        WEAPON_REMOVE_INDEX
    },
    // Incendiary Upgrade Pack
    {
        WEAPON_NULL_INDEX,
        WEAPON_NULL_INDEX,
        WEAPON_REMOVE_INDEX
    },
    // Pain pills
    {
        WEAPON_NULL_INDEX,
        WEAPON_NULL_INDEX,
        WEAPON_NULL_INDEX
    },
    // Adrenaline
    {
        WEAPON_NULL_INDEX,
        WEAPON_NULL_INDEX,
        WEAPON_NULL_INDEX
    }
};

static const char WI_szWeaponModels[NUM_OF_WEAPONS][] = {
    //====================================================
    // Weapons
    //====================================================
    // NULL
    "",
    // SMG
    "smg_uzi",
    // Shotgun
    "shotgun",
    // Autoshotgun
    "autoshot_m4super",
    // Rifle
    "rifle_m16a2",
    // Hunting rifle
    "sniper_mini14",
    // SMG silenced
    "smg_a",
    // Chrome shotgun
    "pumpshotgun_a",
    // Desert rifle
    "rifle_b",
    // Military rifle
    "sniper_military",
    // Spas shotgun
    "shotgun_spas",
    // Grenade launcher
    "",
    // AK47
    "rifle_ak47",
    // M60
    "m60",
    // MP5
    "smg_mp5",
    // SG552
    "",
    // AWP
    "",
    // Scout
    "sniper_scout",
    //====================================================
    // Melee Weapons
    //====================================================
    // Chainsaw
    "",
    //====================================================
    // Extra Items
    //====================================================
    // Pipe Bomb
    "",
    // Molotov
    "",
    // Vomitjar
    "",
    // First Aid Kit
    "",
    // Defibrillator
    "",
    // Explosive Upgrade Pack
    "",
    // Incendiary Upgrade Pack
    "",
    // Pain pills
    "",
    // Adrenaline
    ""
};

static const char WI_szWeaponSpawns[NUM_OF_WEAPONS][] = {
    //====================================================
    // Weapons
    //====================================================
    // NULL
    "",
    // SMG
    "",
    // Shotgun
    "",
    // Autoshotgun
    "autoshotgun",
    // Rifle
    "rifle",
    // Hunting rifle
    "",
    // SMG silenced
    "",
    // Chrome shotgun
    "",
    // Desert rifle
    "rifle_desert",
    // Military rifle
    "sniper_military",
    // Spas shotgun
    "shotgun_spas",
    // Grenade launcher
    "grenade_launcher",
    // AK47
    "rifle_ak47",
    // M60
    "rifle_m60",
    // MP5
    "",
    // SG552
    "",
    // AWP
    "",
    // Scout
    "",
    //====================================================
    // Melee Weapons
    //====================================================
    // Chainsaw
    "chainsaw",
    //====================================================
    // Extra Items
    //====================================================
    // Pipe Bomb
    "pipe_bomb",
    // Molotov
    "molotov",
    // Vomitjar
    "vomitjar",
    // First Aid Kit
    "first_aid_kit",
    // Defibrillator
    "defibrillator",
    // Explosive Upgrade Pack
    "upgradepack_explosive",
    // Incendiary Upgrade Pack
    "upgradepack_incendiary",
    // Pain pills
    "pain_pills",
    // Adrenaline
    "adrenaline"
};

bool Weapon_bConvar[NUM_OF_WEAPONS];
bool Weapon_bReplaceTier2         = true;
bool Weapon_bReplaceTier2_Finale  = true;
bool Weapon_bReplaceTier2_All     = true;
bool Weapon_bLimitTier2           = true;
bool Weapon_bLimitTier2_Safehouse = true;
bool Weapon_bReplaceStartKits     = true;
bool Weapon_bReplaceFinaleKits    = true;
bool Weapon_bRemoveLaserSight     = true;
bool Weapon_bRemoveExtraItems     = true;

ConVar Weapon_ConVars[NUM_OF_WEAPONS];
ConVar Weapon_cvReplaceTier2;
ConVar Weapon_cvReplaceTier2_Finale;
ConVar Weapon_cvReplaceTier2_All;
ConVar Weapon_cvLimitTier2;
ConVar Weapon_cvLimitTier2_Safehouse;
ConVar Weapon_cvReplaceStartKits;
ConVar Weapon_cvReplaceFinaleKits;
ConVar Weapon_cvRemoveLaserSight;
ConVar Weapon_cvRemoveExtraItems;

//====================================================
// Functions
//====================================================

void WI_Convar_Setup() {
    Weapon_ConVars[WEAPON_SMG_MP5_INDEX] = CreateConVarEx(
    "replace_cssweapons", "1",
    "Replace CSS weapons with normal L4D2 weapons",
    FCVAR_NONE, true, 0.0, true, 1.0);
    Weapon_ConVars[WEAPON_RIFLE_SG552_INDEX]  = Weapon_ConVars[WEAPON_SMG_MP5_INDEX];
    Weapon_ConVars[WEAPON_SNIPER_AWP_INDEX]   = Weapon_ConVars[WEAPON_SMG_MP5_INDEX];
    Weapon_ConVars[WEAPON_SNIPER_SCOUT_INDEX] = Weapon_ConVars[WEAPON_SMG_MP5_INDEX];

    Weapon_ConVars[WEAPON_GRENADE_LAUNCHER_INDEX] = CreateConVarEx(
    "remove_grenade", "1",
    "Remove all grenade launchers",
    FCVAR_NONE, true, 0.0, true, 1.0);

    Weapon_ConVars[WEAPON_CHAINSAW_INDEX] = CreateConVarEx(
    "remove_chainsaw", "1",
    "Remove all chainsaws",
    FCVAR_NONE, true, 0.0, true, 1.0);

    Weapon_ConVars[WEAPON_RIFLE_M60_INDEX] = CreateConVarEx(
    "remove_m60", "1",
    "Remove all M60 rifles",
    FCVAR_NONE, true, 0.0, true, 1.0);

    Weapon_ConVars[WEAPON_FIRST_AID_KIT_INDEX] = CreateConVarEx(
    "remove_statickits", "1",
    "Remove all static medkits (medkits such as the gun shop, these are compiled into the map)",
    FCVAR_NONE, true, 0.0, true, 1.0);

    Weapon_ConVars[WEAPON_DEFIBRILLATOR_INDEX] = CreateConVarEx(
    "remove_defib", "1",
    "Remove all defibrillators",
    FCVAR_NONE, true, 0.0, true, 1.0);

    Weapon_ConVars[WEAPON_UPG_EXPLOSIVE_INDEX] = CreateConVarEx(
    "remove_upg_explosive", "1",
    "Remove all explosive upgrade packs",
    FCVAR_NONE, true, 0.0, true, 1.0);

    Weapon_ConVars[WEAPON_UPG_INCENDIARY_INDEX] = CreateConVarEx(
    "remove_upg_incendiary", "1",
    "Remove all incendiary upgrade packs",
    FCVAR_NONE, true, 0.0, true, 1.0);

    for (int i = FIRST_WEAPON; i < NUM_OF_WEAPONS; i++) {
        if (Weapon_ConVars[i] == null)
            continue;
        Weapon_bConvar[i] = Weapon_ConVars[i].BoolValue;
        Weapon_ConVars[i].AddChangeHook(WI_ConvarChange);
    }

    Weapon_cvReplaceTier2 = CreateConVarEx(
    "replace_tier2", "1",
    "Replace tier 2 weapons in start and end safe room with their tier 1 equivalent",
    FCVAR_NONE, true, 0.0, true, 1.0);
    Weapon_bReplaceTier2 = Weapon_cvReplaceTier2.BoolValue;
    Weapon_cvReplaceTier2.AddChangeHook(WI_ConvarChange);

    Weapon_cvReplaceTier2_Finale = CreateConVarEx(
    "replace_tier2_finale", "1",
    "Replace tier 2 weapons in start safe room with their tier 1 equivalent, on finale",
    FCVAR_NONE, true, 0.0, true, 1.0);
    Weapon_bReplaceTier2_Finale = Weapon_cvReplaceTier2_Finale.BoolValue;
    Weapon_cvReplaceTier2_Finale.AddChangeHook(WI_ConvarChange);

    Weapon_cvReplaceTier2_All = CreateConVarEx(
    "replace_tier2_all", "1",
    "Replace ALL tier 2 weapons with their tier 1 equivalent EVERYWHERE",
    FCVAR_NONE, true, 0.0, true, 1.0);
    Weapon_bReplaceTier2_All = Weapon_cvReplaceTier2_All.BoolValue;
    Weapon_cvReplaceTier2_All.AddChangeHook(WI_ConvarChange);

    Weapon_cvLimitTier2 = CreateConVarEx(
    "limit_tier2", "1",
    "Limit tier 2 weapons outside safe rooms. Replaces a tier 2 stack with tier 1 upon first weapon pickup",
    FCVAR_NONE, true, 0.0, true, 1.0);
    Weapon_bLimitTier2 = Weapon_cvLimitTier2.BoolValue;
    Weapon_cvLimitTier2.AddChangeHook(WI_ConvarChange);

    Weapon_cvLimitTier2_Safehouse = CreateConVarEx(
    "limit_tier2_saferoom", "1",
    "Limit tier 2 weapons inside safe rooms. Replaces a tier 2 stack with tier 1 upon first weapon pickup",
    FCVAR_NONE, true, 0.0, true, 1.0);
    Weapon_bLimitTier2_Safehouse = Weapon_cvLimitTier2_Safehouse.BoolValue;
    Weapon_cvLimitTier2_Safehouse.AddChangeHook(WI_ConvarChange);

    Weapon_cvReplaceStartKits = CreateConVarEx(
    "replace_startkits", "1",
    "Replaces start medkits with pills",
    FCVAR_NONE, true, 0.0, true, 1.0);
    Weapon_bReplaceStartKits = Weapon_cvReplaceStartKits.BoolValue;
    Weapon_cvReplaceStartKits.AddChangeHook(WI_ConvarChange);

    Weapon_cvReplaceFinaleKits = CreateConVarEx(
    "replace_finalekits", "1",
    "Replaces finale medkits with pills",
    FCVAR_NONE, true, 0.0, true, 1.0);
    Weapon_bReplaceFinaleKits = Weapon_cvReplaceFinaleKits.BoolValue;
    Weapon_cvReplaceFinaleKits.AddChangeHook(WI_ConvarChange);

    Weapon_cvRemoveLaserSight = CreateConVarEx(
    "remove_lasersight", "1",
    "Remove all laser sight upgrades",
    FCVAR_NONE, true, 0.0, true, 1.0);
    Weapon_bRemoveLaserSight = Weapon_cvRemoveLaserSight.BoolValue;
    Weapon_cvRemoveLaserSight.AddChangeHook(WI_ConvarChange);

    Weapon_cvRemoveExtraItems = CreateConVarEx(
    "remove_saferoomitems", "1",
    "Remove all extra items inside saferooms (items for slot 3, 4 and 5, minus medkits)",
    FCVAR_NONE, true, 0.0, true, 1.0);
    Weapon_bRemoveExtraItems = Weapon_cvRemoveExtraItems.BoolValue;
    Weapon_cvRemoveExtraItems.AddChangeHook(WI_ConvarChange);
}

void WI_ConvarChange(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    for (int i = FIRST_WEAPON; i < NUM_OF_WEAPONS; i++) {
        if (Weapon_ConVars[i] == null)
            continue;
        Weapon_bConvar[i] = Weapon_ConVars[i].BoolValue;
    }
    Weapon_bReplaceTier2         = Weapon_cvReplaceTier2.BoolValue;
    Weapon_bReplaceTier2_Finale  = Weapon_cvReplaceTier2_Finale.BoolValue;
    Weapon_bReplaceTier2_All     = Weapon_cvReplaceTier2_All.BoolValue;
    Weapon_bLimitTier2           = Weapon_cvLimitTier2.BoolValue;
    Weapon_bLimitTier2_Safehouse = Weapon_cvLimitTier2_Safehouse.BoolValue;
    Weapon_bReplaceStartKits     = Weapon_cvReplaceStartKits.BoolValue;
    Weapon_bReplaceFinaleKits    = Weapon_cvReplaceFinaleKits.BoolValue;
    Weapon_bRemoveLaserSight     = Weapon_cvRemoveLaserSight.BoolValue;
    Weapon_bRemoveExtraItems     = Weapon_cvRemoveExtraItems.BoolValue;
}

//================================================
// GetWeaponIndex(iEntity, const String:szEntityClassName[128])
//================================================
// Searches the weapon index for the given entity
//  class

int WI_GetWeaponIndex(int iEntity, const char szEntityClassName[128]) {
    //------------------------------------------------
    // Check for weapon in class name
    //------------------------------------------------
    // If the class name doesn't contain weapon at all
    //  we don't need to loop thourgh with this entity
    // Return false
    if (StrContains(szEntityClassName, "weapon") == -1)
        return WEAPON_NULL_INDEX;
    //------------------------------------------------
    // Check class name
    //------------------------------------------------
    // If the class name is weapon_spawn we got a
    //  dynamic spawn and as such read the weapon id
    //  for detimernation of the weapon index
    int  iWeaponIndex;
    bool bFoundIndex = false;
    if (strcmp(szEntityClassName, "weapon_spawn") == 0) {
        int iWepID = GetEntProp(iEntity, Prop_Send, "m_weaponID");
        for (iWeaponIndex = FIRST_WEAPON; iWeaponIndex < NUM_OF_WEAPONS; iWeaponIndex++) {
            if (Weapon_Attributes[iWeaponIndex][eWeaponID] != iWepID)
                continue;
            bFoundIndex = true;
            break;
        }
    } else {
        char szBuffer[128];
        for (iWeaponIndex = FIRST_WEAPON; iWeaponIndex < NUM_OF_WEAPONS; iWeaponIndex++) {
            if (strlen(WI_szWeaponSpawns[iWeaponIndex]) < 1)
                continue;
            FormatEx(szBuffer, sizeof(szBuffer), "%s%s%s", SPAWN_PREFIX, WI_szWeaponSpawns[iWeaponIndex], SPAWN_SURFIX);
            if (strcmp(szEntityClassName, szBuffer) != 0)
                continue;
            bFoundIndex = true;
            break;
        }
    }
    //------------------------------------------------
    // Check index
    //------------------------------------------------
    // If we didn't find the index, return false
    if (!bFoundIndex)
        return WEAPON_NULL_INDEX;
    return iWeaponIndex;
}

//================================================
// IsStatic(iEntity, iWeaponIndex)
//================================================
// Checks if the given entity with matching weapon
//  index is a static spawn
bool WI_IsStatic(int iEntity, int iWeaponIndex) {
    if (strlen(WI_szWeaponSpawns[iWeaponIndex]) < 1)
        return false;
    char szEntityClassName[128];
    GetEdictClassname(iEntity, szEntityClassName, sizeof(szEntityClassName));
    char szBuffer[128];
    FormatEx(szBuffer, sizeof(szBuffer), "%s%s%s", SPAWN_PREFIX, WI_szWeaponSpawns[iWeaponIndex], SPAWN_SURFIX);
    if (strcmp(szEntityClassName, szBuffer) != 0)
        return false;
    // This is to prevent crashing
    // Some static spawns doesn't have a model as we just wish to remove them
    if (strlen(WI_szWeaponModels[iWeaponIndex]) < 1)
        return false;
    return true;
}

//================================================
// ReplaceWeapon(iEntity, iWeaponIndex, bool:bSpawnerEvent)
//================================================
// Takes care of handling weapon entities,
//  killing, replacing, and updateing.

void WI_ReplaceWeapon(int iEntity, int iWeaponIndex, bool bSpawnerEvent = false) {
    //------------------------------------------------
    // Removal of weapons
    //------------------------------------------------
    // Checks if the replacement index is equal to -1
    // (WEAPON_REMOVE_INDEX)
    // If so, check the cvar boolean and kill the
    // weapon
    if (!bSpawnerEvent && Weapon_Attributes[iWeaponIndex][eReplacementIndex] == WEAPON_REMOVE_INDEX && Weapon_bConvar[iWeaponIndex]) {
        RemoveEntity(iEntity);
        return;
    }
    //------------------------------------------------
    // Replacement of static weapons
    //------------------------------------------------
    // Replaces all weapon_*weaponname*_spawn with
    // weapon_spawn and the old weapon ID
    char  szModelBuffer[128];
    float vOrigin[3];
    float vRotation[3];
    if (!bSpawnerEvent && WI_IsStatic(iEntity, iWeaponIndex) && (Weapon_Attributes[iWeaponIndex][eWeaponID] != WEAPON_NULL_INDEX)) {
        GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", vOrigin);
        GetEntPropVector(iEntity, Prop_Send, "m_angRotation", vRotation);
        RemoveEntity(iEntity);
        iEntity = CreateEntityByName("weapon_spawn");
        SetEntProp(iEntity, Prop_Send, "m_weaponID", Weapon_Attributes[iWeaponIndex][eWeaponID]);
        FormatEx(szModelBuffer, sizeof(szModelBuffer), "%s%s%s", MODEL_PREFIX, WI_szWeaponModels[iWeaponIndex], MODEL_SURFIX);
        SetEntityModel(iEntity, szModelBuffer);
        TeleportEntity(iEntity, vOrigin, vRotation, NULL_VECTOR);
        DispatchKeyValue(iEntity, "count", "5");
        DispatchSpawn(iEntity);
        SetEntityMoveType(iEntity, MOVETYPE_NONE);
    }
    //------------------------------------------------
    // Replace Weapons
    //------------------------------------------------
    // Replace weapons that needs to be done so
    // This is to replace CSS weapons, but can be
    //  adjusted to fit with any weapon
    if ((!bSpawnerEvent && Weapon_Attributes[iWeaponIndex][eReplacementIndex] != WEAPON_NULL_INDEX || Weapon_Attributes[iWeaponIndex][eReplacementIndex] != WEAPON_REMOVE_INDEX) && Weapon_bConvar[iWeaponIndex]) {
        iWeaponIndex = Weapon_Attributes[iWeaponIndex][eReplacementIndex];
        SetEntProp(iEntity, Prop_Send, "m_weaponID", Weapon_Attributes[iWeaponIndex][eWeaponID]);
        FormatEx(szModelBuffer, sizeof(szModelBuffer), "%s%s%s", MODEL_PREFIX, WI_szWeaponModels[iWeaponIndex], MODEL_SURFIX);
        SetEntityModel(iEntity, szModelBuffer);
    }
    //------------------------------------------------
    // Check for tier 1 equivalent
    //------------------------------------------------
    // Check the current weapon index for a tier 1
    // equivalent
    if (Weapon_Attributes[iWeaponIndex][eTier1EquivalentIndex] == WEAPON_NULL_INDEX)
        return;
    //------------------------------------------------
    // Check location
    //------------------------------------------------
    // Check the location of the weapon, to see if its
    // within a saferoom
    bool bIsInSaferoom = false;
    GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", vOrigin);
    // Within start safe room
    if (!Weapon_bReplaceTier2_All && SDK_IsVersus()) {
        if (GetVectorDistance(Weapon_fMapOrigin_Start, vOrigin) > Weapon_fMapDist_StartExtra && GetVectorDistance(Weapon_fMapOrigin_End, vOrigin) > Weapon_fMapDist_End) {
            if (!bSpawnerEvent)
                return;
        } else {
            bIsInSaferoom = true;
        }
    }
    //------------------------------------------------
    // Check tier 2 replacement booleans
    //------------------------------------------------
    // Check and see if the plugin is set to replace
    //  tier 2 weapons
    // One for non-finale maps and one for finales
    if (!Weapon_bReplaceTier2_All) {
        if (!bSpawnerEvent) {
            if ((!Weapon_bReplaceTier2 && !IsMapFinale()) || (!Weapon_bReplaceTier2_Finale && IsMapFinale()))
                return;
        } else {
            if ((!Weapon_bLimitTier2 && !bIsInSaferoom) || (!Weapon_bLimitTier2_Safehouse && bIsInSaferoom))
                return;
        }
    }
    //------------------------------------------------
    // Replace tier 2 weapon
    //------------------------------------------------
    // And lastly after all these steps, this is where
    // the magic happens
    // Replace the weapon with its tier 1 equivalent
    // and update the model
    iWeaponIndex = Weapon_Attributes[iWeaponIndex][eTier1EquivalentIndex];
    SetEntProp(iEntity, Prop_Send, "m_weaponID", Weapon_Attributes[iWeaponIndex][eWeaponID]);
    FormatEx(szModelBuffer, sizeof(szModelBuffer), "%s%s%s", MODEL_PREFIX, WI_szWeaponModels[iWeaponIndex], MODEL_SURFIX);
    SetEntityModel(iEntity, szModelBuffer);
}

//================================================
// ReplaceExtra(iEntity, iWeaponIndex)
//================================================
// Takes care of handling extra entities,
//  killing, replacing, and updateing.

void WI_ReplaceExtra(int iEntity, int iWeaponIndex) {
    //------------------------------------------------
    // Removal of extras
    //------------------------------------------------
    // Checks if the replacement index is equal to -1
    //  (WEAPON_REMOVE_INDEX)
    // If so, check the cvar boolean and kill the
    //  weapon, minus medkits as these needs special
    //  care
    if (Weapon_Attributes[iWeaponIndex][eReplacementIndex] == WEAPON_REMOVE_INDEX && Weapon_bConvar[iWeaponIndex] && iWeaponIndex != WEAPON_FIRST_AID_KIT_INDEX) {
        RemoveEntity(iEntity);
        return;
    }
    //------------------------------------------------
    // Check entity
    //------------------------------------------------
    // Stop removing extra items that are protected
    // (medkits converted to pain pills)
    for (int i; i < WEAPON_NUMBER_OF_START_KITS; i++) {
        if (Weapon_iKitEntity[i] == iEntity)
            return;
    }
    //------------------------------------------------
    // Check location
    //------------------------------------------------
    // If the item is within the end safe room and its
    //  not finale
    // OR
    // If the items is within start safe room, and it
    //  is not a first aid kit
    // Remove the item
    float vOrigin[3];
    GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", vOrigin);
    bool  bIsInStartSaferoom;
    bool  bIsInStartSaferoomExtra;
    bool  bIsInEndSaferoom;
    bool  bIsInFinaleArea;
    float fStartDistance = GetVectorDistance(Weapon_fMapOrigin_Start, vOrigin);
    if (fStartDistance <= Weapon_fMapDist_Start) {
        bIsInStartSaferoom      = true;
        bIsInStartSaferoomExtra = true;
    } else if (fStartDistance <= Weapon_fMapDist_StartExtra) {
        bIsInStartSaferoomExtra = true;
    } else if (GetVectorDistance(Weapon_fMapOrigin_End, vOrigin) <= Weapon_fMapDist_End) {
        if (IsMapFinale()) {
            bIsInFinaleArea = true;
        } else {
            bIsInEndSaferoom = true;
        }
    }
    if (Weapon_bRemoveExtraItems && (bIsInEndSaferoom || (bIsInStartSaferoomExtra && iWeaponIndex != WEAPON_FIRST_AID_KIT_INDEX))) {
        RemoveEntity(iEntity);
        return;
    }
    //------------------------------------------------
    // Check for medkit
    //------------------------------------------------
    // No need to go on if it is not a medkit
    if (iWeaponIndex != WEAPON_FIRST_AID_KIT_INDEX)
        return;
    //------------------------------------------------
    // Check location of medkit
    //------------------------------------------------
    // If its outside the start safe room we assume
    // it is a static medkit and it needs removal
    if (Weapon_bConvar[iWeaponIndex] && !bIsInStartSaferoom && !bIsInFinaleArea) {
        RemoveEntity(iEntity);
        return;
    }
    if (Weapon_iKitCount >= WEAPON_NUMBER_OF_START_KITS && bIsInStartSaferoom) {
        RemoveEntity(iEntity);
        return;
    }
    if (bIsInStartSaferoom && Weapon_bReplaceStartKits) {
        float vRotation[3];
        char  szSpawnBuffer[128];
        GetEntPropVector(iEntity, Prop_Send, "m_angRotation", vRotation);
        RemoveEntity(iEntity);
        FormatEx(szSpawnBuffer, sizeof(szSpawnBuffer), "%s%s%s", SPAWN_PREFIX, WI_szWeaponSpawns[WEAPON_PAIN_PILLS_INDEX], SPAWN_SURFIX);
        iEntity = CreateEntityByName(szSpawnBuffer);
        TeleportEntity(iEntity, vOrigin, vRotation, NULL_VECTOR);
        DispatchSpawn(iEntity);
        SetEntityMoveType(iEntity, MOVETYPE_NONE);
    } else if (bIsInFinaleArea && Weapon_bReplaceFinaleKits) {
        float vRotation[3];
        char  szSpawnBuffer[128];
        GetEntPropVector(iEntity, Prop_Send, "m_angRotation", vRotation);
        RemoveEntity(iEntity);
        FormatEx(szSpawnBuffer, sizeof(szSpawnBuffer), "%s%s%s", SPAWN_PREFIX, WI_szWeaponSpawns[WEAPON_PAIN_PILLS_INDEX], SPAWN_SURFIX);
        iEntity = CreateEntityByName(szSpawnBuffer);
        TeleportEntity(iEntity, vOrigin, vRotation, NULL_VECTOR);
        DispatchSpawn(iEntity);
        SetEntityMoveType(iEntity, MOVETYPE_NONE);
    }
    if (bIsInStartSaferoom)
        Weapon_iKitEntity[Weapon_iKitCount++] = iEntity;
}

//================================================
// PrecacheModels
//================================================
// Loops through all the models and precache the
// ones we need
void WI_PrecacheModels() {
    for (int i = FIRST_WEAPON; i <= LAST_WEAPON; i++) {
        if (strlen(WI_szWeaponModels[i]) == 0)
            continue;
        char szModelBuffer[128];
        FormatEx(szModelBuffer, sizeof(szModelBuffer), "%s%s%s", MODEL_PREFIX, WI_szWeaponModels[i], MODEL_SURFIX);
        if (IsModelPrecached(szModelBuffer))
            continue;
        PrecacheModel(szModelBuffer);
    }
}

//================================================
// GetMapInfo
//================================================
// Updates the global map variables if needed
//================================================
void WI_GetMapInfo() {
    if (!Weapon_bUpdateMapInfo)
        return;
    Weapon_fMapOrigin_Start[0] = GetMapStartOriginX();
    Weapon_fMapOrigin_Start[1] = GetMapStartOriginY();
    Weapon_fMapOrigin_Start[2] = GetMapStartOriginZ();
    Weapon_fMapOrigin_End  [0] = GetMapEndOriginX();
    Weapon_fMapOrigin_End  [1] = GetMapEndOriginY();
    Weapon_fMapOrigin_End  [2] = GetMapEndOriginZ();
    Weapon_fMapDist_Start      = GetMapStartDist();
    Weapon_fMapDist_StartExtra = GetMapStartExtraDist();
    Weapon_fMapDist_End        = GetMapEndDist();
    Weapon_bUpdateMapInfo      = false;
}

//====================================================
// Module setup
//====================================================
void WI_OnModuleStart() {
    WI_Convar_Setup();
    HookEvent("round_start",       WI_Event_RoundStart);
    HookEvent("round_end",         WI_Event_RoundEnd);
    HookEvent("spawner_give_item", WI_Event_SpawnerGiveItem);
}

void WI_Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    CreateTimer(0.3, WI_Timer_RoundStart, _, TIMER_FLAG_NO_MAPCHANGE);
}

void WI_Event_RoundEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    Weapon_bUpdateMapInfo = true;
}

void WI_OnMapEnd() {
    Weapon_bUpdateMapInfo = true;
}

Action WI_Timer_RoundStart(Handle hTimer) {
    if (!IsPluginEnabled())
        return Plugin_Stop;
    WI_GetMapInfo();
    if (Weapon_bUpdateMapInfo)
        return Plugin_Stop;
    WI_PrecacheModels();
    for (int i = 0; i < WEAPON_NUMBER_OF_START_KITS; i++) {
        Weapon_iKitEntity[i] = 0;
    }
    Weapon_iKitCount = 0;
    int  iEntity;
    int  iWeaponIndex;
    int  iCount = GetEntityCount();
    char szEntClass[128];
    for (iEntity = 1; iEntity <= iCount; iEntity++) {
        if (!IsValidEdict(iEntity) || !IsValidEntity(iEntity))
            continue;
        GetEdictClassname(iEntity, szEntClass, sizeof(szEntClass));
        iWeaponIndex = WI_GetWeaponIndex(iEntity, szEntClass);
        if (iWeaponIndex != WEAPON_NULL_INDEX) {
            if (iWeaponIndex <= LAST_WEAPON) {
                WI_ReplaceWeapon(iEntity, iWeaponIndex);
            } else {
                WI_ReplaceExtra(iEntity, iWeaponIndex);
            }
        }
        if (Weapon_bRemoveLaserSight && StrContains(szEntClass, "upgrade_laser_sight") != -1) {
            RemoveEntity(iEntity);
            continue;
        }
    }
    return Plugin_Stop;
}

void WI_Event_SpawnerGiveItem(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!IsPluginEnabled())
        return;
    int iEntity = eEvent.GetInt("spawner");
    char szEntityClassName[128];
    GetEdictClassname(iEntity, szEntityClassName, sizeof(szEntityClassName));
    int iWeaponIndex = WI_GetWeaponIndex(iEntity, szEntityClassName);
    if (iWeaponIndex == WEAPON_NULL_INDEX)
        return;
    WI_ReplaceWeapon(iEntity, iWeaponIndex, true);
}