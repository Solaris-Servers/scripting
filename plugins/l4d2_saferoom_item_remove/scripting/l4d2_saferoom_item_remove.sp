#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <l4d2_saferoom_detect>

#define DELAY_ROUNDSTART
#define SAFEROOM_END     1
#define SAFEROOM_START   2

ConVar g_cvEnabled;
ConVar g_cvSaferoom;
ConVar g_cvItems;

StringMap g_smItems;

enum Item_Killable {
    ITEM_KILLABLE        = 0,
    ITEM_KILLABLE_HEALTH = (1 << 0),
    ITEM_KILLABLE_WEAPON = (1 << 1),
    ITEM_KILLABLE_MELEE  = (1 << 2),
    ITEM_KILLABLE_OTHER  = (1 << 3)
}

public Plugin myinfo = {
    name        = "Saferoom Item Remover",
    author      = "Tabun, Sir",
    description = "Removes any saferoom item (start or end).",
    version     = "0.0.7",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
}

public void OnPluginStart() {
    PrepareTrie();

    g_cvEnabled = CreateConVar(
    "sm_safeitemkill_enable", "1",
    "Whether end saferoom items should be removed.",
    FCVAR_NONE, true, 0.0, true, 1.0);

    g_cvSaferoom = CreateConVar(
    "sm_safeitemkill_saferooms", "1",
    "Saferooms to empty. Flags: 1 = end saferoom, 2 = start saferoom (3 = kill items from both).",
    FCVAR_NONE, true, 0.0, true, 3.0);

    g_cvItems = CreateConVar(
    "sm_safeitemkill_items", "7",
    "Types to rmove. Flags: 1 = health items, 2 = guns, 4 = melees, 8 = all other usable items, 15 = all",
    FCVAR_NONE, true, 0.0, true, 15.0);

    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!g_cvEnabled.BoolValue)
        return;

    CreateTimer(1.0, Timer_RoundStart, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_RoundStart(Handle hTimer) {
    RemoveEndSaferoomItems();
    return Plugin_Stop;
}

void RemoveEndSaferoomItems() {
    // check for any items in the end saferoom, and remove them
    int iCount[2];

    char szClsName[128];
    Item_Killable eCheckItem;
    for (int i = 1; i <= GetEntityCount(); i++) {
        if (!IsValidEntity(i))
            continue;

        // check item type
        GetEdictClassname(i, szClsName, sizeof(szClsName));

        if (!g_smItems.GetValue(szClsName, eCheckItem))
            continue;

        // see if item is of a killable type by cvar
        if (eCheckItem == ITEM_KILLABLE || g_cvItems.IntValue & view_as<int>(eCheckItem)) {
            if (g_cvSaferoom.IntValue & SAFEROOM_START) {
                if (SAFEDETECT_IsEntityInStartSaferoom(i)) {
                    // kill the item
                    AcceptEntityInput(i, "Kill");
                    iCount[0]++;
                    continue;
                }
            }

            if (g_cvSaferoom.IntValue & SAFEROOM_END) {
                if (SAFEDETECT_IsEntityInEndSaferoom(i)) {
                    // kill the item
                    AcceptEntityInput(i, "Kill");
                    iCount[1]++;
                    continue;
                }
            }
        }
    }

    LogMessage("Removed %i saferoom item(s) (start: %i; end: %i).", iCount[0] + iCount[1], iCount[0], iCount[1]);
}

void PrepareTrie() {
    g_smItems = new StringMap();
    g_smItems.SetValue("weapon_spawn",                        ITEM_KILLABLE_WEAPON);
    g_smItems.SetValue("weapon_ammo_spawn",                   ITEM_KILLABLE_WEAPON);
    g_smItems.SetValue("weapon_pistol_spawn",                 ITEM_KILLABLE_WEAPON);
    g_smItems.SetValue("weapon_pistol_magnum_spawn",          ITEM_KILLABLE_WEAPON);
    g_smItems.SetValue("weapon_smg_spawn",                    ITEM_KILLABLE_WEAPON);
    g_smItems.SetValue("weapon_smg_silenced_spawn",           ITEM_KILLABLE_WEAPON);
    g_smItems.SetValue("weapon_pumpshotgun_spawn",            ITEM_KILLABLE_WEAPON);
    g_smItems.SetValue("weapon_shotgun_chrome_spawn",         ITEM_KILLABLE_WEAPON);
    g_smItems.SetValue("weapon_hunting_rifle_spawn",          ITEM_KILLABLE_WEAPON);
    g_smItems.SetValue("weapon_sniper_military_spawn",        ITEM_KILLABLE_WEAPON);
    g_smItems.SetValue("weapon_rifle_spawn",                  ITEM_KILLABLE_WEAPON);
    g_smItems.SetValue("weapon_rifle_ak47_spawn",             ITEM_KILLABLE_WEAPON);
    g_smItems.SetValue("weapon_rifle_desert_spawn",           ITEM_KILLABLE_WEAPON);
    g_smItems.SetValue("weapon_autoshotgun_spawn",            ITEM_KILLABLE_WEAPON);
    g_smItems.SetValue("weapon_shotgun_spas_spawn",           ITEM_KILLABLE_WEAPON);
    g_smItems.SetValue("weapon_rifle_m60_spawn",              ITEM_KILLABLE_WEAPON);
    g_smItems.SetValue("weapon_grenade_launcher_spawn",       ITEM_KILLABLE_WEAPON);
    g_smItems.SetValue("weapon_chainsaw_spawn",               ITEM_KILLABLE_WEAPON);
    g_smItems.SetValue("weapon_melee_spawn",                  ITEM_KILLABLE_MELEE);
    g_smItems.SetValue("weapon_item_spawn",                   ITEM_KILLABLE_HEALTH);
    g_smItems.SetValue("weapon_first_aid_kit_spawn",          ITEM_KILLABLE_HEALTH);
    g_smItems.SetValue("weapon_defibrillator_spawn",          ITEM_KILLABLE_HEALTH);
    g_smItems.SetValue("weapon_pain_pills_spawn",             ITEM_KILLABLE_HEALTH);
    g_smItems.SetValue("weapon_adrenaline_spawn",             ITEM_KILLABLE_HEALTH);
    g_smItems.SetValue("weapon_pipe_bomb_spawn",              ITEM_KILLABLE_OTHER);
    g_smItems.SetValue("weapon_molotov_spawn",                ITEM_KILLABLE_OTHER);
    g_smItems.SetValue("weapon_vomitjar_spawn",               ITEM_KILLABLE_OTHER);
    g_smItems.SetValue("weapon_gascan_spawn",                 ITEM_KILLABLE_OTHER);
    g_smItems.SetValue("upgrade_spawn",                       ITEM_KILLABLE_OTHER);
    g_smItems.SetValue("upgrade_laser_sight",                 ITEM_KILLABLE_OTHER);
    g_smItems.SetValue("weapon_upgradepack_explosive_spawn",  ITEM_KILLABLE_OTHER);
    g_smItems.SetValue("weapon_upgradepack_incendiary_spawn", ITEM_KILLABLE_OTHER);
    g_smItems.SetValue("upgrade_ammo_incendiary",             ITEM_KILLABLE_OTHER);
    g_smItems.SetValue("upgrade_ammo_explosive",              ITEM_KILLABLE_OTHER);
}