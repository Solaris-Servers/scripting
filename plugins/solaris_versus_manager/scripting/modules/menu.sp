#if defined __MENU__
    #endinput
#endif
#define __MENU__

#define MAXVALUE 10

#include <solaris/team_manager>

void OnModuleStart_Menu() {
    RegConsoleCmd("sm_settings", Cmd_Settings, "Opens the Voting menu");
}

Action Cmd_Settings(int iClient, int iArgs) {
    // Don't care about non-loaded players or Spectators.
    if (iClient <= 0 || GetClientTeam(iClient) == 1 || TM_IsPlayerRespectating(iClient))
        return Plugin_Handled;

    if (GetCurrentMainMode() == NONE)
        return Plugin_Handled;

    for (int i = 0; i < eSettingsSize; i++) {
        ClientSettings(iClient, true, i, -1);
    }

    // Show the Menu.
    CreateSettingsMenu(iClient);
    return Plugin_Handled;
}

void CreateSettingsMenu(int iClient) {
    char szBuffer[64];

    Menu mMenu = new Menu(Menu_SettingsMenuHandler);
    mMenu.SetTitle("Choose settings:\n ");
    mMenu.AddItem("Start", "Start the vote", SettingsWereChanged(iClient) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

    if (ClientSettings(iClient, false, ePunchRockBlock) == -1)   Format(szBuffer, sizeof(szBuffer), "Punch Rock [%s]",       BlockPunchRock() ? "Disabled" : "Enabled");
    else                                                         Format(szBuffer, sizeof(szBuffer), "Punch Rock [%s >> %s]", BlockPunchRock() ? "Disabled" : "Enabled", ClientSettings(iClient, false, ePunchRockBlock) ? "Disable" : "Enable");
    mMenu.AddItem(g_szSettings[ePunchRockBlock], szBuffer, GetCurrentMainMode() == VERSUS ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

    if (ClientSettings(iClient, false, eJumpRockBlock) == -1)    Format(szBuffer, sizeof(szBuffer), "Jump Rock [%s]",       BlockJumpRock() ? "Disabled" : "Enabled");
    else                                                         Format(szBuffer, sizeof(szBuffer), "Jump Rock [%s >> %s]", BlockJumpRock() ? "Disabled" : "Enabled", ClientSettings(iClient, false, eJumpRockBlock) ? "Disable" : "Enable");
    mMenu.AddItem(g_szSettings[eJumpRockBlock], szBuffer, GetCurrentMainMode() == VERSUS ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

    if (ClientSettings(iClient, false, eNoTankRush) == -1)       Format(szBuffer, sizeof(szBuffer), "Anti Rush [%s]",       FreezePointsEnabled() ? "Enabled" : "Disabled");
    else                                                         Format(szBuffer, sizeof(szBuffer), "Anti Rush [%s >> %s]", FreezePointsEnabled() ? "Enabled" : "Disabled", ClientSettings(iClient, false, eNoTankRush) ? "Enable" : "Disable");
    mMenu.AddItem(g_szSettings[eNoTankRush], szBuffer, GetCurrentMainMode() == VERSUS ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

    if (ClientSettings(iClient, false, eDeadstopsBlock) == -1)   Format(szBuffer, sizeof(szBuffer), "Hunter deadstops [%s]",       DeadstopsBlocked() ? "Disabled" : "Enabled");
    else                                                         Format(szBuffer, sizeof(szBuffer), "Hunter deadstops [%s >> %s]", DeadstopsBlocked() ? "Disabled" : "Enabled", ClientSettings(iClient, false, eDeadstopsBlock) ? "Disable" : "Enable");
    mMenu.AddItem(g_szSettings[eDeadstopsBlock], szBuffer);

    if (ClientSettings(iClient, false, eLaserSights) == -1)      Format(szBuffer, sizeof(szBuffer), "Laser Sights [%s]",       UIM_GetItemLimit(MAP_LIMIT, LASERSIGHTS) ? "Enabled" : "Disabled");
    else                                                         Format(szBuffer, sizeof(szBuffer), "Laser Sights [%s >> %s]", UIM_GetItemLimit(MAP_LIMIT, LASERSIGHTS) ? "Enabled" : "Disabled", ClientSettings(iClient, false, eLaserSights) ? "Enable" : "Disable");
    mMenu.AddItem(g_szSettings[eLaserSights], szBuffer);

    mMenu.AddItem("Limits", "Item Limits");
    mMenu.ExitButton = true;
    mMenu.Display(iClient, MENU_TIME_FOREVER);
}

int Menu_SettingsMenuHandler(Menu mMenu, MenuAction maAction, int iClient, int iParam2) {
    if (maAction == MenuAction_End)
        delete mMenu;

    if (maAction == MenuAction_Select) {
        char szBuffer[32];
        mMenu.GetItem(iParam2, szBuffer, sizeof(szBuffer));

        if (strcmp(szBuffer, "Start") == 0) {
            // Game Settings
            int iStrings;
            for (int i = 0; i < ePills; i++) {
                if (ClientSettings(iClient, false, i) != -1)
                    iStrings++;
            }

            int iCount;
            bool bSettingsChanged;
            bool bLimitsChanged;
            char szCombinedLimitsBuff[512];
            char szCombinedSettingsBuff[512];

            if (iStrings) {
                char[][] szSettingsBufferParts = new char[iStrings][64];
                if (ClientSettings(iClient, false, ePunchRockBlock) != -1) {
                    Format(szSettingsBufferParts[iCount], 64, "Punch Rock: {olive}%s{default}", ClientSettings(iClient, false, ePunchRockBlock) ? "Disable" : "Enable");
                    bSettingsChanged = true;
                    iCount++;
                }

                if (ClientSettings(iClient, false, eJumpRockBlock) != -1) {
                    Format(szSettingsBufferParts[iCount], 64, "Jump Rock: {olive}%s{default}", ClientSettings(iClient, false, eJumpRockBlock) ? "Disable" : "Enable");
                    bSettingsChanged = true;
                    iCount++;
                }

                if (ClientSettings(iClient, false, eNoTankRush) != -1) {
                    Format(szSettingsBufferParts[iCount], 64, "Anti Rush: {olive}%s{default}", ClientSettings(iClient, false, eNoTankRush) ? "Enable" : "Disable");
                    bSettingsChanged = true;
                    iCount++;
                }

                if (ClientSettings(iClient, false, eDeadstopsBlock) != -1) {
                    Format(szSettingsBufferParts[iCount], 64, "Deadstops: {olive}%s{default}", ClientSettings(iClient, false, eDeadstopsBlock) ? "Disable" : "Enable");
                    bSettingsChanged = true;
                    iCount++;
                }

                if (ClientSettings(iClient, false, eLaserSights) != -1) {
                    Format(szSettingsBufferParts[iCount], 64, "Laser Sights: {olive}%s{default}", ClientSettings(iClient, false, eLaserSights) ? "Enable" : "Disable");
                    bSettingsChanged = true;
                    iCount++;
                }

                for (int i = 0; i < iStrings; i++) {
                    Format(szCombinedSettingsBuff, sizeof(szCombinedSettingsBuff), "%s%s%s", szCombinedSettingsBuff, i > 0 ? ", " : "", szSettingsBufferParts[i]);
                }

                Format(szCombinedSettingsBuff, sizeof(szCombinedSettingsBuff), "{blue}[{default}Settings{blue}]{default} %s.", szCombinedSettingsBuff);
            }

            // Item Limits
            iStrings = 0;
            for (int i = ePills; i < eSettingsSize; i++) {
                if (ClientSettings(iClient, false, i) != -1)
                    iStrings++;
            }

            if (iStrings) {
                char[][] szLimitsBufferParts = new char[iStrings][64];
                iCount = 0;

                if (ClientSettings(iClient, false, ePills) != -1) {
                    Format(szLimitsBufferParts[iCount], 64, "Pills - {olive}%i{default}", ClientSettings(iClient, false, ePills));
                    bLimitsChanged = true;
                    iCount++;
                }

                if (ClientSettings(iClient, false, eAdrenaline) != -1) {
                    Format(szLimitsBufferParts[iCount], 64, "Adrenaline - {olive}%i{default}", ClientSettings(iClient, false, eAdrenaline));
                    bLimitsChanged = true;
                    iCount++;
                }

                if (ClientSettings(iClient, false, eVomitjar) != -1) {
                    Format(szLimitsBufferParts[iCount], 64, "Vomit jars - {olive}%i{default}", ClientSettings(iClient, false, eVomitjar));
                    bLimitsChanged = true;
                    iCount++;
                }

                if (ClientSettings(iClient, false, ePipeBomb) != -1) {
                    Format(szLimitsBufferParts[iCount], 64, "Pipe bombs - {olive}%i{default}", ClientSettings(iClient, false, ePipeBomb));
                    bLimitsChanged = true;
                    iCount++;
                }

                for (int i = 0; i < iStrings; i++) {
                    Format(szCombinedLimitsBuff, sizeof(szCombinedLimitsBuff), "%s%s%s", szCombinedLimitsBuff, i > 0 ? ", " : "", szLimitsBufferParts[i]);
                }

                Format(szCombinedLimitsBuff, sizeof(szCombinedLimitsBuff), "{blue}[{default}Settings{blue}]{default} Set Limits: %s.", szCombinedLimitsBuff);
            }

            // start vote
            bool bVoteStarted = StartVote(iClient);
            if (bVoteStarted) {
                if (bSettingsChanged)
                    CPrintToChatAll(szCombinedSettingsBuff);

                if (bLimitsChanged)
                    CPrintToChatAll(szCombinedLimitsBuff);

                for (int i = 0; i < eSettingsSize; i++) {
                    SettingsToApply(true, i, ClientSettings(iClient, false, i));
                }
            }
        } else if (strcmp(szBuffer, g_szSettings[ePunchRockBlock]) == 0) {
            if (ClientSettings(iClient, false, ePunchRockBlock) == -1)  ClientSettings(iClient, true, ePunchRockBlock, !BlockPunchRock())
            else                                                        ClientSettings(iClient, true, ePunchRockBlock, -1);

            CreateSettingsMenu(iClient);
        } else if (strcmp(szBuffer, g_szSettings[eJumpRockBlock]) == 0) {
            if (ClientSettings(iClient, false, eJumpRockBlock) == -1)   ClientSettings(iClient, true, eJumpRockBlock, !BlockJumpRock())
            else                                                        ClientSettings(iClient, true, eJumpRockBlock, -1);

            CreateSettingsMenu(iClient);
        } else if (strcmp(szBuffer, g_szSettings[eNoTankRush]) == 0) {
            if (ClientSettings(iClient, false, eNoTankRush) == -1)      ClientSettings(iClient, true, eNoTankRush, !FreezePointsEnabled())
            else                                                        ClientSettings(iClient, true, eNoTankRush, -1);

            CreateSettingsMenu(iClient);
        } else if (strcmp(szBuffer, g_szSettings[eDeadstopsBlock]) == 0) {
            if (ClientSettings(iClient, false, eDeadstopsBlock) == -1)  ClientSettings(iClient, true, eDeadstopsBlock, !DeadstopsBlocked())
            else                                                        ClientSettings(iClient, true, eDeadstopsBlock, -1);

            CreateSettingsMenu(iClient);
        } else if (strcmp(szBuffer, g_szSettings[eLaserSights]) == 0) {
            if (ClientSettings(iClient, false, eLaserSights) == -1)     ClientSettings(iClient, true, eLaserSights, !UIM_GetItemLimit(MAP_LIMIT, LASERSIGHTS))
            else                                                        ClientSettings(iClient, true, eLaserSights, -1);

            CreateSettingsMenu(iClient);
        } else if (strcmp(szBuffer, "Limits") == 0) {
            CreateItemsMenu(iClient);
        }
    }

    return 0;
}

void CreateItemsMenu(int iClient) {
    char szBuffer[64];
    Menu mMenu = new Menu(Menu_ItemsMenuHandler);
    mMenu.SetTitle("Choose item:\n ");

    if (ClientSettings(iClient, false, ePills) == -1)      Format(szBuffer, sizeof(szBuffer), "Pills [%i]",            UIM_GetItemLimit(MAP_LIMIT, PILLS));
    else                                                   Format(szBuffer, sizeof(szBuffer), "Pills [%i >> %i]",      UIM_GetItemLimit(MAP_LIMIT, PILLS), ClientSettings(iClient, false, ePills));
    mMenu.AddItem(g_szSettings[ePills], szBuffer);

    if (ClientSettings(iClient, false, eAdrenaline) == -1) Format(szBuffer, sizeof(szBuffer), "Adrenaline [%i]",       UIM_GetItemLimit(MAP_LIMIT, ADRENALINE));
    else                                                   Format(szBuffer, sizeof(szBuffer), "Adrenaline [%i >> %i]", UIM_GetItemLimit(MAP_LIMIT, ADRENALINE), ClientSettings(iClient, false, eAdrenaline));
    mMenu.AddItem(g_szSettings[eAdrenaline], szBuffer);

    if (ClientSettings(iClient, false, eVomitjar) == -1)   Format(szBuffer, sizeof(szBuffer), "Vomit Jar [%i]",        UIM_GetItemLimit(MAP_LIMIT, VOMITJAR));
    else                                                   Format(szBuffer, sizeof(szBuffer), "Vomit Jar [%i >> %i]",  UIM_GetItemLimit(MAP_LIMIT, VOMITJAR), ClientSettings(iClient, false, eVomitjar));
    mMenu.AddItem(g_szSettings[eVomitjar], szBuffer);

    if (ClientSettings(iClient, false, ePipeBomb) == -1)   Format(szBuffer, sizeof(szBuffer), "Pipe Bomb [%i]",        UIM_GetItemLimit(MAP_LIMIT, PIPEBOMB));
    else                                                   Format(szBuffer, sizeof(szBuffer), "Pipe Bomb [%i >> %i]",  UIM_GetItemLimit(MAP_LIMIT, PIPEBOMB), ClientSettings(iClient, false, ePipeBomb));
    mMenu.AddItem(g_szSettings[ePipeBomb], szBuffer);

    mMenu.ExitButton = true;
    mMenu.ExitBackButton = true;
    mMenu.Display(iClient, MENU_TIME_FOREVER);
}

int Menu_ItemsMenuHandler(Menu mMenu, MenuAction maAction, int iClient, int iParam2) {
    if (maAction == MenuAction_End)
        delete mMenu;

    if (maAction == MenuAction_Cancel) {
        if (iParam2 == MenuCancel_ExitBack)
            CreateSettingsMenu(iClient);
    }

    if (maAction == MenuAction_Select) {
        char szBuffer[32];
        if (mMenu.GetItem(iParam2, szBuffer, sizeof(szBuffer))) {
            int iIdx = -1;
            for (int i = 0; i < sizeof(g_szSettings); i++) {
                if (strcmp(szBuffer, g_szSettings[i]) == 0) {
                    iIdx = i;
                    break;
                }
            }

            CreateLimitsMenu(iClient, iIdx);
        }
    }

    return 0;
}

void CreateLimitsMenu(int iClient, int iIdx) {
    char szInfo[32];
    char szBuffer[32];
    Menu mMenu = new Menu(Menu_LimitsMenuHandler);
    mMenu.SetTitle("Choose value:\n ");

    for (int i = 0; i <= MAXVALUE; i++) {
        if (ClientSettings(iClient, false, iIdx) == -1) {
            Format(szInfo,   sizeof(szInfo),   "%s_%i", g_szSettings[iIdx], i);
            Format(szBuffer, sizeof(szBuffer), "%i%s", i, iIdx == ePills      && UIM_GetItemLimit(MAP_LIMIT, PILLS)      == i ||
                                                          iIdx == eAdrenaline && UIM_GetItemLimit(MAP_LIMIT, ADRENALINE) == i ||
                                                          iIdx == eVomitjar   && UIM_GetItemLimit(MAP_LIMIT, VOMITJAR)   == i ||
                                                          iIdx == ePipeBomb   && UIM_GetItemLimit(MAP_LIMIT, PIPEBOMB)   == i ? " [Current]" : "");

            mMenu.AddItem(szInfo, szBuffer, iIdx == ePills      && UIM_GetItemLimit(MAP_LIMIT, PILLS)      == i ||
                                            iIdx == eAdrenaline && UIM_GetItemLimit(MAP_LIMIT, ADRENALINE) == i ||
                                            iIdx == eVomitjar   && UIM_GetItemLimit(MAP_LIMIT, VOMITJAR)   == i ||
                                            iIdx == ePipeBomb   && UIM_GetItemLimit(MAP_LIMIT, PIPEBOMB)   == i ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        } else {
            Format(szInfo,   sizeof(szInfo),   "%s_%i", g_szSettings[iIdx], i);
            Format(szBuffer, sizeof(szBuffer), "%i%s", i, ClientSettings(iClient, false, iIdx) == i ? " [Chosen]" : "");
            mMenu.AddItem(szInfo, szBuffer, ClientSettings(iClient, false, iIdx) == i ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        }
    }

    mMenu.ExitButton = true;
    mMenu.ExitBackButton = true;
    mMenu.Display(iClient, MENU_TIME_FOREVER);
}

int Menu_LimitsMenuHandler(Menu mMenu, MenuAction maAction, int iClient, int iParam2) {
    if (maAction == MenuAction_End)
        delete mMenu;

    if (maAction == MenuAction_Cancel) {
        if (iParam2 == MenuCancel_ExitBack)
            CreateItemsMenu(iClient);
    }

    if (maAction == MenuAction_Select) {
        char szBuffer[32];
        if (mMenu.GetItem(iParam2, szBuffer, sizeof(szBuffer))) {
            char szSubstrArray[2][32];
            ExplodeString(szBuffer, "_", szSubstrArray, sizeof(szSubstrArray), 32, false);

            for (int i = 0; i < sizeof(g_szSettings); i++) {
                if (strcmp(szSubstrArray[0], g_szSettings[i]) == 0) {
                    int iVal = StringToInt(szSubstrArray[1]);
                    ClientSettings(iClient, true, i, iVal);
                    if (i == ePills && ClientSettings(iClient, false, i) == UIM_GetItemLimit(MAP_LIMIT, PILLS))
                        ClientSettings(iClient, true, i, -1);
                    if (i == eAdrenaline && ClientSettings(iClient, false, i) == UIM_GetItemLimit(MAP_LIMIT, ADRENALINE))
                        ClientSettings(iClient, true, i, -1);
                    if (i == eVomitjar && ClientSettings(iClient, false, i) == UIM_GetItemLimit(MAP_LIMIT, VOMITJAR))
                        ClientSettings(iClient, true, i, -1);
                    if (i == ePipeBomb && ClientSettings(iClient, false, i) == UIM_GetItemLimit(MAP_LIMIT, PIPEBOMB))
                        ClientSettings(iClient, true, i, -1);
                    break;
                }
            }

            CreateItemsMenu(iClient);
        }
    }

    return 0;
}

stock bool SettingsWereChanged(int iClient) {
    for (int i = 0; i < eSettingsSize; i++) {
        if (ClientSettings(iClient, false, i) != -1)
            return true;
    }
    return false;
}