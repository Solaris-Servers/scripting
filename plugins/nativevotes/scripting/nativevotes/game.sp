/**
 * vim: set ts=4 :
 * =============================================================================
 * NativeVotes
 * NativeVotes is a voting API plugin for L4D, L4D2
 * Based on the SourceMod voting API
 *
 * NativeVotes (C) 2011-2014 Ross Bemrose (Powerlord). All rights reserved.
 * SourceMod (C)2004-2008 AlliedModders LLC.  All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */
#if defined _nativevotes_game_included
    #endinput
#endif

#define _nativevotes_game_included

#include <sourcemod>
#include <solaris/stocks>

#define L4DL4D2_COUNT 2

#define INVALID_ISSUE -1

//----------------------------------------------------------------------------
// Translation strings

//----------------------------------------------------------------------------
// L4D/L4D2

#define L4DL4D2_VOTE_YES_STRING "Yes"
#define L4DL4D2_VOTE_NO_STRING  "No"

#define L4D_VOTE_KICK_START  "#L4D_vote_kick_player"
#define L4D_VOTE_KICK_PASSED "#L4D_vote_passed_kick_player"

// User vote to restart map.
#define L4D_VOTE_RESTART_GAME_START     "#L4D_vote_restart_game"
#define L4D_VOTE_RESTART_GAME_PASSED    "#L4D_vote_passed_restart_game"
#define L4D_VOTE_RESTART_CHAPTER_START  "#L4D_vote_restart_chapter"
#define L4D_VOTE_RESTART_CHAPTER_PASSED "#L4D_vote_passed_restart_chapter"
#define L4D_VOTE_RESTART_VERSUS_START   "#L4D_vote_versus_level_restart"
#define L4D_VOTE_RESTART_VERSUS_PASSED  "#L4D_vote_passed_versus_level_restart"

// User vote to change maps.
#define L4D_VOTE_CHANGECAMPAIGN_START  "#L4D_vote_mission_change"
#define L4D_VOTE_CHANGECAMPAIGN_PASSED "#L4D_vote_passed_mission_change"
#define L4D_VOTE_CHANGELEVEL_START     "#L4D_vote_chapter_change"
#define L4D_VOTE_CHANGELEVEL_PASSED    "#L4D_vote_passed_chapter_change"

// User vote to return to lobby.
#define L4D_VOTE_RETURNTOLOBBY_START  "#L4D_vote_return_to_lobby"
#define L4D_VOTE_RETURNTOLOBBY_PASSED "#L4D_vote_passed_return_to_lobby"

// User vote to change difficulty.
#define L4D_VOTE_CHANGEDIFFICULTY_START  "#L4D_vote_change_difficulty"
#define L4D_VOTE_CHANGEDIFFICULTY_PASSED "#L4D_vote_passed_change_difficulty"

// While not a vote string, it works just as well.
#define L4D_VOTE_CUSTOM "#L4D_TargetID_Player"

//----------------------------------------------------------------------------
// L4D2

// User vote to change alltalk.
#define L4D2_VOTE_ALLTALK_START   "#L4D_vote_alltalk_change"
#define L4D2_VOTE_ALLTALK_PASSED  "#L4D_vote_passed_alltalk_change"
#define L4D2_VOTE_ALLTALK_ENABLE  "#L4D_vote_alltalk_enable"
#define L4D2_VOTE_ALLTALK_DISABLE "#L4D_vote_alltalk_disable"

// TF2 (and SDK2013?) VoteFail / CallVoteFail reasons
enum {
    VOTE_FAILED_GENERIC,
    VOTE_FAILED_TRANSITIONING_PLAYERS,
    VOTE_FAILED_RATE_EXCEEDED,
    VOTE_FAILED_YES_MUST_EXCEED_NO,
    VOTE_FAILED_QUORUM_FAILURE,
    VOTE_FAILED_ISSUE_DISABLED,
    VOTE_FAILED_MAP_NOT_FOUND,
    VOTE_FAILED_MAP_NAME_REQUIRED,
    VOTE_FAILED_FAILED_RECENTLY,
    VOTE_FAILED_TEAM_CANT_CALL,
    VOTE_FAILED_WAITINGFORPLAYERS,
    VOTE_FAILED_PLAYERNOTFOUND,
    VOTE_FAILED_CANNOT_KICK_ADMIN,
    VOTE_FAILED_SCRAMBLE_IN_PROGRESS,
    VOTE_FAILED_SPECTATOR,
    VOTE_FAILED_NEXTLEVEL_SET,
    VOTE_FAILED_MAP_NOT_VALID,
    VOTE_FAILED_CANNOT_KICK_FOR_TIME,
    VOTE_FAILED_CANNOT_KICK_DURING_ROUND,
    VOTE_FAILED_MODIFICATION_ALREADY_ACTIVE
}


//----------------------------------------------------------------------------
// Generic functions
//

// This is deprecated in NativeVotes 1.1
enum {
    ValveVote_Kick = 0,
    ValveVote_Restart = 1,
    ValveVote_ChangeLevel = 2,
    ValveVote_NextLevel = 3,
    ValveVote_Scramble = 4,
    ValveVote_SwapTeams = 5
}

static int g_VoteController = -1;

bool Game_IsGameSupported(char[] engineName="", int maxlength=0) {
    g_EngineVersion = GetEngineVersion();
    //LogMessage("Detected Engine version: %d", g_EngineVersion);
    if (maxlength > 0) {
        GetEngineVersionName(g_EngineVersion, engineName, maxlength);
    }

    switch (g_EngineVersion) {
        case Engine_Left4Dead, Engine_Left4Dead2: {
            return true;
        }
    }
    return false;
}

void Game_InitializeCvars() {
}

NativeVotesKickType Game_GetKickType(const char[] param1, int &target) {
    NativeVotesKickType kickType;
    switch(g_EngineVersion) {
        case Engine_Left4Dead, Engine_Left4Dead2: {
            target   = StringToInt(param1);
            kickType = NativeVotesKickType_Generic;
        }
    }
    return kickType;
}

bool CheckVoteController() {
    int entity = INVALID_ENT_REFERENCE;
    if (g_VoteController != -1) {
        entity = EntRefToEntIndex(g_VoteController);
    }
    if (entity == INVALID_ENT_REFERENCE) {
        entity = FindEntityByClassname(-1, "vote_controller");
        if (entity == -1) {
            //LogError("Could not find Vote Controller.");
            return false;
        }
        g_VoteController = EntIndexToEntRef(entity);
    }
    return true;
}

// All logic for choosing a game-specific function should happen here.
// There should be one per function in the game shared and specific sections
int Game_ParseVote(const char[] option) {
    int item = NATIVEVOTES_VOTE_INVALID;
    switch(g_EngineVersion) {
        case Engine_Left4Dead, Engine_Left4Dead2: {
            item = L4DL4D2_ParseVote(option);
        }
    }
    return item;
}

int Game_GetMaxItems() {
    return L4DL4D2_COUNT;
}

bool Game_CheckVoteType(NativeVotesType type) {
    bool returnVal = false;
    switch(g_EngineVersion) {
        case Engine_Left4Dead: {
            returnVal = L4D_CheckVoteType(type);
        }
        case Engine_Left4Dead2: {
            returnVal = L4D2_CheckVoteType(type);
        }
    }
    return returnVal;
}

bool Game_CheckVotePassType(NativeVotesPassType type) {
    bool returnVal = false;
    switch(g_EngineVersion) {
        case Engine_Left4Dead: {
            returnVal = L4D_CheckVotePassType(type);
        }
        case Engine_Left4Dead2: {
            returnVal = L4D2_CheckVotePassType(type);
        }
    }
    return returnVal;
}

bool Game_DisplayVoteToOne(NativeVote vote, int client) {
    if (g_bCancelled) {
        return false;
    }
    int clients[1];
    clients[0] = client;
    return Game_DisplayVote(vote, clients, 1);
}

bool Game_DisplayVote(NativeVote vote, int[] clients, int num_clients) {
    if (g_bCancelled) {
        return false;
    }
    switch(g_EngineVersion) {
        case Engine_Left4Dead: {
            L4D_DisplayVote(vote, num_clients);
        }
        case Engine_Left4Dead2: {
            L4D2_DisplayVote(vote, clients, num_clients);
        }
    }


    #if defined LOG
        char details[MAX_VOTE_DETAILS_LENGTH];
        char translation[TRANSLATION_LENGTH];
        NativeVotesType voteType = Data_GetType(vote);
        Data_GetDetails(vote, details, sizeof(details));
        Game_VoteTypeToTranslation(voteType, translation, sizeof(translation));
        LogMessage("Displaying vote: type: %d, translation: \"%s\", details: \"%s\"", voteType, translation, details);
    #endif

    return true;
}

void Game_DisplayVoteFail(NativeVote vote) {
    int team = Data_GetTeam(vote);
    int total = 0;
    int[] players = new int[MaxClients];
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i) || IsFakeClient(i))
            continue;
        players[total++] = i;
    }
    Game_DisplayRawVoteFail(players, total, team);
}

void Game_DisplayRawVoteFail(int[] clients, int numClients, int team) {
    switch(g_EngineVersion) {
        case Engine_Left4Dead: {
            L4D_VoteFail(team);
        }
        case Engine_Left4Dead2: {
            L4D2_VoteFail(clients, numClients, team);
        }
    }
    #if defined LOG
        LogMessage("Vote Failed to %d client(s): \"%d\"", numClients, reason);
    #endif
}

void Game_DisplayVotePass(NativeVote vote, const char[] details="", int client=0) {
    NativeVotesPassType passType = VoteTypeToVotePass(Data_GetType(vote));
    Game_DisplayVotePassEx(vote, passType, details, client);
}

void Game_DisplayVotePassEx(NativeVote vote, NativeVotesPassType passType, const char[] details="", int client=0) {
    int team = Data_GetTeam(vote);
    Game_DisplayRawVotePass(passType, team, client, details);
}

void Game_DisplayRawVotePass(NativeVotesPassType passType, int team, int client=0, const char[] details="") {
    char translation[TRANSLATION_LENGTH];
    switch (g_EngineVersion) {
        case Engine_Left4Dead: {
            if (!client) {
                L4DL4D2_VotePassToTranslation(passType, translation, sizeof(translation));
                L4D_VotePass(translation, details, team);
            }
        }
        case Engine_Left4Dead2: {
            L4DL4D2_VotePassToTranslation(passType, translation, sizeof(translation));
            switch (passType) {
                case NativeVotesPass_AlltalkOn: {
                    L4D2_VotePass(translation, L4D2_VOTE_ALLTALK_ENABLE, team, client);
                }
                case NativeVotesPass_AlltalkOff: {
                    L4D2_VotePass(translation, L4D2_VOTE_ALLTALK_DISABLE, team, client);
                }
                default: {
                    L4D2_VotePass(translation, details, team, client);
                }
            }
        }
    }

    #if defined LOG
        if (client != 0)
            LogMessage("Vote Passed: \"%s\", \"%s\"", translation, details);
    #endif
}

void Game_DisplayVotePassCustom(NativeVote vote, const char[] translation, int client) {
    int team = Data_GetTeam(vote);
    Game_DisplayRawVotePassCustom(translation, team, client);
}

void Game_DisplayRawVotePassCustom(const char[] translation, int team, int client) {
    switch (g_EngineVersion)
    {
        case Engine_Left4Dead: {
            ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes_DisplayPassCustom is not supported on L4D");
        }
        case Engine_Left4Dead2: {
            L4D2_VotePass(L4D_VOTE_CUSTOM, translation, team, client);
        }
    }

    #if defined LOG
        if (client != 0)
            LogMessage("Vote Passed Custom: \"%s\"", translation);
    #endif
}

void Game_DisplayCallVoteFail(int client, NativeVotesCallFailType reason) {
    int reasonType = VoteCallFailTypeToInt(reason);
    switch (g_EngineVersion) {
        case Engine_Left4Dead, Engine_Left4Dead2: {
            L4DL4D2_CallVoteFail(client, reasonType);
        }
    }

    #if defined LOG
        LogMessage("Call vote failed: client: %N, reason: %d", client, reason);
    #endif
}

void Game_ClientSelectedItem(int client, int item) {
    switch(g_EngineVersion) {
        case Engine_Left4Dead, Engine_Left4Dead2: {
            L4DL4D2_ClientSelectedItem(client, item);
        }
    }
}

void Game_UpdateVoteCounts(ArrayList hVoteCounts, int totalClients) {
    switch(g_EngineVersion) {
        case Engine_Left4Dead, Engine_Left4Dead2: {
            L4DL4D2_UpdateVoteCounts(hVoteCounts, totalClients);
        }
    }
}

// stock because at the moment it's only used in logging code which isn't always compiled.
stock void Game_VoteTypeToTranslation(NativeVotesType voteType, char[] translation, int maxlength) {
    switch(g_EngineVersion) {
        case Engine_Left4Dead, Engine_Left4Dead2: {
            L4DL4D2_VoteTypeToTranslation(voteType, translation, maxlength);
        }
    }
}

stock void Game_UpdateClientCount(int num_clients) {
    switch(g_EngineVersion) {
        case Engine_Left4Dead, Engine_Left4Dead2: {
            L4DL4D2_UpdateClientCount(num_clients);
        }
    }
}

public Action Game_ResetVote(Handle timer) {
    switch(g_EngineVersion) {
        case Engine_Left4Dead, Engine_Left4Dead2: {
            L4DL4D2_ResetVote();
        }
    }
    return Plugin_Stop;
}

void Game_VoteYes(int client) {
    switch (g_EngineVersion) {
        case Engine_Left4Dead, Engine_Left4Dead2: {
            FakeClientCommand(client, "Vote Yes");
        }
    }
}

void Game_VoteNo(int client) {
    switch (g_EngineVersion) {
        case Engine_Left4Dead, Engine_Left4Dead2: {
            FakeClientCommand(client, "Vote No");
        }
    }
}

bool Game_IsVoteInProgress() {
    switch (g_EngineVersion) {
        case Engine_Left4Dead, Engine_Left4Dead2: {
            return L4DL4D2_IsVoteInProgress();
        }
    }
    return false;
}

stock NativeVotesType Game_VoteStringToVoteType(char[] voteString) {
    return NativeVotesType_None;
}

stock int Game_VoteTypeToVoteOverride(NativeVotesType voteType) {
    return NativeVotesOverride_None;
}

stock NativeVotesType Game_VoteOverrideToVoteType(int overrideType) {
    return NativeVotesType_None;
}

stock int Game_VoteStringToVoteOverride(const char[] voteString) {
    return NativeVotesOverride_None;
}

stock bool Game_OverrideTypeToVoteString(int overrideType, char[] voteString, int maxlength) {
    return false;
}

stock bool Game_OverrideTypeToTranslationString(int overrideType, char[] translationString, int maxlength) {
    return false;
}

bool Game_AreDisabledIssuesHidden() {
    return true;
}

// All games shared functions
//----------------------------------------------------------------------------
// Data functions

static NativeVotesPassType VoteTypeToVotePass(NativeVotesType voteType) {
    NativeVotesPassType passType = NativeVotesPass_None;
    switch(voteType) {
        case NativeVotesType_Custom_YesNo, NativeVotesType_Custom_Mult: {
            passType = NativeVotesPass_Custom;
        }
        case NativeVotesType_ChgCampaign: {
            passType = NativeVotesPass_ChgCampaign;
        }
        case NativeVotesType_ChgDifficulty: {
            passType = NativeVotesPass_ChgDifficulty;
        }
        case NativeVotesType_ReturnToLobby: {
            passType = NativeVotesPass_ReturnToLobby;
        }
        case NativeVotesType_AlltalkOn: {
            passType = NativeVotesPass_AlltalkOn;
        }
        case NativeVotesType_AlltalkOff: {
            passType = NativeVotesPass_AlltalkOff;
        }
        case NativeVotesType_Restart: {
            passType = NativeVotesPass_Restart;
        }
        case NativeVotesType_Kick, NativeVotesType_KickIdle, NativeVotesType_KickScamming, NativeVotesType_KickCheating: {
            passType = NativeVotesPass_Kick;
        }
        case NativeVotesType_ChgLevel: {
            passType = NativeVotesPass_ChgLevel;
        }
        case NativeVotesType_NextLevel, NativeVotesType_NextLevelMult: {
            passType = NativeVotesPass_NextLevel;
        }
        case NativeVotesType_ScrambleNow, NativeVotesType_ScrambleEnd: {
            passType = NativeVotesPass_Scramble;
        }
        case NativeVotesType_ChgMission: {
            passType = NativeVotesPass_ChgMission;
        }
        case NativeVotesType_SwapTeams: {
            passType = NativeVotesPass_SwapTeams;
        }
        case NativeVotesType_Surrender: {
            passType = NativeVotesPass_Surrender;
        }
        case NativeVotesType_Rematch: {
            passType = NativeVotesPass_Rematch;
        }
        case NativeVotesType_Continue: {
            passType = NativeVotesPass_Continue;
        }
        case NativeVotesType_StartRound: {
            passType = NativeVotesPass_StartRound;
        }
        case NativeVotesType_Eternaween: {
            passType = NativeVotesPass_Eternaween;
        }
        case NativeVotesType_AutoBalanceOn: {
            passType = NativeVotesPass_AutoBalanceOn;
        }
        case NativeVotesType_AutoBalanceOff: {
            passType = NativeVotesPass_AutoBalanceOff;
        }
        case NativeVotesType_ClassLimitsOn: {
            passType = NativeVotesPass_ClassLimitsOn;
        }
        case NativeVotesType_ClassLimitsOff: {
            passType = NativeVotesPass_ClassLimitsOff;
        }
        case NativeVotesType_Extend: {
            passType = NativeVotesPass_Extend;
        }
        default: {
            passType = NativeVotesPass_Custom;
        }
    }
    return passType;
}

static int VoteCallFailTypeToInt(NativeVotesCallFailType failType) {
    switch (g_EngineVersion) {
        case Engine_Left4Dead, Engine_Left4Dead2: {
            switch (failType) {
                case NativeVotesCallFail_Generic: {
                    return VOTE_FAILED_GENERIC;
                }
                case NativeVotesCallFail_Loading: {
                    return VOTE_FAILED_TRANSITIONING_PLAYERS;
                }
                case NativeVotesCallFail_Recent: {
                    return VOTE_FAILED_FAILED_RECENTLY;
                }
            }
        }
    }
    return VOTE_FAILED_GENERIC;
}

static void GetEngineVersionName(EngineVersion version, char[] printName, int maxlength) {
    switch (version) {
        case Engine_Unknown: {
            strcopy(printName, maxlength, "Unknown");
        }
        case Engine_Original: {
            strcopy(printName, maxlength, "Original");
        }
        case Engine_SourceSDK2006: {
            strcopy(printName, maxlength, "Source SDK 2006");
        }
        case Engine_SourceSDK2007: {
            strcopy(printName, maxlength, "Source SDK 2007");
        }
        case Engine_Left4Dead: {
            strcopy(printName, maxlength, "Left 4 Dead ");
        }
        case Engine_DarkMessiah: {
            strcopy(printName, maxlength, "Dark Messiah");
        }
        case Engine_Left4Dead2: {
            strcopy(printName, maxlength, "Left 4 Dead 2");
        }
        case Engine_AlienSwarm: {
            strcopy(printName, maxlength, "Alien Swarm");
        }
        case Engine_BloodyGoodTime: {
            strcopy(printName, maxlength, "Bloody Good Time");
        }
        case Engine_EYE: {
            strcopy(printName, maxlength, "E.Y.E. Divine Cybermancy");
        }
        case Engine_Portal2: {
            strcopy(printName, maxlength, "Portal 2");
        }
        case Engine_CSGO: {
            strcopy(printName, maxlength, "Counter-Strike: Global Offensive");
        }
        case Engine_CSS: {
            strcopy(printName, maxlength, "Counter-Strike: Source");
        }
        case Engine_DOTA: {
            strcopy(printName, maxlength, "DOTA 2");
        }
        case Engine_HL2DM: {
            strcopy(printName, maxlength, "Half-Life 2: Deathmatch");
        }
        case Engine_DODS: {
            strcopy(printName, maxlength, "Day of Defeat: Source");
        }
        case Engine_TF2: {
            strcopy(printName, maxlength, "Team Fortress 2");
        }
        case Engine_NuclearDawn: {
            strcopy(printName, maxlength, "Nuclear Dawn");
        }
        default: {
            strcopy(printName, maxlength, "Not listed");
        }
    }
}

//----------------------------------------------------------------------------
// L4D/L4D2 shared functions

// NATIVEVOTES_VOTE_INVALID means parse failed
static int L4DL4D2_ParseVote(const char[] option) {
    if (StrEqual(option, "Yes", false)) {
        return NATIVEVOTES_VOTE_YES;
    } else if (StrEqual(option, "No", false)) {
        return NATIVEVOTES_VOTE_NO;
    }
    return NATIVEVOTES_VOTE_INVALID;
}

static void L4DL4D2_ClientSelectedItem(int client, int item) {
    int choice;
    if (item == NATIVEVOTES_VOTE_NO) {
        choice = 0;
    } else if (item == NATIVEVOTES_VOTE_YES) {
        choice = 1;
    }
    BfWrite voteCast = UserMessageToBfWrite(StartMessageOne("VoteRegistered", client, USERMSG_RELIABLE));
    voteCast.WriteByte(choice);
    EndMessage();
}

static void L4DL4D2_UpdateVoteCounts(ArrayList votes, int totalClients) {
    int yesVotes = votes.Get(NATIVEVOTES_VOTE_YES);
    int noVotes  = votes.Get(NATIVEVOTES_VOTE_NO);
    Event changeEvent = CreateEvent("vote_changed");
    changeEvent.SetInt("yesVotes", yesVotes);
    changeEvent.SetInt("noVotes", noVotes);
    changeEvent.SetInt("potentialVotes", totalClients);
    changeEvent.Fire();
    if (CheckVoteController()) {
        SetEntProp(g_VoteController, Prop_Send, "m_votesYes", yesVotes);
        SetEntProp(g_VoteController, Prop_Send, "m_votesNo", noVotes);
    }
}

static stock void L4DL4D2_UpdateClientCount(int num_clients) {
    if (CheckVoteController()) {
        SetEntProp(g_VoteController, Prop_Send, "m_potentialVotes", num_clients);
    }
}

static void L4DL4D2_CallVoteFail(int client, int reason) {
    BfWrite callVoteFail = UserMessageToBfWrite(StartMessageOne("CallVoteFailed", client, USERMSG_RELIABLE));
    callVoteFail.WriteByte(reason);
    EndMessage();
}

static void L4DL4D2_VoteTypeToTranslation(NativeVotesType voteType, char[] translation, int maxlength) {
    switch(voteType) {
        case NativeVotesType_ChgCampaign: {
            strcopy(translation, maxlength, L4D_VOTE_CHANGECAMPAIGN_START);
        }
        case NativeVotesType_ChgDifficulty: {
            strcopy(translation, maxlength, L4D_VOTE_CHANGEDIFFICULTY_START);
        }
        case NativeVotesType_ReturnToLobby: {
            strcopy(translation, maxlength, L4D_VOTE_RETURNTOLOBBY_START);
        }
        case NativeVotesType_AlltalkOn, NativeVotesType_AlltalkOff: {
            strcopy(translation, maxlength, L4D2_VOTE_ALLTALK_START);
        }
        case NativeVotesType_Restart: {
            // same as CRestartGameIssue::GetDisplayString()
            if (SDK_IsVersus()) {
                strcopy(translation, maxlength, L4D_VOTE_RESTART_VERSUS_START);
            } else if (SDK_IsSurvival()) {
                strcopy(translation, maxlength, L4D_VOTE_RESTART_CHAPTER_START);
            } else {
                strcopy(translation, maxlength, L4D_VOTE_RESTART_GAME_START);
            }
        }
        case NativeVotesType_Kick: {
            strcopy(translation, maxlength, L4D_VOTE_KICK_START);
        }
        case NativeVotesType_ChgLevel: {
            strcopy(translation, maxlength, L4D_VOTE_CHANGELEVEL_START);
        }
        default: {
            strcopy(translation, maxlength, L4D_VOTE_CUSTOM);
        }
    }
}

static void L4DL4D2_VotePassToTranslation(NativeVotesPassType passType, char[] translation, int maxlength) {
    switch(passType) {
        case NativeVotesPass_Custom: {
            strcopy(translation, maxlength, L4D_VOTE_CUSTOM);
        }
        case NativeVotesPass_ChgCampaign: {
            strcopy(translation, maxlength, L4D_VOTE_CHANGECAMPAIGN_PASSED);
        }
        case NativeVotesPass_ChgDifficulty: {
            strcopy(translation, maxlength, L4D_VOTE_CHANGEDIFFICULTY_PASSED);
        }
        case NativeVotesPass_ReturnToLobby: {
            strcopy(translation, maxlength, L4D_VOTE_RETURNTOLOBBY_PASSED);
        }
        case NativeVotesPass_AlltalkOn, NativeVotesPass_AlltalkOff: {
            strcopy(translation, maxlength, L4D2_VOTE_ALLTALK_PASSED);
        }
        case NativeVotesPass_Restart: {
            if (SDK_IsVersus()) {
                strcopy(translation, maxlength, L4D_VOTE_RESTART_VERSUS_PASSED);
            } else if (SDK_IsSurvival()) {
                strcopy(translation, maxlength, L4D_VOTE_RESTART_CHAPTER_PASSED);
            } else {
                strcopy(translation, maxlength, L4D_VOTE_RESTART_GAME_PASSED);
            }
        }
        case NativeVotesPass_Kick: {
            strcopy(translation, maxlength, L4D_VOTE_KICK_PASSED);
        }
        case NativeVotesPass_ChgLevel: {
            strcopy(translation, maxlength, L4D_VOTE_CHANGELEVEL_PASSED);
        }
        default: {
            strcopy(translation, maxlength, L4D_VOTE_CUSTOM);
        }
    }
}

static void L4DL4D2_ResetVote() {
    if (CheckVoteController()) {
        SetEntProp(g_VoteController, Prop_Send, "m_activeIssueIndex", INVALID_ISSUE);
        SetEntProp(g_VoteController, Prop_Send, "m_votesYes", 0);
        SetEntProp(g_VoteController, Prop_Send, "m_votesNo", 0);
        SetEntProp(g_VoteController, Prop_Send, "m_potentialVotes", 0);
        SetEntProp(g_VoteController, Prop_Send, "m_onlyTeamToVote", NATIVEVOTES_ALL_TEAMS);
    }
}

static bool L4DL4D2_IsVoteInProgress() {
    if (CheckVoteController()) {
        return (GetEntProp(g_VoteController, Prop_Send, "m_activeIssueIndex") > INVALID_ISSUE);
    }
    return false;
}

//----------------------------------------------------------------------------
// L4D functions

static void L4D_DisplayVote(NativeVote vote, int num_clients) {
    char translation[TRANSLATION_LENGTH];
    NativeVotesType voteType = Data_GetType(vote);
    L4DL4D2_VoteTypeToTranslation(voteType, translation, sizeof(translation));
    char details[MAX_VOTE_DETAILS_LENGTH];
    Data_GetDetails(vote, details, MAX_VOTE_DETAILS_LENGTH);
    int team = Data_GetTeam(vote);
    if (CheckVoteController()) {
        // TODO: Need to look these values up
        SetEntProp(g_VoteController, Prop_Send, "m_activeIssueIndex", 0); // For now, set to 0 to block in-game votes
        SetEntProp(g_VoteController, Prop_Send, "m_onlyTeamToVote", team);
        SetEntProp(g_VoteController, Prop_Send, "m_votesYes", 0);
        SetEntProp(g_VoteController, Prop_Send, "m_votesNo", 0);
        SetEntProp(g_VoteController, Prop_Send, "m_potentialVotes", num_clients);
    }

    Event voteStart = CreateEvent("vote_started");
    voteStart.SetInt("team", team);
    voteStart.SetInt("initiator", Data_GetInitiator(vote));
    voteStart.SetString("issue", translation);
    voteStart.SetString("param1", details);
    voteStart.Fire();
}

static void L4D_VoteEnded() {
    Event endEvent = CreateEvent("vote_ended");
    endEvent.Fire();
}

static void L4D_VotePass(const char[] translation, const char[] details, int team) {
    L4D_VoteEnded();
    Event passEvent = CreateEvent("vote_passed");
    passEvent.SetString("details", translation);
    passEvent.SetString("param1", details);
    passEvent.SetInt("team", team);
    passEvent.Fire();
}

static void L4D_VoteFail(int team) {
    L4D_VoteEnded();
    Event failEvent = CreateEvent("vote_failed");
    failEvent.SetInt("team", team);
    failEvent.Fire();
}

static bool L4D_CheckVoteType(NativeVotesType voteType) {
    switch(voteType) {
        case NativeVotesType_Custom_YesNo, NativeVotesType_ChgCampaign, NativeVotesType_ChgDifficulty,
        NativeVotesType_ReturnToLobby, NativeVotesType_Restart, NativeVotesType_Kick,
        NativeVotesType_ChgLevel: {
            return true;
        }
    }
    return false;
}

static bool L4D_CheckVotePassType(NativeVotesPassType passType) {
    switch(passType) {
        case NativeVotesPass_Custom, NativeVotesPass_ChgCampaign, NativeVotesPass_ChgDifficulty,
        NativeVotesPass_ReturnToLobby, NativeVotesPass_Restart, NativeVotesPass_Kick,
        NativeVotesPass_ChgLevel: {
            return true;
        }
    }
    return false;
}

//----------------------------------------------------------------------------
// L4D2 functions

static void L4D2_DisplayVote(NativeVote vote, int[] clients, int num_clients) {
    char translation[TRANSLATION_LENGTH];
    NativeVotesType voteType = Data_GetType(vote);
    L4DL4D2_VoteTypeToTranslation(voteType, translation, sizeof(translation));
    char details[MAX_VOTE_DETAILS_LENGTH];
    int team = Data_GetTeam(vote);
    bool bCustom = false;
    switch (voteType) {
        case NativeVotesType_AlltalkOn: {
            strcopy(details, MAX_VOTE_DETAILS_LENGTH, L4D2_VOTE_ALLTALK_ENABLE);
        }
        case NativeVotesType_AlltalkOff: {
            strcopy(details, MAX_VOTE_DETAILS_LENGTH, L4D2_VOTE_ALLTALK_DISABLE);
        }
        case NativeVotesType_Custom_YesNo, NativeVotesType_Custom_Mult: {
            Data_GetTitle(vote, details, MAX_VOTE_DETAILS_LENGTH);
            bCustom = true;
        }
        default: {
            Data_GetDetails(vote, details, MAX_VOTE_DETAILS_LENGTH);
        }
    }

    int initiator = Data_GetInitiator(vote);
    char initiatorName[MAX_NAME_LENGTH];

    if (initiator != NATIVEVOTES_SERVER_INDEX && initiator > 0 && initiator <= MaxClients && IsClientInGame(initiator)) {
        GetClientName(initiator, initiatorName, MAX_NAME_LENGTH);
    }

    for (int i = 0; i < num_clients; ++i) {
        g_newMenuTitle[0] = '\0';
        MenuAction actions = Data_GetActions(vote);
        Action changeTitle = Plugin_Continue;
        if (bCustom && actions & MenuAction_Display) {
            g_curDisplayClient = clients[i];
            changeTitle = view_as<Action>(DoAction(vote, MenuAction_Display, clients[i], 0));
        }

        g_curDisplayClient = 0;
        BfWrite voteStart = UserMessageToBfWrite(StartMessageOne("VoteStart", clients[i], USERMSG_RELIABLE));
        voteStart.WriteByte(team);
        voteStart.WriteByte(initiator);
        voteStart.WriteString(translation);
        if (changeTitle == Plugin_Changed) {
            voteStart.WriteString(g_newMenuTitle);
        } else {
            voteStart.WriteString(details);
        }
        voteStart.WriteString(initiatorName);
        EndMessage();
    }
    if (CheckVoteController()) {
        SetEntProp(g_VoteController, Prop_Send, "m_onlyTeamToVote", team);
        SetEntProp(g_VoteController, Prop_Send, "m_votesYes", 0);
        SetEntProp(g_VoteController, Prop_Send, "m_votesNo", 0);
        SetEntProp(g_VoteController, Prop_Send, "m_potentialVotes", num_clients);
        SetEntProp(g_VoteController, Prop_Send, "m_activeIssueIndex", 0); // Set to 0 to block ingame votes
    }
}

static void L4D2_VotePass(const char[] translation, const char[] details, int team, int client=0) {
    BfWrite votePass;
    if (!client) {
        votePass = UserMessageToBfWrite(StartMessageAll("VotePass", USERMSG_RELIABLE));
    } else {
        votePass = UserMessageToBfWrite(StartMessageOne("VotePass", client, USERMSG_RELIABLE));
    }
    votePass.WriteByte(team);
    votePass.WriteString(translation);
    votePass.WriteString(details);
    EndMessage();
}

static void L4D2_VoteFail(int[] clients, int numClients, int team) {
    BfWrite voteFailed = UserMessageToBfWrite(StartMessage("VoteFail", clients, numClients, USERMSG_RELIABLE));
    voteFailed.WriteByte(team);
    EndMessage();
}

static bool L4D2_CheckVoteType(NativeVotesType voteType) {
    switch(voteType) {
        case NativeVotesType_Custom_YesNo, NativeVotesType_ChgCampaign, NativeVotesType_ChgDifficulty,
        NativeVotesType_ReturnToLobby, NativeVotesType_AlltalkOn, NativeVotesType_AlltalkOff,
        NativeVotesType_Restart, NativeVotesType_Kick, NativeVotesType_ChgLevel: {
            return true;
        }
    }
    return false;
}

static bool L4D2_CheckVotePassType(NativeVotesPassType passType) {
    switch(passType) {
        case NativeVotesPass_Custom, NativeVotesPass_ChgCampaign, NativeVotesPass_ChgDifficulty,
        NativeVotesPass_ReturnToLobby, NativeVotesPass_AlltalkOn, NativeVotesPass_AlltalkOff,
        NativeVotesPass_Restart, NativeVotesPass_Kick, NativeVotesPass_ChgLevel: {
            return true;
        }
    }
    return false;
}

// The stocks below are used by the vote override system
// Not all are used by the plugin
stock bool Game_IsVoteTypeCustom(NativeVotesType voteType) {
    switch(voteType) {
        case NativeVotesType_Custom_YesNo, NativeVotesType_Custom_Mult: {
            return true;
        }
    }
    return false;
}

stock bool Game_IsVoteTypeYesNo(NativeVotesType voteType) {
    switch(voteType) {
        case NativeVotesType_Custom_Mult, NativeVotesType_NextLevelMult: {
            return false;
        }
    }
    return true;
}