#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colors>

#include <solaris/votes>
#include <solaris/team_manager>

#undef REQUIRE_PLUGIN
#include <readyup>
#define REQUIRE_PLUGIN

#define MAX_ENTITY_NAME_LENGTH 64

enum {
    eUndecided,       // 0: Undecided.
    ePumpShotgun,     // 1: Pump Shotgun.
    eChromeShotgun,   // 2: Chrome Shotgun.
    eUzi,             // 3: Uzi.
    eSilencedUzi,     // 4: Silenced Uzi.
    eScout,           // 5: Scout.
    eAwp,             // 6: AWP.
    eGrenadeLauncher, // 7: Grenade Launcher.
    eDeagle           // 8: Deagle.
};

static const char szGiveWeaponNames[][] = {
    "",                        // 0: Undecided.
    "weapon_pumpshotgun",      // 1: Pump Shotgun.
    "weapon_shotgun_chrome",   // 2: Chrome Shotgun.
    "weapon_smg",              // 3: Uzi.
    "weapon_smg_silenced",     // 4: Silenced Uzi.
    "weapon_sniper_scout",     // 5: Scout.
    "weapon_sniper_awp",       // 6: AWP.
    "weapon_grenade_launcher", // 7: Grenade Launcher.
    "weapon_pistol_magnum"     // 8: Deagle.
};

static const char szRemoveWeaponNames[][] = {
    "shotgun_chrome_spawn",
    "spawn",
    "ammo_spawn",
    "smg",
    "smg_silenced",
    "shotgun_chrome",
    "pumpshotgun",
    "hunting_rifle",
    "pistol",
    "pistol_magnum"
};

SolarisVote g_SolarisVoteWeaponsLoadout;
int g_iCurrentMode = eUndecided;
int g_iVotingMode = 0;
bool g_bVoteUnderstood[MAXPLAYERS + 1] = {false, ...};
Menu g_mMenu;

public Plugin myinfo = {
    name        = "Weapon Loadout",
    author      = "Sir, A1m`",
    description = "Allows the Players to choose which weapons to play the mode in.",
    version     = "2.3",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart() {
    InitMenu();
    g_SolarisVoteWeaponsLoadout = (new SolarisVote()).RestrictToGamemodes(GM_VERSUS)
                                                     .SetRequiredVotes(RV_MORETHANHALF)
                                                     .RestrictToBeforeRoundStart()
                                                     .RestrictToFirstHalf()
                                                     .SetSuccessMessage("Survivor weapons set")
                                                     .OnSuccess(VoteCallback_WeaponsLoadout);
    HookEvent("round_start", Event_RoundStart);
    HookEvent("player_team", Event_PlayerTeam);

    RegConsoleCmd("sm_mode", Cmd_VoteMode, "Opens the Voting menu");
}

void InitMenu() {
    g_mMenu = new Menu(Menu_VoteMenuHandler);
    g_mMenu.SetTitle("Hunters vs ???");
    g_mMenu.AddItem("Pump Shotguns", "Pump Shotgun");
    g_mMenu.AddItem("Chrome Shotguns", "Chrome Shotgun");
    g_mMenu.AddItem("Uzis", "Uzi");
    g_mMenu.AddItem("Silenced Uzis", "Silenced Uzi");
    g_mMenu.AddItem("Scouts", "Scout");
    g_mMenu.AddItem("AWPs", "AWP");
    g_mMenu.AddItem("Grenade Launchers", "Grenade Launcher");
    g_mMenu.AddItem("Deagles", "Deagle");
    g_mMenu.ExitButton = true;
}

void Event_PlayerTeam(Event eEvent, char[] szName , bool bDontBroadcast) {
    // Mode not picked, don't care.
    if (g_iCurrentMode == eUndecided)
        return;

    // Only during Ready-up
    if (!IsInReady())
        return;

    int iTeam = eEvent.GetInt("team");
    // Only care about Survivors (Team 2)
    if (iTeam != 2)
        return;

    int iUserId = eEvent.GetInt("userid");
    CreateTimer(0.1, Timer_ChangeTeamDelay, iUserId, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_ChangeTeamDelay(Handle hTimer, any iUserId) {
    int iClient = GetClientOfUserId(iUserId);
    if (iClient <= 0)
        return Plugin_Stop;

    if (GetClientTeam(iClient) != 2)
        return Plugin_Stop;

    GiveSurvivorsWeapons(iClient, true);
    return Plugin_Stop;
}

void Event_RoundStart(Event eEvent, char[] szName, bool bDontBroadcast) {
    // Let players know they can vote for their mode if the mode is undecided.
    if (g_iCurrentMode == eUndecided) {
        CreateTimer(15.0, Timer_InformPlayers, _, TIMER_REPEAT);
        return;
    }

    // Clear all Weapons on this delayed timer.
    CreateTimer(0.5, Timer_ClearMap, _, TIMER_FLAG_NO_MAPCHANGE);
    // Give decided Weapons on this delayed timer.
    CreateTimer(2.0, Timer_GiveSurvivorsWeapons, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Cmd_VoteMode(int iClient, int iArgs) {
    // Don't care about non-loaded players or Spectators.
    if (iClient <= 0)
        return Plugin_Handled;

    if (GetClientTeam(iClient) == 1)
        return Plugin_Handled;

    if (TM_IsPlayerRespectating(iClient))
        return Plugin_Handled;

    // This player understands what to do.
    g_bVoteUnderstood[iClient] = true;
    // Show the Menu.
    g_mMenu.Display(iClient, MENU_TIME_FOREVER);
    return Plugin_Handled;
}

public int Menu_VoteMenuHandler(Menu mMenu, MenuAction mAction, int iClient, int iIdx) {
    if (mAction == MenuAction_Select) {
        char szVotePrint[64];
        char szVoteTitle[32];
        char szInfo[32];
        if (mMenu.GetItem(iIdx, szInfo, sizeof(szInfo))) {
            Format(szVotePrint, sizeof(szVotePrint), "changing weapons to {olive}%s{default}.", szInfo);
            Format(szVoteTitle, sizeof(szVoteTitle), "Survivors get %s?", szInfo);
            g_SolarisVoteWeaponsLoadout.SetRequiredPlayers(GetMaxPlayers())
                                       .SetPrint(szVotePrint)
                                       .SetTitle(szVoteTitle);
            // start vote
            bool bVoteStarted = g_SolarisVoteWeaponsLoadout.Start(iClient);
            if (bVoteStarted) g_iVotingMode = iIdx + 1;
        }
    }
    return 0;
}

void VoteCallback_WeaponsLoadout() {
    g_iCurrentMode = g_iVotingMode;
    // Clear all Weapons on this delayed timer.
    CreateTimer(0.5, Timer_ClearMap, _, TIMER_FLAG_NO_MAPCHANGE);
    // Give decided Weapons on this delayed timer.
    CreateTimer(2.0, Timer_GiveSurvivorsWeapons, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_ClearMap(Handle hTimer) {
    ClearMap();
    return Plugin_Stop;
}

Action Timer_GiveSurvivorsWeapons(Handle hTimer) {
    GiveSurvivorsWeapons();
    return Plugin_Stop;
}

void ClearMap() {
    // We only clear Chrome Shotguns because we need weaponrules to be loaded for pistols and deagles, so we converted everything to chromes in it. :D
    // After the weaponrules timer, we strike.
    // Surely you can do better than this Sir, get to this when you have time.
    char szEntityName[MAX_ENTITY_NAME_LENGTH];
    int  iOwner = -1;
    int  iEntity = INVALID_ENT_REFERENCE;

    // Converted Weapons
    while ((iEntity = FindEntityByClassname(iEntity, "weapon_*")) != INVALID_ENT_REFERENCE) {
        if (iEntity <= MaxClients)
            continue;

        if (!IsValidEntity(iEntity))
            continue;

        GetEntityClassname(iEntity, szEntityName, sizeof(szEntityName));
        for (int i = 0; i < sizeof(szRemoveWeaponNames); i++) {
            // weapon_ - 7
            if (strcmp(szEntityName[7], szRemoveWeaponNames[i]) == 0) {
                iOwner = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
                if (!IsValidOwner(iOwner))
                    RemoveEntity(iEntity);
                break;
            }
        }
    }
}

void GiveSurvivorsWeapons(int iClient = 0, bool bOnlyIfSurvivorEmpty = false) {
    // Establish what Weapon we're going for and format its name into a String.
    char sWeapon[MAX_ENTITY_NAME_LENGTH];
    strcopy(sWeapon, sizeof(sWeapon), szGiveWeaponNames[g_iCurrentMode]);

    if (strlen(sWeapon) == 0) {
        return;
    }
    // Loop through Clients, clear their current primary weapons (if they have one)
    if (iClient != 0) {
        RemoveAndGivePlayerWeapon(iClient, sWeapon, bOnlyIfSurvivorEmpty);
        return;
    }

    for (int i = 1; i <= MaxClients; i++) {
        RemoveAndGivePlayerWeapon(i, sWeapon, bOnlyIfSurvivorEmpty);
    }
}

void RemoveAndGivePlayerWeapon(int iClient, const char[] szWeaponName, bool bOnlyIfSurvivorEmpty = false) {
    if (!IsClientInGame(iClient))
        return;

    if (GetClientTeam(iClient) != 2)
        return;

    if (!IsPlayerAlive(iClient))
        return;

    int iCurrMainWeapon      = GetPlayerWeaponSlot(iClient, 0);
    int iCurrSecondaryWeapon = GetPlayerWeaponSlot(iClient, 1);

    // Does the player already have an item in this slot?
    if (iCurrMainWeapon != -1) {
        // If we only want to give weapons to empty handed players, don't do anything for this player.
        if (bOnlyIfSurvivorEmpty)
            return;

        // Remove current Weapon.
        RemovePlayerItem(iClient, iCurrMainWeapon);
    }

    // Remove current Weapon.
    if (iCurrSecondaryWeapon != -1)
        RemovePlayerItem(iClient, iCurrSecondaryWeapon);
    GivePlayerItem(iClient, szWeaponName);
}

Action Timer_InformPlayers(Handle hTimer) {
    static int iNumPrinted = 0;
    // Don't annoy the players, remind them a maximum of 6 times.
    if (iNumPrinted >= 6 || g_iCurrentMode != eUndecided) {
        iNumPrinted = 0;
        return Plugin_Stop;
    }

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (GetClientTeam(i) == 1)
            continue;

        if (TM_IsPlayerRespectating(i))
            continue;

        if (g_bVoteUnderstood[i])
            continue;

        CPrintToChat(i, "{blue}[{green}Zone{blue}]{default}: Welcome to {blue}Zone{green}Hunters{default}.");
        CPrintToChat(i, "{blue}[{green}Zone{blue}]{default}: Type {olive}!mode {default}in chat to vote on weapons used.");
    }

    iNumPrinted++;
    return Plugin_Continue;
}

int GetMaxPlayers() {
    return FindConVar("survivor_limit").IntValue + FindConVar("z_max_player_zombies").IntValue;
}

bool IsValidOwner(int iClient) {
    return (iClient > 0 && IsClientInGame(iClient));
}