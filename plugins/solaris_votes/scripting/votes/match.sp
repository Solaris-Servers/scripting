#if defined __solaris_votes_match_included
    #endinput
#endif
#define __solaris_votes_match_included

#define MATCHMODES_FILE "configs/matchmodes.txt"
#define CFGOGL_PATH     "cfg/cfgogl/"

SolarisVote voteMatch;
SolarisVote voteRMatch;

KeyValues kvMatchmodes;

char szMatchCfgAlias[64];

void Match_OnPluginStart() {
    voteMatch  = (new SolarisVote()).SetRequiredVotes(RV_MAJORITY)
                                    .SetSuccessMessage("Confogl is loading...")
                                    .OnSuccess(Callback_Match_StartMatch);

    voteRMatch = (new SolarisVote()).SetRequiredVotes(RV_MAJORITY)
                                    .SetPrint("turning off confogl.")
                                    .SetTitle("Turn off confogl?")
                                    .SetSuccessMessage("Confogl is resetting...")
                                    .OnSuccess(Callback_Match_ResetMatch);

    Match_ReadMatchmodesTxt();

    RegConsoleCmd("sm_match",  Cmd_Match_StartMatch);
    RegConsoleCmd("sm_rmatch", Cmd_Match_ResetMatch);
}

/**
 * Reads Matchmodes KeyValues from sourcemod/configs/matchmodes.txt
 */
void Match_ReadMatchmodesTxt() {
    char szMatchmodesPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, szMatchmodesPath, sizeof(szMatchmodesPath), MATCHMODES_FILE);

    kvMatchmodes = new KeyValues("MatchModes");
    if (!kvMatchmodes.ImportFromFile(szMatchmodesPath)) {
        SetFailState("Couldn't load sourcemod/configs/matchmodes.txt");
    }
}

Action Cmd_Match_StartMatch(int iClient, int iArgs) {
    if (TM_IsReserved())
        return Plugin_Handled;

    if (iClient <= 0)
        return Plugin_Handled;

    if (!IsClientInGame(iClient))
        return Plugin_Handled;

    if (iArgs > 0) {
        char szCfgAlias[64];
        GetCmdArg(1, szCfgAlias, sizeof(szCfgAlias));
        Match_StartMatch(iClient, szCfgAlias);
        return Plugin_Handled;
    }

    Match_OpenMatchMenu(iClient);
    return Plugin_Handled;
}

void Match_StartMatch(int iClient, char[] szCfgAlias) {
    char szCfgPath[PLATFORM_MAX_PATH];

    StrCat(szCfgPath, sizeof(szCfgPath), CFGOGL_PATH);
    StrCat(szCfgPath, sizeof(szCfgPath), szCfgAlias);

    ReplaceString(szCfgAlias, sizeof(szCfgPath), "\\", "");
    ReplaceString(szCfgAlias, sizeof(szCfgPath), "/",  "");

    // config path does not exist
    if (!DirExists(szCfgPath) || strcmp(szCfgAlias, "..") == 0) {
        CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} Config {olive}%s{default} not found.", szCfgAlias);
        return;
    }

    char szCfgName[32];
    Match_GetConfigName(szCfgName, sizeof(szCfgName), szCfgAlias);

    char szVotePrint[64];
    char szVoteTitle[64];
    if (g_bConfoglAvailable && LGO_IsMatchModeLoaded()) {
        FormatEx(szVotePrint, sizeof(szVotePrint), "changing config to \"{olive}%s{default}\".", szCfgName);
        FormatEx(szVoteTitle, sizeof(szVoteTitle), "Change config to \"%s\"?", szCfgName);
    } else {
        FormatEx(szVotePrint, sizeof(szVotePrint), "loading \"{olive}%s{default}\" config.", szCfgName);
        FormatEx(szVoteTitle, sizeof(szVoteTitle), "Load \"%s\" config", szCfgName);
    }

    strcopy(szMatchCfgAlias, sizeof(szMatchCfgAlias), szCfgAlias);
    voteMatch.SetPrint(szVotePrint)
             .SetTitle(szVoteTitle)
             .Start(iClient);
}

void Callback_Match_StartMatch() {
    ServerCommand("sm_forcematch %s", szMatchCfgAlias);
    strcopy(szMatchCfgAlias, sizeof(szMatchCfgAlias), "");
}

void Match_OpenMatchMenu(int iClient) {
    Menu mMatchMenu = new Menu(Handler_Match_StartMatchMenu);

    bool bLoaded = g_bConfoglAvailable && LGO_IsMatchModeLoaded() && FindConVar("l4d_ready_cfg_name") != null;
    char szMenuTitle[128];
    if (bLoaded) {
        char szReadyCfgName[64];
        FindConVar("l4d_ready_cfg_name").GetString(szReadyCfgName, sizeof(szReadyCfgName));
        FormatEx(szMenuTitle, sizeof(szMenuTitle), "Current config: \"%s\"\nSelect another match mode:\n ", szReadyCfgName);
    } else {
        FormatEx(szMenuTitle, sizeof(szMenuTitle), "Select a match mode:\n ");
    }

    mMatchMenu.SetTitle(szMenuTitle)
    mMatchMenu.AddItem("sm_rmatch", "Reset match [!rmatch]\n ", bLoaded ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

    kvMatchmodes.Rewind();

    char szMenuItem[64];
    if (kvMatchmodes.GotoFirstSubKey()) {
        do {
            kvMatchmodes.GetSectionName(szMenuItem, sizeof(szMenuItem));
            mMatchMenu.AddItem(szMenuItem, szMenuItem);
        } while (kvMatchmodes.GotoNextKey());
    }

    mMatchMenu.Display(iClient, MENU_TIME_FOREVER);
}

int Handler_Match_StartMatchMenu(Menu mMatchMenu, MenuAction maAction, int iClient, int iParam2) {
    if (maAction == MenuAction_End)
        delete mMatchMenu;
    // on select - open config submenu
    if (maAction == MenuAction_Select) {
        char szMenuSelection[32];
        mMatchMenu.GetItem(iParam2, szMenuSelection, sizeof(szMenuSelection));

        if (strcmp(szMenuSelection, "sm_rmatch") == 0) {
            ClientCommand(iClient, "sm_rmatch");
            return 0;
        }

        kvMatchmodes.Rewind();
        if (kvMatchmodes.JumpToKey(szMenuSelection) && kvMatchmodes.GotoFirstSubKey()) {
            // if sub-section contains any keys, create another menu
            char szMenuTitle[128];
            char szReadyCFGname[64];
            char szMenuItem[32];
            Menu mMatchSubMenu = new Menu(Handler_Match_StartMatchSubMenu);
            if (g_bConfoglAvailable && LGO_IsMatchModeLoaded() && FindConVar("l4d_ready_cfg_name") != null) {
                FindConVar("l4d_ready_cfg_name").GetString(szReadyCFGname, sizeof(szReadyCFGname));
                FormatEx(szMenuTitle, sizeof(szMenuTitle), "Current config: \"%s\"\nSelect another config:\n ", szReadyCFGname);
            } else {
                FormatEx(szMenuTitle, sizeof(szMenuTitle), "Select a config:\n ");
            }
            mMatchSubMenu.SetTitle(szMenuTitle);
            do {
                kvMatchmodes.GetSectionName(szMenuSelection, sizeof(szMenuSelection));
                kvMatchmodes.GetString("name", szMenuItem, sizeof(szMenuItem));
                mMatchSubMenu.AddItem(szMenuSelection, szMenuItem);
            } while(kvMatchmodes.GotoNextKey());

            // display menu
            mMatchSubMenu.ExitBackButton = true;
            mMatchSubMenu.Display(iClient, MENU_TIME_FOREVER);
        } else {
            // if no keys in sub-section - notify client
            CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} No configs for selected mode were found.");
            Match_OpenMatchMenu(iClient);
        }
    }

    return 0;
}

int Handler_Match_StartMatchSubMenu(Menu mMatchSubMenu, MenuAction maAction, int iClient, int iParam2) {
    switch(maAction) {
        case MenuAction_End:
            delete mMatchSubMenu;
        case MenuAction_Cancel:
            if (iParam2 == MenuCancel_ExitBack)
                Match_OpenMatchMenu(iClient);
        case MenuAction_Select: {
            char szCfgAlias[64];
            mMatchSubMenu.GetItem(iParam2, szCfgAlias, sizeof(szCfgAlias));
            Match_StartMatch(iClient, szCfgAlias);
        }
    }
    return 0;
}

Action Cmd_Match_ResetMatch(int iClient, int args) {
    if (TM_IsReserved())
        return Plugin_Handled;

    if (iClient <= 0)
        return Plugin_Handled;

    if (!IsClientInGame(iClient))
        return Plugin_Handled;

    if (g_bConfoglAvailable && LGO_IsMatchModeLoaded()) {
        voteRMatch.Start(iClient);
        return Plugin_Handled;
    }

    CPrintToChatEx(iClient, iClient, "{teamcolor}[{default}Vote{teamcolor}]{default} No match is running.");
    return Plugin_Handled;
}

void Callback_Match_ResetMatch() {
    ServerCommand("sm_resetmatch");
    strcopy(szMatchCfgAlias, sizeof(szMatchCfgAlias), "");
}

/**
 * Read MatchModes KeyValues and attempt to extract "name" value matching config key-name into a passed string buffer
 *
 * @param szBuffer      Buffer to write config name to (if not found in Matchmodes file, szCfgAlias is used)
 * @param length        Buffer max length
 * @param szCfgAlias    Alias name (key) of the config in matchmodes file
 * @return was
 */
bool Match_GetConfigName(char[] szBuffer, int length, const char[] szCfgAlias) {
    kvMatchmodes.Rewind();

    if (kvMatchmodes.GotoFirstSubKey()) {
        do {
            if (kvMatchmodes.JumpToKey(szCfgAlias)) {
                kvMatchmodes.GetString("name", szBuffer, length, szCfgAlias);
                return true;
            }
        } while (kvMatchmodes.GotoNextKey());
    }

    strcopy(szBuffer, length, szCfgAlias); // set default value to szCfgAlias, in case no name was found
    return false;
}