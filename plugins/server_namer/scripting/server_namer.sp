#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>

#undef REQUIRE_PLUGIN
#include <confogl>
#define REQUIRE_PLUGIN

ConVar g_cvMainName;
ConVar g_cvHostNum;
ConVar g_cvFormatCase1;
ConVar g_cvFormatCase2;
ConVar g_cvFormatCase3;

ConVar g_cvGamemode;
char   g_szGamemode[128];

ConVar g_cvDifficulty;
char   g_szDifficulty[32];

ConVar g_cvCfgName;
char   g_szCfgName[128];

ConVar g_cvPassword;
char   g_szPassword[32];

public Plugin myinfo = {
    name        = "Server namer",
    version     = "3.2",
    description = "Changes server hostname according to the current game mode",
    author      = "sheo",
    url         = "https://forums.alliedmods.net/showthread.php?p=2030557"
}

public void OnPluginStart() {
    g_cvMainName = CreateConVar(
    "sn_main_name", "Hostname", "Main server name.",
    FCVAR_NONE, false, 0.0, false, 0.0);
    g_cvMainName.AddChangeHook(CvChg_ChgFormat);

    g_cvHostNum = CreateConVar(
    "sn_host_num", "0", "Server number, usually set at lauch command line.",
    FCVAR_NONE, false, 0.0, false, 0.0);
    g_cvHostNum.AddChangeHook(CvChg_ChgFormat);

    g_cvFormatCase1 = CreateConVar(
    "sn_hostname_format1", "{hostname} #{servernum} -> {gamemode}{cw}", "Hostname format. Case: Confogl or Vanilla without difficulty levels, such as Versus.",
    FCVAR_NONE, false, 0.0, false, 0.0);
    g_cvFormatCase1.AddChangeHook(CvChg_ChgFormat);

    g_cvFormatCase2 = CreateConVar(
    "sn_hostname_format2", "{hostname} #{servernum} -> {gamemode} ({difficulty}){cw}", "Hostname format. Case: Vanilla with difficulty levels, such as Campaign.",
    FCVAR_NONE, false, 0.0, false, 0.0);
    g_cvFormatCase2.AddChangeHook(CvChg_ChgFormat);

    g_cvFormatCase3 = CreateConVar(
    "sn_hostname_format3", "{hostname} #{servernum}", "Hostname format. Case: empty server.",
    FCVAR_NONE, false, 0.0, false, 0.0);
    g_cvFormatCase3.AddChangeHook(CvChg_ChgFormat);

    g_cvGamemode = FindConVar("mp_gamemode");
    g_cvGamemode.GetString(g_szGamemode, sizeof(g_szGamemode));
    g_cvGamemode.AddChangeHook(CvChg_ChgMode);

    g_cvDifficulty = FindConVar("z_difficulty");
    g_cvDifficulty.GetString(g_szDifficulty, sizeof(g_szDifficulty));
    g_cvDifficulty.AddChangeHook(CvChg_ChgDiff);

    RegAdminCmd("sn_hostname", Cmd_Hostname, ADMFLAG_KICK);
}

public void OnAllPluginsLoaded() {
    g_cvCfgName = FindConVar("l4d_ready_cfg_name");
    g_cvCfgName.GetString(g_szCfgName, sizeof(g_szCfgName));
    g_cvCfgName.AddChangeHook(CvChg_CfgName);

    g_cvPassword = FindConVar("sm_server_password");
    g_cvPassword.GetString(g_szPassword, sizeof(g_szPassword));
    g_cvPassword.AddChangeHook(CvChg_Pw);
}

public void LGO_OnMatchModeLoaded() {
    IsConfoglEnabled(true, true);
    PrepareBuffer();
}

public void LGO_OnMatchModeUnloaded() {
    IsConfoglEnabled(true, false);
    PrepareBuffer();
}

public void OnMapStart() {
    PrepareBuffer();
}

public void OnConfigsExecuted() {
    PrepareBuffer();
}

public void OnClientConnected(int iClient) {
    PrepareBuffer();
}

public void OnClientDisconnect(int iClient) {
    PrepareBuffer();
}

void CvChg_ChgFormat(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    PrepareBuffer();
}

void CvChg_ChgMode(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_cvGamemode.GetString(g_szGamemode, sizeof(g_szGamemode));
    PrepareBuffer();
}

void CvChg_ChgDiff(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_cvDifficulty.GetString(g_szDifficulty, sizeof(g_szDifficulty));
    PrepareBuffer();
}

void CvChg_CfgName(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_cvCfgName.GetString(g_szCfgName, sizeof(g_szCfgName));
    PrepareBuffer();
}

void CvChg_Pw(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_cvPassword.GetString(g_szPassword, sizeof(g_szPassword));
    PrepareBuffer();
}

Action Cmd_Hostname(int iClient, int iArgs) {
    if (iArgs == 0) {
        IsCustomNameEnabled(true, false);
        PrepareBuffer();
        return Plugin_Handled;
    }

    static ConVar cv;
    if (cv == null)
        cv = FindConVar("hostname");

    static char szArg[128];
    GetCmdArg(1, szArg, sizeof(szArg));
    cv.SetString(szArg, false, false);
    IsCustomNameEnabled(true, true);
    return Plugin_Handled;
}

void PrepareBuffer() {
    if (IsCustomNameEnabled())
        return;

    static char szResult[128];

    if (ServerIsEmpty()) {
        g_cvFormatCase3.GetString(szResult, sizeof(szResult));
        SetHostname(szResult);
        return;
    }

    if (IsConfoglEnabled()) {
        g_cvFormatCase1.GetString(szResult, sizeof(szResult));
        ReplaceString(szResult, sizeof(szResult), "{gamemode}", g_szCfgName);
        SetHostname(szResult);
        return;
    }

    static KeyValues kvGamemode;
    if (kvGamemode == null) {
        kvGamemode = new KeyValues("GameMods");
        if (!kvGamemode.ImportFromFile("addons/sourcemod/configs/server_namer.txt"))
            SetFailState("configs/server_namer.txt not found!");
    }

    static char szGamemode [128];
    static char szDifficulty[32];

    kvGamemode.Rewind();

    if (kvGamemode.JumpToKey(g_szGamemode)) {
        kvGamemode.GetString("name", szGamemode, sizeof(szGamemode));

        if (kvGamemode.GetNum("difficulty") == 0) {
            g_cvFormatCase1.GetString(szResult, sizeof(szResult));
            ReplaceString(szResult, sizeof(szResult), "{gamemode}", szGamemode);
            SetHostname(szResult);
            return;
        }

        kvGamemode.Rewind();

        kvGamemode.JumpToKey("difficulties");
        kvGamemode.GetString(g_szDifficulty, szDifficulty, sizeof(szDifficulty));

        g_cvFormatCase2.GetString(szResult, sizeof(szResult));
        ReplaceString(szResult, sizeof(szResult), "{gamemode}",   szGamemode);
        ReplaceString(szResult, sizeof(szResult), "{difficulty}", szDifficulty);
        SetHostname(szResult);
        return;
    }

    g_cvFormatCase3.GetString(szResult, sizeof(szResult));
    SetHostname(szResult);
}

void SetHostname(char[] szResult) {
    static char szHostName[128];
    g_cvMainName.GetString(szHostName, sizeof(szHostName));
    ReplaceString(szResult, sizeof(szHostName), "{hostname}", szHostName);

    static char szHostNum[4];
    g_cvHostNum.GetString(szHostNum, sizeof(szHostNum));
    ReplaceString(szResult, sizeof(szHostNum), "{servernum}", szHostNum);

    static char szPw[16];
    Format(szPw, sizeof(szPw), "%s", strlen(g_szPassword) > 0 ? " [CW]" : "");
    ReplaceString(szResult, sizeof(szPw), "{cw}", szPw);

    static ConVar cv;
    if (cv == null)
        cv = FindConVar("hostname");
    cv.SetString(szResult, false, false);
}

bool ServerIsEmpty() {
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientConnected(i))
            continue;

        if (IsFakeClient(i))
            continue;

        return false;
    }

    return true;
}

bool IsConfoglEnabled(bool bSet = false, bool bVal = false) {
    static bool bCfgogl = false;
    if (bSet) bCfgogl = bVal;
    return bCfgogl;
}

bool IsCustomNameEnabled(bool bSet = false, bool bVal = false) {
    static bool bCustomName = false;
    if (bSet) bCustomName = bVal;
    return bCustomName;
}