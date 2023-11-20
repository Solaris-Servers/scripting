#if defined __ADMINMENU__
    #endinput
#endif
#define __ADMINMENU__

TopMenu hTopMenu;

void OnModuleStart_AdminMenu() {
    TopMenu topmenu;
    if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
        OnAdminMenuReady(topmenu);
}

// MENU RELATED //
public void OnAdminMenuReady(Handle aTopMenu) {
    TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

    /* Block us from being called twice */
    if (topmenu == hTopMenu)
        return;

    /* Save the Handle */
    hTopMenu = topmenu;
    if (topmenu == null) {
        LogError("[WARNING!] The topmenu handle was invalid! Unable to add items to the menu");
        return;
    }

    TopMenuObject MenuObject = hTopMenu.AddCategory("sm_cccategory", Category_Handler, "sm_cccategory", ADMFLAG_UNBAN, "Custom Commands");
    hTopMenu.AddItem("sm_ccplayer", Handle_MenuGag,   MenuObject, "sm_ccplayer", ADMFLAG_UNBAN, "Player Commands");
    hTopMenu.AddItem("sm_ccserver", Handle_MenuUnGag, MenuObject, "sm_ccserver", ADMFLAG_UNBAN, "Server Commands");
}

// Admin Category Name
void Category_Handler(TopMenu mMenu, TopMenuAction mAction, TopMenuObject ObjectId, int iClient, char[] szBuffer, int iLen) {
    switch (mAction) {
        case TopMenuAction_DisplayTitle: {
            FormatEx(szBuffer, iLen, "Custom Commands");
        }
        case TopMenuAction_DisplayOption: {
            Format(szBuffer, iLen, "Custom Commands");
        }
    }
}

void AdminMenu_Player(TopMenu mMenu, TopMenuAction mAction, TopMenuObject ObjectId, int iClient, char[] szBuffer, int iLen) {
    switch (mAction) {
        case TopMenuAction_DisplayOption: {
            Format(szBuffer, iLen, "Player Commands");
        }
        case TopMenuAction_SelectOption: {
            BuildPlayerMenu(iClient);
        }
    }
}

void AdminMenu_Server(TopMenu mMenu, TopMenuAction mAction, TopMenuObject ObjectId, int iClient, char[] szBuffer, int iLen) {
    switch (mAction) {
        case TopMenuAction_DisplayOption: {
            Format(szBuffer, iLen, "Server Commands");
        }
        case TopMenuAction_SelectOption: {
            BuildServerMenu(iClient);
        }
    }
}

void BuildPlayerMenu(int iClient) {
    Menu mMenu = new Menu(MenuHandler_PlayerMenu);
    mMenu.SetTitle("Player Commands");
    mMenu.AddItem("l4d2chargeplayer",    "Charge Player");
    mMenu.AddItem("l4d2incapplayer",     "Incap Player");
    mMenu.AddItem("l4d2smackillplayer",  "Smackill Player");
    mMenu.AddItem("l4d2speedplayer",     "Set Player Speed");
    mMenu.AddItem("l4d2sethpplayer",     "Set Player Health");
    mMenu.AddItem("l4d2colorplayer",     "Set Player Color");
    mMenu.AddItem("l4d2sizeplayer",      "Set Player Scale");
    mMenu.AddItem("l4d2shakeplayer",     "Shake Player");
    mMenu.AddItem("l4d2teleplayer",      "Teleport Player");
    mMenu.AddItem("l4d2dontrush",        "Dont Rush Player");
    mMenu.AddItem("l4d2airstrike",       "Send Airstrike");
    mMenu.AddItem("l4d2changehp",        "Change Health Style");
    mMenu.AddItem("l4d2godmode",         "God mode");
    mMenu.AddItem("l4d2createexplosion", "Set Explosion");
    mMenu.ExitBackButton = true;
    mMenu.Display(iClient, MENU_TIME_FOREVER);
}

void BuildServerMenu(int iClient) {
    Menu mMenu = CreateMenu(MenuHandler_ServerMenu);
    mMenu.SetTitle("Player Commands");
    mMenu.AddItem("l4d2gnomerain", "Gnome Rain");
    mMenu.AddItem("l4d2survrain", "Survivors Rain");
    mMenu.AddItem("l4d2gnomewipe", "Wipe all gnomes");
    mMenu.ExitBackButton = true;
    mMenu.Display(iClient, MENU_TIME_FOREVER);
}

int MenuHandler_PlayerMenu(Menu mMenu, MenuAction mAction, int iClient, int iParam2) {
    switch (mAction) {
        case MenuAction_Select: {
            switch (iParam2) {
                case 0  : DisplayChargePlayerMenu(iClient);
                case 1  : DisplayIncapPlayerMenu(iClient);
                case 2  : DisplaySmackillPlayerMenu(iClient);
                case 3  : DisplaySpeedPlayerMenu(iClient);
                case 4  : DisplaySetHpPlayerMenu(iClient);
                case 5  : DisplayColorPlayerMenu(iClient);
                case 6  : DisplayScalePlayerMenu(iClient);
                case 7  : DisplayShakePlayerMenu(iClient);
                case 8  : DisplayTeleportPlayerMenu(iClient);
                case 9  : DisplayDontRushMenu(iClient);
                case 10 : DisplayAirstrikeMenu(iClient);
                case 11 : DisplayChangeHpMenu(iClient);
                case 12 : DisplayGodModeMenu(iClient);
                case 13 : DisplayCreateExplosionMenu(iClient);
            }
        }
        case MenuAction_Cancel: {
            if (iParam2 == MenuCancel_ExitBack && hTopMenu != null)
                hTopMenu.Display(iClient, TopMenuPosition_LastCategory);
        }
        case MenuAction_End: {
            delete mMenu;
        }
    }
    return 0;
}

int MenuHandler_ServerMenu(Handle menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        switch (param2)
        {
            case 0:
            {
                StartGnomeRain(client);
                PrintHintTextToAll("It's raining gnomes!");
            }
            case 1:
            {
                StartL4dRain(client);
                PrintHintTextToAll("It's raining... survivors?!");
            }
            case 2:
            {
                CmdGnomeWipe(client, 0);
            }
        }
    }
    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack && hTopMenu != null)
        {
            DisplayTopMenu(hTopMenu, client, TopMenuPosition_LastCategory);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

//---------------------------------Show Categories--------------------------------------------
void MenuItem_Charge(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "Charge Player", "", param);
    }
    if (action == TopMenuAction_SelectOption)
    {
        DisplayChargePlayerMenu(param);
    }
}

void MenuItem_VomitPlayer(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "Vomit Player", "", param);
    }
    if (action == TopMenuAction_SelectOption)
    {
        DisplayVomitPlayerMenu(param);
    }
}

void MenuItem_TeleportPlayer(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "Teleport Player", "", param);
    }
    if (action == TopMenuAction_SelectOption)
    {
        DisplayTeleportPlayerMenu(param);
    }
}

void MenuItem_GodMode(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "God Mode", "", param);
    }
    if (action == TopMenuAction_SelectOption)
    {
        DisplayGodModeMenu(param);
    }
}

void MenuItem_IncapPlayer(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "Incapacitate Player", "", param);
    }
    if (action == TopMenuAction_SelectOption)
    {
        DisplayIncapPlayerMenu(param);
    }
}

void MenuItem_SmackillPlayer(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "Smackill Player", "", param);
    }
    if (action == TopMenuAction_SelectOption)
    {
        DisplaySmackillPlayerMenu(param);
    }
}

void MenuItem_Rock(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "Launch Rock", "", param);
    }
    if (action == TopMenuAction_SelectOption)
    {
        CmdRock(param, 0);
    }
}

void MenuItem_SpeedPlayer(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "Set player speed", "", param);
    }
    if (action == TopMenuAction_SelectOption)
    {
        DisplaySpeedPlayerMenu(param);
    }
}

void MenuItem_SetHpPlayer(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "Set player health", "", param);
    }
    if (action == TopMenuAction_SelectOption)
    {
        DisplaySetHpPlayerMenu(param);
    }
}

void MenuItem_ColorPlayer(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "Set player color", "", param);
    }
    if (action == TopMenuAction_SelectOption)
    {
        DisplayColorPlayerMenu(param);
    }
}

void MenuItem_CreateExplosion(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "Create explosion", "", param);
    }
    if (action == TopMenuAction_SelectOption)
    {
        DisplayCreateExplosionMenu(param);
    }
}

void MenuItem_ScalePlayer(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "Set player scale", "", param);
    }
    if (action == TopMenuAction_SelectOption)
    {
        DisplayScalePlayerMenu(param);
    }
}

void MenuItem_ShakePlayer(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "Shake player", "", param);
    }
    if (action == TopMenuAction_SelectOption)
    {
        DisplayShakePlayerMenu(param);
    }
}

void MenuItem_DontRush(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "Anti Rush Player", "", param);
    }
    if (action == TopMenuAction_SelectOption)
    {
        DisplayDontRushMenu(param);
    }
}

void MenuItem_Airstrike(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "Send Airstrike", "", param);
    }
    if (action == TopMenuAction_SelectOption)
    {
        DisplayAirstrikeMenu(param);
    }
}

void MenuItem_GnomeRain(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "Gnome Rain", "", param);
    }
    if (action == TopMenuAction_SelectOption)
    {
        StartGnomeRain(param);
        PrintHintTextToAll("It's raining gnomes!");
    }
}

void MenuItem_SurvRain(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "L4D1 Survivor Rain", "", param);
    }
    if (action == TopMenuAction_SelectOption)
    {
        StartL4dRain(param);
        PrintHintTextToAll("It's raining... survivors?!");
    }
}

void MenuItem_GnomeWipe(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "Wipe gnomes", "", param);
    }
    if (action == TopMenuAction_SelectOption)
    {
        CmdGnomeWipe(param, 0);
    }
}

void MenuItem_ChangeHp(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "Switch Health Style", "", param);
    }
    if (action == TopMenuAction_SelectOption)
    {
        DisplayChangeHpMenu(param);
    }
}

//---------------------------------Display menus---------------------------------------
void DisplayVomitPlayerMenu(int client)
{
    Handle menu2 = CreateMenu(MenuHandler_VomitPlayer);
    SetMenuTitle(menu2, "Select Player:");
    SetMenuExitBackButton(menu2, true);
    AddTargetsToMenu2(menu2, client, COMMAND_FILTER_CONNECTED);
    DisplayMenu(menu2, client, MENU_TIME_FOREVER);
}

void DisplayTeleportPlayerMenu(int client)
{
    Handle menu2 = CreateMenu(MenuHandler_TeleportPlayer);
    SetMenuTitle(menu2, "Select Player:");
    SetMenuExitBackButton(menu2, true);
    AddTargetsToMenu2(menu2, client, COMMAND_FILTER_CONNECTED);
    DisplayMenu(menu2, client, MENU_TIME_FOREVER);
}

void DisplayChargePlayerMenu(int client)
{
    Handle menu2 = CreateMenu(MenuHandler_ChargePlayer);
    SetMenuTitle(menu2, "Select Player:");
    SetMenuExitBackButton(menu2, true);
    AddTargetsToMenu2(menu2, client, COMMAND_FILTER_CONNECTED);
    DisplayMenu(menu2, client, MENU_TIME_FOREVER);
}

void DisplayGodModeMenu(int client)
{
    Handle menu2 = CreateMenu(MenuHandler_GodMode);
    SetMenuTitle(menu2, "Select Player:");
    SetMenuExitBackButton(menu2, true);
    AddTargetsToMenu2(menu2, client, COMMAND_FILTER_CONNECTED);
    DisplayMenu(menu2, client, MENU_TIME_FOREVER);
}

void DisplayIncapPlayerMenu(int client)
{
    Handle menu3 = CreateMenu(MenuHandler_IncapPlayer);
    SetMenuTitle(menu3, "Select Player:");
    SetMenuExitBackButton(menu3, true);
    AddTargetsToMenu2(menu3, client, COMMAND_FILTER_ALIVE);
    DisplayMenu(menu3, client, MENU_TIME_FOREVER);
}

void DisplaySmackillPlayerMenu(int client)
{
    Handle menu3 = CreateMenu(MenuHandler_SmackillPlayer);
    SetMenuTitle(menu3, "Smackill Player:");
    SetMenuExitBackButton(menu3, true);
    AddTargetsToMenu2(menu3, client, COMMAND_FILTER_ALIVE);
    DisplayMenu(menu3, client, MENU_TIME_FOREVER);
}

void DisplaySpeedPlayerMenu(int client)
{
    Handle menu4 = CreateMenu(MenuSubHandler_SpeedPlayer);
    SetMenuTitle(menu4, "Select Player:");
    SetMenuExitBackButton(menu4, true);
    AddTargetsToMenu2(menu4, client, COMMAND_FILTER_CONNECTED);
    DisplayMenu(menu4, client, MENU_TIME_FOREVER);
}

void DisplaySetHpPlayerMenu(int client)
{
    Handle menu5 = CreateMenu(MenuSubHandler_SetHpPlayer);
    SetMenuTitle(menu5, "Select Player:");
    SetMenuExitBackButton(menu5, true);
    AddTargetsToMenu2(menu5, client, COMMAND_FILTER_CONNECTED);
    DisplayMenu(menu5, client, MENU_TIME_FOREVER);
}

void DisplayChangeHpMenu(int client)
{
    Handle menu5 = CreateMenu(MenuSubHandler_ChangeHp);
    SetMenuTitle(menu5, "Select Player:");
    SetMenuExitBackButton(menu5, true);
    AddTargetsToMenu2(menu5, client, COMMAND_FILTER_CONNECTED);
    DisplayMenu(menu5, client, MENU_TIME_FOREVER);
}

void DisplayColorPlayerMenu(int client)
{
    Handle menu6 = CreateMenu(MenuSubHandler_ColorPlayer);
    SetMenuTitle(menu6, "Select Player:");
    SetMenuExitBackButton(menu6, true);
    AddTargetsToMenu2(menu6, client, COMMAND_FILTER_CONNECTED);
    DisplayMenu(menu6, client, MENU_TIME_FOREVER);
}

void DisplayCreateExplosionMenu(int client)
{
    Handle menu7 = CreateMenu(MenuHandler_CreateExplosion);
    SetMenuTitle(menu7, "Select Position:");
    SetMenuExitBackButton(menu7, true);
    AddMenuItem(menu7, "onpos", "On Current Position");
    AddMenuItem(menu7, "onang", "On Cursor Position");
    DisplayMenu(menu7, client, MENU_TIME_FOREVER);
}

void DisplayScalePlayerMenu(int client)
{
    Handle menu8 = CreateMenu(MenuSubHandler_ScalePlayer);
    SetMenuTitle(menu8, "Select Player:");
    SetMenuExitBackButton(menu8, true);
    AddTargetsToMenu2(menu8, client, COMMAND_FILTER_CONNECTED);
    DisplayMenu(menu8, client, MENU_TIME_FOREVER);
}

void DisplayShakePlayerMenu(int client)
{
    Handle menu8 = CreateMenu(MenuSubHandler_ShakePlayer);
    SetMenuTitle(menu8, "Select Player:");
    SetMenuExitBackButton(menu8, true);
    AddTargetsToMenu2(menu8, client, COMMAND_FILTER_CONNECTED);
    DisplayMenu(menu8, client, MENU_TIME_FOREVER);
}

void DisplayDontRushMenu(int client)
{
    Handle menu10 = CreateMenu(MenuHandler_DontRush);
    SetMenuTitle(menu10, "Select Player:");
    SetMenuExitBackButton(menu10, true);
    AddTargetsToMenu2(menu10, client, COMMAND_FILTER_CONNECTED);
    DisplayMenu(menu10, client, MENU_TIME_FOREVER);
}

void DisplayAirstrikeMenu(int client)
{
    Handle menu11 = CreateMenu(MenuHandler_Airstrike);
    SetMenuTitle(menu11, "Select Player:");
    SetMenuExitBackButton(menu11, true);
    AddTargetsToMenu2(menu11, client, COMMAND_FILTER_CONNECTED);
    DisplayMenu(menu11, client, MENU_TIME_FOREVER);
}

//-------------------------------Sub Menus Needed-----------------------------
int MenuSubHandler_SpeedPlayer(Handle menu4, MenuAction action, int client, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu4;
    }

    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack && hTopMenu != null)
        {
            DisplayTopMenu(hTopMenu, client, TopMenuPosition_LastCategory);
        }
    }
    else if (action == MenuAction_Select)
    {
        static char info[32];
        GetMenuItem(menu4, param2, info, sizeof(info));
        g_iCurrentUserId[client] = StringToInt(info);
        DisplaySpeedValueMenu(client);
    }
    return 0;
}

int MenuSubHandler_SetHpPlayer(Handle menu5, MenuAction action, int client, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu5;
    }

    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack && hTopMenu != null)
        {
            DisplayTopMenu(hTopMenu, client, TopMenuPosition_LastCategory);
        }
    }
    else if (action == MenuAction_Select)
    {
        static char info[32];
        GetMenuItem(menu5, param2, info, sizeof(info));
        g_iCurrentUserId[client] = StringToInt(info);
        DisplaySetHpValueMenu(client);
    }
    return 0;
}

int MenuSubHandler_ChangeHp(Handle menu5, MenuAction action, int client, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu5;
    }

    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack && hTopMenu != null)
        {
            DisplayTopMenu(hTopMenu, client, TopMenuPosition_LastCategory);
        }
    }
    else if (action == MenuAction_Select)
    {
        static char info[32];
        GetMenuItem(menu5, param2, info, sizeof(info));
        g_iCurrentUserId[client] = StringToInt(info);
        DisplayChangeHpStyleMenu(client);
    }
    return 0;
}

int MenuSubHandler_ColorPlayer(Handle menu6, MenuAction action, int client, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu6;
    }

    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack && hTopMenu != null)
        {
            DisplayTopMenu(hTopMenu, client, TopMenuPosition_LastCategory);
        }
    }
    else if (action == MenuAction_Select)
    {
        static char info[32];
        GetMenuItem(menu6, param2, info, sizeof(info));
        g_iCurrentUserId[client] = StringToInt(info);
        DisplayColorValueMenu(client);
    }
    return 0;
}

int MenuSubHandler_ScalePlayer(Handle menu8, MenuAction action, int client, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu8;
    }

    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack && hTopMenu != null)
        {
            DisplayTopMenu(hTopMenu, client, TopMenuPosition_LastCategory);
        }
    }
    else if (action == MenuAction_Select)
    {
        static char info[32];
        GetMenuItem(menu8, param2, info, sizeof(info));
        g_iCurrentUserId[client] = StringToInt(info);
        DisplayScaleValueMenu(client);
    }
    return 0;
}

int MenuSubHandler_ShakePlayer(Handle menu8, MenuAction action, int client, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu8;
    }

    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack && hTopMenu != null)
        {
            DisplayTopMenu(hTopMenu, client, TopMenuPosition_LastCategory);
        }
    }
    else if (action == MenuAction_Select)
    {
        static char info[32];
        GetMenuItem(menu8, param2, info, sizeof(info));
        g_iCurrentUserId[client] = StringToInt(info);
        DisplayShakeValueMenu(client);
    }
    return 0;
}

void DisplaySpeedValueMenu(int client)
{
    Handle menu2a = CreateMenu(MenuHandler_SpeedPlayer);
    SetMenuTitle(menu2a, "New Speed:");
    SetMenuExitBackButton(menu2a, true);
    AddMenuItem(menu2a, "l4d2speeddouble", "x2 Speed");
    AddMenuItem(menu2a, "l4d2speedtriple", "x3 Speed");
    AddMenuItem(menu2a, "l4d2speedhalf", "1/2 Speed");
    AddMenuItem(menu2a, "l4d2speed3", "1/3 Speed");
    AddMenuItem(menu2a, "l4d2speed4", "1/4 Speed");
    AddMenuItem(menu2a, "l4d2speedquarter", "x4 Speed");
    AddMenuItem(menu2a, "l4d2speedfreeze", "0 Speed");
    AddMenuItem(menu2a, "l4d2speednormal", "Normal Speed");
    DisplayMenu(menu2a, client, MENU_TIME_FOREVER);
}

void DisplaySetHpValueMenu(int client)
{
    Handle menu2b = CreateMenu(MenuHandler_SetHpPlayer);
    SetMenuTitle(menu2b, "New Health:");
    SetMenuExitBackButton(menu2b, true);
    AddMenuItem(menu2b, "l4d2hpdouble", "x2 Health");
    AddMenuItem(menu2b, "l4d2hptriple", "x3 Health");
    AddMenuItem(menu2b, "l4d2hphalf", "1/2 Health");
    AddMenuItem(menu2b, "l4d2hp3", "1/3 Health");
    AddMenuItem(menu2b, "l4d2hp4", "1/4 Health");
    AddMenuItem(menu2b, "l4d2hpquarter", "x4 Health");
    AddMenuItem(menu2b, "l4d2hppls100", "+100 Health");
    AddMenuItem(menu2b, "l4d2hppls50", "+50 Health");
    DisplayMenu(menu2b, client, MENU_TIME_FOREVER);
}

void DisplayColorValueMenu(int client)
{
    Handle menu2c = CreateMenu(MenuHandler_ColorPlayer);
    SetMenuTitle(menu2c, "Select Color:");
    SetMenuExitBackButton(menu2c, true);
    AddMenuItem(menu2c, "l4d2colorred", "Red");
    AddMenuItem(menu2c, "l4d2colorblue", "Blue");
    AddMenuItem(menu2c, "l4d2colorgreen", "Green");
    AddMenuItem(menu2c, "l4d2coloryellow", "Yellow");
    AddMenuItem(menu2c, "l4d2colorblack", "Black");
    AddMenuItem(menu2c, "l4d2colorwhite", "White - Normal");
    AddMenuItem(menu2c, "l4d2colortrans", "Transparent");
    AddMenuItem(menu2c, "l4d2colorhtrans", "Semi Transparent");
    DisplayMenu(menu2c, client, MENU_TIME_FOREVER);
}

void DisplayScaleValueMenu(int client)
{
    Handle menu2a = CreateMenu(MenuHandler_ScalePlayer);
    SetMenuTitle(menu2a, "New Scale:");
    SetMenuExitBackButton(menu2a, true);
    AddMenuItem(menu2a, "l4d2scaledouble", "x2 Scale");
    AddMenuItem(menu2a, "l4d2scaletriple", "x3 Scale");
    AddMenuItem(menu2a, "l4d2scalehalf", "1/2 Scale");
    AddMenuItem(menu2a, "l4d2scale3", "1/3 Scale");
    AddMenuItem(menu2a, "l4d2scale4", "1/4 Scale");
    AddMenuItem(menu2a, "l4d2scalequarter", "x4 Scale");
    AddMenuItem(menu2a, "l4d2scalefreeze", "0 Scale");
    AddMenuItem(menu2a, "l4d2scalenormal", "Normal scale");
    DisplayMenu(menu2a, client, MENU_TIME_FOREVER);
}

void DisplayShakeValueMenu(int client)
{
    Handle menu2a = CreateMenu(MenuHandler_ShakePlayer);
    SetMenuTitle(menu2a, "Shake duration:");
    AddMenuItem(menu2a, "shake60", "1 Minute");
    AddMenuItem(menu2a, "shake45", "45 Seconds");
    AddMenuItem(menu2a, "shake30", "30 Seconds");
    AddMenuItem(menu2a, "shake15", "15 Seconds");
    AddMenuItem(menu2a, "shake10", "10 Seconds");
    AddMenuItem(menu2a, "shake5", "5 Seconds");
    AddMenuItem(menu2a, "shake1", "1 Second");
    SetMenuExitBackButton(menu2a, true);
    DisplayMenu(menu2a, client, MENU_TIME_FOREVER);
}

void DisplayChangeHpStyleMenu(int client)
{
    Handle menu2a = CreateMenu(MenuHandler_ChangeHpPlayer);
    SetMenuTitle(menu2a, "Select Style:");
    SetMenuExitBackButton(menu2a, true);
    AddMenuItem(menu2a, "l4d2perm", "Permanent Health");
    AddMenuItem(menu2a, "l4d2temp", "Temporal Health");
    DisplayMenu(menu2a, client, MENU_TIME_FOREVER);
}

//-------------------------------Do action------------------------------------
int MenuHandler_VomitPlayer(Handle menu2, MenuAction action, int client, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu2;
    }

    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack && hTopMenu != null)
        {
            DisplayTopMenu(hTopMenu, client, TopMenuPosition_LastCategory);
        }
    }
    else if (action == MenuAction_Select)
    {
        static char info[32];
        int userid, target;
        GetMenuItem(menu2, param2, info, sizeof(info));
        userid = StringToInt(info);
        target = GetClientOfUserId(userid);

        LogCommand("'%N' used the 'Vomit Player' command on '%N'", client, target);

        VomitPlayer(target, client);
        DisplayVomitPlayerMenu(client);
    }
    return 0;
}

int MenuHandler_TeleportPlayer(Handle menu2, MenuAction action, int client, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu2;
    }

    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack && hTopMenu != null)
        {
            DisplayTopMenu(hTopMenu, client, TopMenuPosition_LastCategory);
        }
    }
    else if (action == MenuAction_Select)
    {
        static char info[32];
        int userid, target;
        GetMenuItem(menu2, param2, info, sizeof(info));
        userid = StringToInt(info);
        target = GetClientOfUserId(userid);

        float VecOrigin[3];
        DoClientTrace(client, MASK_OPAQUE, true, VecOrigin);

        LogCommand("'%N' used the 'Teleport' command on '%N'", client, target);
        TeleportEntity(target, VecOrigin, NULL_VECTOR, NULL_VECTOR);

        DisplayTeleportPlayerMenu(client);
    }
    return 0;
}

int MenuHandler_ChargePlayer(Handle menu2, MenuAction action, int client, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu2;
    }

    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack && hTopMenu != null)
        {
            DisplayTopMenu(hTopMenu, client, TopMenuPosition_LastCategory);
        }
    }
    else if (action == MenuAction_Select)
    {
        static char info[32];
        int userid, target;
        GetMenuItem(menu2, param2, info, sizeof(info));
        userid = StringToInt(info);
        target = GetClientOfUserId(userid);

        LogCommand("'%N' used the 'Charge' command on '%N'", client, target);
        Charge(target, client);

        DisplayChargePlayerMenu(client);
    }
    return 0;
}

int MenuHandler_GodMode(Handle menu2, MenuAction action, int client, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu2;
    }

    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack && hTopMenu != null)
        {
            DisplayTopMenu(hTopMenu, client, TopMenuPosition_LastCategory);
        }
    }
    else if (action == MenuAction_Select)
    {
        static char info[32];
        int userid, target;
        GetMenuItem(menu2, param2, info, sizeof(info));
        userid = StringToInt(info);
        target = GetClientOfUserId(userid);

        LogCommand("'%N' used the 'God Mode' command on '%N'", client, target);
        GodMode(target, client);

        DisplayGodModeMenu(client);
    }
    return 0;
}

int MenuHandler_IncapPlayer(Handle menu3, MenuAction action, int client, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu3;
    }

    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack && hTopMenu != null)
        {
            DisplayTopMenu(hTopMenu, client, TopMenuPosition_LastCategory);
        }
    }
    else if (action == MenuAction_Select)
    {
        static char info[32];
        int userid, target;
        GetMenuItem(menu3, param2, info, sizeof(info));
        userid = StringToInt(info);
        target = GetClientOfUserId(userid);

        LogCommand("'%N' used the 'Incap Player' command on '%N'", client, target);
        IncapPlayer(target, client);

        DisplayIncapPlayerMenu(client);
    }
    return 0;
}

int MenuHandler_SmackillPlayer(Handle menu3, MenuAction action, int client, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu3;
    }

    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack && hTopMenu != null)
        {
            DisplayTopMenu(hTopMenu, client, TopMenuPosition_LastCategory);
        }
    }
    else if (action == MenuAction_Select)
    {
        static char info[32];
        int userid, target;
        GetMenuItem(menu3, param2, info, sizeof(info));
        userid = StringToInt(info);
        target = GetClientOfUserId(userid);

        LogCommand("'%N' used the 'Smackill Player' command on '%N'", client, target);
        SmackillPlayer(target, client);

        DisplaySmackillPlayerMenu(client);
    }
    return 0;
}

int MenuHandler_SpeedPlayer(Handle menu2a, MenuAction action, int client, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu2a;
    }

    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack && hTopMenu != null)
        {
            DisplayTopMenu(hTopMenu, client, TopMenuPosition_LastCategory);
        }
    }
    else if (action == MenuAction_Select)
    {
        int target = GetClientOfUserId(g_iCurrentUserId[client]);

        if (!Cmd_CheckClient(target, client, true, -1, true)) return 0;

        float speed = GetEntPropFloat(target, Prop_Send, "m_flLaggedMovementValue");

        switch (param2)
        {
            case 0: speed *= 2;
            case 1: speed *= 3;
            case 2: speed /= 2;
            case 3: speed /= 3;
            case 4: speed /= 4;
            case 5: speed *= 4;
            case 6: speed = 0.0;
            case 7: speed = 1.0;
        }
        LogCommand("'%N' used the 'Speed Player' command on '%N' with value <%f>", client, target, speed);

        ChangeSpeed(target, client, speed);
        DisplaySpeedPlayerMenu(client);
    }
    return 0;
}

int MenuHandler_SetHpPlayer(Handle menu2b, MenuAction action, int client, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu2b;
    }

    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack && hTopMenu != null)
        {
            DisplayTopMenu(hTopMenu, client, TopMenuPosition_LastCategory);
        }
    }
    else if (action == MenuAction_Select)
    {
        int health;
        int target = GetClientOfUserId(g_iCurrentUserId[client]);

        if (!Cmd_CheckClient(target, client, true, -1, true)) return 0;

        switch (param2)
        {
            case 0: health = GetClientHealth(target) * 2;
            case 1: health = GetClientHealth(target) * 3;
            case 2: health = GetClientHealth(target) / 2;
            case 3: health = GetClientHealth(target) / 3;
            case 4: health = GetClientHealth(target) / 4;
            case 5: health = GetClientHealth(target) * 4;
            case 6: health = GetClientHealth(target) + 100;
            case 7: health = GetClientHealth(target) + 50;
        }
        LogCommand("'%N' used the 'Set Health' command on '%N' with value <%i>", client, target, health);

        SetHealth(target, client, health);
        DisplaySetHpPlayerMenu(client);
    }
    return 0;
}

int MenuHandler_ColorPlayer(Handle menu2c, MenuAction action, int client, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu2c;
    }

    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack && hTopMenu != null)
        {
            DisplayTopMenu(hTopMenu, client, TopMenuPosition_LastCategory);
        }
    }
    else if (action == MenuAction_Select)
    {
        int target = GetClientOfUserId(g_iCurrentUserId[client]);

        if (!Cmd_CheckClient(target, client, false, -1, true)) return 0;

        static char colorSelect[24];
        switch (param2)
        {
            case 0: strcopy(colorSelect, sizeof(colorSelect), RED);
            case 1: strcopy(colorSelect, sizeof(colorSelect), BLUE);
            case 2: strcopy(colorSelect, sizeof(colorSelect), GREEN);
            case 3: strcopy(colorSelect, sizeof(colorSelect), YELLOW);
            case 4: strcopy(colorSelect, sizeof(colorSelect), BLACK);
            case 5: strcopy(colorSelect, sizeof(colorSelect), WHITE);
            case 6: strcopy(colorSelect, sizeof(colorSelect), TRANSPARENT);
            case 7: strcopy(colorSelect, sizeof(colorSelect), HALFTRANSPARENT);
        }
        LogCommand("'%N' used the 'Color Player' command on '%N' with value <%s>", client, target, colorSelect);

        ChangeColor(target, client, colorSelect);
        DisplayColorPlayerMenu(client);
    }
    return 0;
}

int MenuHandler_CreateExplosion(Handle menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }

    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack && hTopMenu != null)
        {
            DisplayTopMenu(hTopMenu, client, TopMenuPosition_LastCategory);
        }
    }
    else if (action == MenuAction_Select)
    {
        switch (param2)
        {
            case 0:
            {
                float pos[3];
                GetClientAbsOrigin(client, pos);
                CreateExplosion(pos);
            }
            case 1:
            {
                float VecOrigin[3];
                DoClientTrace(client, MASK_OPAQUE, true, VecOrigin);
                CreateExplosion(VecOrigin);
            }
        }
        LogCommand("'%N' used the 'Set Explosion' command", client);
        DisplayCreateExplosionMenu(client);
    }
    return 0;
}

int MenuHandler_ScalePlayer(Handle menu2a, MenuAction action, int client, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu2a;
    }

    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack && hTopMenu != null)
        {
            DisplayTopMenu(hTopMenu, client, TopMenuPosition_LastCategory);
        }
    }
    else if (action == MenuAction_Select)
    {
        float scale;
        int target = GetClientOfUserId(g_iCurrentUserId[client]);

        if (!Cmd_CheckClient(target, client, false, -1, true)) return 0;

        switch (param2)
        {
            case 0: scale = GetEntPropFloat(target, Prop_Send, "m_flModelScale") * 2;
            case 1: scale = GetEntPropFloat(target, Prop_Send, "m_flModelScale") * 3;
            case 2: scale = GetEntPropFloat(target, Prop_Send, "m_flModelScale") / 2;
            case 3: scale = GetEntPropFloat(target, Prop_Send, "m_flModelScale") / 3;
            case 4: scale = GetEntPropFloat(target, Prop_Send, "m_flModelScale") / 4;
            case 5: scale = GetEntPropFloat(target, Prop_Send, "m_flModelScale") * 4;
            case 6: scale = 0.0;
            case 7: scale = 1.0;
        }
        LogCommand("'%N' used the 'Size Player' command on '%N' with value <%f>", client, target, scale);

        ChangeScale(target, client, scale);
        DisplayScalePlayerMenu(client);
    }
    return 0;
}

int MenuHandler_ShakePlayer(Handle menu2a, MenuAction action, int client, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu2a;
    }

    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack && hTopMenu != null)
        {
            DisplayTopMenu(hTopMenu, client, TopMenuPosition_LastCategory);
        }
    }
    else if (action == MenuAction_Select)
    {
        int target = GetClientOfUserId(g_iCurrentUserId[client]);

        if (!Cmd_CheckClient(target, client, false, -1, true)) return 0;

        float duration = 0.0;
        switch (param2)
        {
            case 0: duration = 60.0;
            case 1: duration = 45.0;
            case 2: duration = 30.0;
            case 3: duration = 15.0;
            case 4: duration = 10.0;
            case 5: duration = 5.0;
            case 6: duration = 1.0;
        }
        LogCommand("'%N' used the 'Shake' command on '%N' with value <%f>", client, target, duration);

        Shake(target, client, duration);
        DisplayShakePlayerMenu(client);
    }
    return 0;
}

int MenuHandler_DontRush(Handle menu10, MenuAction action, int client, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu10;
    }

    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack && hTopMenu != null)
        {
            DisplayTopMenu(hTopMenu, client, TopMenuPosition_LastCategory);
        }
    }
    else if (action == MenuAction_Select)
    {
        static char info[32];
        int userid, target;
        GetMenuItem(menu10, param2, info, sizeof(info));
        userid = StringToInt(info);
        target = GetClientOfUserId(userid);

        LogCommand("'%N' used the 'Anti Rush' command on '%N'", client, target);
        TeleportBack(target, client);

        DisplayDontRushMenu(client);
    }
    return 0;
}

int MenuHandler_Airstrike(Handle menu2, MenuAction action, int client, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu2;
    }

    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack && hTopMenu != null)
        {
            DisplayTopMenu(hTopMenu, client, TopMenuPosition_LastCategory);
        }
    }
    else if (action == MenuAction_Select)
    {
        static char info[32];
        int userid, target;
        GetMenuItem(menu2, param2, info, sizeof(info));
        userid = StringToInt(info);
        target = GetClientOfUserId(userid);

        if (!Cmd_CheckClient(target, client, true, -1, true)) return 0;

        LogCommand("'%N' used the 'Airstrike' command on '%N'", client, target);
        Airstrike(target);

        DisplayAirstrikeMenu(client);
    }
    return 0;
}

int MenuHandler_ChangeHpPlayer(Handle menu2, MenuAction action, int client, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu2;
    }

    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack && hTopMenu != null)
        {
            DisplayTopMenu(hTopMenu, client, TopMenuPosition_LastCategory);
        }
    }
    else if (action == MenuAction_Select)
    {
        int target = GetClientOfUserId(g_iCurrentUserId[client]);

        if (!Cmd_CheckClient(target, client, true, 1, true)) return 0;

        int type = 0;
        static char temp_str[5];
        switch (param2)
        {
            case 0:
            {
                type = 1;
                strcopy(temp_str, sizeof(temp_str), "perm");
            }
            case 1:
            {
                type = 2;
                strcopy(temp_str, sizeof(temp_str), "temp");
            }
        }
        LogCommand("'%N' used the 'Change Health Type' command on '%N' with value <%s>", client, target, temp_str);

        SwitchHealth(target, client, type);
        DisplayChangeHpMenu(client);
    }
    return 0;
}