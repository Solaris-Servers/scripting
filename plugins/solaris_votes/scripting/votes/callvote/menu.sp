#if defined __solaris_votes_callvote_menu_included
    #endinput
#endif
#define __solaris_votes_callvote_menu_included

StringMap smCampaigns;
StringMap smExcludeMissions;

#define CHANGE_CHAPTER    0
#define CHANGE_DIFFICULTY 1
#define CHANGE_MISSION    2
#define RESTART_GAME      3
#define CHANGE_ALLTALK    4

char szValveCampaigns[][][] = {
    {"L4D2C1",  "Dead Center"   },
    {"L4D2C2",  "Dark Carnival" },
    {"L4D2C3",  "Swamp Fever"   },
    {"L4D2C4",  "Hard Rain"     },
    {"L4D2C5",  "The Parish"    },
    {"L4D2C6",  "The Passing"   },
    {"L4D2C7",  "The Sacrifice" },
    {"L4D2C8",  "No Mercy"      },
    {"L4D2C9",  "Crash Course"  },
    {"L4D2C10", "Death Toll"    },
    {"L4D2C11", "Dead Air"      },
    {"L4D2C12", "Blood Harvest" },
    {"L4D2C13", "Cold Stream"   },
    {"L4D2C14", "The Last Stand"}
};

void MenuInit() {
    // List of Valve campaigns
    smCampaigns = new StringMap();
    for (int i = 0; i < sizeof(szValveCampaigns); i++) {
        // reads from string that looks like "L4D2C12" only the campaign number after "L4D2C" part ("12")
        char szMissionNum[4];
        strcopy(szMissionNum, sizeof(szMissionNum), szValveCampaigns[i][0][5]);
        
        char szMissionName[32];
        FormatEx(szMissionName, sizeof(szMissionName), "#L4D360UI_CampaignName_C%s", szMissionNum);
        smCampaigns.SetString(szMissionName, szValveCampaigns[i][1]);
    }
    
    // List of excluded missions
    smExcludeMissions = new StringMap();
    smExcludeMissions.SetValue("credits",          1);
    smExcludeMissions.SetValue("HoldoutChallenge", 1);
    smExcludeMissions.SetValue("HoldoutTraining",  1);
    smExcludeMissions.SetValue("parishdash",       1);
    smExcludeMissions.SetValue("shootzones",       1);
}

// ------------
// Menus Stuff
// ------------

// Core
void CreateVoteManagerMenu(int iClient) {
    Menu mMenu = new Menu(Menu_VoteManager);

    mMenu.SetTitle(
    "Select a vote to start:");

    mMenu.AddItem(
    "returntolobby", "Return to lobby");

    mMenu.AddItem(
    "votekick", "Kick a player");

    mMenu.AddItem(
    "changechapter", "Change a chapter",
    IsVoteEnabled(CHANGE_CHAPTER) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

    mMenu.AddItem(
    "changedifficulty", "Change a difficulty",
    IsVoteEnabled(CHANGE_DIFFICULTY) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

    mMenu.AddItem(
    "changemission", "Change a campaign",
    IsVoteEnabled(CHANGE_MISSION) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

    mMenu.AddItem(
    "restartgame", "Restart the game",
    IsVoteEnabled(RESTART_GAME) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

    mMenu.AddItem(
    "changealltalk", "Change all talk",
    IsVoteEnabled(CHANGE_ALLTALK) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

    // Display Menu
    mMenu.Display(iClient, MENU_TIME_FOREVER);
}

bool IsVoteEnabled(int iVote) {
    static bool bEnabled = false;
    bEnabled = false;

    switch (iVote) {
        case CHANGE_CHAPTER: {
            if (SDK_IsScavenge() || SDK_IsSurvival())
                bEnabled = true;

            if (g_bIsSurf)
                bEnabled = false;

            if (TM_IsReserved())
                bEnabled = false;

            if (g_bIsPracticogl)
                bEnabled = true;
        }
        case CHANGE_DIFFICULTY: {
            if (SDK_IsCoop() || SDK_IsRealism() || strcmp(g_gmBase, "holdout") == 0 || strcmp(g_gmBase, "dash") == 0 || strcmp(g_gmBase, "shootzones") == 0)
                bEnabled = true;

            if (g_bIsSurf)
                bEnabled = false;

            if (g_bIsGauntlet)
                bEnabled = false;
        }
        case CHANGE_MISSION: {
            if (SDK_IsVersus() || SDK_IsCoop() || SDK_IsRealism())
                bEnabled = true;

            if (g_bIsSurf)
                bEnabled = false;

            if (TM_IsReserved())
                bEnabled = false;
        }
        case RESTART_GAME: {
            if (SDK_IsVersus() || SDK_IsCoop() || SDK_IsSurvival() || SDK_IsRealism() || strcmp(g_gmBase, "holdout") == 0 || strcmp(g_gmBase, "dash") == 0 || strcmp(g_gmBase, "shootzones") == 0)
                bEnabled = true;

            if (g_bIsSurf)
                bEnabled = false;
        }
        case CHANGE_ALLTALK: {
            if (SDK_IsVersus() || SDK_IsScavenge())
                bEnabled = true;
        }
    }

    return bEnabled;
}

int Menu_VoteManager(Menu mMenu, MenuAction maAction, int iClient, int iParam2) {
    if (maAction == MenuAction_Select) {
        switch (iParam2) {
            case 0: CreateReturnToLobbyMenu(iClient);
            case 1: CreateVoteKickMenu(iClient);
            case 2: CreateChangeChapterMenu(iClient);
            case 3: CreateChangeDifficultyMenu(iClient);
            case 4: CreateChangeMissionMenu(iClient);
            case 5: CreateRestartGameMenu(iClient);
            case 6: CreateChangeAllTalkMenu(iClient);
        }
    }
    if (maAction ==  MenuAction_End)
        delete mMenu;
    return 0;
}

// Return to lobby
void CreateReturnToLobbyMenu(int iClient) {
    Menu mMenu = new Menu(Menu_VoteReturnToLobby);
    mMenu.SetTitle("Are you sure you want to start a vote for returning to lobby?");
    mMenu.AddItem("yes", "Yes");
    mMenu.AddItem("no",  "No");
    mMenu.Display(iClient, MENU_TIME_FOREVER);
}

int Menu_VoteReturnToLobby(Menu mMenu, MenuAction maAction, int iClient, int iParam2) {
    switch (maAction) {
        case MenuAction_Select: {
            char szCVArg[128];
            if (mMenu.GetItem(iParam2, szCVArg, sizeof(szCVArg))) {
                if (strcmp(szCVArg, "yes", false) == 0) {
                    ReturnToLobbyVote(iClient);
                } else if (strcmp(szCVArg, "no", false) == 0) {
                    CreateVoteManagerMenu(iClient);
                }
            }
        }
        case MenuAction_End: {
            delete mMenu;
        }
    }
    return 0;
}

// Kick Vote
Action Cmd_VoteKick(int iClient, int iArgs) {
    if (iClient <= 0)
        return Plugin_Handled;
    
    if (!IsClientInGame(iClient))
        return Plugin_Handled;
    
    if (ST_IsSpecClient(iClient))
        return Plugin_Handled;
    
    if (TM_IsPlayerRespectating(iClient))
        return Plugin_Handled;
    
    CreateVoteKickMenu(iClient);
    return Plugin_Handled;
}

void CreateVoteKickMenu(int iClient) {
    if (GetTeamHumanCount(GetClientTeam(iClient)) < 3 && g_cvSurvivorLimit.IntValue != 2 && g_cvInfectedLimit.IntValue != 2) {
        CPrintToChatEx(iClient, iClient, "{teamcolor}You{default} cannot start a vote for {olive}kicking a player{default}. Not enough players {teamcolor}in your team{default}!");
        return;
    }

    Menu mMenu = new Menu(Menu_VoteKick);
    int iTeam = GetClientTeam(iClient);

    char szName[MAX_NAME_LENGTH];
    char szUserId[256];

    mMenu.SetTitle("Select a player to kick:");

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;
        
        if (IsFakeClient(i))
            continue;
        
        if (i == iClient)
            continue;
        
        if (GetClientTeam(i) == iTeam) {
            FormatEx(szUserId, sizeof(szUserId), "%i", GetClientUserId(i));
            
            if (GetClientName(i, szName, sizeof(szName)))
                mMenu.AddItem(szUserId, szName);
        }
    }

    mMenu.ExitBackButton = true;
    mMenu.Display(iClient, MENU_TIME_FOREVER);
}

int Menu_VoteKick(Menu mMenu, MenuAction maAction, int iClient, int iParam2) {
    switch (maAction) {
        case MenuAction_Select: {
            char szUserId[256];
            if (mMenu.GetItem(iParam2, szUserId, sizeof(szUserId)))
                KickVote(iClient, szUserId);
        }
        case MenuAction_End: {
            delete mMenu;
        }
        case MenuAction_Cancel: {
            if (iParam2 == MenuCancel_ExitBack)
                CreateVoteManagerMenu(iClient);
        }
    }
    return 0;
}

// Change a Map
void CreateChangeChapterMenu(int iClient) {
    if ((!g_bIsSurf && (SDK_IsScavenge() || SDK_IsSurvival())) || g_bIsPracticogl) {
        Menu mMenu = new Menu(Menu_VoteChangeChapter);
        mMenu.SetTitle("Select a campaign:");
        int iDummy;
        static char szSubName[256], szTitle[256], szKey[256];
        SourceKeyValues kvDummy;
        SourceKeyValues kvMissions = kvDummy.GetAllMissions();
        for (SourceKeyValues kvSub = kvMissions.GetFirstTrueSubKey(); !kvSub.IsNull(); kvSub = kvSub.GetNextTrueSubKey()) {
            kvSub.GetName(szSubName, sizeof(szSubName));
            if (smExcludeMissions.GetValue(szSubName, iDummy))
                continue;
            
            FormatEx(szKey, sizeof(szKey), "modes/%s", g_szGameMode);
            if (kvSub.FindKey(szKey).IsNull())
                continue;
            
            if (!kvSub.GetInt("builtin"))
                continue;
            
            kvSub.GetString("DisplayTitle", szTitle, sizeof(szTitle), "N/A");
            smCampaigns.GetString(szTitle, szTitle, sizeof(szTitle));
            mMenu.AddItem(szSubName, szTitle);
        }
        
        mMenu.ExitBackButton = true;
        mMenu.Display(iClient, MENU_TIME_FOREVER);
    }
}

int Menu_VoteChangeChapter(Menu mMenu, MenuAction maAction, int iClient, int iParam2) {
    switch (maAction) {
        case MenuAction_Select: {
            static char szSubName[256];
            if (mMenu.GetItem(iParam2, szSubName, sizeof(szSubName)))
                CreateChangeChapterSubMenu(iClient, szSubName);
        }
        case MenuAction_End: {
            delete mMenu;
        }
        case MenuAction_Cancel: {
            if (iParam2 == MenuCancel_ExitBack)
                CreateVoteManagerMenu(iClient);
        }
    }
    return 0;
}

void CreateChangeChapterSubMenu(int iClient, const char[] szSubName) {
    Menu mMenu = new Menu(SubMenu_VoteChangeChapter);
    mMenu.SetTitle("Select a chapter:");
    static char szMap[256], szMapName[256], szKey[256], szGmBaseUpper[16], szMapNameUpper[16], szUIChaptername[64];
    FormatEx(szKey, sizeof(szKey), "%s/modes/%s", szSubName, g_szGameMode);
    SourceKeyValues kvDummy;
    SourceKeyValues kvMissions = kvDummy.GetAllMissions();
    SourceKeyValues kvChapters = kvMissions.FindKey(szKey);
    if (!kvChapters.IsNull()) {
        for (SourceKeyValues kvSub = kvChapters.GetFirstTrueSubKey(); !kvSub.IsNull(); kvSub = kvSub.GetNextTrueSubKey()) {
            kvSub.GetString("Map", szMap, sizeof(szMap), "N/A");
            ST_StrToUpper(g_gmBase, szGmBaseUpper,  sizeof(szGmBaseUpper));
            ST_StrToUpper(szMap,    szMapNameUpper, sizeof(szMapNameUpper));
            SplitString(szMapNameUpper, "_", szMapNameUpper, sizeof(szMapNameUpper));
            FormatEx(szUIChaptername, sizeof(szUIChaptername), "#L4D360UI_LevelName_%s_%s", szGmBaseUpper, szMapNameUpper);
            FormatEx(szMapName, sizeof(szMapName), "%t [%s]", szUIChaptername[1], szMap)
            mMenu.AddItem(szMap, szMapName);
        }
    }
    mMenu.ExitBackButton = true;
    mMenu.Display(iClient, MENU_TIME_FOREVER);
}

int SubMenu_VoteChangeChapter(Menu mMenu, MenuAction maAction, int iClient, int iParam2) {
    switch (maAction) {
        case MenuAction_Select: {
            static char szMap[256];
            if (mMenu.GetItem(iParam2, szMap, sizeof(szMap)))
                ChangeChapterVote(iClient, szMap, false);
        }
        case MenuAction_End: {
            delete mMenu;
        }
        case MenuAction_Cancel: {
            if (iParam2 == MenuCancel_ExitBack)
                CreateChangeChapterMenu(iClient);
        }
    }
    return 0;
}

// Change a difficulty
void CreateChangeDifficultyMenu(int iClient) {
    if (!g_bIsSurf && !g_bIsGauntlet && (SDK_IsCoop() || SDK_IsRealism() || strcmp(g_gmBase, "holdout") == 0 || strcmp(g_gmBase, "dash") == 0 || strcmp(g_gmBase, "shootzones") == 0)) {
        Menu mMenu = new Menu(Menu_VoteChangeDifficulty);
        mMenu.SetTitle("Select a difficulty:");
        mMenu.AddItem("Easy",       "Easy");
        mMenu.AddItem("Normal",     "Normal");
        mMenu.AddItem("Hard",       "Hard");
        mMenu.AddItem("Impossible", "Expert");
        mMenu.ExitBackButton = true;
        mMenu.Display(iClient, MENU_TIME_FOREVER);
    }
}

int Menu_VoteChangeDifficulty(Menu mMenu, MenuAction maAction, int iClient, int iParam2) {
    switch (maAction) {
        case MenuAction_Select: {
            char szCVArg[128];
            if (mMenu.GetItem(iParam2, szCVArg, sizeof(szCVArg)))
                ChangeDifficultyVote(iClient, szCVArg);
        }
        case MenuAction_End: {
            delete mMenu;
        }
        case MenuAction_Cancel: {
            if (iParam2 == MenuCancel_ExitBack)
                CreateVoteManagerMenu(iClient);
        }
    }
    return 0;
}

// Change a campaign
void CreateChangeMissionMenu(int iClient) {
    if (!g_bIsSurf && (SDK_IsVersus() || SDK_IsCoop() || SDK_IsRealism())) {
        Menu mMenu = new Menu(Menu_VoteChangeCampaign);
        mMenu.SetTitle("Select a campaign:");
        for (int i; i < sizeof(szValveCampaigns); i++) {
            mMenu.AddItem(szValveCampaigns[i][0], szValveCampaigns[i][1]);
        }
        mMenu.ExitBackButton = true;
        mMenu.Display(iClient, MENU_TIME_FOREVER);
    }
}

int Menu_VoteChangeCampaign(Menu mMenu, MenuAction maAction, int iClient, int iParam2) {
    switch (maAction) {
        case MenuAction_Select: {
            char szCVArg[128];
            if (mMenu.GetItem(iParam2, szCVArg, sizeof(szCVArg)))
                ChangeMissionVote(iClient, szCVArg);
        }
        case MenuAction_End: {
            delete mMenu;
        }
        case MenuAction_Cancel: {
            if (iParam2 == MenuCancel_ExitBack)
                CreateVoteManagerMenu(iClient);
        }
    }
    return 0;
}

// Restart the Game
void CreateRestartGameMenu(int iClient) {
    if (!g_bIsSurf && (SDK_IsVersus() || SDK_IsCoop() || SDK_IsSurvival() || SDK_IsRealism() || strcmp(g_gmBase, "holdout") == 0 || strcmp(g_gmBase, "dash") == 0 || strcmp(g_gmBase, "shootzones") == 0)) {
        Menu mMenu = new Menu(Menu_VoteRestartGame);
        mMenu.SetTitle("Are you sure you want to start a vote for restarting the game?");
        mMenu.AddItem("yes", "Yes");
        mMenu.AddItem("no",  "No");
        mMenu.Display(iClient, MENU_TIME_FOREVER);
    }
}

int Menu_VoteRestartGame(Menu mMenu, MenuAction maAction, int iClient, int iParam2) {
    switch (maAction) {
        case MenuAction_Select: {
            char szCVArg[128];
            if (mMenu.GetItem(iParam2, szCVArg, sizeof(szCVArg))) {
                if (strcmp(szCVArg, "yes", false) == 0) {
                    RestartGameVote(iClient);
                } else if (strcmp(szCVArg, "no", false) == 0) {
                    CreateVoteManagerMenu(iClient);
                }
            }
        }
        case MenuAction_End: {
            delete mMenu;
        }
    }
    return 0;
}

// Change All Talk
void CreateChangeAllTalkMenu(int iClient) {
    if (SDK_IsVersus() || SDK_IsScavenge()) {
        Menu mMenu = new Menu(Menu_VoteChangeAllTalk);
        mMenu.SetTitle("Are you sure you want to start a vote for changing all talk?");
        mMenu.AddItem("yes", "Yes");
        mMenu.AddItem("no",  "No");
        mMenu.Display(iClient, MENU_TIME_FOREVER);
    }
}

int Menu_VoteChangeAllTalk(Menu mMenu, MenuAction maAction, int iClient, int iParam2) {
    switch (maAction) {
        case MenuAction_Select: {
            char szCVArg[128];
            if (mMenu.GetItem(iParam2, szCVArg, sizeof(szCVArg))) {
                if (strcmp(szCVArg, "yes", false) == 0) {
                    ChangeAllTalkVote(iClient);
                } else if (strcmp(szCVArg, "no", false) == 0) {
                    CreateVoteManagerMenu(iClient);
                }
            }
        }
        case MenuAction_End: {
            delete mMenu;
        }
    }
    return 0;
}