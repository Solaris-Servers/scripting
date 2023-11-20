#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2util>
#include <colors>
#include <solaris/stocks>

#define TEAM_SURVIVOR           2

#define SOUND_NAME "player/suit_denydevice.wav"

enum struct LimitArrayEntry {
    int LAE_iLimit;
    int LAE_iGiveAmmo;
    int LAE_arrWeapon[WEPID_SIZE / 32 + 1];
    int LAE_arrMelee [WEPID_MELEES_SIZE / 32 + 1];
}

int g_iLastPrintTickCount[MAXPLAYERS + 1];
int g_iWeaponAlreadyGiven[MAXPLAYERS + 1][MAX_EDICTS];

bool g_bIsLocked;
bool g_bIsIncappedWithMelee[MAXPLAYERS + 1];

ArrayList g_arrLimits;
StringMap g_smMeleeWeaponNames;

public Plugin myinfo = {
    name        = "L4D Weapon Limits",
    author      = "CanadaRox, Stabby, Forgetest, A1m`, robex",
    description = "Restrict weapons individually or together",
    version     = "2.2.1",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart() {
    L4D2Weapons_Init();
    LimitArrayEntry eArrayEntry;
    g_arrLimits = new ArrayList(sizeof(eArrayEntry));

    g_smMeleeWeaponNames = new StringMap();
    for (int i = 0; i < WEPID_MELEES_SIZE; i++) {
        g_smMeleeWeaponNames.SetValue(MeleeWeaponNames[i], i);
    }

    RegServerCmd("l4d_wlimits_add",   Cmd_AddLimit,    "Add a weapon limit");
    RegServerCmd("l4d_wlimits_lock",  Cmd_LockLimits,  "Locks the limits to improve search speeds");
    RegServerCmd("l4d_wlimits_clear", Cmd_ClearLimits, "Clears all weapon limits (limits must be locked to be cleared)");

    HookEvent("round_start",                Event_RoundStart);
    HookEvent("player_incapacitated_start", Event_PlayerIncap);
    HookEvent("revive_success",             Event_ReviveSuccess);
    HookEvent("player_death",               Event_PlayerDeath);
    HookEvent("player_bot_replace",         Event_BotReplacedPlayer);
    HookEvent("bot_player_replace",         Event_PlayerReplacedBot);
}

public void OnMapStart() {
    PrecacheSound(SOUND_NAME);
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    for (int i = 1; i <= MaxClients; i++) {
        g_bIsIncappedWithMelee[i] = false;
        g_iLastPrintTickCount [i] = 0;
    }
}

public void OnClientPutInServer(int iClient) {
    SDKHook(iClient, SDKHook_WeaponCanUse, Hook_WeaponCanUse);
}

public void OnClientDisconnect(int iClient) {
    SDKUnhook(iClient, SDKHook_WeaponCanUse, Hook_WeaponCanUse);
}

Action Cmd_AddLimit(int iArgs) {
    if (g_bIsLocked) {
        PrintToServer("Limits have been locked !");
        return Plugin_Handled;
    }
    if (iArgs < 3) {
        PrintToServer("Usage: l4d_wlimits_add <limit> <ammo> <weapon1> <weapon2> ... <weaponN>\nAmmo: -1: Given for primary weapon spawns only, 0: no ammo given ever, else: ammo always given !");
        return Plugin_Handled;
    }

    char szArg[ENTITY_MAX_NAME_LENGTH];
    GetCmdArg(1, szArg, sizeof(szArg));

    LimitArrayEntry eNewEntry;

    eNewEntry.LAE_iLimit = StringToInt(szArg);
    GetCmdArg(2, szArg, sizeof(szArg));
    eNewEntry.LAE_iGiveAmmo = StringToInt(szArg);

    int iWepId, iMeleeId;
    for (int i = 3; i <= iArgs; i++) {
        GetCmdArg(i, szArg, sizeof(szArg));
        iWepId = WeaponNameToId(szArg);
        AddBitMask(eNewEntry.LAE_arrWeapon, iWepId);
        // assume it might be a melee
        if (iWepId == WEPID_NONE) {
            if (g_smMeleeWeaponNames.GetValue(szArg, iMeleeId)) {
                AddBitMask(eNewEntry.LAE_arrMelee, iMeleeId);
            }
        }
    }
    g_arrLimits.PushArray(eNewEntry, sizeof(eNewEntry));
    return Plugin_Handled;
}

Action Cmd_LockLimits(int iArgs) {
    if (g_bIsLocked) {
        PrintToServer("Weapon limits already locked!");
    } else {
        g_bIsLocked = true;
        PrintToServer("Weapon limits locked!");
    }
    return Plugin_Handled;
}

Action Cmd_ClearLimits(int iArgs) {
    if (g_bIsLocked) {
        g_bIsLocked = false;
        PrintToChatAll("[L4D Weapon Limits] Weapon limits cleared!");
        if (g_arrLimits != null) g_arrLimits.Clear();
    }
    return Plugin_Handled;
}

Action Hook_WeaponCanUse(int iClient, int iWeapon) {
    // TODO: There seems to be an issue that this hook will be constantly called
    //       when client with no weapon on equivalent slot just eyes or walks on it.
    //       If the weapon meets limit, client will have the warning spamming unexpectedly.

    if (!g_bIsLocked)                                return Plugin_Continue;
    if (GetClientTeam(iClient) != L4D2Team_Survivor) return Plugin_Continue;

    int  iWepId   = IdentifyWeapon(iWeapon);
    bool bIsMelee = (iWepId == WEPID_MELEE);
    int  iMeleeId = 0;

    if (bIsMelee) iMeleeId = IdentifyMeleeWeapon(iWeapon);

    int iWepSlot      = GetSlotFromWeaponId(iWepId);
    int iPlayerWeapon = GetPlayerWeaponSlot(iClient, iWepSlot);
    int iPlayerWepId  = IdentifyWeapon(iPlayerWeapon);

    LimitArrayEntry eArrayEntry;

    int iSize = g_arrLimits.Length;
    for (int i = 0; i < iSize; i++) {
        g_arrLimits.GetArray(i, eArrayEntry, sizeof(eArrayEntry));
        if (bIsMelee) {
            int iSpecificMeleeCount = GetMeleeCount(eArrayEntry.LAE_arrMelee);
            int iAllMeleeCount      = GetWeaponCount(eArrayEntry.LAE_arrWeapon);

            bool bIsSpecificMeleeLimited = IsWeaponLimited(eArrayEntry.LAE_arrMelee,  iMeleeId);
            bool bIsAllMeleeLimited      = IsWeaponLimited(eArrayEntry.LAE_arrWeapon, iWepId);

            if (bIsSpecificMeleeLimited && iSpecificMeleeCount >= eArrayEntry.LAE_iLimit) {
                DenyWeapon(iWepSlot, eArrayEntry, iWeapon, iClient);
                return Plugin_Handled;
            }
            if (bIsAllMeleeLimited && iAllMeleeCount >= eArrayEntry.LAE_iLimit) {
                // dont deny swapping melees when theres only a limit on global melees
                if (iPlayerWepId != WEPID_MELEE) {
                    DenyWeapon(iWepSlot, eArrayEntry, iWeapon, iClient);
                    return Plugin_Handled;
                }
            }
        } else {
            // is weapon about to be picked up limited and over the limit?
            if (IsWeaponLimited(eArrayEntry.LAE_arrWeapon, iWepId) && GetWeaponCount(eArrayEntry.LAE_arrWeapon) >= eArrayEntry.LAE_iLimit) {
                // is currently held weapon limited?
                if (!iPlayerWepId || iWepId == iPlayerWepId || !IsWeaponLimited(eArrayEntry.LAE_arrWeapon, iPlayerWepId)) {
                    DenyWeapon(iWepSlot, eArrayEntry, iWeapon, iClient);
                    return Plugin_Handled;
                }
            }
        }
    }
    return Plugin_Continue;
}

void Event_PlayerIncap(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)                                return;
    if (GetClientTeam(iClient) != L4D2Team_Survivor) return;
    int iMelee = GetPlayerWeaponSlot(iClient, 1);
    if (IdentifyWeapon(iMelee) == WEPID_MELEE) g_bIsIncappedWithMelee[iClient] = true;
}

void Event_ReviveSuccess(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("subject"));
    if (iClient <= 0)                     return;
    if (!g_bIsIncappedWithMelee[iClient]) return;
    g_bIsIncappedWithMelee[iClient] = false;
}

void Event_PlayerDeath(Event eEvent, const char[] name, bool dontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)                                return;
    if (GetClientTeam(iClient) != L4D2Team_Survivor) return;
    if (!g_bIsIncappedWithMelee[iClient])            return;
    g_bIsIncappedWithMelee[iClient] = false;
}

void Event_BotReplacedPlayer(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iBot = GetClientOfUserId(eEvent.GetInt("bot"));
    if (iBot <= 0)                                return;
    if (GetClientTeam(iBot) != L4D2Team_Survivor) return;
    int iPlayer = GetClientOfUserId(eEvent.GetInt("player"));
    g_bIsIncappedWithMelee[iBot]    = g_bIsIncappedWithMelee[iPlayer];
    g_bIsIncappedWithMelee[iPlayer] = false;
}

void Event_PlayerReplacedBot(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iPlayer = GetClientOfUserId(eEvent.GetInt("player"));
    if (iPlayer <= 0)                                return;
    if (GetClientTeam(iPlayer) != L4D2Team_Survivor) return;
    int iBot = GetClientOfUserId(eEvent.GetInt("bot"));
    g_bIsIncappedWithMelee[iPlayer] = g_bIsIncappedWithMelee[iBot];
    g_bIsIncappedWithMelee[iBot]    = false;
}

void AddBitMask(int[] iMask, int iWeaponId) {
    iMask[iWeaponId / 32] |= (1 << (iWeaponId % 32));
}

bool IsWeaponLimited(const int[] iMask, int iWepId) {
    return view_as<bool>(iMask[iWepId / 32] & (1 << (iWepId % 32)));
}

void DenyWeapon(int iWepSlot, LimitArrayEntry eArrayEntry, int iWeapon, int iClient) {
    if ((iWepSlot == 0 && eArrayEntry.LAE_iGiveAmmo == -1) || eArrayEntry.LAE_iGiveAmmo != 0)
        SDK_AmmoSpawnUse(iClient);

    // Notify the client only when they are attempting to pick this up
    // in which way spamming gets avoided due to auto-pick-up checking left since Counter:Strike.

    // g_iWeaponAlreadyGiven - if the weapon is given by another plugin, the player will not press the use key
    // g_iLastPrintTickCount - sometimes there is a double seal in one frame because the player touches the weapon and presses a use key

    int iWeaponRef     = EntIndexToEntRef(iWeapon);
    int iLastTick      = GetGameTickCount();
    int iButtonPressed = GetEntProp(iClient, Prop_Data, "m_afButtonPressed");

    if ((g_iWeaponAlreadyGiven[iClient][iWeapon] != iWeaponRef || iButtonPressed & IN_USE) && g_iLastPrintTickCount[iClient] != iLastTick) {
        if (eArrayEntry.LAE_iLimit == 0) CPrintToChat(iClient, "{blue}[{default}Weapon Limits{blue}]{default} This weapon group is locked!");
        else                             CPrintToChat(iClient, "{blue}[{default}Weapon Limits{blue}]{default} This weapon group has reached its max of {green}%d", eArrayEntry.LAE_iLimit);
        EmitSoundToClient(iClient, SOUND_NAME);

        g_iWeaponAlreadyGiven[iClient][iWeapon] = iWeaponRef;
        g_iLastPrintTickCount[iClient]          = iLastTick;
    }
}

int GetWeaponCount(const int[] iMask) {
    bool bQueryMelee = view_as<bool>(iMask[WEPID_MELEE / 32] & (1 << (WEPID_MELEE % 32)));
    int iCount, iWepId;
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))                    continue;
        if (GetClientTeam(i) != L4D2Team_Survivor) continue;
        if (!IsPlayerAlive(i))                     continue;
        for (int j = 0; j < L4D2WeaponSlot_Size; j++) {
            iWepId = IdentifyWeapon(GetPlayerWeaponSlot(i, j));
            if (IsWeaponLimited(iMask, iWepId) || (j == 1 && bQueryMelee && g_bIsIncappedWithMelee[i]))
                iCount++;
        }
    }
    return iCount;
}

int GetMeleeCount(const int[] iMask) {
    int iCount, iMeleeId;
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))                    continue;
        if (GetClientTeam(i) != L4D2Team_Survivor) continue;
        if (!IsPlayerAlive(i))                     continue;

        iMeleeId = IdentifyMeleeWeapon(GetPlayerWeaponSlot(i, L4D2WeaponSlot_Secondary));
        if (iMeleeId == WEPID_MELEE_NONE) continue;

        if (IsWeaponLimited(iMask, iMeleeId) || g_bIsIncappedWithMelee[i])
            iCount++;
    }
    return iCount;
}