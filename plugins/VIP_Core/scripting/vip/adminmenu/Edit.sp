#if defined __AdminMenu_Edit__
    #endinput
#endif
#define __AdminMenu_Edit__

void ShowEditTimeMenu(int iClient)
{
    char szBuffer[128];
    Menu hMenu = new Menu(MenuHandler_EditTimeMenu);

    hMenu.SetTitle("%T:\n ", "MENU_EDIT_TIME", iClient);
    hMenu.ExitBackButton = true;

    FormatEx(SZF(szBuffer), "%T", "MENU_TIME_SET", iClient);
    hMenu.AddItem(NULL_STRING, szBuffer);
    FormatEx(SZF(szBuffer), "%T", "MENU_TIME_ADD", iClient);
    hMenu.AddItem(NULL_STRING, szBuffer);
    FormatEx(SZF(szBuffer), "%T", "MENU_TIME_TAKE", iClient);
    hMenu.AddItem(NULL_STRING, szBuffer);

    ReductionMenu(hMenu, 3);

    hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int MenuHandler_EditTimeMenu(Menu hMenu, MenuAction action, int iClient, int iItem)
{
    switch(action)
    {
        case MenuAction_End: delete hMenu;
        case MenuAction_Cancel:
        {
            if (iItem == MenuCancel_ExitBack)
            {
                ShowTargetInfoMenu(iClient);
            }
        }
        case MenuAction_Select:
        {
            g_hClientData[iClient].SetValue(DATA_KEY_TimeType, iItem);
            g_hClientData[iClient].SetValue(DATA_KEY_MenuType, MENU_TYPE_EDIT);
            ShowTimeMenu(iClient);
        }
    }
    return 0;
}