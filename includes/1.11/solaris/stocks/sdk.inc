#if defined __stocks_sdk_included
    #endinput
#endif
#define __stocks_sdk_included

#include <sourcemod>
#include <sdktools>

/**
 * Get a handle to the gamedata
 *
 * @return              Handle to game config, or null if not found.
 */
stock GameData SDK_GetGameConf() {
    static GameData g_hGameConf;
    if (g_hGameConf == null) {
        g_hGameConf = new GameData("stocks_sdk");
    }
    return g_hGameConf;
}

/**
 * Get the address of the global CDirector instance (TheDirector)
 *
 * @return              Address of the global CDirector, or Address_Null on failure.
 */
stock Address SDK_GetCDirector() {
    static Address TheDirector = Address_Null;
    if (TheDirector == Address_Null) {
        TheDirector = SDK_GetGameConf().GetAddress("CDirector");
    }
    return TheDirector;
}

stock Handle SDK_GameRulesBoolCall(const char[] szSig) {
    StartPrepSDKCall(SDKCall_GameRules);
    if (!PrepSDKCall_SetFromConf(SDK_GetGameConf(), SDKConf_Signature, szSig)) {
        return null;
    }
    PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
    return EndPrepSDKCall();
}

/**
 * Sets scores for teams
 *
 * @note Sets only visible values, does not update actual score values
 * @noreturn
 */
stock void SDK_SetCampaignScores(int iSurvScore, int iInfScore) {
    static Handle SetCampaignScoresSDKCall = null;
    if (SetCampaignScoresSDKCall == null) {
        StartPrepSDKCall(SDKCall_GameRules);
        if (!PrepSDKCall_SetFromConf(SDK_GetGameConf(), SDKConf_Signature, "CTerrorGameRules::SetCampaignScores")) {
            return;
        }
        PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
        PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
        SetCampaignScoresSDKCall = EndPrepSDKCall();
    }
    SDKCall(SetCampaignScoresSDKCall, iSurvScore, iInfScore);
}

/**
 * Resets scores for teams.
 *
 * @note Calls CDirector::ClearScavengeScores and CDirectorVersusMode::ClearTeamScoresNonVirtual, so you don't have to worry about game modes yourself
 * @noreturn
 */
stock void SDK_ResetTeamScores() {
    static Handle ClearTeamScoresSDKCall = null;
    if (ClearTeamScoresSDKCall == null) {
        StartPrepSDKCall(SDKCall_Raw);
        if (!PrepSDKCall_SetFromConf(SDK_GetGameConf(), SDKConf_Signature, "CDirector::ClearTeamScores")) {
            return;
        }
        PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
        ClearTeamScoresSDKCall = EndPrepSDKCall();
    }
    SDKCall(ClearTeamScoresSDKCall, SDK_GetCDirector(), 1);
}

/**
 * Changes level (map) using CDirector.
 *
 * @note Does NOT validate map name. Use FindMap for that.
 * @note Does NOT reset team scores automatically, set second parameter to true if this is desirable.
 * @note if you change to not the first map in scenario it saves the state of "m_bAreTeamsFlipped"
 * @param szMap
 * @param bResetScore
 * @noreturn
 */
stock void SDK_ChangeLevel(const char[] szMap, bool bResetScore=false) {
    static Handle ChangeLevelSDKCall = null;
    if (ChangeLevelSDKCall == null) {
        StartPrepSDKCall(SDKCall_Raw);
        if (!PrepSDKCall_SetFromConf(SDK_GetGameConf(), SDKConf_Signature, "CDirector::OnChangeChapterVote")) {
            return;
        }
        PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
        ChangeLevelSDKCall = EndPrepSDKCall();
    }
    if (bResetScore) {
        SDK_ResetTeamScores();
    }
    SDKCall(ChangeLevelSDKCall, SDK_GetCDirector(), szMap);
}

/**
 * Same as calling "scenario_end" Cmd, but without dealing with cheat flags
 *
 * @noreturn
 */
stock void SDK_ScenarioEnd() {
    static Handle EndScenarioSDKCall = null;
    if (EndScenarioSDKCall == null) {
        StartPrepSDKCall(SDKCall_Raw);
        if (!PrepSDKCall_SetFromConf(SDK_GetGameConf(), SDKConf_Signature, "CDirector::InitiateEndScenario")) {
            return;
        }
        EndScenarioSDKCall = EndPrepSDKCall();
    }
    SDKCall(EndScenarioSDKCall, SDK_GetCDirector());
}

/**
 * Changes map to the first level of a given mission (campaign).
 *
 * @note Mission name is a mission file name from "L4D2C1" (Dead Center) through "L4D2C13" (Cold Stream)
 * @note https://developer.valvesoftware.com/wiki/List_of_L4D2_Missions_Files
 * @param szMission
 * @noreturn
 */
stock void SDK_ChangeMission(const char[] szMission) {
    static Handle ChangeMissionSDKCall = null;
    if (ChangeMissionSDKCall == null) {
        StartPrepSDKCall(SDKCall_Raw);
        if (!PrepSDKCall_SetFromConf(SDK_GetGameConf(), SDKConf_Signature, "CDirector::OnChangeMissionVote")) {
            return;
        }
        PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
        ChangeMissionSDKCall = EndPrepSDKCall();
    }
    SDKCall(ChangeMissionSDKCall, SDK_GetCDirector(), szMission);
}

/**
 * Writes in a given buffer the base game-mode of a current `mp_gamemode`. One of: "coop", "versus", "scavenge", "survival", "realism".
 * Useful during mutation game-types to deduct the base game mode without any hassle.
 *
 * @note https://developer.valvesoftware.com/wiki/L4D2_Gamemodes.txt_File
 * @param szBuf
 * @param iSize
 * @noreturn
 */
stock void SDK_GetGameModeBase(char[] szBuf, int iSize) {
    static Handle GetGameModeBaseSDKCall = null;
    if (GetGameModeBaseSDKCall == null) {
        StartPrepSDKCall(SDKCall_Raw);
        if (!PrepSDKCall_SetFromConf(SDK_GetGameConf(), SDKConf_Signature, "CDirector::GetGameModeBase")) {
            return;
        }
        PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Pointer);
        GetGameModeBaseSDKCall = EndPrepSDKCall();
    }
    SDKCall(GetGameModeBaseSDKCall, SDK_GetCDirector(), szBuf, iSize);
}

/**
 * Clear transition info
 * @noreturn
 */
stock void SDK_ClearTransitionInfo() {
    static Handle ServerShutdownSDKCall = null;
    if (ServerShutdownSDKCall == null) {
        StartPrepSDKCall(SDKCall_Raw);
        if (!PrepSDKCall_SetFromConf(SDK_GetGameConf(), SDKConf_Signature, "CDirector::OnServerShutdown")) {
            return;
        }
        ServerShutdownSDKCall = EndPrepSDKCall();
    }
    SDKCall(ServerShutdownSDKCall, SDK_GetCDirector());
}

/**
 * Swap teams
 * @noreturn
 */
stock void SDK_SwapTeams() {
    static Handle SwapTeamsSDKCall = null;
    if (SwapTeamsSDKCall == null) {
        StartPrepSDKCall(SDKCall_Raw);
        if (!PrepSDKCall_SetFromConf(SDK_GetGameConf(), SDKConf_Signature, "CDirector::SwapTeams")) {
            return;
        }
        PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
        SwapTeamsSDKCall = EndPrepSDKCall();
    }
    SDKCall(SwapTeamsSDKCall, SDK_GetCDirector());
}

/**
 * Tells if the Mission (map) is the first map of the campaign
 * @return bool
 */
stock bool SDK_IsFirstMapInScenario() {
    static Handle IsFirstMapInScenarioSDKCall = null;
    if (IsFirstMapInScenarioSDKCall == null) {
        StartPrepSDKCall(SDKCall_Raw);
        if (!PrepSDKCall_SetFromConf(SDK_GetGameConf(), SDKConf_Signature, "CDirector::IsFirstMapInScenario")) {
            return false;
        }
        PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
        IsFirstMapInScenarioSDKCall = EndPrepSDKCall();
    }
    return SDKCall(IsFirstMapInScenarioSDKCall, SDK_GetCDirector());
}

/**
 * Returns if teams are flipped
 *
 * @return bool
 */
stock bool SDK_AreTeamsFlipped() {
    static Handle AreTeamsFlippedSDKCall = null;
    if (AreTeamsFlippedSDKCall == null) {
        StartPrepSDKCall(SDKCall_Raw);
        if (!PrepSDKCall_SetFromConf(SDK_GetGameConf(), SDKConf_Signature, "CDirector::AreTeamsFlipped")) {
            return false;
        }
        PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
        AreTeamsFlippedSDKCall = EndPrepSDKCall();
    }
    return SDKCall(AreTeamsFlippedSDKCall, SDK_GetCDirector());
}

/**
 * Clear entity state
 * @noreturn
 */
stock void SDK_ResetEntityState(int iEnt) {
    static Handle ResetEntityState = null;
    if (ResetEntityState == null) {
        StartPrepSDKCall(SDKCall_Entity);
        if (!PrepSDKCall_SetFromConf(SDK_GetGameConf(), SDKConf_Signature, "NextBotCombatCharacter::Spawn")) {
            return;
        }
        ResetEntityState = EndPrepSDKCall();
    }
    SDKCall(ResetEntityState, iEnt);
}

/**
 * Compares base gamemode to passed string
 * @param szCompareTo
 * @return bool
 */
stock bool SDK_IsBaseGameModeEquals(const char[] szCompareTo) {
    char szGm[16];
    SDK_GetGameModeBase(szGm, sizeof(szGm));
    return StrEqual(szCompareTo, szGm, false);
}

/**
 * Returns true if base for current gamemode is "coop"
 * @return bool
 */
stock bool SDK_IsCoop() {
    static Handle IsCoopModeSDKCall = null;
    if (IsCoopModeSDKCall == null) {
        IsCoopModeSDKCall = SDK_GameRulesBoolCall("CTerrorGameRules::IsCoopMode");
        if (IsCoopModeSDKCall == null) return false;
    }
    return SDKCall(IsCoopModeSDKCall);
}

/**
 * Returns true if base for current gamemode is "versus"
 * @return bool
 */
stock bool SDK_IsVersus() {
    static Handle IsVersusModeSDKCall = null;
    if (IsVersusModeSDKCall == null) {
        IsVersusModeSDKCall = SDK_GameRulesBoolCall("CTerrorGameRules::IsVersusMode");
        if (IsVersusModeSDKCall == null) return false;
    }
    return SDKCall(IsVersusModeSDKCall);
}

/**
 * Returns true if base for current gamemode is "scavenge"
 * @return bool
 */
stock bool SDK_IsScavenge() {
    static Handle IsScavengeModeSDKCall = null;
    if (IsScavengeModeSDKCall == null) {
        IsScavengeModeSDKCall = SDK_GameRulesBoolCall("CTerrorGameRules::IsScavengeMode");
        if (IsScavengeModeSDKCall == null) return false;
    }
    return SDKCall(IsScavengeModeSDKCall);
}

/**
 * Returns true if base for current gamemode is "survival"
 * @return bool
 */
stock bool SDK_IsSurvival() {
    static Handle IsSurvivalModeSDKCall = null;
    if (IsSurvivalModeSDKCall == null) {
        IsSurvivalModeSDKCall = SDK_GameRulesBoolCall("CTerrorGameRules::IsSurvivalMode");
        if (IsSurvivalModeSDKCall == null) return false;
    }
    return SDKCall(IsSurvivalModeSDKCall);
}

/**
 * Returns true if base for current gamemode is "realism"
 * @return bool
 */
stock bool SDK_IsRealism() {
    static Handle IsRealismModeSDKCall = null;
    if (IsRealismModeSDKCall == null) {
        IsRealismModeSDKCall = SDK_GameRulesBoolCall("CTerrorGameRules::IsRealismMode");
        if (IsRealismModeSDKCall == null) return false;
    }
    return SDKCall(IsRealismModeSDKCall);
}

/**
 * Returns true if current gamemode is a solo player mode
 * @return bool
 */
stock bool SDK_IsSoloMode() {
    static Handle IsSoloModeSDKCall = null;
    if (IsSoloModeSDKCall == null) {
        IsSoloModeSDKCall = SDK_GameRulesBoolCall("CTerrorGameRules::IsSoloMode");
        if (IsSoloModeSDKCall == null) return false;
    }
    return SDKCall(IsSoloModeSDKCall);
}

/**
 * Returns true if current gamemode is a Team vs. Team mode
 * @return bool
 */
stock bool SDK_IsTeamOnTeamMode() {
    static Handle IsTeamOnTeamModeSDKCall = null;
    if (IsTeamOnTeamModeSDKCall == null) {
        IsTeamOnTeamModeSDKCall = SDK_GameRulesBoolCall("CTerrorGameRules::IsTeamOnTeamMode");
        if (IsTeamOnTeamModeSDKCall == null) return false;
    }
    return SDKCall(IsTeamOnTeamModeSDKCall);
}

/**
 * Returns true if current gamemode consists of playing on a single map
 * @return bool
 */
stock bool SDK_IsSingleChapterMode() {
    static Handle IsSingleChapterModeSDKCall = null;
    if (IsSingleChapterModeSDKCall == null) {
        IsSingleChapterModeSDKCall = SDK_GameRulesBoolCall("CTerrorGameRules::IsSingleChapterMode");
        if (IsSingleChapterModeSDKCall == null) return false;
    }
    return SDKCall(IsSingleChapterModeSDKCall);
}

/**
 * Returns true if intro is currently being played ???
 * @return bool
 */
stock bool SDK_IsInIntro() {
    static Handle IsInIntroSDKCall = null;
    if (IsInIntroSDKCall == null) {
        IsInIntroSDKCall = SDK_GameRulesBoolCall("CTerrorGameRules::IsInIntro");
        if (IsInIntroSDKCall == null) return false;
    }
    return SDKCall(IsInIntroSDKCall);
}

/**
 * Returns true if current map is last for the mission
 * @return bool
 */
stock bool SDK_IsMissionFinalMap() {
    static Handle IsMissionFinalMapSDKCall = null;
    if (IsMissionFinalMapSDKCall == null) {
        IsMissionFinalMapSDKCall = SDK_GameRulesBoolCall("CTerrorGameRules::IsMissionFinalMap");
        if (IsMissionFinalMapSDKCall == null) return false;
    }
    return SDKCall(IsMissionFinalMapSDKCall);
}

/**
 * Returns true if current campaign is c1-c5 (useless?)
 * @return bool
 */
stock bool SDK_IsOriginalCampaign() {
    static Handle IsOriginalCampaignSDKCall = null;
    if (IsOriginalCampaignSDKCall == null) {
        IsOriginalCampaignSDKCall = SDK_GameRulesBoolCall("CTerrorGameRules::IsOriginalCampaign");
        if (IsOriginalCampaignSDKCall == null) return false;
    }
    return SDKCall(IsOriginalCampaignSDKCall);
}

/**
 * Returns a number of maps in current campaign
 * @return int
 */
stock int SDK_GetChaptersNum() {
    static Handle GetChaptersNumSDKCall = null;
    if (GetChaptersNumSDKCall == null) {
        StartPrepSDKCall(SDKCall_GameRules);
        if (!PrepSDKCall_SetFromConf(SDK_GetGameConf(), SDKConf_Signature, "CTerrorGameRules::GetNumChaptersForMissionAndMode")) {
            return -1;
        }
        PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
        GetChaptersNumSDKCall = EndPrepSDKCall();
    }
    return SDKCall(GetChaptersNumSDKCall);
}

/**
 * Returns true if current gamemode has configurable difficulty settings (Easy, Normal, Hard, Impossible)
 * @return bool
 */
stock bool SDK_HasDifficulty() {
    static Handle HasDifficultySDKCall = null;
    if (HasDifficultySDKCall == null) {
        HasDifficultySDKCall = SDK_GameRulesBoolCall("CTerrorGameRules::HasConfigurableDifficultySetting");
        if (HasDifficultySDKCall == null) return false;
    }
    return SDKCall(HasDifficultySDKCall);
}

/**
 * Returns true if current gamemode has player-controlled infected
 * @return bool
 */
stock bool SDK_HasPlayerInfected() {
    static Handle HasControlledInfectedSDKCall = null;
    if (HasControlledInfectedSDKCall == null) {
        HasControlledInfectedSDKCall = SDK_GameRulesBoolCall("CTerrorGameRules::HasPlayerControlledZombies");
        if (HasControlledInfectedSDKCall == null) return false;
    }
    return SDKCall(HasControlledInfectedSDKCall);
}

/**
 * Make a player idle
 * @return int
 */
stock int SDK_GoAwayFromKeyboard(int iClient) {
    static Handle GoAwayFromKeyboard = null;
    if (GoAwayFromKeyboard == null) {
        StartPrepSDKCall(SDKCall_Player);
        if (!PrepSDKCall_SetFromConf(SDK_GetGameConf(), SDKConf_Signature, "CTerrorPlayer::GoAwayFromKeyboard")) {
            return -1;
        }
        GoAwayFromKeyboard = EndPrepSDKCall();
    }
    return SDKCall(GoAwayFromKeyboard, iClient);
}

/**
 * Make a player to take over the bot
 * @return int
 */
stock int SDK_TakeOverBot(int iClient) {
    static Handle TakeOverBot = null;
    if (TakeOverBot == null) {
        StartPrepSDKCall(SDKCall_Player);
        if (!PrepSDKCall_SetFromConf(SDK_GetGameConf(), SDKConf_Signature, "CTerrorPlayer::TakeOverBot")) {
            return -1;
        }
        PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
        TakeOverBot = EndPrepSDKCall();
    }
    return SDKCall(TakeOverBot, iClient, true);
}

/**
 * Teleport a player to valid position
 * @return int
 */
stock int SDK_WarpToValidPosition(int iClient) {
    static Handle WarpToValidPosition = null;
    if (WarpToValidPosition == null) {
        StartPrepSDKCall(SDKCall_Player);
        if (!PrepSDKCall_SetFromConf(SDK_GetGameConf(), SDKConf_Signature, "CTerrorPlayer::WarpToValidPositionIfStuck")) {
            return -1;
        }
        WarpToValidPosition = EndPrepSDKCall();
    }
    return SDKCall(WarpToValidPosition, iClient, false);
}

/**
 * Returns true if specified player is stumbled
 * @return bool
 */
stock bool SDK_IsStaggering(int iClient) {
    static Handle IsStaggering = null;
    if (IsStaggering == null) {
        StartPrepSDKCall(SDKCall_Player);
        if (!PrepSDKCall_SetFromConf(SDK_GetGameConf(), SDKConf_Signature, "CTerrorPlayer::IsStaggering")) {
            return false;
        }
        PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
        IsStaggering = EndPrepSDKCall();
    }
    return SDKCall(IsStaggering, iClient);
}

/**
 * Make a player to be idle on marked bot
 * @return int
 */
stock int SDK_SetHumanSpectator(int iBot, int iClient) {
    static Handle SeHumanSpectator = null;
    if (SeHumanSpectator == null) {
        StartPrepSDKCall(SDKCall_Player);
        if (!PrepSDKCall_SetFromConf(SDK_GetGameConf(), SDKConf_Signature, "SurvivorBot::SetHumanSpectator")) {
            return -1;
        }
        PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
        SeHumanSpectator = EndPrepSDKCall();
    }
    return SDKCall(SeHumanSpectator, iBot, iClient);
}

/**
 * Removes touch links for player
 * @return int
 */
stock int SDK_PhysicsRemoveTouchedList(int iClient) {
    static Handle PhysicsRemoveTouchedList = null;
    if (PhysicsRemoveTouchedList == null) {
        StartPrepSDKCall(SDKCall_Static);
        if (!PrepSDKCall_SetFromConf(SDK_GetGameConf(), SDKConf_Signature, "CBaseEntity::PhysicsRemoveTouchedList")) {
            return -1;
        }
        PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
        PhysicsRemoveTouchedList = EndPrepSDKCall();
    }
    return SDKCall(PhysicsRemoveTouchedList, iClient);
}

/**
 * Fills ammo to player
 * @return int
 */
stock int SDK_AmmoSpawnUse(int iClient) {
    static Handle AmmoSpawnUse = null;
    if (AmmoSpawnUse == null) {
        StartPrepSDKCall(SDKCall_Entity);
        if (!PrepSDKCall_SetFromConf(SDK_GetGameConf(), SDKConf_Signature, "CWeaponAmmoSpawn::Use")) {
            return -1;
        }
        PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
        AmmoSpawnUse = EndPrepSDKCall();
    }
    return SDKCall(AmmoSpawnUse, 0, iClient);
}

/**
 * Force pummeling charger to drop victim
 * @return int
 */
stock int SDK_OnPummelEnd(int iClient, int iTarget) {
    static Handle OnPummelEnd = null;
    if (OnPummelEnd == null) {
        StartPrepSDKCall(SDKCall_Player);
        if (!PrepSDKCall_SetFromConf(SDK_GetGameConf(), SDKConf_Signature, "CTerrorPlayer::OnPummelEnded")) {
            return -1;
        }
        PrepSDKCall_AddParameter(SDKType_String,      SDKPass_ByRef);
        PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
        OnPummelEnd = EndPrepSDKCall();
    }
    return SDKCall(OnPummelEnd, iClient, "", iTarget);
}