#pragma semicolon 1
#pragma newdecls required

#include <connecthook>

#define DATA_FILE_PATH          "data/connection_whitelist.txt"

ArrayList
    g_alSteamIdsAllowed;

ConVar
    g_cvWhitelistEnabled;

bool
    g_bWhitelistEnabled;

public Plugin myinfo =
{
    name        = "Connection Whitelist",
    author      = "0x0c",
    description = "Drop all connections except whitelisted",
    version     = "1.1.0",
    url         = "http://solaris-servers.ru/"
}

public void OnPluginStart() {
    g_alSteamIdsAllowed = new ArrayList(33);
    g_alSteamIdsAllowed.PushString("STEAM_1:1:10643239");  // me
    g_alSteamIdsAllowed.PushString("STEAM_1:0:28542350");  // elias

    g_cvWhitelistEnabled = CreateConVar("sm_whitelist_enabled", "0", "Drop all connections except whitelisted");
    g_cvWhitelistEnabled.AddChangeHook(ConVarChange_WhitelistEnabled);
    
    g_bWhitelistEnabled  = g_cvWhitelistEnabled.BoolValue;

    RegAdminCmd("sm_whitelist_add",     Cmd_WhitelistAdd,     ADMFLAG_KICK);
    RegAdminCmd("sm_whitelist_remove",  Cmd_WhitelistRemove,  ADMFLAG_KICK);
    RegAdminCmd("sm_whitelist_refresh", Cmd_WhitelistRefresh, ADMFLAG_KICK);

    ReadOrCreateDataFileWithComments();
}

void ReadOrCreateDataFileWithComments() {
    char szDataPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, szDataPath, sizeof(szDataPath), "%s", DATA_FILE_PATH);
    File file;

    if (!FileExists(szDataPath)) {
        file = OpenFile(szDataPath, "w");
        delete file;
        return;
    }

    int  iCommentAt = -1;
    char szLine[255];
    char szLineWOComment[32];
    
    file = OpenFile(szDataPath, "r");
    while (!file.EndOfFile()) {
        file.ReadLine(szLine, PLATFORM_MAX_PATH);
        iCommentAt = SplitString(szLine, "//", szLineWOComment, sizeof(szLineWOComment));

        if (~iCommentAt) {
            strcopy(szLine, sizeof(szLine), szLineWOComment);
            szLineWOComment = "";
        }

        TrimString(szLine);
        if (strlen(szLine) > 0 && g_alSteamIdsAllowed.FindString(szLine) == -1) {
            g_alSteamIdsAllowed.PushString(szLine);
        }
    }

    delete file;
}

public Action OnClientPreConnect(const char[] name, const char[] password, const char[] ip, const char[] szSteamID, char rejectReason[255]) {
    if (!g_bWhitelistEnabled) {
        return Plugin_Continue;
    }
    // this and the conditon above are not merged to avoid excessive ArrayList.FindString() calls when whitelist is disabled
    if (~g_alSteamIdsAllowed.FindString(szSteamID)) {
        return Plugin_Continue;
    }

    PrintToServer("Dropped connection from %s (%s)", name, szSteamID);
    Format(rejectReason, sizeof(rejectReason), "Sorry, you are not allowed to connect at this time.");
    return Plugin_Stop;
}

public void ConVarChange_WhitelistEnabled(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bWhitelistEnabled = cv.BoolValue;
}

public Action Cmd_WhitelistAdd(int iClient, int iArgs) {
    if (iArgs < 1) {
        ReplyToCommand(iClient, "Usage: sm_whitelist_add <STEAM_ID>");
        return Plugin_Handled;
    }
    char szSteamID[65];
    GetCmdArg(1, szSteamID, sizeof(szSteamID));
    ReplaceString(szSteamID, sizeof(szSteamID), "STEAM_0", "STEAM_1");
    if (g_alSteamIdsAllowed.FindString(szSteamID) > -1) {
        return Plugin_Handled;
    }
    g_alSteamIdsAllowed.PushString(szSteamID);

    return Plugin_Handled;
}

public Action Cmd_WhitelistRemove(int iClient, int iArgs) {
    if (iArgs < 1) {
        ReplyToCommand(iClient, "Usage: sm_whitelist_remove <STEAM_ID>");
        return Plugin_Handled;
    }
    char szSteamID[65];
    GetCmdArg(1, szSteamID, sizeof(szSteamID));
    ReplaceString(szSteamID, sizeof(szSteamID), "STEAM_0", "STEAM_1");

    int index = g_alSteamIdsAllowed.FindString(szSteamID);
    if (index > - 1) {
        g_alSteamIdsAllowed.Erase(index);
    } else {
        ReplyToCommand(iClient, "SteamID %s is not whitelisted");
    }

    return Plugin_Handled;
}

public Action Cmd_WhitelistRefresh(int iClient, int iArgs) {
    ReadOrCreateDataFileWithComments();
    return Plugin_Handled;
}
