#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <basecomm>
#include <sourcecomms>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <adminmenu>
#define REQUIRE_PLUGIN

//-----------------------------//
// Do not edit below this line //
//-----------------------------//

#define PREFIX     ""
#define UPDATE_URL "http://s.ppalex.com/updater/sourcecomms-0.9/sc-updatefile.txt"

#define NOW 0
#define TYPE_TEMP_SHIFT 10

#define TYPE_MUTE           1
#define TYPE_GAG            2
#define TYPE_SILENCE        3
#define TYPE_UNMUTE         4
#define TYPE_UNGAG          5
#define TYPE_UNSILENCE      6
#define TYPE_TEMP_UNMUTE    14 // TYPE_TEMP_SHIFT + TYPE_UNMUTE
#define TYPE_TEMP_UNGAG     15 // TYPE_TEMP_SHIFT + TYPE_UNGAG
#define TYPE_TEMP_UNSILENCE 16 // TYPE_TEMP_SHIFT + TYPE_UNSILENCE

#define MAX_REASONS  32
#define DISPLAY_SIZE 64
#define REASON_SIZE  192

#define MAX_TIMES   32
#define DATAPACKPOS 16

int iNumReasons;
char g_sReasonDisplays[MAX_REASONS][DISPLAY_SIZE];
char g_sReasonKey[MAX_REASONS][REASON_SIZE];

int iNumTimes;
int g_iTimeMinutes[MAX_TIMES];
char g_sTimeDisplays[MAX_TIMES][DISPLAY_SIZE];

enum State /* ConfigState */
{
    ConfigStateNone = 0,
    ConfigStateConfig,
    ConfigStateReasons,
    ConfigStateTimes,
    ConfigStateServers,
    StateSize
}

enum DatabaseState /* Database connection state */
{
    DatabaseState_None = 0,
    DatabaseState_Wait,
    DatabaseState_Connecting,
    DatabaseState_Connected,
    DatabaseState_Size
}

DatabaseState g_DatabaseState;

int g_iConnectLock = 0;
int g_iSequence    = 0;

State ConfigState;
Handle ConfigParser;

TopMenu hTopMenu;

/* Cvar handle*/
ConVar CvarHostIp;
ConVar CvarPort;

char ServerIp[24];
char ServerPort[7];

/* Database handle */
Handle g_hDatabase;
Handle SQLiteDB;

char DatabasePrefix[10] = "sb";

/* Timer handles */
Handle g_hPlayerRecheck[MAXPLAYERS + 1]   = {null, ...};
Handle g_hGagExpireTimer[MAXPLAYERS + 1]  = {null, ...};
Handle g_hMuteExpireTimer[MAXPLAYERS + 1] = {null, ...};

float RetryTime         = 15.0;
int DefaultTime         = 30;
int DisUBImCheck        = 0;
int ConsoleImmunity     = 0;
int ConfigMaxLength     = 0;
int ConfigWhiteListOnly = 0;
int serverID            = 0;

/* List menu */
enum PeskyPanels
{
    curTarget,
    curIndex,
    viewingMute,
    viewingGag,
    viewingList,
    PeskyPanelsSize
}

int g_iPeskyPanels[MAXPLAYERS + 1][view_as<int>(PeskyPanelsSize)];

bool g_bPlayerStatus[MAXPLAYERS + 1];
char g_sName[MAXPLAYERS + 1][MAX_NAME_LENGTH];

bType g_MuteType[MAXPLAYERS + 1];
int g_iMuteTime[MAXPLAYERS + 1];
int g_iMuteLength[MAXPLAYERS + 1];
int g_iMuteLevel[MAXPLAYERS + 1];
char g_sMuteAdminName[MAXPLAYERS + 1][MAX_NAME_LENGTH];
char g_sMuteReason[MAXPLAYERS + 1][256];
char g_sMuteAdminAuth[MAXPLAYERS + 1][64];

bType g_GagType[MAXPLAYERS + 1];
int g_iGagTime[MAXPLAYERS + 1];
int g_iGagLength[MAXPLAYERS + 1];
int g_iGagLevel[MAXPLAYERS + 1];
char g_sGagAdminName[MAXPLAYERS + 1][MAX_NAME_LENGTH];
char g_sGagReason[MAXPLAYERS + 1][256];
char g_sGagAdminAuth[MAXPLAYERS + 1][64];

ArrayList g_hServersWhiteList;

public Plugin myinfo =
{
    name        = "SourceComms",
    author      = "Alex",
    description = "Advanced punishments management for the Source engine in SourceBans style",
    version     = "0.9.266",
    url         = "https://forums.alliedmods.net/showthread.php?t=207176"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("SourceComms_SetClientMute",     Native_SetClientMute);
    CreateNative("SourceComms_SetClientGag",      Native_SetClientGag);
    CreateNative("SourceComms_GetClientMuteType", Native_GetClientMuteType);
    CreateNative("SourceComms_GetClientGagType",  Native_GetClientGagType);
    MarkNativeAsOptional("SQL_SetCharset");
    RegPluginLibrary("sourcecomms");
    return APLRes_Success;
}

public void OnPluginStart()
{
    Handle hTemp = null;

    if (LibraryExists("adminmenu") && ((hTemp = GetAdminTopMenu()) != null))
    {
        OnAdminMenuReady(hTemp);
    }

    CvarHostIp = FindConVar("hostip");
    CvarPort   = FindConVar("hostport");
    g_hServersWhiteList = new ArrayList();

    AddCommandListener(CommandCallback, "sm_gag");
    AddCommandListener(CommandCallback, "sm_mute");
    AddCommandListener(CommandCallback, "sm_silence");
    AddCommandListener(CommandCallback, "sm_ungag");
    AddCommandListener(CommandCallback, "sm_unmute");
    AddCommandListener(CommandCallback, "sm_unsilence");

    RegServerCmd("sc_fw_block",  FWBlock,  "Blocking player comms by command from sourceban web site");
    RegServerCmd("sc_fw_ungag",  FWUngag,  "Ungagging player by command from sourceban web site");
    RegServerCmd("sc_fw_unmute", FWUnmute, "Unmuting player by command from sourceban web site");

    RegConsoleCmd("sm_comms", CommandComms, "Shows current player communications status");

    HookEvent("player_changename", Event_OnPlayerName, EventHookMode_Post);
    AddTempEntHook("Player Decal", Player_Decal);

    // Catch config error
    if (!SQL_CheckConfig("sourcecomms"))
    {
        SetFailState("Database failure: could not find database conf sourcecomms");
        return;
    }

    DB_Connect();
    InitializeBackupDB();
    ServerInfo();

    LoadTranslations("common.phrases");
    LoadTranslations("sourcecomms.phrases");
}

public Action Player_Decal(const char[] name, const int[] clients, int count, float delay)
{
    int client = TE_ReadNum("m_nPlayer");

    if (g_MuteType[client] > bNot || g_GagType[client] > bNot)
    {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "adminmenu"))
    {
        hTopMenu = null;
    }
}

public void OnMapStart()
{
    ReadConfig();
}

public void OnMapEnd()
{
    // Clean up on map end just so we can start a fresh connection when we need it later.
    // Also it is necessary for using SQL_SetCharset
    if (g_hDatabase)
    {
        delete g_hDatabase;
    }

    g_hDatabase = null;
}

// CLIENT CONNECTION FUNCTIONS //
public void OnClientDisconnect(int client)
{
    if (g_hPlayerRecheck[client] != null && CloseHandle(g_hPlayerRecheck[client]))
    {
        g_hPlayerRecheck[client] = null;
    }

    CloseMuteExpireTimer(client);
    CloseGagExpireTimer(client);
}

public bool OnClientConnect(int client, char[] rejectmsg, int maxlen)
{
    g_bPlayerStatus[client] = false;
    return true;
}

public void OnClientConnected(int client)
{
    g_sName[client][0] = '\0';
    MarkClientAsUnMuted(client);
    MarkClientAsUnGagged(client);
}

public void OnClientPostAdminCheck(int client)
{
    char clientAuth[64];
    GetClientAuthId(client, AuthId_Steam2, clientAuth, sizeof(clientAuth), true);
    GetClientName(client, g_sName[client], sizeof(g_sName[]));

    /* Do not check bots or check player with lan steamid. */
    if (clientAuth[0] == 'B' || clientAuth[9] == 'L' || !DB_Connect())
    {
        g_bPlayerStatus[client] = true;
        return;
    }

    if (client > 0 && IsClientInGame(client) && !IsFakeClient(client))
    {
        // if plugin was late loaded
        if (BaseComm_IsClientMuted(client))
        {
            MarkClientAsMuted(client);
        }
        if (BaseComm_IsClientGagged(client))
        {
            MarkClientAsGagged(client);
        }

        char sClAuthYZEscaped[sizeof(clientAuth) * 2 + 1];
        SQL_EscapeString(g_hDatabase, clientAuth[8], sClAuthYZEscaped, sizeof(sClAuthYZEscaped));

        char Query[4096];
        FormatEx(Query, sizeof(Query),
           "SELECT      (c.ends - UNIX_TIMESTAMP()) AS remaining, \
                        c.length, c.type, c.created, c.reason, a.user, \
                        IF (a.immunity>=g.immunity, a.immunity, IFNULL(g.immunity, 0)) AS immunity, \
                        c.aid, c.sid, a.authid \
            FROM        %s_comms     AS c \
            LEFT JOIN   %s_admins    AS a  ON a.aid = c.aid \
            LEFT JOIN   %s_srvgroups AS g  ON g.name = a.srv_group \
            WHERE       RemoveType IS NULL \
                          AND c.authid REGEXP '^STEAM_[0-9]:%s$' \
                          AND (length = '0' OR ends > UNIX_TIMESTAMP())",
            DatabasePrefix, DatabasePrefix, DatabasePrefix, sClAuthYZEscaped);

        SQL_TQuery(g_hDatabase, Query_VerifyBlock, Query, GetClientUserId(client), DBPrio_High);
    }
}

// OTHER CLIENT CODE //
public void Event_OnPlayerName(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (client > 0 && IsClientInGame(client))
    {
        event.GetString("newname", g_sName[client], sizeof(g_sName[]));
    }
}

public void BaseComm_OnClientMute(int client, bool muteState)
{
    if (client > 0 && client <= MaxClients)
    {
        if (muteState)
        {
            if (g_MuteType[client] == bNot)
            {
                MarkClientAsMuted(client, _, _, _, _, _, "Muted through BaseComm natives");
                SavePunishment(_, client, TYPE_MUTE,  _, "Muted through BaseComm natives");
            }
        }
        else
        {
            if (g_MuteType[client] > bNot)
            {
                MarkClientAsUnMuted(client);
            }
        }
    }
}

public void BaseComm_OnClientGag(int client, bool gagState)
{
    if (client > 0 && client <= MaxClients)
    {
        if (gagState)
        {
            if (g_GagType[client] == bNot)
            {
                MarkClientAsGagged(client, _, _, _, _, _, "Gagged through BaseComm natives");
                SavePunishment(_,  client, TYPE_GAG,   _, "Gagged through BaseComm natives");
            }
        }
        else
        {
            if (g_GagType[client] > bNot)
            {
                MarkClientAsUnGagged(client);
            }
        }
    }
}

// COMMAND CODE //
public Action CommandComms(int client, int args)
{
    if (!client)
    {
        ReplyToCommand(client, "%s%t", PREFIX, "CommandComms_na");
        return Plugin_Continue;
    }

    if (g_MuteType[client] > bNot || g_GagType[client] > bNot)
    {
        AdminMenu_ListTarget(client, client, 0);
    }
    else
    {
        ReplyToCommand(client, "%s%t", PREFIX, "CommandComms_nb");
    }

    return Plugin_Handled;
}

public Action FWBlock(int args)
{
    char arg_string[256];
    char sArg[3][64];
    GetCmdArgString(arg_string, sizeof(arg_string));

    int type;
    int length;

    if (ExplodeString(arg_string, " ", sArg, 3, 64) != 3 || !StringToIntEx(sArg[0], type) || type < 1 || type > 3 || !StringToIntEx(sArg[1], length))
    {
        LogError("Wrong usage of sc_fw_block");
        return Plugin_Stop;
    }

    LogMessage("Received block command from web: steam %s, type %d, length %d", sArg[2], type, length);

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsClientAuthorized(i) && !IsFakeClient(i))
        {
            char clientAuth[64];
            GetClientAuthId(i, AuthId_Steam2, clientAuth, sizeof(clientAuth), true);

            if (strcmp(clientAuth, sArg[2], false) == 0)
            {
                if (g_MuteType[i] == bNot && (type == 1 || type == 3))
                {
                    PerformMute(i, _, length / 60, _, _, _, _);
                    PrintToChat(i, "%s%t", PREFIX, "Muted on connect");
                    LogMessage("%s is muted from web", clientAuth);
                }

                if (g_GagType[i] == bNot && (type == 2 || type == 3))
                {
                    PerformGag(i, _, length / 60, _, _, _, _);
                    PrintToChat(i, "%s%t", PREFIX, "Gagged on connect");
                    LogMessage("%s is gagged from web", clientAuth);
                }

                break;
            }
        }
    }

    return Plugin_Handled;
}

public Action FWUngag(int args)
{
    char arg_string[256];
    char sArg[1][64];
    GetCmdArgString(arg_string, sizeof(arg_string));

    if (!ExplodeString(arg_string, " ", sArg, 1, 64))
    {
        LogError("Wrong usage of sc_fw_ungag");
        return Plugin_Stop;
    }

    LogMessage("Received ungag command from web: steam %s", sArg[0]);

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsClientAuthorized(i) && !IsFakeClient(i))
        {
            char clientAuth[64];
            GetClientAuthId(i, AuthId_Steam2, clientAuth, sizeof(clientAuth), true);

            if (strcmp(clientAuth, sArg[0], false) == 0)
            {
                if (g_GagType[i] > bNot)
                {
                    PerformUnGag(i);
                    PrintToChat(i, "%s%t", PREFIX, "FWUngag");
                    LogMessage("%s is ungagged from web", clientAuth);
                }
                else
                {
                    LogError("Can't ungag %s from web, it isn't gagged", clientAuth);
                }

                break;
            }
        }
    }

    return Plugin_Handled;
}

public Action FWUnmute(int args)
{
    char arg_string[256];
    char sArg[1][64];
    GetCmdArgString(arg_string, sizeof(arg_string));

    if (!ExplodeString(arg_string, " ", sArg, 1, 64))
    {
        LogError("Wrong usage of sc_fw_ungag");
        return Plugin_Stop;
    }

    LogMessage("Received unmute command from web: steam %s", sArg[0]);

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsClientAuthorized(i) && !IsFakeClient(i))
        {
            char clientAuth[64];
            GetClientAuthId(i, AuthId_Steam2, clientAuth, sizeof(clientAuth), true);

            if (strcmp(clientAuth, sArg[0], false) == 0)
            {
                if (g_MuteType[i] > bNot)
                {
                    PerformUnMute(i);
                    PrintToChat(i, "%s%t", PREFIX, "FWUnmute");
                    LogMessage("%s is unmuted from web", clientAuth);
                }
                else
                {
                    LogError("Can't unmute %s from web, it isn't muted", clientAuth);
                }

                break;
            }
        }
    }

    return Plugin_Handled;
}

public Action CommandCallback(int client, const char[] command, int args)
{
    if (client && !CheckCommandAccess(client, command, ADMFLAG_CHAT))
    {
        return Plugin_Continue;
    }

    int type;

    if (StrEqual(command, "sm_gag", false))
    {
        type = TYPE_GAG;
    }
    else if (StrEqual(command, "sm_mute", false))
    {
        type = TYPE_MUTE;
    }
    else if (StrEqual(command, "sm_ungag", false))
    {
        type = TYPE_UNGAG;
    }
    else if (StrEqual(command, "sm_unmute", false))
    {
        type = TYPE_UNMUTE;
    }
    else if (StrEqual(command, "sm_silence", false))
    {
        type = TYPE_SILENCE;
    }
    else if (StrEqual(command, "sm_unsilence", false))
    {
        type = TYPE_UNSILENCE;
    }
    else
    {
        return Plugin_Stop;
    }

    if (args < 1)
    {
        ReplyToCommand(client, "%sUsage: %s <#userid|name> %s", PREFIX, command, type <= TYPE_SILENCE ? "[time|0] [reason]" : "[reason]");

        if (type <= TYPE_SILENCE)
        {
            ReplyToCommand(client, "%sUsage: %s <#userid|name> [reason]", PREFIX, command);
        }

        return Plugin_Stop;
    }

    char sBuffer[256];
    GetCmdArgString(sBuffer, sizeof(sBuffer));

    if (type <= TYPE_SILENCE)
    {
        CreateBlock(client, _, _, type, _, sBuffer);
    }
    else
    {
        ProcessUnBlock(client, _, type, _, sBuffer);
    }

    return Plugin_Stop;
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

    TopMenuObject MenuObject = hTopMenu.AddCategory("sourcecomm_cmds", Handle_Commands, "sourcecomm_cmds", ADMFLAG_CHAT, "Source Comms");

    if (MenuObject == INVALID_TOPMENUOBJECT)
    {
        return;
    }

    hTopMenu.AddItem("sourcecomm_gag",       Handle_MenuGag,       MenuObject, "sm_gag",       ADMFLAG_CHAT, "Gag Player");
    hTopMenu.AddItem("sourcecomm_ungag",     Handle_MenuUnGag,     MenuObject, "sm_ungag",     ADMFLAG_CHAT, "Ungag Player");
    hTopMenu.AddItem("sourcecomm_mute",      Handle_MenuMute,      MenuObject, "sm_mute",      ADMFLAG_CHAT, "Mute Player");
    hTopMenu.AddItem("sourcecomm_unmute",    Handle_MenuUnMute,    MenuObject, "sm_unmute",    ADMFLAG_CHAT, "Unmute Player");
    hTopMenu.AddItem("sourcecomm_silence",   Handle_MenuSilence,   MenuObject, "sm_silence",   ADMFLAG_CHAT, "Silence Player");
    hTopMenu.AddItem("sourcecomm_unsilence", Handle_MenuUnSilence, MenuObject, "sm_unsilence", ADMFLAG_CHAT, "Unsilence Player");
    hTopMenu.AddItem("sourcecomm_list",      Handle_MenuList,      MenuObject, "sm_commlist",  ADMFLAG_CHAT, "Comm List");
}

public int Handle_Commands(TopMenu menu, TopMenuAction action, TopMenuObject object_id, int param1, char[] buffer, int maxlength)
{
    switch (action)
    {
        case TopMenuAction_DisplayOption:
        {
            Format(buffer, maxlength, "%T", "AdminMenu_Main", param1);
        }
        case TopMenuAction_DisplayTitle:
        {
            Format(buffer, maxlength, "%T", "AdminMenu_Select_Main", param1);
        }
    }

    return 0;
}

public int Handle_MenuGag(TopMenu menu, TopMenuAction action, TopMenuObject object_id, int param1, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "%T", "AdminMenu_Gag", param1);
    }
    else if (action == TopMenuAction_SelectOption)
    {
        AdminMenu_Target(param1, TYPE_GAG);
    }

    return 0;
}

public int Handle_MenuUnGag(TopMenu menu, TopMenuAction action, TopMenuObject object_id, int param1, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "%T", "AdminMenu_UnGag", param1);
    }
    else if (action == TopMenuAction_SelectOption)
    {
        AdminMenu_Target(param1, TYPE_UNGAG);
    }

    return 0;
}

public int Handle_MenuMute(TopMenu menu, TopMenuAction action, TopMenuObject object_id, int param1, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "%T", "AdminMenu_Mute", param1);
    }
    else if (action == TopMenuAction_SelectOption)
    {
        AdminMenu_Target(param1, TYPE_MUTE);
    }

    return 0;
}

public int Handle_MenuUnMute(TopMenu menu, TopMenuAction action, TopMenuObject object_id, int param1, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "%T", "AdminMenu_UnMute", param1);
    }
    else if (action == TopMenuAction_SelectOption)
    {
        AdminMenu_Target(param1, TYPE_UNMUTE);
    }

    return 0;
}

public int Handle_MenuSilence(TopMenu menu, TopMenuAction action, TopMenuObject object_id, int param1, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "%T", "AdminMenu_Silence", param1);
    }
    else if (action == TopMenuAction_SelectOption)
    {
        AdminMenu_Target(param1, TYPE_SILENCE);
    }

    return 0;
}

public int Handle_MenuUnSilence(TopMenu menu, TopMenuAction action, TopMenuObject object_id, int param1, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "%T", "AdminMenu_UnSilence", param1);
    }
    else if (action == TopMenuAction_SelectOption)
    {
        AdminMenu_Target(param1, TYPE_UNSILENCE);
    }

    return 0;
}

public int Handle_MenuList(TopMenu menu, TopMenuAction action, TopMenuObject object_id, int param1, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "%T", "AdminMenu_List", param1);
    }
    else if (action == TopMenuAction_SelectOption)
    {
        g_iPeskyPanels[param1][viewingList] = false;
        AdminMenu_List(param1, 0);
    }

    return 0;
}

void AdminMenu_Target(int client, int type)
{
    char Title[192];
    char Option[32];

    switch (type)
    {
        case TYPE_GAG:
        {
            Format(Title, sizeof(Title), "%T", "AdminMenu_Select_Gag", client);
        }
        case TYPE_MUTE:
        {
            Format(Title, sizeof(Title), "%T", "AdminMenu_Select_Mute", client);
        }
        case TYPE_SILENCE:
        {
            Format(Title, sizeof(Title), "%T", "AdminMenu_Select_Silence", client);
        }
        case TYPE_UNGAG:
        {
            Format(Title, sizeof(Title), "%T", "AdminMenu_Select_Ungag", client);
        }
        case TYPE_UNMUTE:
        {
            Format(Title, sizeof(Title), "%T", "AdminMenu_Select_Unmute", client);
        }
        case TYPE_UNSILENCE:
        {
            Format(Title, sizeof(Title), "%T", "AdminMenu_Select_Unsilence", client);
        }
    }

    Menu hMenu = new Menu(MenuHandler_MenuTarget);    // Common menu - players list. Almost full for blocking, and almost empty for unblocking
    hMenu.SetTitle(Title);
    hMenu.ExitBackButton = true;

    int iClients;

    if (type <= 3)    // Mute, gag, silence
    {
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && !IsFakeClient(i))
            {
                switch (type)
                {
                    case TYPE_MUTE:
                    {
                        if (g_MuteType[i] > bNot)
                        {
                            continue;
                        }
                    }
                    case TYPE_GAG:
                    {
                        if (g_GagType[i] > bNot)
                        {
                            continue;
                        }
                    }
                    case TYPE_SILENCE:
                    {
                        if (g_MuteType[i] > bNot || g_GagType[i] > bNot)
                        {
                            continue;
                        }
                    }
                }

                iClients++;
                strcopy(Title, sizeof(Title), g_sName[i]);
                AdminMenu_GetPunishPhrase(client, i, Title, sizeof(Title));
                Format(Option, sizeof(Option), "%d %d", GetClientUserId(i), type);
                hMenu.AddItem(Option, Title, (CanUserTarget(client, i) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED));
            }
        }
    }
    else        // UnMute, ungag, unsilence
    {
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && !IsFakeClient(i))
            {
                switch (type)
                {
                    case TYPE_UNMUTE:
                    {
                        if (g_MuteType[i] > bNot)
                        {
                            iClients++;
                            strcopy(Title, sizeof(Title), g_sName[i]);
                            Format(Option, sizeof(Option), "%d %d", GetClientUserId(i), type);
                            hMenu.AddItem(Option, Title, (CanUserTarget(client, i) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED));
                        }
                    }
                    case TYPE_UNGAG:
                    {
                        if (g_GagType[i] > bNot)
                        {
                            iClients++;
                            strcopy(Title, sizeof(Title), g_sName[i]);
                            Format(Option, sizeof(Option), "%d %d", GetClientUserId(i), type);
                            hMenu.AddItem(Option, Title, (CanUserTarget(client, i) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED));
                        }
                    }
                    case TYPE_UNSILENCE:
                    {
                        if (g_MuteType[i] > bNot && g_GagType[i] > bNot)
                        {
                            iClients++;
                            strcopy(Title, sizeof(Title), g_sName[i]);
                            Format(Option, sizeof(Option), "%d %d", GetClientUserId(i), type);
                            hMenu.AddItem(Option, Title, (CanUserTarget(client, i) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED));
                        }
                    }
                }
            }
        }
    }

    if (!iClients)
    {
        switch (type)
        {
            case TYPE_UNMUTE:
            {
                Format(Title, sizeof(Title), "%T", "AdminMenu_Option_Mute_Empty", client);
            }
            case TYPE_UNGAG:
            {
                Format(Title, sizeof(Title), "%T", "AdminMenu_Option_Gag_Empty", client);
            }
            case TYPE_UNSILENCE:
            {
                Format(Title, sizeof(Title), "%T", "AdminMenu_Option_Silence_Empty", client);
            }
            default:
            {
                Format(Title, sizeof(Title), "%T", "AdminMenu_Option_Empty", client);
            }
        }

        hMenu.AddItem("0", Title, ITEMDRAW_DISABLED);
    }

    hMenu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_MenuTarget(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_End:
        {
            delete menu;
        }
        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack && hTopMenu != null)
            {
                hTopMenu.Display(param1, TopMenuPosition_LastCategory);
            }
        }
        case MenuAction_Select:
        {
            char Option[32];
            char Temp[2][8];
            menu.GetItem(param2, Option, sizeof(Option));
            ExplodeString(Option, " ", Temp, 2, 8);
            int target = GetClientOfUserId(StringToInt(Temp[0]));

            if (Bool_ValidMenuTarget(param1, target))
            {
                int type = StringToInt(Temp[1]);

                if (type <= TYPE_SILENCE)
                {
                    AdminMenu_Duration(param1, target, type);
                }
                else
                {
                    ProcessUnBlock(param1, target, type);
                }
            }
        }
    }

    return 0;
}

void AdminMenu_Duration(int client, int target, int type)
{
    Menu hMenu = new Menu(MenuHandler_MenuDuration);
    char sBuffer[192];
    char sTemp[64];
    Format(sBuffer, sizeof(sBuffer), "%T", "AdminMenu_Title_Durations", client);
    hMenu.SetTitle(sBuffer);
    hMenu.ExitBackButton = true;

    for (int i = 0; i <= iNumTimes; i++)
    {
        if (IsAllowedBlockLength(client, g_iTimeMinutes[i]))
        {
            Format(sTemp, sizeof(sTemp), "%d %d %d", GetClientUserId(target), type, i);    // TargetID TYPE_BLOCK index_of_Time
            hMenu.AddItem(sTemp, g_sTimeDisplays[i]);
        }
    }

    hMenu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_MenuDuration(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_End:
        {
            delete menu;
        }
        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack && hTopMenu != null)
            {
                hTopMenu.Display(param1, TopMenuPosition_LastCategory);
            }
        }
        case MenuAction_Select:
        {
            char sOption[32];
            char sTemp[3][8];
            menu.GetItem(param2, sOption, sizeof(sOption));
            ExplodeString(sOption, " ", sTemp, 3, 8);

            int target = GetClientOfUserId(StringToInt(sTemp[0]));

            if (Bool_ValidMenuTarget(param1, target))
            {
                int type = StringToInt(sTemp[1]);
                int lengthIndex = StringToInt(sTemp[2]);

                if (iNumReasons) // we have reasons to show
                {
                    AdminMenu_Reason(param1, target, type, lengthIndex);
                }
                else
                {
                    CreateBlock(param1, target, g_iTimeMinutes[lengthIndex], type);
                }
            }
        }
    }

    return 0;
}

void AdminMenu_Reason(int client, int target, int type, int lengthIndex)
{
    Menu hMenu = new Menu(MenuHandler_MenuReason);
    char sBuffer[192];
    char sTemp[64];
    Format(sBuffer, sizeof(sBuffer), "%T", "AdminMenu_Title_Reasons", client);
    hMenu.SetTitle(sBuffer);
    hMenu.ExitBackButton = true;

    for (int i = 0; i <= iNumReasons; i++)
    {
        Format(sTemp, sizeof(sTemp), "%d %d %d %d", GetClientUserId(target), type, i, lengthIndex);    // TargetID TYPE_BLOCK ReasonIndex LenghtIndex
        hMenu.AddItem(sTemp, g_sReasonDisplays[i]);
    }

    hMenu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_MenuReason(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_End:
        {
            delete menu;
        }
        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack && hTopMenu != null)
            {
                hTopMenu.Display(param1, TopMenuPosition_LastCategory);
            }
        }
        case MenuAction_Select:
        {
            char sOption[64];
            char sTemp[4][8];
            menu.GetItem(param2, sOption, sizeof(sOption));
            ExplodeString(sOption, " ", sTemp, 4, 8);

            int target = GetClientOfUserId(StringToInt(sTemp[0]));

            if (Bool_ValidMenuTarget(param1, target))
            {
                int type = StringToInt(sTemp[1]);
                int reasonIndex = StringToInt(sTemp[2]);
                int lengthIndex = StringToInt(sTemp[3]);
                int length;

                if (lengthIndex >= 0 && lengthIndex <= iNumTimes)
                {
                    length = g_iTimeMinutes[lengthIndex];
                }
                else
                {
                    length = DefaultTime;
                    LogError("Wrong length index in menu - using default time");
                }

                CreateBlock(param1, target, length, type, g_sReasonKey[reasonIndex]);
            }
        }
    }

    return 0;
}

void AdminMenu_List(int client, int index)
{
    char sTitle[192];
    char sOption[32];
    Format(sTitle, sizeof(sTitle), "%T", "AdminMenu_Select_List", client);
    int iClients;
    Menu hMenu = new Menu(MenuHandler_MenuList);
    hMenu.SetTitle(sTitle);

    if (!g_iPeskyPanels[client][viewingList])
    {
        hMenu.ExitBackButton = true;
    }

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && (g_MuteType[i] > bNot || g_GagType[i] > bNot))
        {
            iClients++;
            strcopy(sTitle, sizeof(sTitle), g_sName[i]);
            AdminMenu_GetPunishPhrase(client, i, sTitle, sizeof(sTitle));
            Format(sOption, sizeof(sOption), "%d", GetClientUserId(i));
            hMenu.AddItem(sOption, sTitle);
        }
    }

    if (!iClients)
    {
        Format(sTitle, sizeof(sTitle), "%T", "ListMenu_Option_Empty", client);
        hMenu.AddItem("0", sTitle, ITEMDRAW_DISABLED);
    }

    hMenu.DisplayAt(client, index, MENU_TIME_FOREVER);
}

public int MenuHandler_MenuList(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_End:
        {
            delete menu;
        }
        case MenuAction_Cancel:
        {
            if (!g_iPeskyPanels[param1][viewingList])
            {
                if (param2 == MenuCancel_ExitBack && hTopMenu != null)
                {
                    hTopMenu.Display(param1, TopMenuPosition_LastCategory);
                }
            }
        }
        case MenuAction_Select:
        {
            char sOption[32];
            menu.GetItem(param2, sOption, sizeof(sOption));

            int target = GetClientOfUserId(StringToInt(sOption));

            if (Bool_ValidMenuTarget(param1, target))
            {
                AdminMenu_ListTarget(param1, target, GetMenuSelectionPosition());
            }
            else
            {
                AdminMenu_List(param1, GetMenuSelectionPosition());
            }
        }
    }

    return 0;
}

void AdminMenu_ListTarget(int client, int target, int index, int viewMute = 0, int viewGag = 0)
{
    int userid = GetClientUserId(target);
    Menu hMenu = new Menu(MenuHandler_MenuListTarget);
    char sBuffer[192];
    char sOption[32];
    hMenu.SetTitle(g_sName[target]);
    SetMenuPagination(hMenu, MENU_NO_PAGINATION);
    SetMenuExitButton(hMenu, true);
    hMenu.ExitBackButton = false;

    if (g_MuteType[target] > bNot)
    {
        Format(sBuffer, sizeof(sBuffer), "%T", "ListMenu_Option_Mute", client);
        Format(sOption, sizeof(sOption), "0 %d %d %b %b", userid, index, viewMute, viewGag);
        hMenu.AddItem(sOption, sBuffer);

        if (viewMute)
        {
            Format(sBuffer, sizeof(sBuffer), "%T", "ListMenu_Option_Admin", client, g_sMuteAdminName[target]);
            hMenu.AddItem("", sBuffer, ITEMDRAW_DISABLED);

            char sMuteTemp[192];
            char _sMuteTime[192];
            Format(sMuteTemp, sizeof(sMuteTemp), "%T", "ListMenu_Option_Duration", client);

            if (g_MuteType[target] == bPerm)
            {
                Format(sBuffer, sizeof(sBuffer), "%s%T", sMuteTemp, "ListMenu_Option_Duration_Perm", client);
            }
            else if (g_MuteType[target] == bTime)
            {
                Format(sBuffer, sizeof(sBuffer), "%s%T", sMuteTemp, "ListMenu_Option_Duration_Time", client, g_iMuteLength[target]);
            }
            else if (g_MuteType[target] == bSess)
            {
                Format(sBuffer, sizeof(sBuffer), "%s%T", sMuteTemp, "ListMenu_Option_Duration_Temp", client);
            }
            else
            {
                Format(sBuffer, sizeof(sBuffer), "error");
            }

            hMenu.AddItem("", sBuffer, ITEMDRAW_DISABLED);

            FormatTime(_sMuteTime, sizeof(_sMuteTime), NULL_STRING, g_iMuteTime[target]);
            Format(sBuffer, sizeof(sBuffer), "%T", "ListMenu_Option_Issue", client, _sMuteTime);
            hMenu.AddItem("", sBuffer, ITEMDRAW_DISABLED);

            Format(sMuteTemp, sizeof(sMuteTemp), "%T", "ListMenu_Option_Expire", client);

            if (g_MuteType[target] == bPerm)
            {
                Format(sBuffer, sizeof(sBuffer), "%s%T", sMuteTemp, "ListMenu_Option_Expire_Perm", client);
            }
            else if (g_MuteType[target] == bTime)
            {
                FormatTime(_sMuteTime, sizeof(_sMuteTime), NULL_STRING, (g_iMuteTime[target] + g_iMuteLength[target] * 60));
                Format(sBuffer, sizeof(sBuffer), "%s%T", sMuteTemp, "ListMenu_Option_Expire_Time", client, _sMuteTime);
            }
            else if (g_MuteType[target] == bSess)
            {
                Format(sBuffer, sizeof(sBuffer), "%s%T", sMuteTemp, "ListMenu_Option_Expire_Temp_Reconnect", client);
            }
            else
            {
                Format(sBuffer, sizeof(sBuffer), "error");
            }

            hMenu.AddItem("", sBuffer, ITEMDRAW_DISABLED);

            if (strlen(g_sMuteReason[target]) > 0)
            {
                Format(sBuffer, sizeof(sBuffer), "%T", "ListMenu_Option_Reason", client);
                Format(sOption, sizeof(sOption), "1 %d %d %b %b", userid, index, viewMute, viewGag);
                hMenu.AddItem(sOption, sBuffer);
            }
            else
            {
                Format(sBuffer, sizeof(sBuffer), "%T", "ListMenu_Option_Reason_None", client);
                hMenu.AddItem("", sBuffer, ITEMDRAW_DISABLED);
            }
        }
    }

    if (g_GagType[target] > bNot)
    {
        Format(sBuffer, sizeof(sBuffer), "%T", "ListMenu_Option_Gag", client);
        Format(sOption, sizeof(sOption), "2 %d %d %b %b", userid, index, viewMute, viewGag);
        hMenu.AddItem(sOption, sBuffer);

        if (viewGag)
        {
            Format(sBuffer, sizeof(sBuffer), "%T", "ListMenu_Option_Admin", client, g_sGagAdminName[target]);
            hMenu.AddItem("", sBuffer, ITEMDRAW_DISABLED);

            char sGagTemp[192];
            char _sGagTime[192];
            Format(sGagTemp, sizeof(sGagTemp), "%T", "ListMenu_Option_Duration", client);

            if (g_GagType[target] == bPerm)
            {
                Format(sBuffer, sizeof(sBuffer), "%s%T", sGagTemp, "ListMenu_Option_Duration_Perm", client);
            }
            else if (g_GagType[target] == bTime)
            {
                Format(sBuffer, sizeof(sBuffer), "%s%T", sGagTemp, "ListMenu_Option_Duration_Time", client, g_iGagLength[target]);
            }
            else if (g_GagType[target] == bSess)
            {
                Format(sBuffer, sizeof(sBuffer), "%s%T", sGagTemp, "ListMenu_Option_Duration_Temp", client);
            }
            else
            {
                Format(sBuffer, sizeof(sBuffer), "error");
            }

            hMenu.AddItem("", sBuffer, ITEMDRAW_DISABLED);

            FormatTime(_sGagTime, sizeof(_sGagTime), NULL_STRING, g_iGagTime[target]);
            Format(sBuffer, sizeof(sBuffer), "%T", "ListMenu_Option_Issue", client, _sGagTime);
            hMenu.AddItem("", sBuffer, ITEMDRAW_DISABLED);

            Format(sGagTemp, sizeof(sGagTemp), "%T", "ListMenu_Option_Expire", client);

            if (g_GagType[target] == bPerm)
            {
                Format(sBuffer, sizeof(sBuffer), "%s%T", sGagTemp, "ListMenu_Option_Expire_Perm", client);
            }
            else if (g_GagType[target] == bTime)
            {
                FormatTime(_sGagTime, sizeof(_sGagTime), NULL_STRING, (g_iGagTime[target] + g_iGagLength[target] * 60));
                Format(sBuffer, sizeof(sBuffer), "%s%T", sGagTemp, "ListMenu_Option_Expire_Time", client, _sGagTime);
            }
            else if (g_GagType[target] == bSess)
            {
                Format(sBuffer, sizeof(sBuffer), "%s%T", sGagTemp, "ListMenu_Option_Expire_Temp_Reconnect", client);
            }
            else
            {
                Format(sBuffer, sizeof(sBuffer), "error");
            }

            hMenu.AddItem("", sBuffer, ITEMDRAW_DISABLED);

            if (strlen(g_sGagReason[target]) > 0)
            {
                Format(sBuffer, sizeof(sBuffer), "%T", "ListMenu_Option_Reason", client);
                Format(sOption, sizeof(sOption), "3 %d %d %b %b", userid, index, viewMute, viewGag);
                hMenu.AddItem(sOption, sBuffer);
            }
            else
            {
                Format(sBuffer, sizeof(sBuffer), "%T", "ListMenu_Option_Reason_None", client);
                hMenu.AddItem("", sBuffer, ITEMDRAW_DISABLED);
            }
        }
    }

    g_iPeskyPanels[client][curIndex]    = index;
    g_iPeskyPanels[client][curTarget]   = target;
    g_iPeskyPanels[client][viewingGag]  = viewGag;
    g_iPeskyPanels[client][viewingMute] = viewMute;
    hMenu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_MenuListTarget(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_End:
        {
            delete menu;
        }
        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
            {
                AdminMenu_List(param1, g_iPeskyPanels[param1][curIndex]);
            }
        }
        case MenuAction_Select:
        {
            char sOption[64];
            char sTemp[5][8];
            menu.GetItem(param2, sOption, sizeof(sOption));
            ExplodeString(sOption, " ", sTemp, 5, 8);

            int target = GetClientOfUserId(StringToInt(sTemp[1]));

            if (param1 == target || Bool_ValidMenuTarget(param1, target))
            {
                switch (StringToInt(sTemp[0]))
                {
                    case 0:
                    {
                        AdminMenu_ListTarget(param1, target, StringToInt(sTemp[2]), !(StringToInt(sTemp[3])), 0);
                    }
                    case 1, 3:
                    {
                        AdminMenu_ListTargetReason(param1, target, g_iPeskyPanels[param1][viewingMute], g_iPeskyPanels[param1][viewingGag]);
                    }
                    case 2:
                    {
                        AdminMenu_ListTarget(param1, target, StringToInt(sTemp[2]), 0, !(StringToInt(sTemp[4])));
                    }
                }
            }
            else
            {
                AdminMenu_List(param1, StringToInt(sTemp[2]));
            }

        }
    }

    return 0;
}

void AdminMenu_ListTargetReason(int client, int target, int showMute, int showGag)
{
    char sTemp[192];
    char sBuffer[192];
    Panel hPanel = new Panel();
    hPanel.SetTitle(g_sName[target]);
    hPanel.DrawItem(" ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);

    if (showMute)
    {
        Format(sTemp, sizeof(sTemp), "%T", "ReasonPanel_Punishment_Mute", client);

        if (g_MuteType[target] == bPerm)
        {
            Format(sBuffer, sizeof(sBuffer), "%s%T", sTemp, "ReasonPanel_Perm", client);
        }
        else if (g_MuteType[target] == bTime)
        {
            Format(sBuffer, sizeof(sBuffer), "%s%T", sTemp, "ReasonPanel_Time", client, g_iMuteLength[target]);
        }
        else if (g_MuteType[target] == bSess)
        {
            Format(sBuffer, sizeof(sBuffer), "%s%T", sTemp, "ReasonPanel_Temp", client);
        }
        else
        {
            Format(sBuffer, sizeof(sBuffer), "error");
        }

        hPanel.DrawText(sBuffer);

        Format(sBuffer, sizeof(sBuffer), "%T", "ReasonPanel_Reason", client, g_sMuteReason[target]);
        hPanel.DrawText(sBuffer);
    }
    else if (showGag)
    {
        Format(sTemp, sizeof(sTemp), "%T", "ReasonPanel_Punishment_Gag", client);

        if (g_GagType[target] == bPerm)
        {
            Format(sBuffer, sizeof(sBuffer), "%s%T", sTemp, "ReasonPanel_Perm", client);
        }
        else if (g_GagType[target] == bTime)
        {
            Format(sBuffer, sizeof(sBuffer), "%s%T", sTemp, "ReasonPanel_Time", client, g_iGagLength[target]);
        }
        else if (g_GagType[target] == bSess)
        {
            Format(sBuffer, sizeof(sBuffer), "%s%T", sTemp, "ReasonPanel_Temp", client);
        }
        else
        {
            Format(sBuffer, sizeof(sBuffer), "error");
        }

        hPanel.DrawText(sBuffer);

        Format(sBuffer, sizeof(sBuffer), "%T", "ReasonPanel_Reason", client, g_sGagReason[target]);
        hPanel.DrawText(sBuffer);
    }

    hPanel.DrawItem(" ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
    hPanel.CurrentKey = 10;
    Format(sBuffer, sizeof(sBuffer), "%T", "ReasonPanel_Back", client);
    hPanel.DrawItem(sBuffer);
    hPanel.Send(client, PanelHandler_ListTargetReason, MENU_TIME_FOREVER);
    delete hPanel;
}

public int PanelHandler_ListTargetReason(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            AdminMenu_ListTarget(param1, g_iPeskyPanels[param1][curTarget], g_iPeskyPanels[param1][curIndex], g_iPeskyPanels[param1][viewingMute], g_iPeskyPanels[param1][viewingGag]);
        }
    }

    return 0;
}

// SQL CALLBACKS //
public void GotDatabase(Handle owner, Handle hndl, const char[] error, any data)
{
    // If this happens to be an old connection request, ignore it.
    if (data != g_iConnectLock || g_hDatabase)
    {
        if (hndl)
        {
            delete hndl;
        }

        return;
    }

    g_iConnectLock  = 0;
    g_DatabaseState = DatabaseState_Connected;
    g_hDatabase     = hndl;

    // See if the connection is valid.  If not, don't un-mark the caches
    // as needing rebuilding, in case the next connection request works.
    if (!g_hDatabase)
    {
        LogError("Connecting to database failed: %s", error);
        return;
    }

    // Set character set to UTF-8 in the database
    if (GetFeatureStatus(FeatureType_Native, "SQL_SetCharset") == FeatureStatus_Available)
    {
        SQL_SetCharset(g_hDatabase, "utf8");
    }
    else
    {
        char query[128];
        FormatEx(query, sizeof(query), "SET NAMES 'UTF8'");
        SQL_TQuery(g_hDatabase, Query_ErrorCheck, query);
    }

    // Process queue
    SQL_TQuery(SQLiteDB, Query_ProcessQueue,
       "SELECT  id, steam_id, time, start_time, reason, name, admin_id, admin_ip, type \
        FROM    queue2");

    // Force recheck players
    ForcePlayersRecheck();
}

public void Query_AddBlockInsert(Handle owner, Handle hndl, const char[] error, DataPack data)
{
    if (DB_Conn_Lost(hndl) || error[0])
    {
        LogError("Query_AddBlockInsert failed: %s", error);

        data.Reset();
        int length = data.ReadCell();
        int type   = data.ReadCell();
        char reason[256];
        char name[MAX_NAME_LENGTH];
        char auth[64];
        char adminAuth[32];
        char adminIp[20];
        data.ReadString(name,      sizeof(name));
        data.ReadString(auth,      sizeof(auth));
        data.ReadString(reason,    sizeof(reason));
        data.ReadString(adminAuth, sizeof(adminAuth));
        data.ReadString(adminIp,   sizeof(adminIp));
        InsertTempBlock(length, type, name, auth, reason, adminAuth, adminIp);
    }

    delete data;
}

public int Query_UnBlockSelect(Handle owner, Handle hndl, const char[] error, DataPack data)
{
    char adminAuth[30];
    char targetAuth[30];
    char reason[256];

    data.Reset();
    int adminUserID  = data.ReadCell();
    int targetUserID = data.ReadCell();
    int type         = data.ReadCell();    // not in use unless DEBUG
    data.ReadString(adminAuth,  sizeof(adminAuth));
    data.ReadString(targetAuth, sizeof(targetAuth));
    data.ReadString(reason,     sizeof(reason));

    int admin  = GetClientOfUserId(adminUserID);
    int target = GetClientOfUserId(targetUserID);

    char targetName[MAX_NAME_LENGTH];
    strcopy(targetName, MAX_NAME_LENGTH, target && IsClientInGame(target) ? g_sName[target] : targetAuth);        //FIXME

    bool hasErrors = false;
    // If error is not an empty string the query failed
    if (DB_Conn_Lost(hndl) || error[0] != '\0')
    {
        LogError("Query_UnBlockSelect failed: %s", error);

        if (admin && IsClientInGame(admin))
        {
            PrintToChat(admin, "%s%T", PREFIX, "Unblock Select Failed", admin, targetAuth);
            PrintToConsole(admin, "%s%T", PREFIX, "Unblock Select Failed", admin, targetAuth);
        }
        else
        {
            PrintToServer("%s%T", PREFIX, "Unblock Select Failed", LANG_SERVER, targetAuth);
        }

        hasErrors = true;
    }

    // If there was no results then a ban does not exist for that id
    if (!DB_Conn_Lost(hndl) && !SQL_GetRowCount(hndl))
    {
        if (admin && IsClientInGame(admin))
        {
            PrintToChat(admin, "%s%t", PREFIX, "No blocks found", targetAuth);
            PrintToConsole(admin, "%s%t", PREFIX, "No blocks found", targetAuth);
        }
        else
        {
            PrintToServer("%s%T", PREFIX, "No blocks found", LANG_SERVER, targetAuth);
        }

        hasErrors = true;
    }

    if (hasErrors)
    {
        TempUnBlock(data); // Datapack closed inside.
        return 0;
    }
    else
    {
        bool b_success = false;
        // Get the values from the founded blocks.
        while(SQL_MoreRows(hndl))
        {
            // Oh noes! What happened?!
            if (!SQL_FetchRow(hndl))
            {
                continue;
            }

            int bid       = SQL_FetchInt(hndl, 0);
            int iAID      = SQL_FetchInt(hndl, 1);
            int cAID      = SQL_FetchInt(hndl, 2);
            int cImmunity = SQL_FetchInt(hndl, 3);
            int cType     = SQL_FetchInt(hndl, 4);

            // Checking - has we access to unblock?
            if (iAID == cAID || (!admin && StrEqual(adminAuth, "STEAM_0:0:00000000000")) || AdmHasFlag(admin) || (DisUBImCheck == 0 && (GetAdmImmunity(admin) > cImmunity)))
            {
                // Ok! we have rights to unblock
                b_success = true;
                // UnMute/UnGag, Show & log activity
                if (target && IsClientInGame(target))
                {
                    switch (cType)
                    {
                        case TYPE_MUTE:
                        {
                            PerformUnMute(target);
                            LogAction(admin, target, "\"%L\" unmuted \"%L\" (reason \"%s\")", admin, target, reason);
                        }
                        //-------------------------------------------------------------------------------------------------
                        case TYPE_GAG:
                        {
                            PerformUnGag(target);
                            LogAction(admin, target, "\"%L\" ungagged \"%L\" (reason \"%s\")", admin, target, reason);
                        }
                    }
                }

                DataPack dataPack = new DataPack();
                dataPack.WriteCell(adminUserID);
                dataPack.WriteCell(cType);
                dataPack.WriteString(g_sName[target]);
                dataPack.WriteString(targetAuth);

                char unbanReason[sizeof(reason) * 2 + 1];
                SQL_EscapeString(g_hDatabase, reason, unbanReason, sizeof(unbanReason));

                char query[2048];
                Format(query, sizeof(query),
                   "UPDATE  %s_comms \
                    SET     RemovedBy = %d, \
                            RemoveType = 'U', \
                            RemovedOn = UNIX_TIMESTAMP(), \
                            ureason = '%s' \
                    WHERE   bid = %d",
                    DatabasePrefix, iAID, unbanReason, bid);

                SQL_TQuery(g_hDatabase, Query_UnBlockUpdate, query, dataPack);
            }
            else
            {
                // sorry, we don't have permission to unblock!
                switch (cType)
                {
                    case TYPE_MUTE:
                    {
                        if (admin && IsClientInGame(admin))
                        {
                            PrintToChat(admin, "%s%t", PREFIX, "No permission unmute", targetName);
                            PrintToConsole(admin, "%s%t", PREFIX, "No permission unmute", targetName);
                        }

                        LogAction(admin, target, "\"%L\" tried (and didn't have permission) to unmute %s (reason \"%s\")", admin, targetAuth, reason);
                    }
                    //-------------------------------------------------------------------------------------------------
                    case TYPE_GAG:
                    {
                        if (admin && IsClientInGame(admin))
                        {
                            PrintToChat(admin, "%s%t", PREFIX, "No permission ungag", targetName);
                            PrintToConsole(admin, "%s%t", PREFIX, "No permission ungag", targetName);
                        }

                        LogAction(admin, target, "\"%L\" tried (and didn't have permission) to ungag %s (reason \"%s\")", admin, targetAuth, reason);
                    }
                }
            }
        }

        if (b_success && target && IsClientInGame(target))
        {
            ShowActivityToServer(admin, type, _, _, g_sName[target], _);

            if (type == TYPE_UNSILENCE)
            {
                // check result for possible combination with temp and time punishments (temp was skipped in code above)
                data.Position = view_as<DataPackPos>(DATAPACKPOS);

                if (g_MuteType[target] > bNot)
                {
                    data.WriteCell(TYPE_UNMUTE);
                    TempUnBlock(data);
                    data = null;
                }
                else if (g_GagType[target] > bNot)
                {
                    data.WriteCell(TYPE_UNGAG);
                    TempUnBlock(data);
                    data = null;
                }
            }
        }
    }

    if (data != null)
    {
        delete data;
    }

    return 0;
}

public void Query_UnBlockUpdate(Handle owner, Handle hndl, const char[] error, DataPack data)
{
    int admin;
    int type;
    char targetName[MAX_NAME_LENGTH];
    char targetAuth[30];

    data.Reset();
    admin = GetClientOfUserId(data.ReadCell());
    type  = data.ReadCell();
    data.ReadString(targetName, sizeof(targetName));
    data.ReadString(targetAuth, sizeof(targetAuth));
    delete data;

    if (DB_Conn_Lost(hndl) || error[0] != '\0')
    {
        LogError("Query_UnBlockUpdate failed: %s", error);

        if (admin && IsClientInGame(admin))
        {
            PrintToChat(admin, "%s%t", PREFIX, "Unblock insert failed");
            PrintToConsole(admin, "%s%t", PREFIX, "Unblock insert failed");
        }

        return;
    }

    switch (type)
    {
        case TYPE_MUTE:
        {
            LogAction(admin, -1, "\"%L\" removed mute for %s from DB", admin, targetAuth);

            if (admin && IsClientInGame(admin))
            {
                PrintToChat(admin, "%s%t", PREFIX, "successfully unmuted", targetName);
                PrintToConsole(admin, "%s%t", PREFIX, "successfully unmuted", targetName);
            }
            else
            {
                PrintToServer("%s%T", PREFIX, "successfully unmuted", LANG_SERVER, targetName);
            }
        }
        //-------------------------------------------------------------------------------------------------
        case TYPE_GAG:
        {
            LogAction(admin, -1, "\"%L\" removed gag for %s from DB", admin, targetAuth);

            if (admin && IsClientInGame(admin))
            {
                PrintToChat(admin, "%s%t", PREFIX, "successfully ungagged", targetName);
                PrintToConsole(admin, "%s%t", PREFIX, "successfully ungagged", targetName);
            }
            else
            {
                PrintToServer("%s%T", PREFIX, "successfully ungagged", LANG_SERVER, targetName);
            }
        }
    }
}

// ProcessQueueCallback is called as the result of selecting all the rows from the queue table
public void Query_ProcessQueue(Handle owner, Handle hndl, const char[] error, any data)
{
    if (hndl == null || error[0])
    {
        LogError("Query_ProcessQueue failed: %s", error);
        return;
    }

    char auth[64];
    char name[MAX_NAME_LENGTH];
    char reason[256];
    char adminAuth[64];
    char adminIp[20];
    char query[4096];

    while(SQL_MoreRows(hndl))
    {
        // Oh noes! What happened?!
        if (!SQL_FetchRow(hndl))
        {
            continue;
        }

        char sAuthEscaped[sizeof(auth) * 2 + 1];
        char banReason[sizeof(reason) * 2 + 1];
        char sAdmAuthEscaped[sizeof(adminAuth) * 2 + 1];
        char sAdmAuthYZEscaped[sizeof(adminAuth) * 2 + 1];
        char banName[MAX_NAME_LENGTH * 2  + 1];

        // if we get to here then there are rows in the queue pending processing
        //steam_id TEXT, time INTEGER, start_time INTEGER, reason TEXT, name TEXT, admin_id TEXT, admin_ip TEXT, type INTEGER
        int id = SQL_FetchInt(hndl, 0);
        SQL_FetchString(hndl, 1, auth, sizeof(auth));
        int time = SQL_FetchInt(hndl, 2);
        int startTime = SQL_FetchInt(hndl, 3);
        SQL_FetchString(hndl, 4, reason, sizeof(reason));
        SQL_FetchString(hndl, 5, name, sizeof(name));
        SQL_FetchString(hndl, 6, adminAuth, sizeof(adminAuth));
        SQL_FetchString(hndl, 7, adminIp, sizeof(adminIp));
        int type = SQL_FetchInt(hndl, 8);

        if (DB_Connect())
        {
            SQL_EscapeString(g_hDatabase, auth,         sAuthEscaped,      sizeof(sAuthEscaped));
            SQL_EscapeString(g_hDatabase, name,         banName,           sizeof(banName));
            SQL_EscapeString(g_hDatabase, reason,       banReason,         sizeof(banReason));
            SQL_EscapeString(g_hDatabase, adminAuth,    sAdmAuthEscaped,   sizeof(sAdmAuthEscaped));
            SQL_EscapeString(g_hDatabase, adminAuth[8], sAdmAuthYZEscaped, sizeof(sAdmAuthYZEscaped));
        }
        else
        {
            continue;
        }
        // all blocks should be entered into db!

        FormatEx(query, sizeof(query),
               "INSERT INTO     %s_comms (authid, uniqueId, name, created, ends, length, reason, aid, adminIp, sid, type) \
                VALUES         ('%s', '%s', '%s', %d, %d, %d, '%s', \
                                IFNULL((SELECT aid FROM %s_admins WHERE authid = '%s' OR authid REGEXP '^STEAM_[0-9]:%s$'), '0'), \
                                '%s', %d, %d)",
                DatabasePrefix, sAuthEscaped, sAuthEscaped[8], banName, startTime, (startTime + (time*60)), (time*60), banReason, DatabasePrefix, sAdmAuthEscaped, sAdmAuthYZEscaped, adminIp, serverID, type);

        SQL_TQuery(g_hDatabase, Query_AddBlockFromQueue, query, id);
    }
}

public void Query_AddBlockFromQueue(Handle owner, Handle hndl, const char[] error, any data)
{
    char query[512];

    if (error[0] == '\0')
    {
        // The insert was successful so delete the record from the queue
        FormatEx(query, sizeof(query),
           "DELETE FROM queue2 \
            WHERE       id = %d",
            data);

        SQL_TQuery(SQLiteDB, Query_ErrorCheck, query);
    }
}

public void Query_ErrorCheck(Handle owner, Handle hndl, const char[] error, any data)
{
    if (DB_Conn_Lost(hndl) || error[0])
    {
        LogError("%T (%s)", "Failed to query database", LANG_SERVER, error);
    }
}

public void Query_VerifyBlock(Handle owner, Handle hndl, const char[] error, any userid)
{
    char clientAuth[64];
    int client = GetClientOfUserId(userid);

    if (!client)
    {
        return;
    }

    /* Failure happen. Do retry with delay */
    if (DB_Conn_Lost(hndl))
    {
        LogError("Query_VerifyBlock failed: %s", error);

        if (g_hPlayerRecheck[client] == null)
        {
            g_hPlayerRecheck[client] = CreateTimer(RetryTime, ClientRecheck, userid);
        }

        return;
    }

    GetClientAuthId(client, AuthId_Steam2, clientAuth, sizeof(clientAuth), true);

    //SELECT (c.ends - UNIX_TIMESTAMP()) as remaining, c.length, c.type, c.created, c.reason, a.user,
    //IF (a.immunity>=g.immunity, a.immunity, IFNULL(g.immunity, 0)) as immunity, c.aid, c.sid, c.authid
    //FROM %s_comms c LEFT JOIN %s_admins a ON a.aid=c.aid LEFT JOIN %s_srvgroups g ON g.name = a.srv_group
    //WHERE c.authid REGEXP '^STEAM_[0-9]:%s$' AND (length = '0' OR ends > UNIX_TIMESTAMP()) AND RemoveType IS NULL",
    if (SQL_GetRowCount(hndl) > 0)
    {
        while(SQL_FetchRow(hndl))
        {
            if (NotApplyToThisServer(SQL_FetchInt(hndl, 8)))
            {
                continue;
            }

            char sReason[256];
            char sAdmName[MAX_NAME_LENGTH];
            char sAdmAuth[64];
            int remaining_time = SQL_FetchInt(hndl, 0);
            int length         = SQL_FetchInt(hndl, 1);
            int type           = SQL_FetchInt(hndl, 2);
            int time           = SQL_FetchInt(hndl, 3);
            SQL_FetchString(hndl, 4, sReason, sizeof(sReason));
            SQL_FetchString(hndl, 5, sAdmName, sizeof(sAdmName));
            int immunity = SQL_FetchInt(hndl, 6);
            int aid      = SQL_FetchInt(hndl, 7);
            SQL_FetchString(hndl, 9, sAdmAuth, sizeof(sAdmAuth));

            // Block from CONSOLE (aid=0) and we have `console immunity` value in config
            if (!aid && ConsoleImmunity > immunity)
            {
                immunity = ConsoleImmunity;
            }

            switch (type)
            {
                case TYPE_MUTE:
                {
                    if (g_MuteType[client] < bTime)
                    {
                        PerformMute(client, time, length / 60, sAdmName, sAdmAuth, immunity, sReason, remaining_time);
                        PrintToChat(client, "%s%t", PREFIX, "Muted on connect");
                    }
                }
                case TYPE_GAG:
                {
                    if (g_GagType[client] < bTime)
                    {
                        PerformGag(client, time, length / 60, sAdmName, sAdmAuth, immunity, sReason, remaining_time);
                        PrintToChat(client, "%s%t", PREFIX, "Gagged on connect");
                    }
                }
            }
        }
    }

    g_bPlayerStatus[client] = true;
}

// TIMER CALL BACKS //
public Action ClientRecheck(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);

    if (!client)
    {
        return Plugin_Stop;
    }

    if (IsClientConnected(client))
    {
        OnClientPostAdminCheck(client);
    }

    g_hPlayerRecheck[client] = null;
    return Plugin_Stop;
}

public Action Timer_MuteExpire(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);

    if (!client)
    {
        return Plugin_Stop;
    }

    PrintToChat(client, "%s%t", PREFIX, "Mute expired");

    g_hMuteExpireTimer[client] = null;
    MarkClientAsUnMuted(client);

    if (IsClientInGame(client))
    {
        BaseComm_SetClientMute(client, false);
    }

    return Plugin_Stop;
}

public Action Timer_GagExpire(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);

    if (!client)
    {
        return Plugin_Stop;
    }

    PrintToChat(client, "%s%t", PREFIX, "Gag expired");

    g_hGagExpireTimer[client] = null;
    MarkClientAsUnGagged(client);

    if (IsClientInGame(client))
    {
        BaseComm_SetClientGag(client, false);
    }

    return Plugin_Stop;
}

public Action Timer_StopWait(Handle timer, any data)
{
    g_DatabaseState = DatabaseState_None;
    DB_Connect();
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

static void InternalReadConfig(const char[] path)
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
        else if (strcmp("CommsReasons", name, false) == 0)
        {
            ConfigState = ConfigStateReasons;
        }
        else if (strcmp("CommsTimes", name, false) == 0)
        {
            ConfigState = ConfigStateTimes;
        }
        else if (strcmp("ServersWhiteList", name, false) == 0)
        {
            ConfigState = ConfigStateServers;
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
            if (strcmp("DatabasePrefix", key, false) == 0)
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
            else if (strcmp("ServerID", key, false) == 0)
            {
                if (!StringToIntEx(value, serverID) || serverID < 1)
                {
                    serverID = 0;
                }
            }
            else if (strcmp("DefaultTime", key, false) == 0)
            {
                DefaultTime = StringToInt(value);

                if (DefaultTime < 0)
                {
                    DefaultTime = -1;
                }

                if (DefaultTime == 0)
                {
                    DefaultTime = 30;
                }
            }
            else if (strcmp("DisableUnblockImmunityCheck", key, false) == 0)
            {
                DisUBImCheck = StringToInt(value);

                if (DisUBImCheck != 1)
                {
                    DisUBImCheck = 0;
                }
            }
            else if (strcmp("ConsoleImmunity", key, false) == 0)
            {
                ConsoleImmunity = StringToInt(value);

                if (ConsoleImmunity < 0 || ConsoleImmunity > 100)
                {
                    ConsoleImmunity = 0;
                }
            }
            else if (strcmp("MaxLength", key, false) == 0)
            {
                ConfigMaxLength = StringToInt(value);
            }
            else if (strcmp("OnlyWhiteListServers", key, false) == 0)
            {
                ConfigWhiteListOnly = StringToInt(value);

                if (ConfigWhiteListOnly != 1)
                {
                    ConfigWhiteListOnly = 0;
                }
            }
        }
        case ConfigStateReasons:
        {
            Format(g_sReasonKey[iNumReasons], REASON_SIZE, "%s", key);
            Format(g_sReasonDisplays[iNumReasons], DISPLAY_SIZE, "%s", value);
            iNumReasons++;
        }
        case ConfigStateTimes:
        {
            Format(g_sTimeDisplays[iNumTimes], DISPLAY_SIZE, "%s", value);
            g_iTimeMinutes[iNumTimes] = StringToInt(key);
            iNumTimes++;
        }
        case ConfigStateServers:
        {
            if (strcmp("id", key, false) == 0)
            {
                int srvID = StringToInt(value);

                if (srvID >= 0)
                {
                    g_hServersWhiteList.Push(srvID);
                }
            }
        }
    }

    return SMCParse_Continue;
}

public SMCResult ReadConfig_EndSection(Handle smc)
{
    return SMCParse_Continue;
}

// STOCK FUNCTIONS //
stock bool DB_Connect()
{
    if (g_hDatabase)
    {
        return true;
    }

    if (g_DatabaseState == DatabaseState_Wait) // 100500 connections in a minute is bad idea..
    {
        return false;
    }

    if (g_DatabaseState != DatabaseState_Connecting)
    {
        g_DatabaseState = DatabaseState_Connecting;
        g_iConnectLock  = ++g_iSequence;
        // Connect using the "sourcebans" section, or the "default" section if "sourcebans" does not exist
        SQL_TConnect(GotDatabase, "sourcecomms", g_iConnectLock);
    }

    return false;
}

stock bool DB_Conn_Lost(Handle hndl)
{
    if (hndl == null)
    {
        if (g_hDatabase != null)
        {
            LogError("Lost connection to DB. Reconnect after delay.");
            delete g_hDatabase;
            g_hDatabase = null;
        }

        if (g_DatabaseState != DatabaseState_Wait)
        {
            g_DatabaseState = DatabaseState_Wait;
            CreateTimer(RetryTime, Timer_StopWait, _, TIMER_FLAG_NO_MAPCHANGE);
        }

        return true;
    }
    else
    {
        return false;
    }
}

stock void InitializeBackupDB()
{
    char error[255];
    SQLiteDB = SQLite_UseDatabase("sourcecomms-queue", error, sizeof(error));

    if (SQLiteDB == null)
    {
        SetFailState(error);
    }

    SQL_TQuery(SQLiteDB, Query_ErrorCheck,
       "CREATE TABLE IF NOT EXISTS queue2 (\
            id INTEGER PRIMARY KEY, \
            steam_id TEXT, \
            time INTEGER, \
            start_time INTEGER, \
            reason TEXT, \
            name TEXT, \
            admin_id TEXT, \
            admin_ip TEXT, \
            type INTEGER)");
}

stock void CreateBlock(int client, int targetId = 0, int length = -1, int type, const char[] sReason = "", const char[] sArgs = "")
{
    int[] target_list = new int[MaxClients + 1];
    int target_count;
    bool tn_is_ml;
    char target_name[MAX_NAME_LENGTH];
    char reason[256];
    bool skipped = false;

    // checking args
    if (targetId)
    {
        target_list[0] = targetId;
        target_count = 1;
        tn_is_ml = false;
        strcopy(target_name, sizeof(target_name), g_sName[targetId]);
        strcopy(reason,      sizeof(reason),      sReason);
    }
    else if (strlen(sArgs))
    {
        char sArg[3][192];

        if (ExplodeString(sArgs, "\"", sArg, 3, 192, true) == 3 && strlen(sArg[0]) == 0)    // exploding by quotes
        {
            char sTempArg[2][192];
            TrimString(sArg[2]);
            sArg[0] = sArg[1];        // target name
            ExplodeString(sArg[2], " ", sTempArg, 2, 192, true); // get length and reason
            sArg[1] = sTempArg[0];    // lenght
            sArg[2] = sTempArg[1];    // reason
        }
        else
        {
            ExplodeString(sArgs, " ", sArg, 3, 192, true);    // exploding by spaces
        }

        // Get the target, find target returns a message on failure so we do not
        if ((target_count = ProcessTargetString(sArg[0], client, target_list, MaxClients + 1, COMMAND_FILTER_NO_BOTS, target_name, sizeof(target_name), tn_is_ml)) <= 0)
        {
            ReplyToTargetError(client, target_count);
            return;
        }

        // Get the block length
        if (!StringToIntEx(sArg[1], length))    // not valid number in second argument
        {
            length = DefaultTime;
            Format(reason, sizeof(reason), "%s %s", sArg[1], sArg[2]);
        }
        else
        {
            strcopy(reason, sizeof(reason), sArg[2]);
        }

        // Strip spaces and quotes from reason
        TrimString(reason);
        StripQuotes(reason);

        if (!IsAllowedBlockLength(client, length, target_count))
        {
            ReplyToCommand(client, "%s%t", PREFIX, "no access");
            return;
        }
    }
    else
    {
        return;
    }

    int admImmunity = GetAdmImmunity(client);
    char adminAuth[64];

    if (client && IsClientInGame(client))
    {
        GetClientAuthId(client, AuthId_Steam2, adminAuth, sizeof(adminAuth), true);
    }
    else
    {
        // setup dummy adminAuth and adminIp for server
        strcopy(adminAuth, sizeof(adminAuth), "STEAM_0:0:00000000000");
    }

    for (int i = 0; i < target_count; i++)
    {
        int target = target_list[i];

        if (!g_bPlayerStatus[target])
        {
            // The target has not been blocks verify. It must be completed before you can block anyone.
            ReplyToCommand(client, "%s%t", PREFIX, "Player Comms Not Verified");
            skipped = true;
            continue; // skip
        }

        switch (type)
        {
            case TYPE_MUTE:
            {
                if (!BaseComm_IsClientMuted(target))
                {
                    PerformMute(target, _, length, g_sName[client], adminAuth, admImmunity, reason);
                    LogAction(client, target, "\"%L\" muted \"%L\" (minutes \"%d\") (reason \"%s\")", client, target, length, reason);
                }
                else
                {
                    ReplyToCommand(client, "%s%t", PREFIX, "Player already muted", g_sName[target]);
                    skipped = true;
                    continue;
                }
            }
            //-------------------------------------------------------------------------------------------------
            case TYPE_GAG:
            {
                if (!BaseComm_IsClientGagged(target))
                {
                    PerformGag(target, _, length, g_sName[client], adminAuth, admImmunity, reason);
                    LogAction(client, target, "\"%L\" gagged \"%L\" (minutes \"%d\") (reason \"%s\")", client, target, length, reason);
                }
                else
                {
                    ReplyToCommand(client, "%s%t", PREFIX, "Player already gagged", g_sName[target]);
                    skipped = true;
                    continue;
                }
            }
            //-------------------------------------------------------------------------------------------------
            case TYPE_SILENCE:
            {
                if (!BaseComm_IsClientGagged(target) && !BaseComm_IsClientMuted(target))
                {
                    PerformMute(target, _, length, g_sName[client], adminAuth, admImmunity, reason);
                    PerformGag(target,  _, length, g_sName[client], adminAuth, admImmunity, reason);
                    LogAction(client, target, "\"%L\" silenced \"%L\" (minutes \"%d\") (reason \"%s\")", client, target, length, reason);
                }
                else
                {
                    ReplyToCommand(client, "%s%t", PREFIX, "Player already silenced", g_sName[target]);
                    skipped = true;
                    continue;
                }
            }
        }
    }

    if (target_count == 1 && !skipped)
    {
        SavePunishment(client, target_list[0], type, length, reason);
    }

    if (target_count > 1 || !skipped)
    {
        ShowActivityToServer(client, type, length, reason, target_name, tn_is_ml);
    }

    return;
}

stock void ProcessUnBlock(int client, int targetId = 0, int type, char[] sReason = "", const char[] sArgs = "")
{
    int[] target_list = new int[MaxClients + 1];
    int target_count;
    bool tn_is_ml;
    char target_name[MAX_NAME_LENGTH];
    char reason[256];

    if (targetId)
    {
        target_list[0] = targetId;
        target_count = 1;
        tn_is_ml = false;
        strcopy(target_name, sizeof(target_name), g_sName[targetId]);
        strcopy(reason,      sizeof(reason),      sReason);
    }
    else
    {
        char sBuffer[256];
        char sArg[3][192];
        GetCmdArgString(sBuffer, sizeof(sBuffer));

        if (ExplodeString(sBuffer, "\"", sArg, 3, 192, true) == 3 && strlen(sArg[0]) == 0)
        {
            TrimString(sArg[2]);
            sArg[0] = sArg[1];  // target name
            sArg[1] = sArg[2];  // reason; sArg[2] - not in use
        }
        else
        {
            ExplodeString(sBuffer, " ", sArg, 2, 192, true);
        }

        strcopy(reason, sizeof(reason), sArg[1]);
        // Strip spaces and quotes from reason
        TrimString(reason);
        StripQuotes(reason);

        // Get the target, find target returns a message on failure so we do not
        if ((target_count = ProcessTargetString(sArg[0], client, target_list, MaxClients + 1, COMMAND_FILTER_NO_BOTS, target_name, sizeof(target_name), tn_is_ml)) <= 0)
        {
            ReplyToTargetError(client, target_count);
            return;
        }
    }

    char adminAuth[64];
    char targetAuth[64];

    if (client && IsClientInGame(client))
    {
        GetClientAuthId(client, AuthId_Steam2, adminAuth, sizeof(adminAuth), true);
    }
    else
    {
        // setup dummy adminAuth and adminIp for server
        strcopy(adminAuth, sizeof(adminAuth), "STEAM_0:0:00000000000");
    }

    if (target_count > 1)
    {
        for (int i = 0; i < target_count; i++)
        {
            int target = target_list[i];

            if (IsClientInGame(target))
            {
                GetClientAuthId(target, AuthId_Steam2, targetAuth, sizeof(targetAuth), true);
            }
            else
            {
                continue;
            }

            DataPack dataPack = new DataPack();
            dataPack.WriteCell(GetClientUserId2(client));
            dataPack.WriteCell(GetClientUserId(target));
            dataPack.WriteCell(type);
            dataPack.WriteString(adminAuth);
            dataPack.WriteString(targetAuth);    // not in use in this case
            dataPack.WriteString(reason);
            TempUnBlock(dataPack);
        }

        ShowActivityToServer(client, type + TYPE_TEMP_SHIFT, _, _, target_name, tn_is_ml);
    }
    else
    {
        char typeWHERE[100];
        bool dontCheckDB = false;
        int target = target_list[0];

        if (IsClientInGame(target))
        {
            GetClientAuthId(target, AuthId_Steam2, targetAuth, sizeof(targetAuth), true);
        }
        else
        {
            return;
        }

        switch (type)
        {
            case TYPE_UNMUTE:
            {
                if (!BaseComm_IsClientMuted(target))
                {
                    ReplyToCommand(client, "%s%t", PREFIX, "Player not muted");
                    return;
                }
                else
                {
                    FormatEx(typeWHERE, sizeof(typeWHERE), "c.type = '%d'", TYPE_MUTE);

                    if (g_MuteType[target] == bSess)
                    {
                        dontCheckDB = true;
                    }
                }
            }
            //-------------------------------------------------------------------------------------------------
            case TYPE_UNGAG:
            {
                if (!BaseComm_IsClientGagged(target))
                {
                    ReplyToCommand(client, "%s%t", PREFIX, "Player not gagged");
                    return;
                }
                else
                {
                    FormatEx(typeWHERE, sizeof(typeWHERE), "c.type = '%d'", TYPE_GAG);

                    if (g_GagType[target] == bSess)
                    {
                        dontCheckDB = true;
                    }
                }
            }
            //-------------------------------------------------------------------------------------------------
            case TYPE_UNSILENCE:
            {
                if (!BaseComm_IsClientMuted(target) || !BaseComm_IsClientGagged(target))
                {
                    ReplyToCommand(client, "%s%t", PREFIX, "Player not silenced");
                    return;
                }
                else
                {
                    FormatEx(typeWHERE, sizeof(typeWHERE), "(c.type = '%d' OR c.type = '%d')", TYPE_MUTE, TYPE_GAG);

                    if (g_MuteType[target] == bSess && g_GagType[target] == bSess)
                    {
                        dontCheckDB = true;
                    }
                }
            }
        }

        // Pack everything into a data pack so we can retain it
        DataPack dataPack = new DataPack();
        dataPack.WriteCell(GetClientUserId2(client));
        dataPack.WriteCell(GetClientUserId(target));
        dataPack.WriteCell(type);
        dataPack.WriteString(adminAuth);
        dataPack.WriteString(targetAuth);
        dataPack.WriteString(reason);

        // Check current player status. If player has temporary punishment - don't get info from DB
        if (!dontCheckDB && DB_Connect())
        {
            char sAdminAuthEscaped[sizeof(adminAuth) * 2 + 1];
            char sAdminAuthYZEscaped[sizeof(adminAuth) * 2 + 1];
            char sTargetAuthEscaped[sizeof(targetAuth) * 2 + 1];
            char sTargetAuthYZEscaped[sizeof(targetAuth) * 2 + 1];

            SQL_EscapeString(g_hDatabase, adminAuth,     sAdminAuthEscaped,    sizeof(sAdminAuthEscaped));
            SQL_EscapeString(g_hDatabase, adminAuth[8],  sAdminAuthYZEscaped,  sizeof(sAdminAuthYZEscaped));
            SQL_EscapeString(g_hDatabase, targetAuth,    sTargetAuthEscaped,   sizeof(sTargetAuthEscaped));
            SQL_EscapeString(g_hDatabase, targetAuth[8], sTargetAuthYZEscaped, sizeof(sTargetAuthYZEscaped));

            char query[4096];
            Format(query, sizeof(query),
               "SELECT      c.bid, \
                            IFNULL((SELECT aid FROM %s_admins WHERE authid = '%s' OR authid REGEXP '^STEAM_[0-9]:%s$'), '0') as iaid, \
                            c.aid, \
                            IF (a.immunity>=g.immunity, a.immunity, IFNULL(g.immunity, 0)) as immunity, \
                            c.type \
                FROM        %s_comms     AS c \
                LEFT JOIN   %s_admins    AS a ON a.aid = c.aid \
                LEFT JOIN   %s_srvgroups AS g ON g.name = a.srv_group \
                WHERE       RemoveType IS NULL \
                              AND (c.authid = '%s' OR c.authid REGEXP '^STEAM_[0-9]:%s$') \
                              AND (length = '0' OR ends > UNIX_TIMESTAMP()) \
                              AND %s",
                DatabasePrefix, sAdminAuthEscaped, sAdminAuthYZEscaped, DatabasePrefix, DatabasePrefix, DatabasePrefix, sTargetAuthEscaped, sTargetAuthYZEscaped, typeWHERE);

            SQL_TQuery(g_hDatabase, Query_UnBlockSelect, query, dataPack);
        }
        else
        {
            if (TempUnBlock(dataPack))
            {
                ShowActivityToServer(client, type + TYPE_TEMP_SHIFT, _, _, g_sName[target], _);
            }
        }
    }
}

stock bool TempUnBlock(DataPack data)
{
    char adminAuth[30];
    char targetAuth[30];
    char reason[256];
    data.Reset();
    int adminUserID  = data.ReadCell();
    int targetUserID = data.ReadCell();
    int type         = data.ReadCell();
    data.ReadString(adminAuth,  sizeof(adminAuth));
    data.ReadString(targetAuth, sizeof(targetAuth));
    data.ReadString(reason,     sizeof(reason));
    delete data; // Need to close datapack

    int admin  = GetClientOfUserId(adminUserID);
    int target = GetClientOfUserId(targetUserID);

    if (!target)
    {
        return false; // target has gone away
    }

    int AdmImmunity = GetAdmImmunity(admin);
    bool AdmImCheck = (DisUBImCheck == 0 && ((type == TYPE_MUTE && AdmImmunity > g_iMuteLevel[target]) || (type == TYPE_GAG && AdmImmunity > g_iGagLevel[target]) || (type == TYPE_SILENCE && AdmImmunity > g_iMuteLevel[target] && AdmImmunity > g_iGagLevel[target])));

    // Check access for unblock without db changes (temporary unblock)
    bool bHasPermission = (!admin && StrEqual(adminAuth, "STEAM_0:0:00000000000")) || AdmHasFlag(admin) || AdmImCheck;
    // can, if we are console or have special flag. else - deep checking by issuer authid
    if (!bHasPermission)
    {
        switch (type)
        {
            case TYPE_UNMUTE:
            {
                bHasPermission = StrEqual(adminAuth, g_sMuteAdminAuth[target]);
            }
            case TYPE_UNGAG:
            {
                bHasPermission = StrEqual(adminAuth, g_sGagAdminAuth[target]);
            }
            case TYPE_UNSILENCE:
            {
                bHasPermission = StrEqual(adminAuth, g_sMuteAdminAuth[target]) && StrEqual(adminAuth, g_sGagAdminAuth[target]);
            }
        }
    }

    if (bHasPermission)
    {
        switch (type)
        {
            case TYPE_UNMUTE:
            {
                PerformUnMute(target);
                LogAction(admin, target, "\"%L\" temporary unmuted \"%L\" (reason \"%s\")", admin, target, reason);
            }
            //-------------------------------------------------------------------------------------------------
            case TYPE_UNGAG:
            {
                PerformUnGag(target);
                LogAction(admin, target, "\"%L\" temporary ungagged \"%L\" (reason \"%s\")", admin, target, reason);
            }
            //-------------------------------------------------------------------------------------------------
            case TYPE_UNSILENCE:
            {
                PerformUnMute(target);
                PerformUnGag(target);
                LogAction(admin, target, "\"%L\" temporary unsilenced \"%L\" (reason \"%s\")", admin, target, reason);
            }
            default:
            {
                return false;
            }
        }

        return true;
    }
    else
    {
        if (admin && IsClientInGame(admin))
        {
            PrintToChat(admin, "%s%t", PREFIX, "No db error unlock perm");
            PrintToConsole(admin, "%s%t", PREFIX, "No db error unlock perm");
        }

        return false;
    }
}

stock void InsertTempBlock(int length, int type, const char[] name, const char[] auth, const char[] reason, const char[] adminAuth, const char[] adminIp)
{
    LogMessage("Saving punishment for %s into queue", auth);

    char banName[MAX_NAME_LENGTH * 2 + 1];
    char banReason[256 * 2 + 1];
    char sAuthEscaped[64 * 2 + 1];
    char sAdminAuthEscaped[64 * 2 + 1];
    char sQuery[4096];
    char sQueryVal[2048];
    char sQueryMute[2048];
    char sQueryGag[2048];

    // escaping everything
    SQL_EscapeString(SQLiteDB, name,      banName,           sizeof(banName));
    SQL_EscapeString(SQLiteDB, reason,    banReason,         sizeof(banReason));
    SQL_EscapeString(SQLiteDB, auth,      sAuthEscaped,      sizeof(sAuthEscaped));
    SQL_EscapeString(SQLiteDB, adminAuth, sAdminAuthEscaped, sizeof(sAdminAuthEscaped));

    // steam_id time start_time reason name admin_id admin_ip
    FormatEx(sQueryVal, sizeof(sQueryVal),
        "'%s', %d, %d, '%s', '%s', '%s', '%s'",
        sAuthEscaped, length, GetTime(), banReason, banName, sAdminAuthEscaped, adminIp);

    if (type == TYPE_MUTE || type == TYPE_SILENCE)
    {
        FormatEx(sQueryMute, sizeof(sQueryMute), "(%s, %d)", sQueryVal, TYPE_MUTE);
    }

    if (type == TYPE_GAG || type == TYPE_SILENCE)
    {
        FormatEx(sQueryGag, sizeof(sQueryGag), "(%s, %d)", sQueryVal, TYPE_GAG);
    }

    FormatEx(sQuery, sizeof(sQuery),
        "INSERT INTO queue2 (steam_id, time, start_time, reason, name, admin_id, admin_ip, type) VALUES %s%s%s",
        sQueryMute, type == TYPE_SILENCE ? ", " : "", sQueryGag);

    SQL_TQuery(SQLiteDB, Query_ErrorCheck, sQuery);
}

stock void ServerInfo()
{
    int pieces[4];
    int longip = CvarHostIp.IntValue;
    pieces[0] = (longip >> 24) & 0x000000FF;
    pieces[1] = (longip >> 16) & 0x000000FF;
    pieces[2] = (longip >> 8) & 0x000000FF;
    pieces[3] = longip & 0x000000FF;
    FormatEx(ServerIp, sizeof(ServerIp), "%d.%d.%d.%d", pieces[0], pieces[1], pieces[2], pieces[3]);
    CvarPort.GetString(ServerPort, sizeof(ServerPort));
}

stock void ReadConfig()
{
    InitializeConfigParser();

    if (ConfigParser == null)
    {
        return;
    }

    char ConfigFile1[PLATFORM_MAX_PATH];
    char ConfigFile2[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, ConfigFile1, sizeof(ConfigFile1), "configs/sourcebans/sourcebans.cfg");
    BuildPath(Path_SM, ConfigFile2, sizeof(ConfigFile2), "configs/sourcebans/sourcecomms.cfg");

    if (FileExists(ConfigFile1))
    {
        PrintToServer("%sLoading configs/sourcebans/sourcebans.cfg config file", PREFIX);
        InternalReadConfig(ConfigFile1);
    }
    else
    {
        SetFailState("FATAL *** ERROR *** can't find %s", ConfigFile1);
    }
    if (FileExists(ConfigFile2))
    {
        PrintToServer("%sLoading configs/sourcebans/sourcecomms.cfg config file", PREFIX);
        iNumReasons = 0;
        iNumTimes = 0;
        InternalReadConfig(ConfigFile2);

        if (iNumReasons)
        {
            iNumReasons--;
        }

        if (iNumTimes)
        {
            iNumTimes--;
        }

        if (serverID == 0)
        {
            LogError("You must set valid `ServerID` value in sourcebans.cfg!");

            if (ConfigWhiteListOnly)
            {
                LogError("ServersWhiteList feature disabled!");
                ConfigWhiteListOnly = 0;
            }
        }
    }
    else
    {
        SetFailState("FATAL *** ERROR *** can't find %s", ConfigFile2);
    }
}

// some more
void AdminMenu_GetPunishPhrase(int client, int target, char[] name, int length)
{
    char Buffer[192];

    if (g_MuteType[target] > bNot && g_GagType[target] > bNot)
    {
        Format(Buffer, sizeof(Buffer), "%T", "AdminMenu_Display_Silenced", client, name);
    }
    else if (g_MuteType[target] > bNot)
    {
        Format(Buffer, sizeof(Buffer), "%T", "AdminMenu_Display_Muted", client, name);
    }
    else if (g_GagType[target] > bNot)
    {
        Format(Buffer, sizeof(Buffer), "%T", "AdminMenu_Display_Gagged", client, name);
    }
    else
    {
        Format(Buffer, sizeof(Buffer), "%T", "AdminMenu_Display_None", client, name);
    }

    strcopy(name, length, Buffer);
}

bool Bool_ValidMenuTarget(int client, int target)
{
    if (target <= 0)
    {
        if (client)
        {
            PrintToChat(client, "%s%t", PREFIX, "AdminMenu_Not_Available");
        }
        else
        {
            ReplyToCommand(client, "%s%t", PREFIX, "AdminMenu_Not_Available");
        }

        return false;
    }
    else if (!CanUserTarget(client, target))
    {
        if (client)
        {
            PrintToChat(client, "%s%t", PREFIX, "Command_Target_Not_Targetable");
        }
        else
        {
            ReplyToCommand(client, "%s%t", PREFIX, "Command_Target_Not_Targetable");
        }

        return false;
    }

    return true;
}

stock bool IsAllowedBlockLength(int admin, int length, int target_count = 1)
{
    if (target_count == 1)
    {
        if (!ConfigMaxLength)
        {
            return true;    // Restriction disabled
        }

        if (!admin)
        {
            return true;    // all allowed for console
        }

        if (AdmHasFlag(admin))
        {
            return true;    // all allowed for admins with special flag
        }

        if (!length || length > ConfigMaxLength)
        {
            return false;
        }
        else
        {
            return true;
        }
    }
    else
    {
        if (length < 0)
        {
            return true;    // session punishments allowed for mass-tergeting
        }

        if (!length)
        {
            return false;
        }

        if (length > 30)
        {
            return false;
        }

        if (length > DefaultTime)
        {
            return false;
        }
        else
        {
            return true;
        }
    }
}

stock bool AdmHasFlag(int admin)
{
    return admin && CheckCommandAccess(admin, "", ADMFLAG_CUSTOM2, true);
}

stock int GetAdmImmunity(int admin)
{
    if (admin > 0 && GetUserAdmin(admin) != INVALID_ADMIN_ID)
    {
        return GetAdminImmunityLevel(GetUserAdmin(admin));
    }
    else
    {
        return 0;
    }
}

stock int GetClientUserId2(int client)
{
    if (client)
    {
        return GetClientUserId(client);
    }
    else
    {
        return 0;    // for CONSOLE
    }
}

stock void ForcePlayersRecheck()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsClientAuthorized(i) && !IsFakeClient(i) && g_hPlayerRecheck[i] == null)
        {
            g_hPlayerRecheck[i] = CreateTimer(float(i), ClientRecheck, GetClientUserId(i));
        }
    }
}

stock bool NotApplyToThisServer(int srvID)
{
    if (ConfigWhiteListOnly && g_hServersWhiteList.FindValue(srvID) == -1)
    {
        return true;
    }
    else
    {
        return false;
    }
}

stock void MarkClientAsUnMuted(int target)
{
    g_MuteType[target]          = bNot;
    g_iMuteTime[target]         = 0;
    g_iMuteLength[target]       = 0;
    g_iMuteLevel[target]        = -1;
    g_sMuteAdminName[target][0] = '\0';
    g_sMuteReason[target][0]    = '\0';
    g_sMuteAdminAuth[target][0] = '\0';
}

stock void MarkClientAsUnGagged(int target)
{
    g_GagType[target]          = bNot;
    g_iGagTime[target]         = 0;
    g_iGagLength[target]       = 0;
    g_iGagLevel[target]        = -1;
    g_sGagAdminName[target][0] = '\0';
    g_sGagReason[target][0]    = '\0';
    g_sGagAdminAuth[target][0] = '\0';
}

stock void MarkClientAsMuted(int target, int time = NOW, int length = -1, const char[] adminName = "CONSOLE", const char[] adminAuth = "STEAM_0:0:00000000000", int adminImmunity = 0, const char[] reason = "")
{
    if (time)
    {
        g_iMuteTime[target] = time;
    }
    else
    {
        g_iMuteTime[target] = GetTime();
    }

    g_iMuteLength[target] = length;
    g_iMuteLevel[target]  = adminImmunity ? adminImmunity : ConsoleImmunity;
    strcopy(g_sMuteAdminName[target], sizeof(g_sMuteAdminName[]), adminName);
    strcopy(g_sMuteReason[target],    sizeof(g_sMuteReason[]),    reason);
    strcopy(g_sMuteAdminAuth[target], sizeof(g_sMuteAdminAuth[]), adminAuth);

    if (length > 0)
    {
        g_MuteType[target] = bTime;
    }
    else if (length == 0)
    {
        g_MuteType[target] = bPerm;
    }
    else
    {
        g_MuteType[target] = bSess;
    }
}

stock void MarkClientAsGagged(int target, int time = NOW, int length = -1, const char[] adminName = "CONSOLE", const char[] adminAuth = "STEAM_0:0:00000000000", int adminImmunity = 0, const char[] reason = "")
{
    if (time)
    {
        g_iGagTime[target] = time;
    }
    else
    {
        g_iGagTime[target] = GetTime();
    }

    g_iGagLength[target] = length;
    g_iGagLevel[target]  = adminImmunity ? adminImmunity : ConsoleImmunity;
    strcopy(g_sGagAdminName[target], sizeof(g_sGagAdminName[]), adminName);
    strcopy(g_sGagReason[target],    sizeof(g_sGagReason[]),    reason);
    strcopy(g_sGagAdminAuth[target], sizeof(g_sGagAdminAuth[]), adminAuth);

    if (length > 0)
    {
        g_GagType[target] = bTime;
    }
    else if (length == 0)
    {
        g_GagType[target] = bPerm;
    }
    else
    {
        g_GagType[target] = bSess;
    }
}

stock void CloseMuteExpireTimer(int target)
{
    if (g_hMuteExpireTimer[target] != null && CloseHandle(g_hMuteExpireTimer[target]))
    {
        g_hMuteExpireTimer[target] = null;
    }
}

stock void CloseGagExpireTimer(int target)
{
    if (g_hGagExpireTimer[target] != null && CloseHandle(g_hGagExpireTimer[target]))
    {
        g_hGagExpireTimer[target] = null;
    }
}

stock void CreateMuteExpireTimer(int target, int remainingTime = 0)
{
    if (g_iMuteLength[target] > 0)
    {
        if (remainingTime)
        {
            g_hMuteExpireTimer[target] = CreateTimer(float(remainingTime), Timer_MuteExpire, GetClientUserId(target), TIMER_FLAG_NO_MAPCHANGE);
        }
        else
        {
            g_hMuteExpireTimer[target] = CreateTimer(float(g_iMuteLength[target] * 60), Timer_MuteExpire, GetClientUserId(target), TIMER_FLAG_NO_MAPCHANGE);
        }
    }
}

stock void CreateGagExpireTimer(int target, int remainingTime = 0)
{
    if (g_iGagLength[target] > 0)
    {
        if (remainingTime)
        {
            g_hGagExpireTimer[target] = CreateTimer(float(remainingTime), Timer_GagExpire, GetClientUserId(target), TIMER_FLAG_NO_MAPCHANGE);
        }
        else
        {
            g_hGagExpireTimer[target] = CreateTimer(float(g_iGagLength[target] * 60), Timer_GagExpire, GetClientUserId(target), TIMER_FLAG_NO_MAPCHANGE);
        }
    }
}

stock void PerformUnMute(int target)
{
    MarkClientAsUnMuted(target);
    BaseComm_SetClientMute(target, false);
    CloseMuteExpireTimer(target);
}

stock void PerformUnGag(int target)
{
    MarkClientAsUnGagged(target);
    BaseComm_SetClientGag(target, false);
    CloseGagExpireTimer(target);
}

stock void PerformMute(int target, int time = NOW, int length = -1, const char[] adminName = "CONSOLE", const char[] adminAuth = "STEAM_0:0:00000000000", int adminImmunity = 0, const char[] reason = "", int remaining_time = 0)
{
    MarkClientAsMuted(target, time, length, adminName, adminAuth, adminImmunity, reason);
    BaseComm_SetClientMute(target, true);
    CreateMuteExpireTimer(target, remaining_time);
}

stock void PerformGag(int target, int time = NOW, int length = -1, const char[] adminName = "CONSOLE", const char[] adminAuth = "STEAM_0:0:00000000000", int adminImmunity = 0, const char[] reason = "", int remaining_time = 0)
{
    MarkClientAsGagged(target, time, length, adminName, adminAuth, adminImmunity, reason);
    BaseComm_SetClientGag(target, true);
    CreateGagExpireTimer(target, remaining_time);
}

stock void SavePunishment(int admin = 0, int target, int type, int length = -1 , const char[] reason = "")
{
    if (type < TYPE_MUTE || type > TYPE_SILENCE)
    {
        return;
    }

    // target information
    char targetAuth[64];

    if (IsClientInGame(target))
    {
        GetClientAuthId(target, AuthId_Steam2, targetAuth, sizeof(targetAuth), true);
    }
    else
    {
        return;
    }

    char adminIp[24];
    char adminAuth[64];

    if (admin && IsClientInGame(admin))
    {
        GetClientIP(admin, adminIp, sizeof(adminIp));
        GetClientAuthId(admin, AuthId_Steam2, adminAuth, sizeof(adminAuth), true);
    }
    else
    {
        // setup dummy adminAuth and adminIp for server
        strcopy(adminAuth, sizeof(adminAuth), "STEAM_0:0:00000000000");
        strcopy(adminIp, sizeof(adminIp), ServerIp);
    }

    char sName[MAX_NAME_LENGTH];
    strcopy(sName, sizeof(sName), g_sName[target]);

    if (DB_Connect())
    {
        // Accepts length in minutes, writes to db in seconds! In all over places in plugin - length is in minutes.
        char banName[MAX_NAME_LENGTH * 2 + 1];
        char banReason[256 * 2 + 1];
        char sAuthidEscaped[64 * 2 + 1];
        char sAdminAuthIdEscaped[64 * 2 + 1];
        char sAdminAuthIdYZEscaped[64 * 2 + 1];
        char sQuery[4096];
        char sQueryAdm[512];
        char sQueryVal[1024];
        char sQueryMute[1024];
        char sQueryGag[1024];

        // escaping everything
        SQL_EscapeString(g_hDatabase, sName,        banName,               sizeof(banName));
        SQL_EscapeString(g_hDatabase, reason,       banReason,             sizeof(banReason));
        SQL_EscapeString(g_hDatabase, targetAuth,   sAuthidEscaped,        sizeof(sAuthidEscaped));
        SQL_EscapeString(g_hDatabase, adminAuth,    sAdminAuthIdEscaped,   sizeof(sAdminAuthIdEscaped));
        SQL_EscapeString(g_hDatabase, adminAuth[8], sAdminAuthIdYZEscaped, sizeof(sAdminAuthIdYZEscaped));

        // bid    authid    name    created ends lenght reason aid adminip    sid    removedBy removedType removedon type ureason
        FormatEx(sQueryAdm, sizeof(sQueryAdm),
            "IFNULL((SELECT aid FROM %s_admins WHERE authid = '%s' OR authid REGEXP '^STEAM_[0-9]:%s$'), 0)",
            DatabasePrefix, sAdminAuthIdEscaped, sAdminAuthIdYZEscaped);

        // authid name, created, ends, length, reason, aid, adminIp, sid
        FormatEx(sQueryVal, sizeof(sQueryVal),
            "'%s', '%s', '%s', UNIX_TIMESTAMP(), UNIX_TIMESTAMP() + %d, %d, '%s', %s, '%s', %d",
            sAuthidEscaped, sAuthidEscaped[8], banName, length*60, length*60, banReason, sQueryAdm, adminIp, serverID);

        if (type == TYPE_MUTE || type == TYPE_SILENCE)
        {
            FormatEx(sQueryMute, sizeof(sQueryMute), "(%s, %d)", sQueryVal, TYPE_MUTE);
        }

        if (type == TYPE_GAG || type == TYPE_SILENCE)
        {
            FormatEx(sQueryGag, sizeof(sQueryGag), "(%s, %d)", sQueryVal, TYPE_GAG);
        }

        // litle magic - one query for all actions (mute, gag or silence)
        FormatEx(sQuery, sizeof(sQuery),
            "INSERT INTO %s_comms (authid, uniqueId, name, created, ends, length, reason, aid, adminIp, sid, type) VALUES %s%s%s",
            DatabasePrefix, sQueryMute, type == TYPE_SILENCE ? ", " : "", sQueryGag);

        // all data cached before calling asynchronous functions
        DataPack dataPack = new DataPack();
        dataPack.WriteCell(length);
        dataPack.WriteCell(type);
        dataPack.WriteString(sName);
        dataPack.WriteString(targetAuth);
        dataPack.WriteString(reason);
        dataPack.WriteString(adminAuth);
        dataPack.WriteString(adminIp);
        SQL_TQuery(g_hDatabase, Query_AddBlockInsert, sQuery, dataPack, DBPrio_High);
    }
    else
    {
        InsertTempBlock(length, type, sName, targetAuth, reason, adminAuth, adminIp);
    }
}

stock void ShowActivityToServer(int admin, int type, int length = 0, char[] reason = "", char[] targetName, bool ml = false)
{
    char actionName[32];
    char translationName[64];

    switch (type)
    {
        case TYPE_MUTE:
        {
            if (length > 0)
            {
                strcopy(actionName, sizeof(actionName), "Muted");
            }
            else if (length == 0)
            {
                strcopy(actionName, sizeof(actionName), "Permamuted");
            }
            else    // temp block
            {
                strcopy(actionName, sizeof(actionName), "Temp muted");
            }
        }
        //-------------------------------------------------------------------------------------------------
        case TYPE_GAG:
        {
            if (length > 0)
            {
                strcopy(actionName, sizeof(actionName), "Gagged");
            }
            else if (length == 0)
            {
                strcopy(actionName, sizeof(actionName), "Permagagged");
            }
            else    //temp block
            {
                strcopy(actionName, sizeof(actionName), "Temp gagged");
            }
        }
        //-------------------------------------------------------------------------------------------------
        case TYPE_SILENCE:
        {
            if (length > 0)
            {
                strcopy(actionName, sizeof(actionName), "Silenced");
            }
            else if (length == 0)
            {
                strcopy(actionName, sizeof(actionName), "Permasilenced");
            }
            else    //temp block
            {
                strcopy(actionName, sizeof(actionName), "Temp silenced");
            }
        }
        //-------------------------------------------------------------------------------------------------
        case TYPE_UNMUTE:
        {
            strcopy(actionName, sizeof(actionName), "Unmuted");
        }
        //-------------------------------------------------------------------------------------------------
        case TYPE_UNGAG:
        {
            strcopy(actionName, sizeof(actionName), "Ungagged");
        }
        //-------------------------------------------------------------------------------------------------
        case TYPE_TEMP_UNMUTE:
        {
            strcopy(actionName, sizeof(actionName), "Temp unmuted");
        }
        //-------------------------------------------------------------------------------------------------
        case TYPE_TEMP_UNGAG:
        {
            strcopy(actionName, sizeof(actionName), "Temp ungagged");
        }
        //-------------------------------------------------------------------------------------------------
        case TYPE_TEMP_UNSILENCE:
        {
            strcopy(actionName, sizeof(actionName), "Temp unsilenced");
        }
        //-------------------------------------------------------------------------------------------------
        default:
        {
            return;
        }
    }

    Format(translationName, sizeof(translationName), "%s %s", actionName, reason[0] == '\0' ? "player" : "player reason");

    if (length > 0)
    {
        if (ml)
        {
            ShowActivity2(admin, PREFIX, "%t", translationName, targetName, length, reason);
        }
        else
        {
            ShowActivity2(admin, PREFIX, "%t", translationName, "_s", targetName, length, reason);
        }
    }
    else
    {
        if (ml)
        {
            ShowActivity2(admin, PREFIX, "%t", translationName, targetName, reason);
        }
        else
        {
            ShowActivity2(admin, PREFIX, "%t", translationName, "_s", targetName, reason);
        }
    }
}

// Natives //
public int Native_SetClientMute(Handle hPlugin, int numParams)
{
    int target = GetNativeCell(1);

    if (target < 1 || target > MaxClients)
    {
        return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", target);
    }

    if (!IsClientInGame(target))
    {
        return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", target);
    }

    bool muteState = GetNativeCell(2);
    int muteLength = GetNativeCell(3);

    if (muteState && muteLength == 0)
    {
        return ThrowNativeError(SP_ERROR_NATIVE, "Permanent mute is not allowed!");
    }

    bool bSaveToDB = GetNativeCell(4);

    if (!muteState && bSaveToDB)
    {
        return ThrowNativeError(SP_ERROR_NATIVE, "Removing punishments from DB is not allowed!");
    }

    char sReason[256];
    GetNativeString(5, sReason, sizeof(sReason));

    if (muteState)
    {
        if (g_MuteType[target] > bNot)
        {
            return false;
        }

        PerformMute(target, _, muteLength, _, _, _, sReason);

        if (bSaveToDB)
        {
            SavePunishment(_, target, TYPE_MUTE, muteLength, sReason);
        }
    }
    else
    {
        if (g_MuteType[target] == bNot)
        {
            return false;
        }

        PerformUnMute(target);
    }

    return true;
}

public int Native_SetClientGag(Handle hPlugin, int numParams)
{
    int target = GetNativeCell(1);

    if (target < 1 || target > MaxClients)
    {
        return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", target);
    }

    if (!IsClientInGame(target))
    {
        return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", target);
    }

    bool gagState = GetNativeCell(2);
    int gagLength = GetNativeCell(3);

    if (gagState && gagLength == 0)
    {
        return ThrowNativeError(SP_ERROR_NATIVE, "Permanent gag is not allowed!");
    }

    bool bSaveToDB = GetNativeCell(4);

    if (!gagState && bSaveToDB)
    {
        return ThrowNativeError(SP_ERROR_NATIVE, "Removing punishments from DB is not allowed!");
    }

    char sReason[256];
    GetNativeString(5, sReason, sizeof(sReason));

    if (gagState)
    {
        if (g_GagType[target] > bNot)
        {
            return false;
        }

        PerformGag(target, _, gagLength, _, _, _, sReason);

        if (bSaveToDB)
        {
            SavePunishment(_, target, TYPE_GAG, gagLength, sReason);
        }
    }
    else
    {
        if (g_GagType[target] == bNot)
        {
            return false;
        }

        PerformUnGag(target);
    }

    return true;
}

public int Native_GetClientMuteType(Handle hPlugin, int numParams)
{
    int target = GetNativeCell(1);

    if (target < 1 || target > MaxClients)
    {
        return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", target);
    }

    if (!IsClientInGame(target))
    {
        return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", target);
    }

    return view_as<bType>(g_MuteType[target]);
}

public int Native_GetClientGagType(Handle hPlugin, int numParams)
{
    int target = GetNativeCell(1);

    if (target < 1 || target > MaxClients)
    {
        return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", target);
    }

    if (!IsClientInGame(target))
    {
        return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", target);
    }

    return view_as<bType>(g_GagType[target]);
}

// Yarr!