#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <solaris/votes>
#include <solaris/stocks>

ConVar g_cvMinSurvivors;
ConVar g_cvMaxSurvivors;

SolarisVote
    g_votePlayerMode;

int g_iDesiredPlayerMode;

public Plugin myinfo = {
    name        = "Player Mode",
    author      = "breezy",
    description = "Allows survivors to change the team limit and adapts gameplay cvars to these changes",
    version     = "1.0",
    url         = "https://github.com/brxce/Gauntlet"
};

public void OnPluginStart() {
    g_cvMinSurvivors = CreateConVar(
    "pm_min_survivors", "1",
    "Minimum number of survivors allowed in the game",
    FCVAR_NONE, true, 1.0, true, 4.0);

    g_cvMaxSurvivors = CreateConVar(
    "pm_max_survivors", "4",
    "Maximum number of survivors allowed in the game",
    FCVAR_NONE, true, 1.0, true, 4.0);

    RegConsoleCmd("sm_playermode", Cmd_PlayerMode, "Change the number of survivors and adapt appropriatel");

    g_votePlayerMode = (new SolarisVote()).ForSurvivors()
                                          .RestrictToGamemodes(GM_COOP | GM_SURVIVAL)
                                          .RestrictToBeforeRoundStart()
                                          .OnSuccess(VoteCallback_PlayerMode);
}

public void OnAllPluginsLoaded() {
    LoadCvars(FindConVar("survivor_limit").IntValue);
}

public void OnPluginEnd() {
    // Survivors
    ResetConVarEx(FindConVar("survivor_limit"));

    // Common
    ResetConVarEx(FindConVar("z_common_limit"));
    ResetConVarEx(FindConVar("z_mob_spawn_min_size"));
    ResetConVarEx(FindConVar("z_mob_spawn_max_size"));
    ResetConVarEx(FindConVar("z_mega_mob_size"));

    // SI
    ResetConVarEx(FindConVar("z_tank_health"));
    ResetConVarEx(FindConVar("z_jockey_ride_damage"));
    ResetConVarEx(FindConVar("z_pounce_damage"));

    // Incap Count
    ResetConVarEx(FindConVar("survivor_ledge_grab_health"));
    ResetConVarEx(FindConVar("survivor_max_incapacitated_count"));
}

Action Cmd_PlayerMode(int iClient, int iArgs) {
    if (iArgs == 0) {
        CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} Usage: {olive}!playermode {green}<{default}value{green}>{default} [ {olive}1{default} <= value <= {olive}%i{default} ].", g_cvMaxSurvivors.IntValue);
        return Plugin_Handled;
    }

    static char szValue[32];
    GetCmdArg(1, szValue, sizeof(szValue));

    static int iValue;
    iValue = StringToInt(szValue);

    if (iValue < g_cvMinSurvivors.IntValue)
        iValue = g_cvMinSurvivors.IntValue;

    if (iValue > g_cvMaxSurvivors.IntValue)
        iValue = g_cvMaxSurvivors.IntValue;

    if (iValue == FindConVar("survivor_limit").IntValue) {
        CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} Player mode {teamcolor}%i{default} is already loaded.", iValue);
        return Plugin_Handled;
    }

    if (iValue < GetTeamSurvivorCount()) {
        CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} Too many players to reduce survivor limit!");
        return Plugin_Handled;
    }

    // prepare vote title
    static char szVotePrint[64];
    Format(szVotePrint, sizeof(szVotePrint), "changing player mode to {olive}%d{default}.", iValue);

    static char szVoteTitle[64];
    Format(szVoteTitle, sizeof(szVoteTitle), "Change player mode to %d?", iValue);

    static char szVotePassed[64];
    Format(szVotePassed, sizeof(szVotePassed), "Player mode changed to %d", iValue);

    g_votePlayerMode.SetPrint(szVotePrint)
                    .SetTitle(szVoteTitle)
                    .SetSuccessMessage(szVotePassed);

    // start vote
    bool bStarted = g_votePlayerMode.Start(iClient);
    if  (bStarted) g_iDesiredPlayerMode = iValue;

    return Plugin_Handled;
}

void VoteCallback_PlayerMode() {
    if (g_iDesiredPlayerMode < GetTeamSurvivorCount()) {
        CPrintToChatAll("{blue}[{default}Vote{blue}]{default} Too many players to reduce survivor limit!");
        g_iDesiredPlayerMode = GetTeamSurvivorCount();

        if (g_iDesiredPlayerMode == FindConVar("survivor_limit").IntValue) {
            CPrintToChatAll("{blue}[{default}Vote{blue}]{default} Current player mode is equal to current amount of players.");
        } else {
            CPrintToChatAll("{blue}[{default}Vote{blue}]{default} Loading player mode {blue}%i{default}.", g_iDesiredPlayerMode);
            LoadCvars(g_iDesiredPlayerMode);
        }
    } else {
        CPrintToChatAll("{blue}[{default}Vote{blue}]{default} Loading player mode {blue}%i{default}.", g_iDesiredPlayerMode);
        LoadCvars(g_iDesiredPlayerMode);
    }
}

void LoadCvars(int iMode) {
    static char szFolder[PLATFORM_MAX_PATH];
    if (strlen(szFolder) == 0) {
        GetGameFolderName(szFolder, sizeof(szFolder));
        BuildPath(Path_SM, szFolder, PLATFORM_MAX_PATH, "configs/playermode_cvars.txt");
    }

    static KeyValues kv;
    if (kv == null) {
        kv = new KeyValues("Cvars");
        if (!kv.ImportFromFile(szFolder))
            SetFailState("Couldn't load playermode_cvars.txt!");
    }
    kv.Rewind();

    static char szMode[16];
    IntToString(iMode, szMode, sizeof(szMode));

    if (kv.JumpToKey(szMode)) {
        if (kv.GotoFirstSubKey()) {
            do {
                static char szConVar[64];
                kv.GetSectionName(szConVar, sizeof(szConVar));

                if (FindConVar(szConVar) != null) {
                    static char szVarType[64];
                    kv.GetString("type", szVarType, sizeof(szVarType));

                    if (strcmp(szVarType, "int") == 0) {
                        FindConVar(szConVar).SetInt(kv.GetNum("value", -1));
                    } else if (strcmp(szVarType, "float") == 0) {
                        FindConVar(szConVar).SetFloat(kv.GetFloat("value", -1.0));
                    } else if (strcmp(szVarType, "string") == 0) {
                        static char szValue[128];
                        kv.GetString("value", szValue, sizeof(szValue), "Invalid String");
                        FindConVar(szConVar).SetString(szValue);
                    }
                }
            } while (kv.GotoNextKey(true));
        }
    }
}

int GetTeamSurvivorCount() {
    int iSurv = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i)) {
            if (HasIdlePlayer(i))
                iSurv++;
            continue;
        }

        if (GetClientTeam(i) != 2)
            continue;

        iSurv++;
    }

    return iSurv;
}

stock bool HasIdlePlayer(int iBot) {
    return GetEntData(iBot, FindSendPropInfo("SurvivorBot", "m_humanSpectatorUserID")) > 0;
}