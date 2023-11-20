/**
* sourcebans.sp
*
* This file contains all Source Server Plugin Functions
* @author SourceBans Development Team
* @version 0.0.0.$Rev: 108 $
* @copyright InterWave Studios (www.interwavestudios.com)
* @package SourceBans
* @link http://www.sourcebans.net
*/
#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sourcebans>
#include <solaris/chat>

#undef REQUIRE_PLUGIN
#include <adminmenu>
#define REQUIRE_PLUGIN

#undef REQUIRE_EXTENSIONS
#include <connecthook>
#define REQUIRE_EXTENSIONS

// GLOBAL DEFINES
#define CONSOLE_AUTH "STEAM_0:0:00000000000"
#define YELLOW       0x01
#define NAMECOLOR    0x02
#define TEAMCOLOR    0x03
#define GREEN        0x04

#define DISABLE_ADDBAN 1
#define DISABLE_UNBAN  2

enum State /* ConfigState */
{
    ConfigStateNone = 0,
    ConfigStateConfig,
    ConfigStateReasons,
    ConfigStateHacking
}

int g_BanTarget[MAXPLAYERS + 1] = {-1, ...};
int g_BanTime[MAXPLAYERS + 1]   = {-1, ...};

State ConfigState;

Handle ConfigParser;
TopMenu hTopMenu;

char BLANK[]  = "";
char Prefix[] = "[SourceBans] ";

char ServerIp[24];
char ServerPort[7];
char DatabasePrefix[10] = "sb";
char WebsiteAddress[128];

/* Admin Stuff*/
// AdminCachePart loadPart;
bool loadAdmins;
bool loadGroups;
bool loadOverrides;
AdminFlag g_FlagLetters[26];
int curLoading = 0;

/* Admin KeyValues */
char groupsLoc[128];
char adminsLoc[128];

/* Cvar handle*/
ConVar CvarHostIp;
ConVar CvarPort;

/* hDatabase handle */
Handle hDatabase;
Handle SQLiteDB;

/* Menu file globals */
Menu ReasonMenuHandle;
Menu HackingMenuHandle;

/* Datapack and Timer handles */
Handle PlayerRecheck[MAXPLAYERS + 1]    = {null, ...};
DataPack PlayerDataPack[MAXPLAYERS + 1] = {null, ...};

/* Player ban check status */
bool PlayerStatus[MAXPLAYERS + 1];

/* Disable of addban and unban */
int CommandDisable;
bool backupConfig = true;
bool enableAdmins = true;

/* Require a lastvisited from SB site */
bool requireSiteLogin = false;

/* Log Stuff */
char logFile[256];

/* Own Chat Reason */
int g_ownReasons[MAXPLAYERS + 1] = {false, ...};

float RetryTime      = 15.0;
int ProcessQueueTime = 5;
// bool g_bConnecting   = false;
bool LateLoaded;
bool AutoAdd;

int serverID = -1;
StringMap Trie_PlayersTemporarilyBanned;

public Plugin myinfo =
{
    name        = "SourceBans",
    author      = "SourceBans Development Team",
    description = "Advanced ban management for the Source engine",
    version     = "1.4.9",
    url         = "http://www.sourcebans.net"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    RegPluginLibrary("sourcebans");
    CreateNative("SBBanPlayer", Native_SBBanPlayer);
    LateLoaded = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    LoadTranslations("common.phrases");
    LoadTranslations("plugin.basecommands");
    LoadTranslations("sourcebans.phrases");
    LoadTranslations("basebans.phrases");

    loadAdmins = loadGroups = loadOverrides = false;

    CvarHostIp = FindConVar("hostip");
    CvarPort   = FindConVar("hostport");

    RegServerCmd("sm_rehash", sm_rehash, "Reload SQL admins");

    RegAdminCmd("sm_ban",    CommandBan,    ADMFLAG_BAN,   "sm_ban <#userid|name> <minutes|0> [reason]");
    RegAdminCmd("sm_banip",  CommandBanIp,  ADMFLAG_BAN,   "sm_banip <ip|#userid|name> <time> [reason]");
    RegAdminCmd("sm_addban", CommandAddBan, ADMFLAG_RCON,  "sm_addban <time> <steamid> [reason]");
    RegAdminCmd("sm_unban",  CommandUnban,  ADMFLAG_UNBAN, "sm_unban <steamid|ip> [reason]");
    RegAdminCmd("sb_reload", CommandReload,    ADMFLAG_RCON,  "Reload sourcebans config and ban reason menu options", BLANK);

    if ((ReasonMenuHandle = new Menu(ReasonSelected)) != null)
    {
        SetMenuPagination(ReasonMenuHandle, 8);
        ReasonMenuHandle.ExitBackButton = true;
    }

    if ((HackingMenuHandle = new Menu(HackingSelected)) != null)
    {
        SetMenuPagination(HackingMenuHandle, 8);
        HackingMenuHandle.ExitBackButton = true;
    }

    g_FlagLetters['a'-'a'] = Admin_Reservation;
    g_FlagLetters['b'-'a'] = Admin_Generic;
    g_FlagLetters['c'-'a'] = Admin_Kick;
    g_FlagLetters['d'-'a'] = Admin_Ban;
    g_FlagLetters['e'-'a'] = Admin_Unban;
    g_FlagLetters['f'-'a'] = Admin_Slay;
    g_FlagLetters['g'-'a'] = Admin_Changemap;
    g_FlagLetters['h'-'a'] = Admin_Convars;
    g_FlagLetters['i'-'a'] = Admin_Config;
    g_FlagLetters['j'-'a'] = Admin_Chat;
    g_FlagLetters['k'-'a'] = Admin_Vote;
    g_FlagLetters['l'-'a'] = Admin_Password;
    g_FlagLetters['m'-'a'] = Admin_RCON;
    g_FlagLetters['n'-'a'] = Admin_Cheats;
    g_FlagLetters['o'-'a'] = Admin_Custom1;
    g_FlagLetters['p'-'a'] = Admin_Custom2;
    g_FlagLetters['q'-'a'] = Admin_Custom3;
    g_FlagLetters['r'-'a'] = Admin_Custom4;
    g_FlagLetters['s'-'a'] = Admin_Custom5;
    g_FlagLetters['t'-'a'] = Admin_Custom6;
    g_FlagLetters['z'-'a'] = Admin_Root;

    BuildPath(Path_SM, logFile, sizeof(logFile), "logs/sourcebans.log");
    // g_bConnecting = true;

    // Catch config error and show link to FAQ
    if (!SQL_CheckConfig("sourcebans"))
    {
        if (ReasonMenuHandle != null)
        {
            delete ReasonMenuHandle;
        }

        if (HackingMenuHandle != null)
        {
            delete HackingMenuHandle;
        }

        LogToFile(logFile, "Database failure: Could not find Database conf \"sourcebans\". See FAQ: http://sourcebans.net/node/19");
        SetFailState("Database failure: Could not find Database conf \"sourcebans\"");
        return;
    }

    SQL_TConnect(GotDatabase, "sourcebans");

    BuildPath(Path_SM, groupsLoc, sizeof(groupsLoc), "configs/admin_groups.cfg");
    BuildPath(Path_SM, adminsLoc, sizeof(adminsLoc), "configs/admins.cfg");

    InitializeBackupDB();

    // This timer is what processes the SQLite queue when the database is unavailable
    CreateTimer(float(ProcessQueueTime * 60), ProcessQueue);

    /* Account for late loading */
    if (LateLoaded)
    {
        char auth[30];

        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientConnected(i) && !IsFakeClient(i))
            {
                PlayerStatus[i] = false;
            }

            if (IsClientInGame(i) && !IsFakeClient(i))
            {
                GetClientAuthId(i, AuthId_Steam2, auth, sizeof(auth), true);
                OnClientAuthorized(i, auth);
            }
        }
    }

    Trie_PlayersTemporarilyBanned = new StringMap();
}

public void OnAllPluginsLoaded()
{
    TopMenu topmenu;

    if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
    {
        OnAdminMenuReady(topmenu);
    }
}

public void OnConfigsExecuted()
{
    char filename[200];
    BuildPath(Path_SM, filename, sizeof(filename), "plugins/basebans.smx");

    if (FileExists(filename))
    {
        char newfilename[200];
        BuildPath(Path_SM, newfilename, sizeof(newfilename), "plugins/disabled/basebans.smx");

        ServerCommand("sm plugins unload basebans");

        if (FileExists(newfilename))
        {
            DeleteFile(newfilename);
        }

        RenameFile(newfilename, filename);
        LogToFile(logFile, "plugins/basebans.smx was unloaded and moved to plugins/disabled/basebans.smx");
    }
}

public void OnMapStart()
{
    ResetSettings();
}

public void OnMapEnd()
{
    for (int i = 0; i <= MaxClients; i++)
    {
        if (PlayerDataPack[i] != null)
        {
            /* Need to close reason pack */
            delete PlayerDataPack[i];
            PlayerDataPack[i] = null;
        }
    }
}

// CLIENT CONNECTION FUNCTIONS //
public Action OnClientPreAdminCheck(int client)
{
    if (curLoading > 0)
    {
        return Plugin_Stop;
    }

    return Plugin_Continue;
}

public void OnClientDisconnect(int client)
{
    if (PlayerRecheck[client] != null)
    {
        KillTimer(PlayerRecheck[client]);
        PlayerRecheck[client] = null;
    }

    g_ownReasons[client] = false;
}

public bool OnClientConnect(int client, char[] rejectmsg, int maxlen)
{
    PlayerStatus[client] = false;
    return true;
}

public void OnClientAuthorized(int client, const char[] auth)
{
    /* Do not check bots nor check player with lan steamid. */
    if (auth[0] == 'B' || auth[9] == 'L' || hDatabase == null)
    {
        PlayerStatus[client] = true;
        return;
    }

    char ip[30];
    GetClientIP(client, ip, sizeof(ip));

    char Query[256];
    FormatEx(Query, sizeof(Query), "SELECT bid FROM %s_bans WHERE ((type = 0 AND authid REGEXP '^STEAM_[0-9]:%s$') OR (type = 1 AND ip = '%s')) AND (length = '0' OR ends > UNIX_TIMESTAMP()) AND RemoveType IS NULL", DatabasePrefix, auth[8], ip);

    SQL_TQuery(hDatabase, VerifyBan, Query, GetClientUserId(client), DBPrio_High);
}

/*
public void OnRebuildAdminCache(AdminCachePart part)
{
    loadPart = part;

    switch (loadPart)
    {
        case AdminCache_Overrides:
        {
            loadOverrides = true;
        }
        case AdminCache_Groups:
        {
            loadGroups = true;
        }
        case AdminCache_Admins:
        {
            loadAdmins = true;
        }
    }

    if (enableAdmins)
    {
        if (hDatabase == null)
        {
            if (!g_bConnecting)
            {
                g_bConnecting = true;
                SQL_TConnect(GotDatabase, "sourcebans");
            }
        }
        else
        {
            GotDatabase(hDatabase, hDatabase, "", 0);
        }
    }
}
*/

// COMMAND CODE //
public Action SolarisChat_OnChatMessage(int client, int args, int team, bool team_chat, ArrayList recipients, char[] tag_color, char[] tag, char[] name_color, char[] name, char[] msg_color, char[] msg)
{
    if (g_ownReasons[client])
    {
        int length = strlen(msg);
        g_ownReasons[client] = false;
        if (StrEqual(msg, "!noreason"))
        {
            PrintToChat(client, "%c[%cSourceBans%c]%c %t", GREEN, NAMECOLOR, GREEN, NAMECOLOR, "Chat Reason Aborted");
            return Plugin_Handled;
        }
        ReplaceString(msg, length, "/", "");
        // ban him!
        PrepareBan(client, g_BanTarget[client], g_BanTime[client], msg, length);
        // block the reason to be sent in chat
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

public Action CommandReload(int client, int args)
{
    ResetSettings();
    return Plugin_Handled;
}

public Action CommandBan(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "%sUsage: sm_ban <#userid|name> <time|0> [reason]", Prefix);
        return Plugin_Handled;
    }

    // This is mainly for me sanity since client used to be called admin and target used to be called client
    int admin = client;

    // Get the target, find target returns a message on failure so we do not
    char buffer[100];
    GetCmdArg(1, buffer, sizeof(buffer));

    int target = FindTarget(client, buffer, true);

    if (target == -1)
    {
        return Plugin_Handled;
    }

    // Get the ban time
    GetCmdArg(2, buffer, sizeof(buffer));
    int time = StringToInt(buffer);

    if (!time && client && !(CheckCommandAccess(client, "sm_unban", ADMFLAG_UNBAN|ADMFLAG_ROOT)))
    {
        ReplyToCommand(client, "You do not have Perm Ban Permission");
        return Plugin_Handled;
    }

    // Get the reason
    char reason[128];

    if (args >= 3)
    {
        GetCmdArg(3, reason, sizeof(reason));
    }
    else
    {
        reason[0] = '\0';
    }

    g_BanTarget[client] = target;
    g_BanTime[client]   = time;

    if (!PlayerStatus[target])
    {
        // The target has not been banned verify. It must be completed before you can ban anyone.
        ReplyToCommand(admin, "%c[%cSourceBans%c]%c %t", GREEN, NAMECOLOR, GREEN, NAMECOLOR, "Ban Not Verified");
        return Plugin_Handled;
    }

    CreateBan(client, target, time, reason);
    return Plugin_Handled;
}

public Action CommandBanIp(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "%sUsage: sm_banip <ip|#userid|name> <time> [reason]", Prefix);
        return Plugin_Handled;
    }

    int len;
    int next_len;
    char Arguments[256];
    char arg[50];
    char time[20];

    GetCmdArgString(Arguments, sizeof(Arguments));
    len = BreakString(Arguments, arg, sizeof(arg));

    if ((next_len = BreakString(Arguments[len], time, sizeof(time))) != -1)
    {
        len += next_len;
    }
    else
    {
        len = 0;
        Arguments[0] = '\0';
    }

    char target_name[MAX_TARGET_LENGTH];
    int target_list[1];
    bool tn_is_ml;
    int target = -1;

    if (ProcessTargetString(arg, client, target_list, 1, COMMAND_FILTER_CONNECTED|COMMAND_FILTER_NO_MULTI, target_name, sizeof(target_name), tn_is_ml) > 0)
    {
        target = target_list[0];

        if (!IsFakeClient(target) && CanUserTarget(client, target))
        {
            GetClientIP(target, arg, sizeof(arg));
        }
    }

    char adminIp[24];
    char adminAuth[64];

    int minutes = StringToInt(time);

    if (!minutes && client && !(CheckCommandAccess(client, "sm_unban", ADMFLAG_UNBAN|ADMFLAG_ROOT)))
    {
        ReplyToCommand(client, "You do not have Perm Ban Permission");
        return Plugin_Handled;
    }

    if (!client)
    {
        // setup dummy adminAuth and adminIp for server
        strcopy(adminAuth, sizeof(adminAuth), CONSOLE_AUTH);
        strcopy(adminIp, sizeof(adminIp), ServerIp);
    }
    else
    {
        GetClientIP(client, adminIp, sizeof(adminIp));
        GetClientAuthId(client, AuthId_Steam2, adminAuth, sizeof(adminAuth), true);
    }

    // Pack everything into a data pack so we can retain it
    DataPack dataPack = new DataPack();
    dataPack.WriteCell(client);
    dataPack.WriteCell(minutes);
    dataPack.WriteString(Arguments[len]);
    dataPack.WriteString(arg);
    dataPack.WriteString(adminAuth);
    dataPack.WriteString(adminIp);

    char Query[256];
    FormatEx(Query, sizeof(Query), "SELECT bid FROM %s_bans WHERE type = 1 AND ip     = '%s' AND (length = 0 OR ends > UNIX_TIMESTAMP()) AND RemoveType IS NULL", DatabasePrefix, arg);

    SQL_TQuery(hDatabase, SelectBanIpCallback,  Query, dataPack, DBPrio_High);
    return Plugin_Handled;
}

public Action CommandUnban(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "%sUsage: sm_unban <steamid|ip> [reason]", Prefix);
        return Plugin_Handled;
    }

    if (CommandDisable & DISABLE_UNBAN)
    {
        // They must go to the website to unban people
        ReplyToCommand(client, "%s%t", Prefix, "Can Not Unban", WebsiteAddress);
        return Plugin_Handled;
    }

    int len;

    char Arguments[256];
    GetCmdArgString(Arguments, sizeof(Arguments));

    char arg[50];
    char adminAuth[64];

    if ((len = BreakString(Arguments, arg, sizeof(arg))) == -1)
    {
        len          = 0;
        Arguments[0] = '\0';
    }

    if (!client)
    {
        // setup dummy adminAuth and adminIp for server
        strcopy(adminAuth, sizeof(adminAuth), CONSOLE_AUTH);
    }
    else
    {
        GetClientAuthId(client, AuthId_Steam2, adminAuth, sizeof(adminAuth), true);
    }

    // Pack everything into a data pack so we can retain it
    DataPack dataPack = new DataPack();
    dataPack.WriteCell(client);
    dataPack.WriteString(Arguments[len]);
    dataPack.WriteString(arg);
    dataPack.WriteString(adminAuth);

    char query[200];

    if (strncmp(arg, "STEAM_", 6) == 0)
    {
        Format(query, sizeof(query), "SELECT bid FROM %s_bans WHERE (type = 0 AND authid = '%s') AND (length = '0' OR ends > UNIX_TIMESTAMP()) AND RemoveType IS NULL", DatabasePrefix, arg);
    }
    else
    {
        Format(query, sizeof(query), "SELECT bid FROM %s_bans WHERE (type = 1 AND ip     = '%s') AND (length = '0' OR ends > UNIX_TIMESTAMP()) AND RemoveType IS NULL", DatabasePrefix, arg);
    }

    SQL_TQuery(hDatabase, SelectUnbanCallback, query, dataPack);
    return Plugin_Handled;
}

public Action CommandAddBan(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "%sUsage: sm_addban <time> <steamid> [reason]", Prefix);
        return Plugin_Handled;
    }

    if (CommandDisable & DISABLE_ADDBAN)
    {
        // They must go to the website to add bans
        ReplyToCommand(client, "%s%t", Prefix, "Can Not Add Ban", WebsiteAddress);
        return Plugin_Handled;
    }

    char arg_string[256];
    GetCmdArgString(arg_string, sizeof(arg_string));

    char time[50];
    char authid[50];

    int len;
    int total_len;

    /* Get time */
    if ((len = BreakString(arg_string, time, sizeof(time))) == -1)
    {
        ReplyToCommand(client, "%sUsage: sm_addban <time> <steamid> [reason]", Prefix);
        return Plugin_Handled;
    }

    total_len += len;

    /* Get steamid */
    if ((len = BreakString(arg_string[total_len], authid, sizeof(authid))) != -1)
    {
        total_len += len;
    }
    else
    {
        total_len     = 0;
        arg_string[0] = '\0';
    }

    char adminIp[24];
    char adminAuth[64];

    int minutes = StringToInt(time);

    if (!minutes && client && !(CheckCommandAccess(client, "sm_unban", ADMFLAG_UNBAN|ADMFLAG_ROOT)))
    {
        ReplyToCommand(client, "You do not have Perm Ban Permission");
        return Plugin_Handled;
    }

    if (!client)
    {
        // setup dummy adminAuth and adminIp for server
        strcopy(adminAuth, sizeof(adminAuth), CONSOLE_AUTH);
        strcopy(adminIp, sizeof(adminIp), ServerIp);
    }
    else
    {
        GetClientIP(client, adminIp, sizeof(adminIp));
        GetClientAuthId(client, AuthId_Steam2, adminAuth, sizeof(adminAuth), true);
    }

    // Pack everything into a data pack so we can retain it
    DataPack dataPack = new DataPack();
    dataPack.WriteCell(client);
    dataPack.WriteCell(minutes);
    dataPack.WriteString(arg_string[total_len]);
    dataPack.WriteString(authid);
    dataPack.WriteString(adminAuth);
    dataPack.WriteString(adminIp);

    char Query[256];
    FormatEx(Query, sizeof(Query), "SELECT bid FROM %s_bans WHERE type = 0 AND authid = '%s' AND (length = 0 OR ends > UNIX_TIMESTAMP()) AND RemoveType IS NULL", DatabasePrefix, authid);
    SQL_TQuery(hDatabase, SelectAddbanCallback, Query, dataPack, DBPrio_High);
    return Plugin_Handled;
}

public Action sm_rehash(int args)
{
    if (enableAdmins)
    {
        DumpAdminCache(AdminCache_Groups, true);
    }

    return Plugin_Handled;
}

public void OnClientPutInServer(int client)
{
    if (enableAdmins)
    {
        DumpAdminCache(AdminCache_Groups, true);
    }
}

// MENU CODE //
public void OnAdminMenuReady(Handle aTopMenu)
{
    TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

    /* Block us from being called twice */
    if (topmenu == hTopMenu)
    {
        return;
    }

    /* Save the Handle */
    hTopMenu = topmenu;

    /* Find the "Player Commands" category */
    TopMenuObject player_commands = hTopMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);

    if (player_commands != INVALID_TOPMENUOBJECT)
    {
        hTopMenu.AddItem("sm_ban", AdminMenu_Ban, player_commands, "sm_ban", ADMFLAG_BAN, "Ban Player");
    }
}

public int AdminMenu_Ban(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    /* Clear the Ownreason bool, so he is able to chat again;) */
    g_ownReasons[param] = false;

    if (action == TopMenuAction_DisplayOption)  // We are only being displayed, We only need to show the option name
    {
        Format(buffer, maxlength, "%T", "Ban player", param);
    }
    else if (action == TopMenuAction_SelectOption)
    {
        DisplayBanTargetMenu(param);    // Someone chose to ban someone, show the list of users menu
    }

    return 0;
}

public int ReasonSelected(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char info[128];
        char key[128];
        menu.GetItem(param2, key, sizeof(key), _, info, sizeof(info));

        if (StrEqual("Hacking", key))
        {
            HackingMenuHandle.Display(param1, MENU_TIME_FOREVER);
            return 0;
        }

        if (StrEqual("Own Reason", key))
        {
            // admin wants to use his own reason
            g_ownReasons[param1] = true;
            PrintToChat(param1, "%c[%cSourceBans%c]%c %t", GREEN, NAMECOLOR, GREEN, NAMECOLOR, "Chat Reason");
            return 0;
        }

        if (g_BanTarget[param1] != -1 && g_BanTime[param1] != -1)
        {
            PrepareBan(param1, g_BanTarget[param1], g_BanTime[param1], info, sizeof(info));
        }

    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_Disconnected)
    {
        if (PlayerDataPack[param1] != null)
        {
            delete PlayerDataPack[param1];
            PlayerDataPack[param1] = null;
        }
    }
    else if (action == MenuAction_Cancel)
    {
        DisplayBanTimeMenu(param1);
    }

    return 0;
}

public int HackingSelected(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char info[128];
        char key[128];
        menu.GetItem(param2, key, sizeof(key), _, info, sizeof(info));

        if (g_BanTarget[param1] != -1 && g_BanTime[param1] != -1)
        {
            PrepareBan(param1, g_BanTarget[param1], g_BanTime[param1], info, sizeof(info));
        }

    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_Disconnected)
    {
        DataPack Pack = PlayerDataPack[param1];

        if (Pack != null)
        {
            Pack.Position = view_as<DataPackPos>(40);
            DataPack ReasonPack = Pack.ReadCell();

            if (ReasonPack != null)
            {
                delete ReasonPack;
            }

            delete Pack;
            PlayerDataPack[param1] = null;
        }
    }
    else if (action == MenuAction_Cancel)
    {
        ReasonMenuHandle.Display(param1, MENU_TIME_FOREVER);
    }

    return 0;
}

public int MenuHandler_BanPlayerList(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack && hTopMenu != null)
        {
            hTopMenu.Display(param1, TopMenuPosition_LastCategory);
        }
    }
    else if (action == MenuAction_Select)
    {
        char info[32];
        char name[32];
        int userid;
        int target;

        menu.GetItem(param2, info, sizeof(info), _, name, sizeof(name));
        userid = StringToInt(info);

        if ((target = GetClientOfUserId(userid)) == 0)
        {
            PrintToChat(param1, "%s%t", Prefix, "Player no longer available");
        }
        else if (!CanUserTarget(param1, target))
        {
            PrintToChat(param1, "%s%t", Prefix, "Unable to target");
        }
        else
        {
            g_BanTarget[param1] = target;
            DisplayBanTimeMenu(param1);
        }
    }

    return 0;
}

public int MenuHandler_BanTimeList(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack && hTopMenu != null)
        {
            hTopMenu.Display(param1, TopMenuPosition_LastCategory);
        }
    }
    else if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        g_BanTime[param1] = StringToInt(info);
        ReasonMenuHandle.Display(param1, MENU_TIME_FOREVER);
    }

    return 0;
}

stock void DisplayBanTargetMenu(int client)
{
    Menu menu = new Menu(MenuHandler_BanPlayerList);

    char title[100];
    Format(title, sizeof(title), "%T:", "Ban player", client);
    menu.SetTitle(title);
    menu.ExitBackButton = true;
    AddTargetsToMenu(menu, client, false, false);
    menu.Display(client, MENU_TIME_FOREVER);
}

stock void DisplayBanTimeMenu(int client)
{
    Menu menu = new Menu(MenuHandler_BanTimeList);

    char title[100];
    Format(title, sizeof(title), "%T:", "Ban player", client);

    menu.SetTitle(title);
    menu.ExitBackButton = true;

    if (CheckCommandAccess(client, "sm_unban", ADMFLAG_UNBAN|ADMFLAG_ROOT))
    {
        menu.AddItem("0", "Permanent");
    }

    menu.AddItem("10",    "10 minutes");
    menu.AddItem("30",    "30 minutes");
    menu.AddItem("60",    "1 hour");
    menu.AddItem("240",   "4 hours");
    menu.AddItem("1440",  "1 day");
    menu.AddItem("10080", "1 week");
    menu.Display(client, MENU_TIME_FOREVER);
}

stock void ResetMenu()
{
    if (ReasonMenuHandle != null)
    {
        ReasonMenuHandle.RemoveAllItems();
    }
}

// QUERY CALL BACKS //
public void GotDatabase(Handle owner, Handle hndl, const char[] error, any data)
{
    if (hndl == null)
    {
        LogToFile(logFile, "Database failure: %s. See FAQ: http://www.sourcebans.net/node/20", error);
        // g_bConnecting = false;
        return;
    }

    hDatabase = hndl;

    char query[1024];
    FormatEx(query, sizeof(query), "SET NAMES `utf8`");
    SQL_TQuery(hDatabase, ErrorCheckCallback, query);

    InsertServerInfo();

    if (loadOverrides)
    {
        loadOverrides = false;
    }

    if (loadGroups && enableAdmins)
    {
        FormatEx(query, 1024, "SELECT name, flags, immunity, groups_immune   \
        FROM %s_srvgroups ORDER BY id", DatabasePrefix);
        curLoading++;
        SQL_TQuery(hDatabase, GroupsDone, query);
        loadGroups = false;
    }

    if (loadAdmins && enableAdmins)
    {
        char queryLastLogin[50] = "";

        if (requireSiteLogin)
        {
            queryLastLogin = "lastvisit IS NOT NULL AND lastvisit != '' AND";
        }

        if (serverID == -1)
        {
            FormatEx(query, 1024, "SELECT authid, srv_password, (SELECT name FROM %s_srvgroups WHERE name = srv_group AND flags != '') AS srv_group, srv_flags, user, immunity  \
            FROM %s_admins_servers_groups AS asg \
            LEFT JOIN %s_admins AS a ON a.aid = asg.admin_id AND a.deleted_at IS NULL AND (a.expired > UNIX_TIMESTAMP() OR a.expired = 0) \
            WHERE %s (server_id = (SELECT sid FROM %s_servers WHERE ip = '%s' AND port = '%s' LIMIT 0, 1)  \
            OR srv_group_id = ANY (SELECT group_id FROM %s_servers_groups WHERE server_id = (SELECT sid FROM %s_servers WHERE ip = '%s' AND port = '%s' LIMIT 0, 1))) \
            GROUP BY aid, authid, srv_password, srv_group, srv_flags, user",
            DatabasePrefix, DatabasePrefix, DatabasePrefix, queryLastLogin, DatabasePrefix, ServerIp, ServerPort, DatabasePrefix, DatabasePrefix, ServerIp, ServerPort);
        }
        else
        {
            FormatEx(query, 1024, "SELECT authid, srv_password, (SELECT name FROM %s_srvgroups WHERE name = srv_group AND flags != '') AS srv_group, srv_flags, user, immunity  \
            FROM %s_admins_servers_groups AS asg \
            LEFT JOIN %s_admins AS a ON a.aid = asg.admin_id AND a.deleted_at IS NULL AND (a.expired > UNIX_TIMESTAMP() OR a.expired = 0) \
            WHERE %s server_id = %d  \
            OR srv_group_id = ANY (SELECT group_id FROM %s_servers_groups WHERE server_id = %d) \
            GROUP BY aid, authid, srv_password, srv_group, srv_flags, user",
            DatabasePrefix, DatabasePrefix, DatabasePrefix, queryLastLogin, serverID, DatabasePrefix, serverID);
        }

        curLoading++;
        SQL_TQuery(hDatabase, AdminsDone, query);
        loadAdmins = false;
    }

    // g_bConnecting = false;
}

public void VerifyInsert(Handle owner, Handle hndl, const char[] error, DataPack dataPack)
{
    if (dataPack == null)
    {
        LogToFile(logFile, "Ban Failed: %s", error);
        return;
    }

    if (hndl == null || error[0])
    {
        LogToFile(logFile, "Verify Insert Query Failed: %s", error);
        int admin = dataPack.ReadCell();
        dataPack.Position = view_as<DataPackPos>(32);
        int time = dataPack.ReadCell();
        DataPack reasonPack = dataPack.ReadCell();
        char reason[128];
        reasonPack.ReadString(reason, sizeof(reason));
        char name[50];
        dataPack.ReadString(name, sizeof(name));
        char auth[30];
        dataPack.ReadString(auth, sizeof(auth));
        char ip[20];
        dataPack.ReadString(ip, sizeof(ip));
        char adminAuth[30];
        dataPack.ReadString(adminAuth, sizeof(adminAuth));
        char adminIp[20];
        dataPack.ReadString(adminIp, sizeof(adminIp));
        dataPack.Reset();
        reasonPack.Reset();

        PlayerDataPack[admin] = null;
        UTIL_InsertTempBan(time, name, auth, ip, reason, adminAuth, adminIp, dataPack);
        return;
    }

    int admin  = dataPack.ReadCell();
    int client = dataPack.ReadCell();

    if (!IsClientConnected(client) || IsFakeClient(client))
    {
        return;
    }

    dataPack.Position = view_as<DataPackPos>(24);

    int UserId = dataPack.ReadCell();
    int time   = dataPack.ReadCell();

    DataPack ReasonPack = dataPack.ReadCell();

    char Name[64];
    dataPack.ReadString(Name, sizeof(Name));

    char Reason[128];
    ReasonPack.ReadString(Reason, sizeof(Reason));

    if (!time)
    {
        if (Reason[0] == '\0')
        {
            ShowActivityEx(admin, Prefix, "%t", "Permabanned player", Name);
        }
        else
        {
            ShowActivityEx(admin, Prefix, "%t", "Permabanned player reason", Name, Reason);
        }
    }
    else
    {
        if (Reason[0] == '\0')
        {
            ShowActivityEx(admin, Prefix, "%t", "Banned player", Name, time);
        }
        else
        {
            ShowActivityEx(admin, Prefix, "%t", "Banned player reason", Name, time, Reason);
        }
    }

    LogAction(admin, client, "\"%L\" banned \"%L\" (minutes \"%d\") (reason \"%s\")", admin, client, time, Reason);

    if (PlayerDataPack[admin] != null)
    {
        delete PlayerDataPack[admin];
        delete ReasonPack;
        PlayerDataPack[admin] = null;
    }

    // Kick player
    if (GetClientUserId(client) == UserId)
    {
        char buffer[128];
        GetClientAuthId(client, AuthId_Steam2, buffer, sizeof(buffer), false);
        KickClient(client, "%t", "Banned Check Site", WebsiteAddress);
        Trie_PlayersTemporarilyBanned.SetValue(buffer, GetTime() + 300, true);
    }
}

public void SelectBanIpCallback(Handle owner, Handle hndl, const char[] error, DataPack data)
{
    int admin;
    int minutes;
    char adminAuth[30];
    char adminIp[30];
    char banReason[256];
    char ip[16];
    char Query[512];
    char reason[128];

    data.Reset();
    admin   = data.ReadCell();
    minutes = data.ReadCell();
    data.ReadString(reason,    sizeof(reason));
    data.ReadString(ip,        sizeof(ip));
    data.ReadString(adminAuth, sizeof(adminAuth));
    data.ReadString(adminIp,   sizeof(adminIp));
    SQL_EscapeString(hDatabase, reason, banReason, sizeof(banReason));

    if (error[0])
    {
        LogToFile(logFile, "Ban IP Select Query Failed: %s", error);

        if (admin && IsClientInGame(admin))
        {
            PrintToChat(admin, "%sFailed to ban %s.", Prefix, ip);
        }
        else
        {
            PrintToServer("%sFailed to ban %s.", Prefix, ip);
        }

        return;
    }

    if (SQL_GetRowCount(hndl))
    {
        if (admin && IsClientInGame(admin))
        {
            PrintToChat(admin, "%s%s is already banned.", Prefix, ip);
        }
        else
        {
            PrintToServer("%s%s is already banned.", Prefix, ip);
        }

        return;
    }

    if (serverID == -1)
    {
        FormatEx(Query, sizeof(Query), "INSERT INTO %s_bans (type, ip, name, created, ends, length, reason, aid, adminIp, sid, country) VALUES \
        (1, '%s', '', UNIX_TIMESTAMP(), UNIX_TIMESTAMP() + %d, %d, '%s', (SELECT aid FROM %s_admins WHERE authid = '%s' OR authid REGEXP '^STEAM_[0-9]:%s$'), '%s', \
        (SELECT sid FROM %s_servers WHERE ip = '%s' AND port = '%s' LIMIT 0, 1), ' ')",
        DatabasePrefix, ip, (minutes*60), (minutes*60), banReason, DatabasePrefix, adminAuth, adminAuth[8], adminIp, DatabasePrefix, ServerIp, ServerPort);
    }
    else
    {
        FormatEx(Query, sizeof(Query), "INSERT INTO %s_bans (type, ip, name, created, ends, length, reason, aid, adminIp, sid, country) VALUES \
        (1, '%s', '', UNIX_TIMESTAMP(), UNIX_TIMESTAMP() + %d, %d, '%s', (SELECT aid FROM %s_admins WHERE authid = '%s' OR authid REGEXP '^STEAM_[0-9]:%s$'), '%s', \
        %d, ' ')", DatabasePrefix, ip, (minutes*60), (minutes*60), banReason, DatabasePrefix, adminAuth, adminAuth[8], adminIp, serverID);
    }

    SQL_TQuery(hDatabase, InsertBanIpCallback, Query, data, DBPrio_High);
}

public void InsertBanIpCallback(Handle owner, Handle hndl, const char[] error, DataPack data)
{
    // if the pack is good unpack it and close the handle
    int admin;
    int minutes;

    char reason[128];
    char arg[30];

    if (data != null)
    {
        data.Reset();
        admin   = data.ReadCell();
        minutes = data.ReadCell();
        data.ReadString(reason, sizeof(reason));
        data.ReadString(arg,    sizeof(arg));
        delete data;
    }
    else
    {
        // Technically this should not be possible
        ThrowError("Invalid Handle in InsertBanIpCallback");
    }

    // If error is not an empty string the query failed
    if (error[0] != '\0')
    {
        LogToFile(logFile, "Ban IP Insert Query Failed: %s", error);

        if (admin && IsClientInGame(admin))
        {
            PrintToChat(admin, "%ssm_banip failed", Prefix);
        }

        return;
    }

    LogAction(admin, -1, "\"%L\" added ban (minutes \"%d\") (ip \"%s\") (reason \"%s\")", admin, minutes, arg, reason);

    if (admin && IsClientInGame(admin))
    {
        PrintToChat(admin, "%s%s successfully banned", Prefix, arg);
    }
    else
    {
        PrintToServer("%s%s successfully banned", Prefix, arg);
    }
}

public void SelectUnbanCallback(Handle owner, Handle hndl, const char[] error, DataPack data)
{
    int admin;
    char arg[30];
    char adminAuth[30];
    char unbanReason[256];
    char reason[128];

    data.Reset();
    admin = data.ReadCell();
    data.ReadString(reason,    sizeof(reason));
    data.ReadString(arg,       sizeof(arg));
    data.ReadString(adminAuth, sizeof(adminAuth));
    SQL_EscapeString(hDatabase, reason, unbanReason, sizeof(unbanReason));

    // If error is not an empty string the query failed
    if (error[0] != '\0')
    {
        LogToFile(logFile, "Unban Select Query Failed: %s", error);

        if (admin && IsClientInGame(admin))
        {
            PrintToChat(admin, "%ssm_unban failed", Prefix);
        }

        delete data;
        return;
    }

    // If there was no results then a ban does not exist for that id
    if (hndl == null || !SQL_GetRowCount(hndl))
    {
        if (admin && IsClientInGame(admin))
        {
            PrintToChat(admin, "%sNo active bans found for that filter", Prefix);
        }
        else
        {
            PrintToServer("%sNo active bans found for that filter", Prefix);
        }

        delete data;
        return;
    }

    // There is ban
    if (hndl != null && SQL_FetchRow(hndl))
    {
        // Get the values from the existing ban record
        int bid = SQL_FetchInt(hndl, 0);

        char query[1000];
        Format(query, sizeof(query), "UPDATE %s_bans SET RemovedBy = (SELECT aid FROM %s_admins WHERE authid = '%s' OR authid REGEXP '^STEAM_[0-9]:%s$'), RemoveType = 'U', RemovedOn = UNIX_TIMESTAMP(), ureason = '%s' WHERE bid = %d", DatabasePrefix, DatabasePrefix, adminAuth, adminAuth[8], unbanReason, bid);
        SQL_TQuery(hDatabase, InsertUnbanCallback, query, data);
    }

    return;
}

public void InsertUnbanCallback(Handle owner, Handle hndl, const char[] error, DataPack data)
{
    // if the pack is good unpack it and close the handle
    int admin;
    char reason[128];
    char arg[30];

    if (data != null)
    {
        data.Reset();
        admin = data.ReadCell();
        data.ReadString(reason, sizeof(reason));
        data.ReadString(arg,    sizeof(arg));
        delete data;
    }
    else
    {
        // Technically this should not be possible
        ThrowError("Invalid Handle in InsertUnbanCallback");
    }

    // If error is not an empty string the query failed
    if (error[0] != '\0')
    {
        LogToFile(logFile, "Unban Insert Query Failed: %s", error);

        if (admin && IsClientInGame(admin))
        {
            PrintToChat(admin, "%ssm_unban failed", Prefix);
        }

        return;
    }

    LogAction(admin, -1, "\"%L\" removed ban (filter \"%s\") (reason \"%s\")", admin, arg, reason);

    if (admin && IsClientInGame(admin))
    {
        PrintToChat(admin, "%s%s successfully unbanned", Prefix, arg);
    }
    else
    {
        PrintToServer("%s%s successfully unbanned", Prefix, arg);
    }
}

public void SelectAddbanCallback(Handle owner, Handle hndl, const char[] error, DataPack data)
{
    int admin;
    int minutes;

    char adminAuth[30];
    char adminIp[30];
    char authid[20];
    char banReason[256];
    char Query[512];
    char reason[128];

    data.Reset();
    admin   = data.ReadCell();
    minutes = data.ReadCell();

    data.ReadString(reason,    sizeof(reason));
    data.ReadString(authid,    sizeof(authid));
    data.ReadString(adminAuth, sizeof(adminAuth));
    data.ReadString(adminIp,   sizeof(adminIp));
    SQL_EscapeString(hDatabase, reason, banReason, sizeof(banReason));

    if (error[0])
    {
        LogToFile(logFile, "Add Ban Select Query Failed: %s", error);

        if (admin && IsClientInGame(admin))
        {
            PrintToChat(admin, "%sFailed to ban %s.", Prefix, authid);
        }
        else
        {
            PrintToServer("%sFailed to ban %s.", Prefix, authid);
        }

        delete data;
        return;
    }

    if (SQL_GetRowCount(hndl))
    {
        if (admin && IsClientInGame(admin))
        {
            PrintToChat(admin, "%s%s is already banned.", Prefix, authid);
        }
        else
        {
            PrintToServer("%s%s is already banned.", Prefix, authid);
        }

        delete data;
        return;
    }

    if (serverID == -1)
    {
        FormatEx(Query, sizeof(Query), "INSERT INTO %s_bans (authid, uniqueId, name, created, ends, length, reason, aid, adminIp, sid, country) VALUES \
        ('%s', '%s', '', UNIX_TIMESTAMP(), UNIX_TIMESTAMP() + %d, %d, '%s', (SELECT aid FROM %s_admins WHERE authid = '%s' OR authid REGEXP '^STEAM_[0-9]:%s$'), '%s', \
        (SELECT sid FROM %s_servers WHERE ip = '%s' AND port = '%s' LIMIT 0, 1), ' ')",
        DatabasePrefix, authid, authid[8], (minutes*60), (minutes*60), banReason, DatabasePrefix, adminAuth, adminAuth[8], adminIp, DatabasePrefix, ServerIp, ServerPort);
    }
    else
    {
        FormatEx(Query, sizeof(Query), "INSERT INTO %s_bans (authid, uniqueId, name, created, ends, length, reason, aid, adminIp, sid, country) VALUES \
        ('%s', '%s', '', UNIX_TIMESTAMP(), UNIX_TIMESTAMP() + %d, %d, '%s', (SELECT aid FROM %s_admins WHERE authid = '%s' OR authid REGEXP '^STEAM_[0-9]:%s$'), '%s', \
        %d, ' ')", DatabasePrefix, authid, authid[8], (minutes*60), (minutes*60), banReason, DatabasePrefix, adminAuth, adminAuth[8], adminIp, serverID);
    }

    SQL_TQuery(hDatabase, InsertAddbanCallback, Query, data, DBPrio_High);
}

public void InsertAddbanCallback(Handle owner, Handle hndl, const char[] error, DataPack data)
{
    int admin;
    int minutes;
    char authid[20];
    char reason[128];

    data.Reset();
    admin   = data.ReadCell();
    minutes = data.ReadCell();
    data.ReadString(reason, sizeof(reason));
    data.ReadString(authid, sizeof(authid));

    // If error is not an empty string the query failed
    if (error[0] != '\0')
    {
        LogToFile(logFile, "Add Ban Insert Query Failed: %s", error);

        if (admin && IsClientInGame(admin))
        {
            PrintToChat(admin, "%ssm_addban failed", Prefix);
        }

        delete data;
        return;
    }

    LogAction(admin, -1, "\"%L\" added ban (minutes \"%i\") (id \"%s\") (reason \"%s\")", admin, minutes, authid, reason);

    if (admin && IsClientInGame(admin))
    {
        PrintToChat(admin, "%s%s successfully banned", Prefix, authid);
    }
    else
    {
        PrintToServer("%s%s successfully banned", Prefix, authid);
    }

    delete data;
}

// ProcessQueueCallback is called as the result of selecting all the rows from the queue table
public void ProcessQueueCallback(Handle owner, Handle hndl, const char[] error, any data)
{
    if (hndl == null || strlen(error) > 0)
    {
        LogToFile(logFile, "Failed to retrieve queued bans from sqlite database, %s", error);
        return;
    }

    int time;
    int startTime;

    char auth[30];
    char reason[128];
    char name[64];
    char ip[20];
    char adminAuth[30];
    char adminIp[20];
    char query[1024];
    char banName[128];
    char banReason[256];

    while (SQL_MoreRows(hndl))
    {
        // Oh noes! What happened?!
        if (!SQL_FetchRow(hndl))
        {
            continue;
        }

        // if we get to here then there are rows in the queue pending processing
        SQL_FetchString(hndl, 0, auth, sizeof(auth));
        time      = SQL_FetchInt(hndl, 1);
        startTime = SQL_FetchInt(hndl, 2);

        SQL_FetchString(hndl, 3, reason, sizeof(reason));
        SQL_FetchString(hndl, 4, name, sizeof(name));
        SQL_FetchString(hndl, 5, ip, sizeof(ip));
        SQL_FetchString(hndl, 6, adminAuth, sizeof(adminAuth));
        SQL_FetchString(hndl, 7, adminIp, sizeof(adminIp));
        SQL_EscapeString(SQLiteDB, name, banName, sizeof(banName));
        SQL_EscapeString(SQLiteDB, reason, banReason, sizeof(banReason));

        if (startTime + time * 60 > GetTime() || time == 0)
        {
            // This ban is still valid and should be entered into the db
            if (serverID == -1)
            {
                FormatEx(query, sizeof(query),
                "INSERT INTO %s_bans (ip, authid, uniqueId, name, created, ends, length, reason, aid, adminIp, sid) VALUES  \
                ('%s', '%s', '%s', '%s', %d, %d, %d, '%s', (SELECT aid FROM %s_admins WHERE authid = '%s' OR authid REGEXP '^STEAM_[0-9]:%s$'), '%s', \
                (SELECT sid FROM %s_servers WHERE ip = '%s' AND port = '%s' LIMIT 0, 1))",
                DatabasePrefix, ip, auth, auth[8], banName, startTime, startTime + time * 60, time * 60, banReason, DatabasePrefix, adminAuth, adminAuth[8], adminIp, DatabasePrefix, ServerIp, ServerPort);
            }
            else
            {
                FormatEx(query, sizeof(query),
                "INSERT INTO %s_bans (ip, authid, uniqueId, name, created, ends, length, reason, aid, adminIp, sid) VALUES  \
                ('%s', '%s', '%s', '%s', %d, %d, %d, '%s', (SELECT aid FROM %s_admins WHERE authid = '%s' OR authid REGEXP '^STEAM_[0-9]:%s$'), '%s', \
                %d)", DatabasePrefix, ip, auth, auth[8], banName, startTime, startTime + time * 60, time * 60, banReason, DatabasePrefix, adminAuth, adminAuth[8], adminIp, serverID);
            }

            DataPack authPack = new DataPack();
            authPack.WriteString(auth);
            authPack.Reset();
            SQL_TQuery(hDatabase, AddedFromSQLiteCallback, query, authPack);
        }
        else
        {
            // The ban is no longer valid and should be deleted from the queue
            FormatEx(query, sizeof(query), "DELETE FROM queue WHERE steam_id = '%s'", auth);
            SQL_TQuery(SQLiteDB, ErrorCheckCallback, query);
        }
    }

    // We have finished processing the queue but should process again in ProcessQueueTime minutes
    CreateTimer(float(ProcessQueueTime * 60), ProcessQueue);
}

public void AddedFromSQLiteCallback(Handle owner, Handle hndl, const char[] error, DataPack data)
{
    char buffer[512];
    char auth[40];
    data.ReadString(auth, sizeof(auth));

    if (error[0] == '\0')
    {
        // The insert was successful so delete the record from the queue
        FormatEx(buffer, sizeof(buffer), "DELETE FROM queue WHERE steam_id = '%s'", auth);
        SQL_TQuery(SQLiteDB, ErrorCheckCallback, buffer);

        // They are added to main banlist, so remove the temp ban
        RemoveBan(auth, BANFLAG_AUTHID);

    }
    else
    {
        // the insert failed so we leave the record in the queue and increase our temporary ban
        FormatEx(buffer, sizeof(buffer), "banid %d %s", ProcessQueueTime, auth);
        ServerCommand(buffer);
    }

    delete data;
}

public void ServerInfoCallback(Handle owner, Handle hndl, const char[] error, any data)
{
    if (error[0])
    {
        LogToFile(logFile, "Server Select Query Failed: %s", error);
        return;
    }

    if (hndl == null || SQL_GetRowCount(hndl) == 0)
    {
        // get the game folder name used to determine the mod
        char desc[64];
        GetGameFolderName(desc, sizeof(desc));

        char query[200];
        FormatEx(query, sizeof(query), "INSERT INTO %s_servers (ip, port, rcon, modid) VALUES ('%s', '%s', '', (SELECT mid FROM %s_mods WHERE modfolder = '%s'))", DatabasePrefix, ServerIp, ServerPort, DatabasePrefix, desc);
        SQL_TQuery(hDatabase, ErrorCheckCallback, query);
    }
}

public void ErrorCheckCallback(Handle owner, Handle hndle, const char[] error, any data)
{
    if (error[0])
    {
        LogToFile(logFile, "Query Failed: %s", error);
    }
}

public void VerifyBan(Handle owner, Handle hndl, const char[] error, any userid)
{
    char clientName[64];
    char clientAuth[64];
    char clientIp[64];

    int client = GetClientOfUserId(userid);

    if (!client)
    {
        return;
    }

    /* Failure happen. Do retry with delay */
    if (hndl == null)
    {
        LogToFile(logFile, "Verify Ban Query Failed: %s", error);
        PlayerRecheck[client] = CreateTimer(RetryTime, ClientRecheck, client);
        return;
    }

    GetClientIP(client, clientIp, sizeof(clientIp));
    GetClientAuthId(client, AuthId_Steam2, clientAuth, sizeof(clientAuth), true);
    GetClientName(client, clientName, sizeof(clientName));

    if (SQL_GetRowCount(hndl) > 0)
    {
        char buffer[40];
        char Name[128];
        char Query[512];

        SQL_EscapeString(hDatabase, clientName, Name, sizeof(Name));

        if (serverID == -1)
        {
            FormatEx(Query, sizeof(Query), "INSERT INTO %s_banlog (sid , time , name , bid) VALUES  \
            ((SELECT sid FROM %s_servers WHERE ip = '%s' AND port = '%s' LIMIT 0, 1), UNIX_TIMESTAMP(), '%s', \
            (SELECT bid FROM %s_bans WHERE ((type = 0 AND authid REGEXP '^STEAM_[0-9]:%s$') OR (type = 1 AND ip = '%s')) AND RemoveType IS NULL LIMIT 0, 1))",
            DatabasePrefix, DatabasePrefix, ServerIp, ServerPort, Name, DatabasePrefix, clientAuth[8], clientIp);
        }
        else
        {
            FormatEx(Query, sizeof(Query), "INSERT INTO %s_banlog (sid , time , name , bid) VALUES  \
            (%d, UNIX_TIMESTAMP(), '%s', \
            (SELECT bid FROM %s_bans WHERE ((type = 0 AND authid REGEXP '^STEAM_[0-9]:%s$') OR (type = 1 AND ip = '%s')) AND RemoveType IS NULL LIMIT 0, 1))",
            DatabasePrefix, serverID, Name, DatabasePrefix, clientAuth[8], clientIp);
        }

        SQL_TQuery(hDatabase, ErrorCheckCallback, Query, client, DBPrio_High);
        FormatEx(buffer, sizeof(buffer), "banid 5 %s", clientAuth);
        ServerCommand(buffer);
        KickClient(client, "%t", "Banned Check Site", WebsiteAddress);
        Trie_PlayersTemporarilyBanned.SetValue(buffer, GetTime() + 300, true);
        return;
    }

    PlayerStatus[client] = true;
}

public void AdminsDone(Handle owner, Handle hndl, const char[] error, any data)
{
    // SELECT authid, srv_password , srv_group, srv_flags, user
    if (hndl == null || strlen(error) > 0)
    {
        --curLoading;
        CheckLoadAdmins();
        LogToFile(logFile, "Failed to retrieve admins from the database, %s", error);
        return;
    }

    char authType[] = "steam";
    char identity[66];
    char password[66];
    char groups[256];
    char flags[32];
    char name[66];

    int admCount   = 0;
    int Immunity   = 0;
    AdminId curAdm = INVALID_ADMIN_ID;
    KeyValues adminsKV = new KeyValues("Admins");

    while (SQL_MoreRows(hndl))
    {
        SQL_FetchRow(hndl);

        if (SQL_IsFieldNull(hndl, 0))
        {
            continue;  // Sometimes some rows return NULL due to some setups
        }

        SQL_FetchString(hndl, 0, identity, 66);
        SQL_FetchString(hndl, 1, password, 66);
        SQL_FetchString(hndl, 2, groups,   256);
        SQL_FetchString(hndl, 3, flags,    32);
        SQL_FetchString(hndl, 4, name,     66);

        Immunity = SQL_FetchInt(hndl, 5);

        TrimString(name);
        TrimString(identity);
        TrimString(groups);
        TrimString(flags);

        // Disable writing to file if they chose to
        if (backupConfig)
        {
            adminsKV.JumpToKey(name, true);

            adminsKV.SetString("auth",     "steam");
            adminsKV.SetString("identity", identity);

            if (strlen(flags) > 0)
            {
                adminsKV.SetString("flags", flags);
            }

            if (strlen(groups) > 0)
            {
                adminsKV.SetString("group", groups);
            }

            if (strlen(password) > 0)
            {
                adminsKV.SetString("password", password);
            }

            if (Immunity > 0)
            {
                adminsKV.SetNum("immunity", Immunity);
            }

            adminsKV.Rewind();
        }

        curAdm = CreateAdmin(name);
        BindAdminIdentity(curAdm, authType, identity);

        char grp[64];

        int curPos     = 0;
        int nextPos    = 0;
        GroupId curGrp = INVALID_GROUP_ID;

        while ((nextPos = SplitString(groups[curPos], ", ", grp, 64)) != -1)
        {
            curPos += nextPos;
            curGrp = FindAdmGroup(grp);

            if (curGrp == INVALID_GROUP_ID)
            {
                LogToFile(logFile, "Unknown group \"%s\"", grp);
            }
            else
            {
                if (!AdminInheritGroup(curAdm, curGrp))
                {
                    LogToFile(logFile, "Unable to inherit group \"%s\"", grp);
                }
            }
        }

        if (strcmp(groups[curPos], "") != 0)
        {
            curGrp = FindAdmGroup(groups[curPos]);

            if (curGrp == INVALID_GROUP_ID)
            {
                LogToFile(logFile, "Unknown group \"%s\"", groups[curPos]);
            }
            else
            {
                if (!AdminInheritGroup(curAdm, curGrp))
                {
                    LogToFile(logFile, "Unable to inherit group \"%s\"", groups[curPos]);
                }

                if (Immunity > GetAdmGroupImmunityLevel(curGrp))
                {
                    SetAdminImmunityLevel(curAdm, Immunity);
                }
                else
                {
                    SetAdminImmunityLevel(curAdm, GetAdmGroupImmunityLevel(curGrp));
                }
            }
        }

        if (strlen(password) > 0)
        {
            SetAdminPassword(curAdm, password);
        }

        for (int i = 0; i < strlen(flags); i++)
        {
            if (flags[i] < 'a' || flags[i] > 'z')
            {
                continue;
            }

            if (g_FlagLetters[flags[i] - 'a'] < Admin_Reservation)
            {
                continue;
            }

            SetAdminFlag(curAdm, g_FlagLetters[flags[i] - 'a'], true);
        }

        ++admCount;
    }

    if (backupConfig)
    {
        adminsKV.ExportToFile(adminsLoc);
    }

    delete adminsKV;

    --curLoading;
    CheckLoadAdmins();
}

public void GroupsDone(Handle owner, Handle hndl, const char[] error, any data)
{
    if (hndl == null)
    {
        curLoading--;
        CheckLoadAdmins();
        LogToFile(logFile, "Failed to retrieve groups from the database, %s", error);
        return;
    }

    char grpName[128];
    char grpFlags[32];

    int Immunity;
    bool reparse = false;
    int grpCount = 0;
    KeyValues groupsKV = new KeyValues("Groups");

    GroupId curGrp = INVALID_GROUP_ID;

    while (SQL_MoreRows(hndl))
    {
        SQL_FetchRow(hndl);

        if (SQL_IsFieldNull(hndl, 0))
        {
            continue;  // Sometimes some rows return NULL due to some setups
        }

        SQL_FetchString(hndl, 0, grpName, 128);
        SQL_FetchString(hndl, 1, grpFlags, 32);
        Immunity = SQL_FetchInt(hndl, 2);

        TrimString(grpName);
        TrimString(grpFlags);

        if (!strcmp(grpName, " "))
        {
            continue;
        }

        curGrp = CreateAdmGroup(grpName);

        if (backupConfig)
        {
            groupsKV.JumpToKey(grpName, true);

            if (strlen(grpFlags) > 0)
            {
                groupsKV.SetString("flags", grpFlags);
            }

            if (Immunity > 0)
            {
                groupsKV.SetNum("immunity", Immunity);
            }

            groupsKV.Rewind();
        }

        if (curGrp == INVALID_GROUP_ID)
        {
            curGrp = FindAdmGroup(grpName);
        }

        for (int i = 0; i < strlen(grpFlags); i++)
        {
            if (grpFlags[i] < 'a' || grpFlags[i] > 'z')
            {
                continue;
            }

            if (g_FlagLetters[grpFlags[i] - 'a'] < Admin_Reservation)
            {
                continue;
            }

            SetAdmGroupAddFlag(curGrp, g_FlagLetters[grpFlags[i] - 'a'], true);
        }

        SetAdmGroupImmunityLevel(curGrp, Immunity);
        grpCount++;
    }

    if (backupConfig)
    {
        groupsKV.ExportToFile(groupsLoc);
    }

    delete groupsKV;

    if (reparse)
    {
        char query[512];
        FormatEx(query, 512, "SELECT name, immunity, groups_immune FROM %s_srvgroups ORDER BY id", DatabasePrefix);
        SQL_TQuery(hDatabase, GroupsSecondPass, query);
    }
    else
    {
        curLoading--;
        CheckLoadAdmins();
    }
}

public void GroupsSecondPass(Handle owner, Handle hndl, const char[] error, any data)
{
    if (hndl == null)
    {
        curLoading--;
        CheckLoadAdmins();
        LogToFile(logFile, "Failed to retrieve groups from the database, %s", error);
        return;
    }

    char grpName[128];
    int Immunity;

    GroupId curGrp = INVALID_GROUP_ID;

    while (SQL_MoreRows(hndl))
    {
        SQL_FetchRow(hndl);

        if (SQL_IsFieldNull(hndl, 0))
        {
            continue;  // Sometimes some rows return NULL due to some setups
        }

        SQL_FetchString(hndl, 0, grpName, 128);
        TrimString(grpName);

        if (!strcmp(grpName, " "))
        {
            continue;
        }

        Immunity    = SQL_FetchInt(hndl, 1);
        curGrp      = FindAdmGroup(grpName);

        if (curGrp == INVALID_GROUP_ID)
        {
            curGrp = CreateAdmGroup(grpName);
        }

        SetAdmGroupImmunityLevel(curGrp, Immunity);
    }

    --curLoading;
    CheckLoadAdmins();
}

// TIMER CALL BACKS //
public Action ClientRecheck(Handle timer, any client)
{
    if (!PlayerStatus[client] && IsClientConnected(client))
    {
        char Authid[64];
        GetClientAuthId(client, AuthId_Steam2, Authid, sizeof(Authid), true);
        OnClientAuthorized(client, Authid);
    }

    PlayerRecheck[client] = null;
    return Plugin_Stop;
}

public Action ProcessQueue(Handle timer, any data)
{
    char buffer[512];
    Format(buffer, sizeof(buffer), "SELECT steam_id, time, start_time, reason, name, ip, admin_id, admin_ip FROM queue");
    SQL_TQuery(SQLiteDB, ProcessQueueCallback, buffer);
    return Plugin_Stop;
}

// PARSER //
static void InitializeConfigParser()
{
    if (ConfigParser == null)
    {
        ConfigParser = SMC_CreateParser();
        SMC_SetReaders(ConfigParser, ReadConfig_NewSection, ReadConfig_KeyValue, ReadConfig_EndSection);
    }
}

void InternalReadConfig(const char[] path)
{
    ConfigState = ConfigStateNone;

    SMCError err = SMC_ParseFile(ConfigParser, path);

    if (err != SMCError_Okay)
    {
        char buffer[64];

        if (SMC_GetErrorString(err, buffer, sizeof(buffer)))
        {
            PrintToServer(buffer);
        }
        else
        {
            PrintToServer("Fatal parse error");
        }
    }
}

public SMCResult ReadConfig_NewSection(Handle smc, const char[] name, bool opt_quotes)
{
    if (name[0])
    {
        if (strcmp("Config", name, false) == 0)
        {
            ConfigState = ConfigStateConfig;
        }
        else if (strcmp("BanReasons", name, false) == 0)
        {
            ConfigState = ConfigStateReasons;
        }
        else if (strcmp("HackingReasons", name, false) == 0)
        {
            ConfigState = ConfigStateHacking;
        }
    }

    return SMCParse_Continue;
}

public SMCResult ReadConfig_KeyValue(Handle smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
    if (!key[0])
    {
        return SMCParse_Continue;
    }

    switch (ConfigState)
    {
        case ConfigStateConfig:
        {
            if (strcmp("website", key, false) == 0)
            {
                strcopy(WebsiteAddress, sizeof(WebsiteAddress), value);
            }
            else if (strcmp("Addban", key, false) == 0)
            {
                if (StringToInt(value) == 0)
                {
                    CommandDisable |= DISABLE_ADDBAN;
                }
            }
            else if (strcmp("AutoAddServer", key, false) == 0)
            {
                if (StringToInt(value) == 1)
                {
                    AutoAdd = true;
                }
                else
                {
                    AutoAdd = false;
                }
            }
            else if (strcmp("Unban", key, false) == 0)
            {
                if (StringToInt(value) == 0)
                {
                    CommandDisable |= DISABLE_UNBAN;
                }
            }
            else if (strcmp("DatabasePrefix", key, false) == 0)
            {
                strcopy(DatabasePrefix, sizeof(DatabasePrefix), value);

                if (DatabasePrefix[0] == '\0')
                {
                    DatabasePrefix = "sb";
                }
            }
            else if (strcmp("RetryTime", key, false) == 0)
            {
                RetryTime = StringToFloat(value);

                if (RetryTime < 15.0)
                {
                    RetryTime = 15.0;
                }
                else if (RetryTime > 60.0)
                {
                    RetryTime = 60.0;
                }
            }
            else if (strcmp("ProcessQueueTime", key, false) == 0)
            {
                ProcessQueueTime = StringToInt(value);
            }
            else if (strcmp("BackupConfigs", key, false) == 0)
            {
                if (StringToInt(value) == 1)
                {
                    backupConfig = true;
                }
                else
                {
                    backupConfig = false;
                }
            }
            else if (strcmp("EnableAdmins", key, false) == 0)
            {
                if (StringToInt(value) == 1)
                {
                    enableAdmins = true;
                }
                else
                {
                    enableAdmins = false;
                }
            }
            else if (strcmp("RequireSiteLogin", key, false) == 0)
            {
                if (StringToInt(value) == 1)
                {
                    requireSiteLogin = true;
                }
                else
                {
                    requireSiteLogin = false;
                }
            }
            else if (strcmp("ServerID", key, false) == 0)
            {
                serverID = StringToInt(value);
            }
        }

        case ConfigStateReasons:
        {
            if (ReasonMenuHandle != null)
            {
                ReasonMenuHandle.AddItem(key, value);
            }
        }
        case ConfigStateHacking:
        {
            if (HackingMenuHandle != null)
            {
                HackingMenuHandle.AddItem(key, value);
            }
        }
    }

    return SMCParse_Continue;
}

public SMCResult ReadConfig_EndSection(Handle smc)
{
    return SMCParse_Continue;
}

/*********************************************************
 * Ban Player from server
 *
 * @param client    The client index of the player to ban
 * @param time      The time to ban the player for (in minutes, 0 = permanent)
 * @param reason    The reason to ban the player from the server
 * @noreturn
 *********************************************************/
public int Native_SBBanPlayer(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int target = GetNativeCell(2);
    int time   = GetNativeCell(3);

    char reason[128];
    GetNativeString(4, reason, 128);

    if (reason[0] == '\0')
    {
        strcopy(reason, sizeof(reason), "Banned by SourceBans");
    }

    if (client && IsClientInGame(client))
    {
        AdminId aid = GetUserAdmin(client);

        if (aid == INVALID_ADMIN_ID)
        {
            ThrowNativeError(1, "Ban Error: Player is not an admin.");
            return 0;
        }

        if (!GetAdminFlag(aid, Admin_Ban))
        {
            ThrowNativeError(2, "Ban Error: Player does not have BAN flag.");
            return 0;
        }
    }

    PrepareBan(client, target, time, reason, sizeof(reason));
    return true;
}

// STOCK FUNCTIONS //
public void InitializeBackupDB()
{
    char error[255];
    SQLiteDB = SQLite_UseDatabase("sourcebans-queue", error, sizeof(error));

    if (SQLiteDB == null)
    {
        SetFailState(error);
    }

    SQL_LockDatabase(SQLiteDB);
    SQL_FastQuery(SQLiteDB, "CREATE TABLE IF NOT EXISTS queue (steam_id TEXT PRIMARY KEY ON CONFLICT REPLACE, time INTEGER, start_time INTEGER, reason TEXT, name TEXT, ip TEXT, admin_id TEXT, admin_ip TEXT);");
    SQL_UnlockDatabase(SQLiteDB);
}

public bool CreateBan(int client, int target, int time, char[] reason)
{
    char adminIp[24];
    char adminAuth[64];

    int admin = client;

    // The server is the one calling the ban
    if (!admin)
    {
        if (reason[0] == '\0')
        {
            // We cannot pop the reason menu if the command was issued from the server
            PrintToServer("%s%T", Prefix, "Include Reason", LANG_SERVER);
            return false;
        }

        // setup dummy adminAuth and adminIp for server
        strcopy(adminAuth, sizeof(adminAuth), CONSOLE_AUTH);
        strcopy(adminIp, sizeof(adminIp), ServerIp);
    }
    else
    {
        GetClientIP(admin, adminIp, sizeof(adminIp));
        GetClientAuthId(admin, AuthId_Steam2, adminAuth, sizeof(adminAuth), true);
    }

    // target information
    char ip[24];
    GetClientIP(target, ip, sizeof(ip));

    char auth[64];
    GetClientAuthId(target, AuthId_Steam2, auth, sizeof(auth), true);

    char name[64];
    GetClientName(target, name, sizeof(name));

    int userid = admin ? GetClientUserId(admin) : 0;

    // Pack everything into a data pack so we can retain it
    DataPack dataPack   = new DataPack();
    DataPack reasonPack = new DataPack();

    reasonPack.WriteString(reason);

    dataPack.WriteCell(admin);
    dataPack.WriteCell(target);
    dataPack.WriteCell(userid);
    dataPack.WriteCell(GetClientUserId(target));
    dataPack.WriteCell(time);
    dataPack.WriteCell(view_as<int>(reasonPack));
    dataPack.WriteString(name);
    dataPack.WriteString(auth);
    dataPack.WriteString(ip);
    dataPack.WriteString(adminAuth);
    dataPack.WriteString(adminIp);

    dataPack.Reset();
    reasonPack.Reset();

    if (reason[0] != '\0')
    {
        // if we have a valid reason pass move forward with the ban
        if (hDatabase != null)
        {
            UTIL_InsertBan(time, name, auth, ip, reason, adminAuth, adminIp, dataPack);
        }
        else
        {
            UTIL_InsertTempBan(time, name, auth, ip, reason, adminAuth, adminIp, dataPack);
        }
    }
    else
    {
        // We need a reason so offer the administrator a menu of reasons
        PlayerDataPack[admin] = dataPack;
        ReasonMenuHandle.Display(admin, MENU_TIME_FOREVER);
        ReplyToCommand(admin, "%c[%cSourceBans%c]%c %t", GREEN, NAMECOLOR, GREEN, NAMECOLOR, "Check Menu");
    }

    return true;
}

stock void UTIL_InsertBan(int time, const char[] name, const char[] Authid, const char[] Ip, const char[] Reason, const char[] AdminAuthid, const char[] AdminIp, DataPack Pack)
{
    char banName[128];
    SQL_EscapeString(hDatabase, name, banName, sizeof(banName));

    char banReason[256];
    SQL_EscapeString(hDatabase, Reason, banReason, sizeof(banReason));

    char Query[1024];

    if (serverID == -1)
    {
        FormatEx(Query, sizeof(Query), "INSERT INTO %s_bans (ip, authid, uniqueId, name, created, ends, length, reason, aid, adminIp, sid, country) VALUES \
        ('%s', '%s', '%s', '%s', UNIX_TIMESTAMP(), UNIX_TIMESTAMP() + %d, %d, '%s', IFNULL((SELECT aid FROM %s_admins WHERE authid = '%s' OR authid REGEXP '^STEAM_[0-9]:%s$'), '0'), '%s', \
        (SELECT sid FROM %s_servers WHERE ip = '%s' AND port = '%s' LIMIT 0, 1), ' ')",
        DatabasePrefix, Ip, Authid, Authid[8], banName, (time*60), (time*60), banReason, DatabasePrefix, AdminAuthid, AdminAuthid[8], AdminIp, DatabasePrefix, ServerIp, ServerPort);
    }
    else
    {
        FormatEx(Query, sizeof(Query), "INSERT INTO %s_bans (ip, authid, uniqueId, name, created, ends, length, reason, aid, adminIp, sid, country) VALUES \
        ('%s', '%s', '%s', '%s', UNIX_TIMESTAMP(), UNIX_TIMESTAMP() + %d, %d, '%s', IFNULL((SELECT aid FROM %s_admins WHERE authid = '%s' OR authid REGEXP '^STEAM_[0-9]:%s$'), '0'), '%s', \
        %d, ' ')", DatabasePrefix, Ip, Authid, Authid[8], banName, (time*60), (time*60), banReason, DatabasePrefix, AdminAuthid, AdminAuthid[8], AdminIp, serverID);
    }

    SQL_TQuery(hDatabase, VerifyInsert, Query, Pack, DBPrio_High);
}

stock void UTIL_InsertTempBan(int time, const char[] name, const char[] auth, const char[] ip, const char[] reason, const char[] adminAuth, const char[] adminIp, DataPack dataPack)
{
    dataPack.ReadCell();
    int client = dataPack.ReadCell();
    dataPack.Position = view_as<DataPackPos>(40);
    DataPack reasonPack = dataPack.ReadCell();

    if (reasonPack != null)
    {
        delete reasonPack;
    }

    delete dataPack;

    // we add a temporary ban and then add the record into the queue to be processed when the database is available
    char buffer[50];
    Format(buffer, sizeof(buffer), "banid %d %s", ProcessQueueTime, auth);
    ServerCommand(buffer);

    if (IsClientInGame(client))
    {
        KickClient(client, "%t", "Banned Check Site", WebsiteAddress);
        Trie_PlayersTemporarilyBanned.SetValue(buffer, GetTime() + 300, true);
    }

    char banName[128];
    SQL_EscapeString(SQLiteDB, name, banName, sizeof(banName));

    char banReason[256];
    SQL_EscapeString(SQLiteDB, reason, banReason, sizeof(banReason));

    char query[512];
    FormatEx(query, sizeof(query), "INSERT INTO queue VALUES ('%s', %i, %i, '%s', '%s', '%s', '%s', '%s')", auth, time, GetTime(), banReason, banName, ip, adminAuth, adminIp);
    SQL_TQuery(SQLiteDB, ErrorCheckCallback, query);
}

stock void CheckLoadAdmins()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsClientAuthorized(i))
        {
            RunAdminCacheChecks(i);
            NotifyPostAdminCheck(i);
        }
    }
}

stock void InsertServerInfo()
{
    if (hDatabase == null)
    {
        return;
    }

    char query[100];
    char pieces[4];

    int longip = CvarHostIp.IntValue;

    pieces[0] = (longip >> 24) & 0x000000FF;
    pieces[1] = (longip >> 16) & 0x000000FF;
    pieces[2] = (longip >> 8)  & 0x000000FF;
    pieces[3] = (longip)       & 0x000000FF;

    FormatEx(ServerIp, sizeof(ServerIp), "%d.%d.%d.%d", pieces[0], pieces[1], pieces[2], pieces[3]);
    CvarPort.GetString(ServerPort, sizeof(ServerPort));

    if (AutoAdd != false)
    {
        FormatEx(query, sizeof(query), "SELECT sid FROM %s_servers WHERE ip = '%s' AND port = '%s'", DatabasePrefix, ServerIp, ServerPort);
        SQL_TQuery(hDatabase, ServerInfoCallback, query);
    }
}

stock void PrepareBan(int client, int target, int time, char[] reason, int size)
{
    if (!target || !IsClientInGame(target))
    {
        return;
    }

    char authid[64];
    GetClientAuthId(target, AuthId_Steam2, authid, sizeof(authid), true);

    char name[32];
    GetClientName(target, name, sizeof(name));

    if (CreateBan(client, target, time, reason))
    {
        if (!time)
        {
            if (reason[0] == '\0')
            {
                ShowActivity(client, "%t", "Permabanned player", name);
            }
            else
            {
                ShowActivity(client, "%t", "Permabanned player reason", name, reason);
            }
        }
        else
        {
            if (reason[0] == '\0')
            {
                ShowActivity(client, "%t", "Banned player", name, time);
            }
            else
            {
                ShowActivity(client, "%t", "Banned player reason", name, time, reason);
            }
        }

        LogAction(client, target, "\"%L\" banned \"%L\" (minutes \"%d\") (reason \"%s\")", client, target, time, reason);

        if (time > 5 || time == 0)
        {
            time = 5;
        }

        char bannedSite[512];
        Format(bannedSite, sizeof(bannedSite), "%T", "Banned Check Site", target, WebsiteAddress);
        BanClient(target, time, BANFLAG_AUTO, bannedSite, bannedSite, "sm_ban", client);
        Trie_PlayersTemporarilyBanned.SetValue(authid, GetTime() + 300, true);
    }

    g_BanTarget[client] = -1;
    g_BanTime[client]   = -1;
}

stock void ReadConfig()
{
    InitializeConfigParser();

    if (ConfigParser == null)
    {
        return;
    }

    char ConfigFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, ConfigFile, sizeof(ConfigFile), "configs/sourcebans/sourcebans.cfg");

    if (FileExists(ConfigFile))
    {
        InternalReadConfig(ConfigFile);
        PrintToServer("%sLoading configs/sourcebans.cfg config file", Prefix);
    }
    else
    {
        char Error[PLATFORM_MAX_PATH + 64];
        FormatEx(Error, sizeof(Error), "%sFATAL *** ERROR *** can not find %s", Prefix, ConfigFile);
        LogToFile(logFile, "FATAL *** ERROR *** can not find %s", ConfigFile);
        SetFailState(Error);
    }
}

stock void ResetSettings()
{
    CommandDisable = 0;
    ResetMenu();
    ReadConfig();
}

// Yarr!
public Action OnClientPreConnect(const char[] name, const char[] password, const char[] ip, const char[] steamID, char rejectReason[255])
{
    int iUnbanTime;

    if (Trie_PlayersTemporarilyBanned.GetValue(steamID, iUnbanTime))
    {
        int iCurrentTime = GetTime();

        if (iCurrentTime < iUnbanTime)
        {
            Format(rejectReason, sizeof(rejectReason), "%t", "Banned Check Site", WebsiteAddress);
            return Plugin_Stop;
        }
        else
        {
            Trie_PlayersTemporarilyBanned.Remove(steamID);
        }
    }

    return Plugin_Continue;
}