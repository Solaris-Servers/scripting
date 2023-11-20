#if defined __Vips__
    #endinput
#endif
#define __Vips__

#include <clientprefs>
#include <solaris/info>
#include <solaris/cannounce>
#include <vip_core>

enum {
    PREFIX = 0,
    PREFIX_COLOR,
    NAME_COLOR,
    TEXT_COLOR,
    SIZE
};

static const char g_szFeature[] = "Chat";
static const char g_szCustom [] = "custom";
static const char g_szList   [] = "list";

static const char g_szFeatures[SIZE][] = {
    "Chat_Prefix",
    "Chat_PrefixColor",
    "Chat_NameColor",
    "Chat_TextColor"
};

Cookie    cSettings[SIZE];
Cookie    cTop;
KeyValues kvSettings;
StringMap smColors;

bool bWaitChat [MAXPLAYERS + 1];
int  iColorChat[MAXPLAYERS + 1];

void Vips_OnModuleStart() {
    smColors = new StringMap();

    cSettings[0] = new Cookie("VIP_Chat_Prefix",      "VIP_Chat_Prefix",      CookieAccess_Private);
    cSettings[1] = new Cookie("VIP_Chat_PrefixColor", "VIP_Chat_PrefixColor", CookieAccess_Private);
    cSettings[2] = new Cookie("VIP_Chat_NameColor",   "VIP_Chat_NameColor",   CookieAccess_Private);
    cSettings[3] = new Cookie("VIP_Chat_TextColor",   "VIP_Chat_TextColor",   CookieAccess_Private);
    cTop         = new Cookie("TOP_Chat_TextColor",   "TOP_Chat_TextColor",   CookieAccess_Private);

    RegConsoleCmd("sm_cc",         Cmd_ColorChat);
    RegConsoleCmd("sm_color_chat", Cmd_ColorChat);

    if (VIP_IsVIPLoaded()) VIP_OnVIPLoaded();

    LoadTranslations("vip_chat.phrases");
}

Action Cmd_ColorChat(int iClient, int iArgs) {
    if (VIP_IsClientVIP(iClient) && VIP_IsClientFeatureUse(iClient, g_szFeature)) {
        DisplayChatMainMenu(iClient);
        return Plugin_Handled;
    }

    int iRank = Solaris_GetRank(iClient);
    if (iRank == 0)
        return Plugin_Continue;

    if (!iColorChat[iClient]) {
        if (iRank > 50) {
            PrintToChat(iClient, "\x04[\x01Top 50\x04]\x01 Only Top-50 players can use this command!");
        } else {
            iColorChat[iClient] = (iRank <= 10 ? 2 : 1);
            char szBuffer[4];
            IntToString(iColorChat[iClient], szBuffer, sizeof(szBuffer));
            cTop.Set(iClient, szBuffer);
            PrintToChat(iClient, "\x04[\x01Top %s\x04]\x01 Color chat enabled!", iRank && iRank <= 10 ? "10" : "50");
        }
    } else {
        iColorChat[iClient] = 0;
        cTop.Set(iClient, "0");
        PrintToChat(iClient, "\x04[\x01Top %s\x04]\x01 Color chat disabled!", iRank && iRank <= 10 ? "10" : "50");
    }

    return Plugin_Handled;
}

public void VIP_OnVIPLoaded() {
    VIP_RegisterFeature(g_szFeature, BOOL, SELECTABLE, OnSelectItem);
    VIP_RegisterFeature(g_szFeatures[PREFIX],       STRING, HIDE);
    VIP_RegisterFeature(g_szFeatures[PREFIX_COLOR], STRING, HIDE);
    VIP_RegisterFeature(g_szFeatures[NAME_COLOR],   STRING, HIDE);
    VIP_RegisterFeature(g_szFeatures[TEXT_COLOR],   STRING, HIDE);
}

void Vips_OnMapStart() {
    char szBuffer[256];
    if (kvSettings != null)
        delete kvSettings;
    smColors.Clear();

    kvSettings = new KeyValues("Chat");
    BuildPath(Path_SM, szBuffer, sizeof(szBuffer), "data/vip/modules/chat_config.ini");

    if (!kvSettings.ImportFromFile(szBuffer)) {
        delete kvSettings;
        SetFailState("Couldn't open the file \"%s\"", szBuffer);
    }

    LoadColors("NameColor_List");
    LoadColors("TextColor_List");
    LoadColors("PrefixColor_List");
    kvSettings.Rewind();
}

void LoadColors(const char[] szKey) {
    kvSettings.Rewind();
    if (kvSettings.JumpToKey(szKey) && kvSettings.GotoFirstSubKey(false)) {
        char szColorCode[16];
        char szColorName[32];
        do {
            kvSettings.GetSectionName(szColorName, sizeof(szColorName));
            kvSettings.GetString(NULL_STRING, szColorCode, sizeof(szColorCode));
            smColors.SetString(szColorCode, szColorName);
        } while (kvSettings.GotoNextKey(false));
    }
}

void Vips_OnChatMessage(int iClient, int iArgs, char[] szTagColor, char[] szTag, char[] szNameColor, char[] szMsgColor, char[] szMsg) {
    char szBuffer[16];
    if (bWaitChat[iClient] && iArgs) {
        if (szMsg[0]) {
            int iIdx;
            VIP_GetVIPClientTrie(iClient).GetValue("Chat_CookieIndex", iIdx);
            DisplayWaitChatMenu(iClient, szMsg, true, iIdx);
        }

        return;
    }

    if (VIP_IsClientVIP(iClient) && VIP_IsClientFeatureUse(iClient, g_szFeature)) {
        if (GetClientChat(iClient, TEXT_COLOR, szBuffer, sizeof(szBuffer)))
            FormatEx(szMsgColor, sizeof(szBuffer), szBuffer);
        if (GetClientChat(iClient, NAME_COLOR, szBuffer, sizeof(szBuffer))) {
            FormatEx(szNameColor, sizeof(szBuffer), szBuffer);
        } else {
            FormatEx(szNameColor, sizeof(szBuffer), "{teamcolor}");
        }

        if (GetClientChat(iClient, PREFIX, szBuffer, sizeof(szBuffer))) {
            FormatEx(szTag, sizeof(szBuffer), "%s ", szBuffer);
            if (GetClientChat(iClient, PREFIX_COLOR, szBuffer, sizeof(szBuffer)))
                FormatEx(szTagColor, sizeof(szBuffer), szBuffer);
        }

        return;
    }

    if (iColorChat[iClient])
        FormatEx(szMsgColor, sizeof(szBuffer), "%s", iColorChat[iClient] == 2 ? "{green}" : "{olive}");
}

bool GetClientChat(int iClient, int iIdx, char[] szBuffer, int iMaxLen) {
    if (VIP_IsClientFeatureUse(iClient, g_szFeatures[iIdx])) {
        VIP_GetClientFeatureString(iClient, g_szFeatures[iIdx], szBuffer, iMaxLen);
        if (strcmp(szBuffer, g_szCustom) == 0 || strcmp(szBuffer, g_szList) == 0) {
            cSettings[iIdx].Get(iClient, szBuffer, iMaxLen);
        } else {
            char szCookie[4];
            cSettings[iIdx].Get(iClient, szCookie, sizeof(szCookie));
            if (szCookie[0] == '0')
                return false;
        }

        if (szBuffer[0] == '0')
            return false;

        if (szBuffer[0])
            return true;
    }

    return false;
}

bool OnSelectItem(int iClient, const char[] szFeatureName) {
    DisplayChatMainMenu(iClient);
    return false;
}

void DisplayChatMainMenu(int iClient) {
    Menu mMenu = new Menu(ChatMainMenu_Handler);
    mMenu.ExitBackButton = true;
    mMenu.SetTitle("%t:\n ", "MainMenuTitle");

    char szBuffer[128];
    FormatEx(szBuffer, sizeof(szBuffer), "%t\n ", "DisableAll");
    mMenu.AddItem("", szBuffer);

    AddMenuFeatureItem(iClient, PREFIX,       mMenu, "Prefix");
    AddMenuFeatureItem(iClient, PREFIX_COLOR, mMenu, "PrefixColor");
    AddMenuFeatureItem(iClient, NAME_COLOR,   mMenu, "NameColor");
    AddMenuFeatureItem(iClient, TEXT_COLOR,   mMenu, "TextColor");

    mMenu.Display(iClient, MENU_TIME_FOREVER);
}

void AddMenuFeatureItem(int iClient, int iIdx, Menu &mMenu, const char[] szFeatureName) {
    char szBuffer[128];
    if (VIP_IsClientFeatureUse(iClient, g_szFeatures[iIdx])) {
        char szItemInfo[128];
        VIP_GetClientFeatureString(iClient, g_szFeatures[iIdx], szBuffer, sizeof(szBuffer));
        cSettings[iIdx].Get(iClient, szItemInfo, sizeof(szItemInfo));

        if (szItemInfo[0] == '0') {
            FormatEx(szBuffer, sizeof(szBuffer), "%t [%t]", szFeatureName, "Disabled");
        } else {
            if (strcmp(szBuffer, g_szCustom) == 0 || strcmp(szBuffer, g_szList) == 0) {
                if (szItemInfo[0]) {
                    smColors.GetString(szItemInfo, szItemInfo, sizeof(szItemInfo));
                    FormatEx(szBuffer, sizeof(szBuffer), "%t - %s", szFeatureName, szItemInfo);
                } else {
                    FormatEx(szBuffer, sizeof(szBuffer), "%t [%t]", szFeatureName, "NotChosen");
                }
            } else {
                Format(szBuffer, sizeof(szBuffer), "%t - %s", szFeatureName, szBuffer);
            }
        }

        FormatEx(szItemInfo, sizeof(szItemInfo), "%i_%s", iIdx, szFeatureName);
        mMenu.AddItem(szItemInfo, szBuffer);
    } else {
        FormatEx(szBuffer, sizeof(szBuffer), "%t (%t)", szFeatureName, "NoAccess");
        mMenu.AddItem("", szBuffer, ITEMDRAW_DISABLED);
    }
}

int ChatMainMenu_Handler(Menu mMenu, MenuAction maAction, int iClient, int iItem) {
    switch (maAction) {
        case MenuAction_End: {
            delete mMenu;
        }
        case MenuAction_Cancel: {
            if (iItem == MenuCancel_ExitBack)
                VIP_SendClientVIPMenu(iClient);
        }
        case MenuAction_Select: {
            char szBuffer[128];
            int  iIdx;
            if (iItem == 0) {
                for (iIdx = 0; iIdx < 4; iIdx++) {
                    if (VIP_IsClientFeatureUse(iClient, g_szFeatures[iIdx])) {
                        VIP_GetClientFeatureString(iClient, g_szFeatures[iIdx], szBuffer, sizeof(szBuffer));
                        if (strcmp(szBuffer, g_szCustom) == 0 || strcmp(szBuffer, g_szList) == 0) {
                            cSettings[iIdx].Set(iClient, "");
                        } else {
                            cSettings[iIdx].Set(iClient, "0");
                        }
                    }
                }

                DisplayChatMainMenu(iClient);
                return 0;
            }

            char szItemInfo[128];
            mMenu.GetItem(iItem, szItemInfo, sizeof(szItemInfo));

            iIdx = szItemInfo[0] - 48;

            VIP_GetClientFeatureString(iClient, g_szFeatures[iIdx], szBuffer, sizeof(szBuffer));
            StringMap smTrie = VIP_GetVIPClientTrie(iClient);

            smTrie.SetString("Chat_MenuType",   szItemInfo[2]);
            smTrie.SetValue("Chat_CookieIndex", iIdx);

            if (strcmp(szBuffer, g_szCustom) == 0) {
                cSettings[iIdx].Get(iClient, szItemInfo, sizeof(szItemInfo));
                if (szItemInfo[0] == '0') szItemInfo[0] = 0;
                DisplayWaitChatMenu(iClient, szItemInfo, false, iIdx);
            } else if (strcmp(szBuffer, g_szList) == 0) {
                DisplayChatListMenu(iClient, szItemInfo[2], iIdx);
            } else {
                smTrie.Remove("Chat_MenuType");
                smTrie.Remove("Chat_CookieIndex");
                cSettings[iIdx].Get(iClient, szItemInfo, sizeof(szItemInfo));
                bool bEnable;
                if (szItemInfo[0]) {
                    bEnable = view_as<bool>(StringToInt(szItemInfo));
                } else {
                    bEnable = true;
                }
                bEnable = !bEnable;
                cSettings[iIdx].Set(iClient, bEnable ? "" : "0");
                cSettings[iIdx].Get(iClient, szItemInfo, sizeof(szItemInfo));
                DisplayChatMainMenu(iClient);
            }

            delete smTrie;
        }
    }

    return 0;
}

void DisplayChatListMenu(int iClient, const char[] szKey, int iIdx) {
    char szBuffer[128];
    char szClientColor[64];
    Menu mMenu = new Menu(ChatListMenu_Handler);
    mMenu.ExitBackButton = true;

    mMenu.SetTitle("%t:\n ", szKey);
    cSettings[iIdx].Get(iClient, szClientColor, sizeof(szClientColor));

    if (szClientColor[0] && szClientColor[0] != '0') {
        FormatEx(szBuffer, sizeof(szBuffer), "%t\n ", "Disable");
        mMenu.AddItem("_disable", szBuffer);
    }

    kvSettings.Rewind();
    FormatEx(szBuffer, sizeof(szBuffer), "%s_List", szKey);

    if (kvSettings.JumpToKey(szBuffer) && kvSettings.GotoFirstSubKey(false)) {
        szBuffer[0] = 0;
        char szColor[64];
        do {
            kvSettings.GetString(NULL_STRING, szColor, sizeof(szColor));
            kvSettings.GetSectionName(szBuffer, sizeof(szBuffer));
            if (strcmp(szClientColor, szColor) == 0) {
                Format(szBuffer, sizeof(szBuffer), "%s (%t)", szBuffer, "Selected");
                mMenu.AddItem(szColor, szBuffer, ITEMDRAW_DISABLED);
                continue;
            }
            mMenu.AddItem(szColor, szBuffer);
        } while (kvSettings.GotoNextKey(false));
        if (szBuffer[0] == 0) {
            FormatEx(szBuffer, sizeof(szBuffer), "%t", "NoItems");
            AddMenuItem(mMenu, "", szBuffer, ITEMDRAW_DISABLED);
        }
    } else {
        FormatEx(szBuffer, sizeof(szBuffer), "%t", "NoItems");
        mMenu.AddItem("", szBuffer, ITEMDRAW_DISABLED);
    }
    mMenu.Display(iClient, MENU_TIME_FOREVER);
}

int ChatListMenu_Handler(Menu mMenu, MenuAction maAction, int iClient, int iItem) {
    switch (maAction) {
        case MenuAction_End: {
            delete mMenu;
        }
        case MenuAction_Cancel: {
            if (iItem == MenuCancel_ExitBack)
                DisplayChatMainMenu(iClient);
        }
        case MenuAction_Select: {
            char szColor[64];
            char szColorName[128];
            int  iIdx;

            mMenu.GetItem(iItem, szColor, sizeof(szColor), _, szColorName, sizeof(szColorName));

            StringMap smTrie = VIP_GetVIPClientTrie(iClient);
            smTrie.GetValue("Chat_CookieIndex", iIdx);

            if (strcmp(szColor, "_disable") == 0) {
                cSettings[iIdx].Set(iClient, "0");
                smTrie.Remove("Chat_MenuType");
                smTrie.Remove("Chat_CookieIndex");
                DisplayChatMainMenu(iClient);
                return 0;
            }

            char szBuffer[64];
            cSettings[iIdx].Set(iClient, szColor);
            smTrie.GetString("Chat_MenuType", szBuffer, sizeof(szBuffer));
            DisplayChatListMenu(iClient, szBuffer, iIdx);
            delete smTrie;
        }
    }
    return 0;
}

void DisplayWaitChatMenu(int iClient, const char[] szValue = "", const bool bIsValid = false, const int iIdx) {
    if (!bIsValid) bWaitChat[iClient] = true;

    Menu mMenu = new Menu(WaitChatMenu_Handler);

    if (szValue[0]) {
        mMenu.SetTitle("%t \"%t\"\n%t: %s\n ", "EnterValueInChat", "Confirm", "Value", szValue);
    } else {
        mMenu.SetTitle("%t \"%t\"\n ", "EnterValueInChat", "Confirm");
    }

    char szBuffer[128];
    FormatEx(szBuffer, sizeof(szBuffer), "%t", "Confirm");
    mMenu.AddItem(szValue, szBuffer, bIsValid ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

    FormatEx(szBuffer, sizeof(szBuffer), "%t\n ", "Cancel");
    mMenu.AddItem("", szBuffer);

    cSettings[iIdx].Get(iClient, szBuffer, sizeof(szBuffer));

    if (szBuffer[0] && szBuffer[0] != '0') {
        FormatEx(szBuffer, sizeof(szBuffer), "%t\n ", "Disable");
        mMenu.AddItem("_disable", szBuffer);
    }

    kvSettings.Rewind();

    if (kvSettings.JumpToKey("Help")) {
        FormatEx(szBuffer, sizeof(szBuffer), "%t\n ", "Help");
        mMenu.AddItem("_help", szBuffer);
    } else {
        mMenu.AddItem("", "", ITEMDRAW_NOTEXT);
    }

    mMenu.AddItem("", "", ITEMDRAW_NOTEXT);
    mMenu.AddItem("", "", ITEMDRAW_NOTEXT);
    mMenu.Display(iClient, MENU_TIME_FOREVER);
}

int WaitChatMenu_Handler(Menu mMenu, MenuAction maAction, int iClient, int iItem) {
    switch (maAction) {
        case MenuAction_End: {
            delete mMenu;
        }
        case MenuAction_Cancel: {
            bWaitChat[iClient] = false;
            if (iItem == MenuCancel_ExitBack)
                DisplayChatMainMenu(iClient);
        }
        case MenuAction_Select: {
            int iIdx;
            StringMap smTrie = VIP_GetVIPClientTrie(iClient);
            smTrie.GetValue("Chat_CookieIndex", iIdx);
            if (iItem == 0) {
                char szBuffer[64];
                char szColor[64];
                mMenu.GetItem(iItem, szColor, sizeof(szColor));
                cSettings[iIdx].Set(iClient, szColor);
                smTrie.GetString("Chat_MenuType", szBuffer, sizeof(szBuffer));
            }
            else {
                char szBuffer[64];
                mMenu.GetItem(iItem, szBuffer, sizeof(szBuffer));
                if (strcmp(szBuffer, "_disable") == 0) {
                    cSettings[iIdx].Set(iClient, "0");
                } else if (strcmp(szBuffer, "_help") == 0) {
                    DisplayHelpMenu(iClient);
                    return 0;
                }
            }
            smTrie.Remove("Chat_MenuType");
            smTrie.Remove("Chat_CookieIndex");
            bWaitChat[iClient] = false;
            DisplayChatMainMenu(iClient);
            delete smTrie;
        }
    }
    return 0;
}

void DisplayHelpMenu(int iClient) {
    char szBuffer[128];
    Panel mPanel = new Panel();
    FormatEx(szBuffer, sizeof(szBuffer), "%t:\n ", "Help");
    mPanel.SetTitle(szBuffer);
    kvSettings.Rewind();

    if (kvSettings.JumpToKey("Help")) {
        if (kvSettings.GotoFirstSubKey(false)) {
            do {
                kvSettings.GetString(NULL_STRING, szBuffer, sizeof(szBuffer));
                mPanel.DrawText(szBuffer);
            } while (kvSettings.GotoNextKey(false));
        }
    }

    mPanel.DrawItem(" ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
    mPanel.DrawItem("<-");
    mPanel.Send(iClient, ChatInfoMenu_Handler, MENU_TIME_FOREVER);
    delete mPanel;
}

int ChatInfoMenu_Handler(Menu mMenu, MenuAction maAction, int iClient, int iItem) {
    if (maAction == MenuAction_Select) {
        int  iIdx;
        char szBuffer[64];
        VIP_GetVIPClientTrie(iClient).GetValue("Chat_CookieIndex", iIdx);
        cSettings[iIdx].Get(iClient, szBuffer, sizeof(szBuffer));
        if (szBuffer[0] == '0') szBuffer[0] = 0;
        DisplayWaitChatMenu(iClient, szBuffer, false, iIdx);
    }
    return 0;
}

public void OnPlayerJoined(int iClient, int iRank, const char[] szLocation, float fHours) {
    if (VIP_IsClientVIP(iClient) && VIP_IsClientFeatureUse(iClient, g_szFeature)) {
        cTop.Set(iClient, "0");
        iColorChat[iClient] = 0;
        return;
    }

    if (!iRank) {
        iColorChat[iClient] = 0;
        return;
    }

    char szBuffer[4];
    cTop.Get(iClient, szBuffer, sizeof(szBuffer));

    if (StringToInt(szBuffer) != 0) {
        Format(szBuffer, sizeof(szBuffer), "%s", iRank > 50 ? "0" : iRank <= 50 && iRank > 10 ? "1" : "2");
        cTop.Set(iClient, szBuffer);
        iColorChat[iClient] = StringToInt(szBuffer);
        return;
    }

    iColorChat[iClient] = 0;
}