/**
 * HLstatsX Community Edition - SourceMod plugin to generate advanced weapon logging
 * http://www.hlxcommunity.com
 * Copyright (C) 2009 Nicholas Hastings (psychonic)
 * Copyright (C) 2007-2008 TTS Oetzel & Goerz GmbH
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <solaris/chat>

#undef REQUIRE_PLUGIN
#include <confogl>
#define REQUIRE_PLUGIN

#define MAX_LOG_WEAPONS 27
#define MAX_WEAPON_LEN  16

char g_szWeaponList[][] = {
    "autoshotgun",
    "rifle",
    "pumpshotgun",
    "smg",
    "dual_pistols",
    "pipe_bomb",
    "hunting_rifle",
    "pistol",
    "prop_minigun",
    "tank_claw",
    "hunter_claw",
    "smoker_claw",
    "boomer_claw",
    "smg_silenced",     // l4d2 start 14 [13]
    "pistol_magnum",
    "rifle_ak47",
    "rifle_desert",
    "shotgun_chrome",
    "shotgun_spas",
    "sniper_military",
    "rifle_sg552",
    "smg_mp5",
    "sniper_awp",
    "sniper_scout",
    "jockey_claw",
    "splitter_claw",
    "charger_claw"
};

ConVar g_cvWStats;
ConVar g_cvActions;
ConVar g_cvHeadShots;
ConVar g_cvMeleeOverride;
ConVar g_cvGameMode;
ConVar g_cvCfgName;

int  g_iWeaponStats[MAXPLAYERS + 1][MAX_LOG_WEAPONS][15];
int  g_iActiveWeaponOffset;

bool g_bLogWStats        = true;
bool g_bLogActions       = true;
bool g_bLogHeadshots     = false;
bool g_bLogMeleeOverride = true;
bool g_bMatchModeLoaded  = false;

char g_szGameMode[32] = "coop";
char g_sCfgName  [64] = "<none>";

#include "modules/loghelper.sp"
#include "modules/wstatshelper.sp"

public Plugin myinfo = {
    name        = "SuperLogs: L4D",
    author      = "psychonic",
    description = "Advanced logging for Left 4 Dead. Generates auxilary logging for use with log parsers such as HLstatsX and Psychostats",
    version     = "1.3.4",
    url         = "http://www.hlxcommunity.com"
};

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    EngineVersion evGame = GetEngineVersion();
    if (evGame != Engine_Left4Dead2 && evGame != Engine_Left4Dead) {
        strcopy(szError, iErrMax, "Plugin only supports Left 4 Dead 1/2");
        return APLRes_SilentFailure;
    }
    return APLRes_Success;
}

public void OnPluginStart() {
    CreatePopulateWeaponTrie();

    g_cvWStats = CreateConVar(
    "superlogs_wstats", "1", "Enable logging of weapon stats (default on)",
    0, true, 0.0, true, 1.0);
    g_cvWStats.AddChangeHook(OnCvarWstatsChange);

    g_cvActions = CreateConVar(
    "superlogs_actions", "1", "Enable logging of player actions, such as \"Got_The_Bomb\" (default on)",
    0, true, 0.0, true, 1.0);
    g_cvActions.AddChangeHook(OnCvarActionsChange);

    g_cvHeadShots = CreateConVar(
    "superlogs_headshots", "0", "Enable logging of headshot player action (default off)",
    0, true, 0.0, true, 1.0);
    g_cvHeadShots.AddChangeHook(OnCvarHeadshotsChange);

    g_cvMeleeOverride = CreateConVar(
    "superlogs_meleeoverride", "1", "Enable changing \"melee\" weapon in server logs to specific weapon (L4D2-only) (default on)",
    0, true, 0.0, true, 1.0);
    g_cvMeleeOverride.AddChangeHook(OnCvarMeleeOverrideChange);

    HookActions();
    HookWStats();
    HookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
    CreateTimer(120.0, FlushWeaponLogs, 0, TIMER_REPEAT);
    GetTeams();
    g_iActiveWeaponOffset = FindSendPropInfo("CTerrorPlayer", "m_hActiveWeapon");

    /* - - - - -
       GameMode
       - - - - - */
    g_cvGameMode = FindConVar("mp_gamemode");
    g_cvGameMode.AddChangeHook(OnCvarMpGameModeChange);
    LogGameMode(g_szGameMode);
    CreateTimer(1.0, Timer_LogMapAndGameMode);
}

public void OnAllPluginsLoaded() {
    /* - - - - -
       MatchMode
       - - - - - */
    if (g_cvCfgName == null) g_cvCfgName = FindConVar("l4d_ready_cfg_name");
    if (g_bMatchModeLoaded)  g_cvCfgName.GetString(g_sCfgName, sizeof(g_sCfgName));
    else                     strcopy(g_sCfgName, sizeof(g_sCfgName), "<none>");
    LogMatchConfig(g_sCfgName);
}

public void OnConfigsExecuted() {
    /* - - - - -
       GameMode
       - - - - - */
    g_cvGameMode.GetString(g_szGameMode, sizeof(g_szGameMode));
    LogGameMode(g_szGameMode);

    /* - - - - -
       MatchMode
       - - - - - */
    if (g_cvCfgName == null) g_cvCfgName = FindConVar("l4d_ready_cfg_name");
    if (g_bMatchModeLoaded)  g_cvCfgName.GetString(g_sCfgName, sizeof(g_sCfgName));
    else                     strcopy(g_sCfgName, sizeof(g_sCfgName), "<none>");
    LogMatchConfig(g_sCfgName);
}

public void OnMapStart() {
    GetTeams();
}

void HookActions() {
    HookEvent("survivor_rescued",        Event_RescueSurvivor);
    HookEvent("heal_success",            Event_Heal);
    HookEvent("revive_success",          Event_Revive);
    HookEvent("witch_harasser_set",      Event_StartleWitch);
    HookEvent("lunge_pounce",            Event_Pounce);
    HookEvent("player_now_it",           Event_Boomered);
    HookEvent("friendly_fire",           Event_FF);
    HookEvent("witch_killed",            Event_WitchKilled);
    HookEvent("award_earned",            Event_Award);
    HookEvent("defibrillator_used",      Event_Defib);
    HookEvent("adrenaline_used",         Event_Adrenaline);
    HookEvent("jockey_ride",             Event_JockeyRide);
    HookEvent("charger_pummel_start",    Event_ChargerPummelStart);
    HookEvent("vomit_bomb_tank",         Event_VomitBombTank);
    HookEvent("scavenge_match_finished", Event_ScavengeEnd);
    HookEvent("versus_match_finished",   Event_VersusEnd);
}

void UnhookActions() {
    UnhookEvent("survivor_rescued",        Event_RescueSurvivor);
    UnhookEvent("heal_success",            Event_Heal);
    UnhookEvent("revive_success",          Event_Revive);
    UnhookEvent("witch_harasser_set",      Event_StartleWitch);
    UnhookEvent("lunge_pounce",            Event_Pounce);
    UnhookEvent("player_now_it",           Event_Boomered);
    UnhookEvent("friendly_fire",           Event_FF);
    UnhookEvent("witch_killed",            Event_WitchKilled);
    UnhookEvent("award_earned",            Event_Award);
    UnhookEvent("defibrillator_used",      Event_Defib);
    UnhookEvent("adrenaline_used",         Event_Adrenaline);
    UnhookEvent("jockey_ride",             Event_JockeyRide);
    UnhookEvent("charger_pummel_start",    Event_ChargerPummelStart);
    UnhookEvent("vomit_bomb_tank",         Event_VomitBombTank);
    UnhookEvent("scavenge_match_finished", Event_ScavengeEnd);
    UnhookEvent("versus_match_finished",   Event_VersusEnd);
}

void HookWStats() {
    HookEvent("weapon_fire",          Event_PlayerShoot);
    HookEvent("weapon_fire_on_empty", Event_PlayerShoot);
    HookEvent("player_hurt",          Event_PlayerHurt);
    HookEvent("infected_hurt",        Event_InfectedHurt);
    HookEvent("player_death",         Event_PlayerDeath);
    HookEvent("player_spawn",         Event_PlayerSpawn);
    HookEvent("round_end_message",    Event_RoundEnd,         EventHookMode_PostNoCopy);
    HookEvent("player_disconnect",    Event_PlayerDisconnect, EventHookMode_Pre);
}

void UnhookWStats() {
    UnhookEvent("weapon_fire",          Event_PlayerShoot);
    UnhookEvent("weapon_fire_on_empty", Event_PlayerShoot);
    UnhookEvent("player_hurt",          Event_PlayerHurt);
    UnhookEvent("infected_hurt",        Event_InfectedHurt);
    UnhookEvent("player_death",         Event_PlayerDeath);
    UnhookEvent("player_spawn",         Event_PlayerSpawn);
    UnhookEvent("round_end_message",    Event_RoundEnd,         EventHookMode_PostNoCopy);
    UnhookEvent("player_disconnect",    Event_PlayerDisconnect, EventHookMode_Pre);
}

public void OnClientPutInServer(int iClient) {
    ResetPlayerStats(iClient);
}

Action FlushWeaponLogs(Handle hTimer) {
    WstatsDumpAll();
    return Plugin_Continue;
}

public void SolarisChat_OnChatMessagePost(const int iClient, const int iArgs, const int iTeam, const bool bTeamChat, const ArrayList aRecipients, const char[] szTagColor, const char[] szTag, const char[] szNameColor, const char[] szName, const char[] szMsgColor, const char[] szMsg) {
    LogPlayerEvent(iClient, bTeamChat ? "say_team" : "say", szMsg, false);
}

void Event_PlayerShoot(Event eEvent, const char[] szName, bool bDontBroadcast) {
    // "local"         "1"             // don't network this, its way too spammy
    // "userid"        "short"
    // "weapon"        "string"        // used weapon name
    // "weaponid"      "short"         // used weapon ID
    // "count"         "short"         // number of bullets
    int iAttacker = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iAttacker > 0) {
        char szWeapon[MAX_WEAPON_LEN];
        eEvent.GetString("weapon", szWeapon, sizeof(szWeapon));
        int iWeaponIndex = GetWeaponIndex(szWeapon);
        if (iWeaponIndex > -1) g_iWeaponStats[iAttacker][iWeaponIndex][LOG_HIT_SHOTS]++;
    }
}

void Event_PlayerHurt(Event eEvent, const char[] szName, bool bDontBroadcast) {
    // "local"         "1"             // Not networked
    // "userid"        "short"         // user ID who was hurt
    // "attacker"      "short"         // user id who attacked
    // "attackerentid" "long"          // entity id who attacked, if attacker not a player, and userid therefore invalid
    // "health"        "short"         // remaining health points
    // "armor"         "byte"          // remaining armor points
    // "weapon"        "string"        // weapon name attacker used, if not the world
    // "dmg_health"    "short"         // damage done to health
    // "dmg_armor"     "byte"          // damage done to armor
    // "hitgroup"      "byte"          // hitgroup that was damaged
    // "type"          "long"          // damage type
    int iAttacker  = GetClientOfUserId(eEvent.GetInt("attacker"));
    if (iAttacker > 0) {
        char szWeapon[MAX_WEAPON_LEN];
        eEvent.GetString("weapon", szWeapon, sizeof(szWeapon));
        int iWeaponIndex = GetWeaponIndex(szWeapon);
        if (iWeaponIndex > -1) {
            g_iWeaponStats[iAttacker][iWeaponIndex][LOG_HIT_HITS]++;
            g_iWeaponStats[iAttacker][iWeaponIndex][LOG_HIT_DAMAGE] += eEvent.GetInt("dmg_health");
            int iHitGroup  = eEvent.GetInt("hitgroup");
            if (iHitGroup < 8) g_iWeaponStats[iAttacker][iWeaponIndex][iHitGroup + LOG_HIT_OFFSET]++;
        } else if (g_bLogActions && !strcmp(szWeapon, "insect_swarm")) {
            int iVictim = GetClientOfUserId(eEvent.GetInt("userid"));
            if (iVictim > 0 && IsClientInGame(iVictim) && GetClientTeam(iVictim) == 2 &&  !GetEntProp(iVictim, Prop_Send, "m_isIncapacitated"))
                LogPlayerToPlayerEvent(iAttacker, iVictim, "triggered", "spit_hurt", true);
        }
    }
}

void Event_InfectedHurt(Event eEvent, const char[] szName, bool bDontBroadcast) {
    // "local"         "1"             // don't network this, its way too spammy
    // "attacker"      "short"         // player userid who attacked
    // "entityid"      "long"          // entity id of infected
    // "hitgroup"      "byte"          // hitgroup that was damaged
    // "amount"        "short"         // how much damage was done
    // "type"          "long"          // damage type
    int iAttacker  = GetClientOfUserId(eEvent.GetInt("attacker"));
    if (iAttacker > 0 && IsClientInGame(iAttacker)) {
        char szWeapon[MAX_WEAPON_LEN];
        GetClientWeapon(iAttacker, szWeapon, sizeof(szWeapon));
        int iWeaponIndex = GetWeaponIndex(szWeapon[7]);
        if (iWeaponIndex > -1) {
            g_iWeaponStats[iAttacker][iWeaponIndex][LOG_HIT_HITS]++;
            g_iWeaponStats[iAttacker][iWeaponIndex][LOG_HIT_DAMAGE] += eEvent.GetInt("amount");
            int iHitGroup  = eEvent.GetInt("hitgroup");
            if (iHitGroup < 8) {
                g_iWeaponStats[iAttacker][iWeaponIndex][iHitGroup + LOG_HIT_OFFSET]++;
            }
        }
    }
}

void Event_PlayerDeathPre(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iAttacker = GetClientOfUserId(eEvent.GetInt("attacker"));
    if (g_bLogHeadshots && eEvent.GetBool("headshot")) {
        LogPlayerEvent(iAttacker, "triggered", "headshot");
    }
    if (g_bLogMeleeOverride && iAttacker > 0 && IsClientInGame(iAttacker)) {
        char szWeapon[64];
        eEvent.GetString("weapon", szWeapon, sizeof(szWeapon));
        if (strncmp(szWeapon, "melee", 5) == 0) {
            int iWeapon = GetEntDataEnt2(iAttacker, g_iActiveWeaponOffset);
            if (IsValidEdict(iWeapon)) {
                // They have time to switch weapons after the kill before the death event
                GetEdictClassname(iWeapon, szWeapon, sizeof(szWeapon));
                if (strncmp(szWeapon[7], "melee", 5) == 0) {
                    GetEntPropString(iWeapon, Prop_Data, "m_strMapSetScriptName", szWeapon, sizeof(szWeapon));
                    eEvent.SetString("weapon", szWeapon);
                }
            }
        }
    }
}

void Event_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast) {
    // "userid"        "short"         // user ID who died
    // "entityid"      "long"          // entity ID who died, userid should be used first, to get the dead Player.  Otherwise, it is not a player, so use this.         $
    // "attacker"      "short"         // user ID who killed
    // "attackername"  "string"        // What type of zombie, so we don't have zombie names
    // "attackerentid" "long"          // if killer not a player, the entindex of who killed.  Again, use attacker first
    // "weapon"        "string"        // weapon name killer used
    // "headshot"      "bool"          // signals a headshot
    // "attackerisbot" "bool"          // is the attacker a bot
    // "victimname"    "string"        // What type of zombie, so we don't have zombie names
    // "victimisbot"   "bool"          // is the victim a bot
    // "abort"         "bool"          // did the victim abort
    // "type"          "long"          // damage type
    // "victim_x"      "float"
    // "victim_y"      "float"
    // "victim_z"      "float"
    int iVictim   = GetClientOfUserId(eEvent.GetInt("userid"));
    int iAttacker = GetClientOfUserId(eEvent.GetInt("attacker"));
    if (g_bLogWStats && iVictim > 0 && iAttacker > 0 && IsClientInGame(iAttacker) && IsClientInGame(iVictim)) {
        char szWeapon[MAX_WEAPON_LEN];
        eEvent.GetString("weapon", szWeapon, sizeof(szWeapon));
        int iWeaponIndex = GetWeaponIndex(szWeapon);
        if (iWeaponIndex > -1) {
            g_iWeaponStats[iAttacker][iWeaponIndex][LOG_HIT_KILLS]++;
            if (eEvent.GetBool("headshot")) {
                g_iWeaponStats[iAttacker][iWeaponIndex][LOG_HIT_HEADSHOTS]++;
            }
            g_iWeaponStats[iVictim][iWeaponIndex][LOG_HIT_DEATHS]++;
            if (GetClientTeam(iAttacker) == GetClientTeam(iVictim)) {
                g_iWeaponStats[iAttacker][iWeaponIndex][LOG_HIT_TEAMKILLS]++;
            }
            DumpPlayerStats(iVictim);
        }
    }
}

void Event_RoundEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    WstatsDumpAll();
}

void Event_PlayerSpawn(Event eEvent, const char[] szName, bool bDontBroadcast) {
    // "userid"        "short"         // user ID on server
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient > 0) ResetPlayerStats(iClient);
}

void Event_PlayerDisconnect(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    OnPlayerDisconnect(iClient);
}

Action Timer_LogMapAndGameMode(Handle hTimer) {
    // Called 1 second after OnPluginStart since srcds does not log the first map loaded. Idea from Stormtrooper's "mapfix.sp" for psychostats
    LogMapLoad();
    LogGameMode(g_szGameMode);
    return Plugin_Continue;
}

void Event_RescueSurvivor(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iPlayer = GetClientOfUserId(eEvent.GetInt("rescuer"));
    if (iPlayer > 0) LogPlayerEvent(iPlayer, "triggered", "rescued_survivor", true);
}

void Event_Heal(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iPlayer = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iPlayer <= 0) return;
    if (iPlayer == GetClientOfUserId(eEvent.GetInt("subject"))) return;
    LogPlayerEvent(iPlayer, "triggered", "healed_teammate", true);
}

void Event_Revive(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iPlayer = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iPlayer > 0) LogPlayerEvent(iPlayer, "triggered", "revived_teammate", true);
}

void Event_StartleWitch(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iPlayer = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iPlayer > 0 && eEvent.GetBool("first")) LogPlayerEvent(iPlayer, "triggered", "startled_witch", true);
}

void Event_Pounce(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iPlayer = GetClientOfUserId(eEvent.GetInt("userid"));
    int iVictim = GetClientOfUserId(eEvent.GetInt("victim"));
    if (iVictim > 0) LogPlayerToPlayerEvent(iPlayer, iVictim, "triggered", "pounce", true);
    else             LogPlayerEvent(iPlayer, "triggered", "pounce", true);
}

void Event_Boomered(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iPlayer = GetClientOfUserId(eEvent.GetInt("attacker"));
    int iVictim = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iPlayer > 0 && eEvent.GetBool("by_boomer")) {
        if (iVictim > 0) LogPlayerToPlayerEvent(iPlayer, iVictim, "triggered", "vomit", true);
        else             LogPlayerEvent(iPlayer, "triggered", "vomit", true);
    }
}

void Event_FF(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iPlayer = GetClientOfUserId(eEvent.GetInt("attacker"));
    int iVictim = GetClientOfUserId(eEvent.GetInt("victim"));
    if (iPlayer > 0 && iPlayer == GetClientOfUserId(eEvent.GetInt("guilty"))) {
        if (iVictim > 0) LogPlayerToPlayerEvent(iPlayer, iVictim, "triggered", "friendly_fire", true);
        else             LogPlayerEvent(iPlayer, "triggered", "friendly_fire", true);
    }
}

void Event_WitchKilled(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (eEvent.GetBool("oneshot")) LogPlayerEvent(GetClientOfUserId(eEvent.GetInt("userid")), "triggered", "cr0wned", true);
}

void Event_Defib(Event eEvent, const char[] szName, bool bDontBroadcast) {
    LogPlayerEvent(GetClientOfUserId(eEvent.GetInt("userid")), "triggered", "defibrillated_teammate", true);
}

void Event_Adrenaline(Event eEvent, const char[] szName, bool bDontBroadcast) {
    LogPlayerEvent(GetClientOfUserId(eEvent.GetInt("userid")), "triggered", "used_adrenaline", true);
}

void Event_JockeyRide(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iPlayer = GetClientOfUserId(eEvent.GetInt("userid"));
    int iVictim = GetClientOfUserId(eEvent.GetInt("victim"));
    if (iPlayer > 0) {
        if (iVictim > 0) LogPlayerToPlayerEvent(iPlayer, iVictim, "triggered", "jockey_ride", true);
        else             LogPlayerEvent(iPlayer, "triggered", "jockey_ride", true);
    }
}

void Event_ChargerPummelStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iPlayer = GetClientOfUserId(eEvent.GetInt("userid"));
    int iVictim = GetClientOfUserId(eEvent.GetInt("victim"));
    if (iVictim > 0) LogPlayerToPlayerEvent(iPlayer, iVictim, "triggered", "charger_pummel", true);
    else             LogPlayerEvent(iPlayer, "triggered", "charger_pummel", true);
}

void Event_VomitBombTank(Event eEvent, const char[] szName, bool bDontBroadcast) {
    LogPlayerEvent(GetClientOfUserId(eEvent.GetInt("userid")), "triggered", "bilebomb_tank", true);
}

void Event_ScavengeEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    LogTeamEvent(eEvent.GetInt("winners"), "triggered", "Scavenge_Win");
}

void Event_VersusEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    LogTeamEvent(eEvent.GetInt("winners"), "triggered", "Versus_Win");
}

void Event_Award(Event eEvent, const char[] szName, bool bDontBroadcast) {
    // "userid"         "short"         // player who earned the award
    // "entityid"       "long"          // client likes ent id
    // "subjectentid"   "long"          // entity id of other party in the award, if any
    // "award"          "short"         // id of award earned
    switch (eEvent.GetInt("award")) {
        case 21  : LogPlayerEvent(GetClientOfUserId(eEvent.GetInt("userid")), "triggered", "hunter_punter",        true);
        case 27  : LogPlayerEvent(GetClientOfUserId(eEvent.GetInt("userid")), "triggered", "tounge_twister",       true);
        case 67  : LogPlayerEvent(GetClientOfUserId(eEvent.GetInt("userid")), "triggered", "protect_teammate",     true);
        case 80  : LogPlayerEvent(GetClientOfUserId(eEvent.GetInt("userid")), "triggered", "no_death_on_tank",     true);
        case 136 : LogPlayerEvent(GetClientOfUserId(eEvent.GetInt("userid")), "triggered", "killed_all_survivors", true);
    }
}

void OnCvarMpGameModeChange(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    if (StrEqual(szOldVal, szNewVal)) return;
    g_cvGameMode.GetString(g_szGameMode, sizeof(g_szGameMode));
    LogGameMode(g_szGameMode);
}

void OnCvarWstatsChange(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    bool bOldValue = g_bLogWStats;
    g_bLogWStats   = g_cvWStats.BoolValue;
    if (bOldValue != g_bLogWStats) {
        if (g_bLogWStats) HookWStats();
        else              UnhookWStats();
    }
}

void OnCvarActionsChange(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    bool bOldValue = g_bLogActions;
    g_bLogActions  = g_cvActions.BoolValue;
    if (bOldValue != g_bLogActions) {
        if (g_bLogActions) HookActions();
        else               UnhookActions();
    }
}

void OnCvarHeadshotsChange(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    bool bOldValue = g_bLogHeadshots;
    g_bLogHeadshots = g_cvHeadShots.BoolValue;
    if (bOldValue != g_bLogHeadshots) {
        if (g_bLogHeadshots && !g_bLogMeleeOverride) {
            HookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
        } else if (!g_bLogMeleeOverride) {
            UnhookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
        }
    }
}

void OnCvarMeleeOverrideChange(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    bool bOldValue = g_bLogMeleeOverride;
    g_bLogMeleeOverride = g_cvMeleeOverride.BoolValue;
    if (bOldValue != g_bLogMeleeOverride) {
        if (g_bLogMeleeOverride && !g_bLogHeadshots) {
            HookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
        } else if (!g_bLogHeadshots) {
            UnhookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
        }
    }
}

public void LGO_OnMatchModeLoaded() {
    g_bMatchModeLoaded = true;
    if (g_cvCfgName == null) g_cvCfgName = FindConVar("l4d_ready_cfg_name");
    g_cvCfgName.GetString(g_sCfgName, sizeof(g_sCfgName));
    LogMatchConfig(g_sCfgName);
}

public void LGO_OnMatchModeUnloaded() {
    g_bMatchModeLoaded = false;
    strcopy(g_sCfgName, sizeof(g_sCfgName), "<none>");
    LogMatchConfig(g_sCfgName);
}