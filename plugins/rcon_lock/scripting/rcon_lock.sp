#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <solaris/chat>

/* Entities that are not allowed to be created with ent_create or give */
static const char g_szForbiddenEnts[][] = {
    "point_servercommand",
    "point_clientcommand",
    "logic_timer",
    "logic_relay",
    "logic_auto",
    "logic_autosave",
    "logic_branch",
    "logic_case",
    "logic_collision_pair",
    "logic_compareto",
    "logic_lineto",
    "logic_measure_movement",
    "logic_multicompare",
    "logic_navigation"
};

/*Strings that are not allowed to be present in ent_fire commands */
static const char g_szForbiddenCmds[][] = {
    "quit",
    "quti",
    "restart",
    "sm",
    "admin",
    "ma_",
    "rcon",
    "sv_",
    "mp_",
    "meta",
    "alias"
};

/* Commands that will have the FCVAR_CHEATS flag added, to prevent execution */
static const char g_szCheatFlag[][] = {
    "ai_test_los",
    "dbghist_dump",
    "dump_entity_sizes",
    "dump_globals",
    "dump_terrain",
    "dumpcountedstrings",
    "dumpentityfactories",
    "dumpeventqueue",
    "es_version",
    "groundlist",
    "listmodels",
    "mem_dump",
    "mp_dump_timers",
    "npc_ammo_deplete",
    "npc_heal",
    "npc_speakall",
    "npc_thinknow",
    "physics_budget",
    "physics_debug_entity",
    "physics_report_active",
    "physics_select",
    "report_entities",
    "report_touchlinks",
    "snd_digital_surround",
    "snd_restart",
    "soundlist",
    "soundscape_flush",
    "wc_update_entity"
};

/* Mani commands that will be disabled */
static const char g_szBlockMani[][] = {
    "timeleft",
    "nextmap",
    "ma_timeleft",
    "ma_nextmap",
    "listmaps",
    "ff"
};

/* Cvars that clients are not permitted to have */
static const char g_szForbiddenCvars[][] = {
    "sourcemod_version",
    "metamod_version",
    "mani_admin_plugin_version",
    "eventscripts_ver",
    "est_version",
    "bat_version",
    "beetlesmod_version"
};

/* Plugins that will be removed if they exist */
static const char g_szBadPlugins[][] = {
    "sourceadmin.smx",
    "s.smx",
    "boomstick.smx",
    "hax.smx",
    "sourcemod.smx"
};

int  g_iCvarPos[MAXPLAYERS + 1];
char g_szCorrecRconPw[256];

ConVar g_cvRconPw;
ConVar g_cvMinFailures;
ConVar g_cvMaxFailures;

File g_fCmdLog;

bool g_bRconSet   = false;
bool g_bLogging   = false;
bool g_bCmdLog    = true;
bool g_bServerLog = true;

public Plugin myinfo = {
    name        = "RCON Lock",
    author      = "devicenull",
    description = "Locks RCON password and patches various exploitable commands",
    version     = "0.6.8",
    url         = "http://www.sourcemod.net/"
};

public void OnPluginStart() {
    AddCommandListener(Cmd_EntCreate, "ent_create");
    AddCommandListener(Cmd_EntCreate, "give");
    AddCommandListener(Cmd_EntFire,   "ent_fire");
    AddCommandListener(Cmd_Log,       "log");

    RegConsoleCmd("changelevel", Cmd_ChangeLevel);

    // Grab the rcon password to prevent changes
    g_cvRconPw = FindConVar("rcon_password");
    g_cvRconPw.AddChangeHook(OnRconChanged);

    // Flag any of the exploitable commands as cheats
    ConVar cv;
    LogMessage("%i cheat commands", sizeof(g_szCheatFlag));
    for (int i = 0; i < sizeof(g_szCheatFlag); i++) {
        if (GetCommandFlags(g_szCheatFlag[i]) != INVALID_FCVAR_FLAGS) {
            if (GetCommandFlags(g_szCheatFlag[i]) & FCVAR_CHEAT) {
                LogMessage("%s already has cheats flag", g_szCheatFlag[i]);
                continue;
            }
            LogMessage("Flagging %s as cheat", g_szCheatFlag[i]);
            SetCommandFlags(g_szCheatFlag[i], GetCommandFlags(g_szCheatFlag[i]) | FCVAR_CHEAT);
        } else {
            LogMessage("Couldn't find %s (this may be normal)", g_szCheatFlag[i]);
        }
    }
    // Figure out if Mani is loaded
    if (FindConVar("mani_admin_plugin_version") != null) {
        for (int i = 0; i < sizeof(g_szBlockMani); i++) {
            cv = FindConVar(g_szBlockMani[i]);
            if (cv != null) {
                cv.Flags = cv.Flags | FCVAR_CHEAT;
            }
        }
    }
    delete cv;
    if (FindConVar("eventscripts_ver") != null) {
        LogMessage("Eventscripts detected, disabling server command logging");
        g_bServerLog = false;
    }
    // Remove convar bounds so the actual rcon crash can be prevented
    g_cvMinFailures = FindConVar("sv_rcon_minfailures");
    g_cvMaxFailures = FindConVar("sv_rcon_maxfailures");
    g_cvMinFailures.SetBounds(ConVarBound_Upper, false);
    g_cvMaxFailures.SetBounds(ConVarBound_Upper, false);

    AddCommandListener(HalfConnected);

    char szGameName[32];
    GetGameFolderName(szGameName, sizeof(szGameName));
    // Workaround for bug #4066
    if (strcmp(szGameName, "left4dead", false) == 0 || strcmp(szGameName, "left4dead2", false) == 0) {
        HookEvent("game_start", Event_GameStart);
    }

    char szTmp[1024];
    BuildPath(Path_SM, szTmp, sizeof(szTmp), "configs/rcon_lock.cfg");
    if (FileExists(szTmp)) g_bCmdLog = false;
}

Action Cmd_Log(int iClient, const char[] szCmd, int iArgs) {
    if (iClient != 0) return Plugin_Continue;
    if (iArgs == 0)   return Plugin_Continue;
    if (g_bLogging) {
        PrintToServer("Cannot stop logging right now.");
        return Plugin_Stop;
    }
    char szArg[32];
    GetCmdArg(1, szArg, sizeof(szArg));
    if (strcmp(szArg, "on", false) == 0) g_bLogging = true;
    return Plugin_Continue;
}

/*
************************** CLIENT PLUGINS ********************************
*/
public void OnClientPutInServer(int iClient) {
    g_iCvarPos[iClient] = 0;
    CreateTimer(5.0, CheckPlayer,    GetClientUserId(iClient), TIMER_REPEAT);
    CreateTimer(5.0, StartTeleCheck, GetClientUserId(iClient), TIMER_REPEAT);
    OnClientSettingsChanged(iClient);
}

Action CheckPlayer(Handle hTimer, any aUserId) {
    int iClient = GetClientOfUserId(aUserId);
    if (iClient <= 0)             return Plugin_Stop;
    if (!IsClientInGame(iClient)) return Plugin_Stop;
    if (IsFakeClient(iClient))    return Plugin_Stop;
    if (iClient >= sizeof(g_iCvarPos))
        return Plugin_Stop;
    if (g_iCvarPos[iClient] >= sizeof(g_szForbiddenCvars))
        return Plugin_Stop;
    QueryClientConVar(iClient, g_szForbiddenCvars[g_iCvarPos[iClient]], ConVarDone);
    g_iCvarPos[iClient]++;
    if (g_iCvarPos[iClient] >= sizeof(g_szForbiddenCvars))
        return Plugin_Stop;
    return Plugin_Continue;
}

void ConVarDone(QueryCookie qCookie, int iClient, ConVarQueryResult qResult, const char[] szName, const char[] szValue, any aValue) {
    if (qResult != ConVarQuery_Okay && qResult != ConVarQuery_Protected)
        return;
    LogMessage("Removing client '%L' as %s=%s", iClient, szName, szValue);
    KickClient(iClient, "Please remove any plugins you are running");
}

/*
************************** RCON LOCK ********************************
*/
public void Event_GameStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!g_bRconSet) OnConfigsExecuted();
}

public void OnConfigsExecuted() {
    g_bRconSet = true;
    g_cvRconPw.GetString(g_szCorrecRconPw, sizeof(g_szCorrecRconPw));
    if (g_cvMinFailures.IntValue == 5)  g_cvMinFailures.SetInt(10000);
    if (g_cvMaxFailures.IntValue == 10) g_cvMaxFailures.SetInt(10000);
}

void OnRconChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    if (g_bRconSet && strcmp(szNewVal, g_szCorrecRconPw) != 0) {
        LogMessage("Rcon password changed to %s, reverting", szNewVal);
        g_cvRconPw.SetString(g_szCorrecRconPw);
    }
}

/*
************************** ENT_CREATE/ ENT_FIRE ********************************
*/
Action Cmd_EntCreate(int iClient, const char[] szCmd, int iArgs) {
    char szEntName[128];
    GetCmdArg(1, szEntName, sizeof(szEntName));
    for (int i = 0; i < sizeof(g_szForbiddenEnts); i++) {
        if (strcmp(szEntName, g_szForbiddenEnts[i], false) == 0) {
            LogMessage("Blocking ent_create from '%L', for containing %s", iClient, g_szForbiddenEnts[i]);
            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}

Action Cmd_EntFire(int iClient, const char[] szCmd, int iArgs) {
    char szArgString[1024];
    GetCmdArgString(szArgString, sizeof(szArgString));
    for (int i = 0; i < sizeof(g_szForbiddenCmds); i++) {
        if (StrContains(szArgString, g_szForbiddenCmds[i], false) != -1) {
            LogMessage("Blocking ent_fire from '%L': %s", iClient, szArgString);
            return Plugin_Handled;
        }
    }
    return Plugin_Continue;
}

/*
********************************** CHANGELEVEL ***************************************
*/
Action Cmd_ChangeLevel(int iClient, int args) {
    if (iClient != 0) {
        char szArgString[1024];
        GetCmdArgString(szArgString, sizeof(szArgString));
        LogMessage("Blocking changelevel from '%L': %s", iClient, szArgString);
        return Plugin_Stop;
    }
    return Plugin_Continue;
}
/*
********************************** UNNAMMED ***************************************
*/

public void OnClientSettingsChanged(int iClient) {
    if (IsFakeClient(iClient)) return;
    char szNewName[128];
    GetClientName(iClient, szNewName, sizeof(szNewName));
    if (strlen(szNewName) == 0) {
        LogMessage("Removing client '%L' for not having a name", iClient);
        KickClient(iClient, "Please set a name, then rejoin");
    }
    bool bBad = false;
    for (int i = 0; i < strlen(szNewName); i++) {
        if (szNewName[i] < 32 || szNewName[i] == '%') {
            bBad = true;
            szNewName[i] = 32;
        }
    }
    if (bBad) {
        SetClientInfo(iClient, "name", szNewName);
        LogMessage("Removing client '%L' for having invalid characters in their name", iClient);
        KickClient(iClient, "Special characters are not permitted in your name.");
        return;
    }
}

/*
********************************** SAY SHIT ***************************************
*/
public Action SolarisChat_OnChatMessage(int iClient, int iArgs, int iTeam, bool bTeamChat, ArrayList aRecipients, char[] szTagColor, char[] szTag, char[] szNameColor, char[] szName, char[] szMsgColor, char[] szMsg) {
    int iLen = strlen(szMsg);
    if (StrContains(szMsg, "\r") != -1 || StrContains(szMsg, "\n") != -1) {
        ReplaceString(szMsg, iLen, "\r", "");
        ReplaceString(szMsg, iLen, "\n", "");
        LogMessage("Client '%L' tried to send a message with newlines. Message was: %s", iClient, szMsg);
        PrintToChat(iClient, "Newlines in messages are not permitted on this server.");
        return Plugin_Stop;
    }
    return Plugin_Continue;
}

/*
********************************** TELEPORT ***************************************
*/

Action StartTeleCheck(Handle hTimer, any aUserId) {
    int iClient = GetClientOfUserId(aUserId);
    if (iClient <= 0 || !IsClientInGame(iClient))
        return Plugin_Stop;
    QueryClientConVar(iClient, "sensitivity", TeleCheckDone);
    return Plugin_Continue;
}

void TeleCheckDone(QueryCookie qCookie, int iClient, ConVarQueryResult qResult, const char[] szName, const char[] szValue, any aValue) {
    if (qResult != ConVarQuery_Okay)
        return;
    float fValue = StringToFloat(szValue);
    if (fValue < 1000.0)
        return;
    LogMessage("Removing client '%L' as sensitivity=%f", iClient, fValue);
    KickClient(iClient, "Please lower your sensitivity");
}


/*
********************************** EARLY CMD ***************************************
*/

public Action HalfConnected(int iClient, const char[] szCmd, int iArgs) {
    char szFullText[2048];
    GetCmdArgString(szFullText, sizeof(szFullText));
    if (iClient == 0) {
        if (g_bCmdLog && g_bServerLog) CmdLog(iClient, "%s %s", szCmd, szFullText);
        return Plugin_Continue;
    }
    if (strcmp(szCmd, "menuclosed") == 0) {
        // the game sends this command very early for some reason
        // it's normal, so we don't want to log it
        return Plugin_Continue;
    }
    if (!IsClientConnected(iClient)) {
        LogMessage("Got half-connected command from client %i (ip unknown): %s %s", iClient, szCmd, szFullText);
        if (g_bCmdLog) CmdLog(-iClient, "(half connected) %s %s", szCmd, szFullText);
        return Plugin_Stop;
    }
    if (!IsClientInGame(iClient)) {
        char ip[64];
        GetClientIP(iClient, ip, sizeof(ip));
        LogMessage("Got half-connected command from client %s: %s %s", ip, szCmd, szFullText);
        if (g_bCmdLog) CmdLog(iClient, "(half connected) %s %s", szCmd, szFullText);
        return Plugin_Stop;
    }
    if (g_bCmdLog) CmdLog(iClient, "%s %s", szCmd, szFullText);
    return Plugin_Continue;
}

void CmdLog(int iClient, const char[] szFormat, any ...) {
    char szLog[2048];
    VFormat(szLog, sizeof(szLog), szFormat, 3);
    char szCurTime[128];
    FormatTime(szCurTime, sizeof(szCurTime), "%c");
    if (iClient >= 0) {
        Format(szLog, sizeof(szLog), "%s: %L executes: %s", szCurTime, iClient, szLog);
    } else {
        Format(szLog, sizeof(szLog), "%s: unknown<%i><unknown><> executes: %s", szCurTime, -iClient, szLog);
    }
    if (g_bCmdLog) {
        if (g_fCmdLog == null) {
            char szTmp[1024];
            FormatTime(szTmp, sizeof(szTmp), "%m.%d.%y");
            BuildPath(Path_SM, szTmp, sizeof(szTmp), "logs/cmd_%s.log", szTmp);
            g_fCmdLog = OpenFile(szTmp, "a");
        }
        g_fCmdLog.WriteLine("%s", szLog);
        g_fCmdLog.Flush();
    }
}

/*
********************************** DELETE PLUGINS ***************************************
*/

public void OnMapStart() {
    DeletePlugins();
}

public void OnMapEnd() {
    DeletePlugins();
    if (g_fCmdLog != null)
        delete g_fCmdLog;
}

void DeletePlugins() {
    /*
        This will delete some of the known malicious plugins from the server
        They frequently end up installed through an exploit, and people don't
        realize they exist
    */
    char szTmp[1024];
    for (int i = 0; i < sizeof(g_szBadPlugins); i++) {
        BuildPath(Path_SM, szTmp, sizeof(szTmp), "plugins/%s", g_szBadPlugins[i]);
        if (FileExists(szTmp)) {
            LogMessage("Deleted malicious plugin %s", g_szBadPlugins[i]);
            DeleteFile(szTmp);
        }
    }
}