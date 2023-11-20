#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>

#undef REQUIRE_PLUGIN
#include <confogl>
#define REQUIRE_PLUGIN

#define CVS_CVAR_MAXLEN 256

int CVSEntry_BlockSize;
enum struct CVSEntry {
    ConVar CVSE_ConVar;
    char   CVSE_OldVal[CVS_CVAR_MAXLEN];
    char   CVSE_NewVal[CVS_CVAR_MAXLEN];
}

ArrayList g_arrCvarSettings;
bool      g_bTrackingStarted;
bool      g_bServerShutDown;

ConVar g_cvGameMode;

public void OnPluginStart() {
    CVSEntry Tmp;
    CVSEntry_BlockSize = sizeof(Tmp);
    g_arrCvarSettings  = new ArrayList(CVSEntry_BlockSize);

    RegServerCmd("vanilla_addcvar",    Cmd_AddCvar,    "Add a ConVar to be set");
    RegServerCmd("vanilla_setcvars",   Cmd_SetCvars,   "Starts enforcing ConVars that have been added.");
    RegServerCmd("vanilla_resetcvars", Cmd_ResetCvars, "Resets enforced ConVars!");

    g_cvGameMode = FindConVar("mp_gamemode");
    g_cvGameMode.AddChangeHook(CvChg_GameMode);

    char szGameMode[16];
    g_cvGameMode.GetString(szGameMode, sizeof(szGameMode));
    LoadConfigs(szGameMode);

    AddCommandListener(ServerShutDown_Listener, "quit");
    AddCommandListener(ServerShutDown_Listener, "_restart");
}

void CvChg_GameMode(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    if (strcmp(szOldVal, szNewVal) == 0)
        return;

    ClearAllCvars();

    static char szGameMode[16];
    g_cvGameMode.GetString(szGameMode, sizeof(szGameMode));
    LoadConfigs(szGameMode);
}

Action ServerShutDown_Listener(int iClient, const char[] szCommand, int iArgs) {
    g_bServerShutDown = true;
    return Plugin_Continue;
}

public void OnPluginEnd() {
    ClearAllCvars();
}

public void LGO_OnMatchModeLoaded() {
    ClearAllCvars();
}

void LoadConfigs(const char[] szGameMode) {
    ServerCommand("exec gamemodes/plugins/%s", szGameMode);
}

Action Cmd_SetCvars(int iArgs) {
    if (g_bTrackingStarted) {
        PrintToServer("Tracking has already been started");
        return Plugin_Handled;
    }

    SetEnforcedCvars();
    g_bTrackingStarted = true;
    return Plugin_Handled;
}

Action Cmd_AddCvar(int iArgs) {
    if (iArgs != 2) {
        PrintToServer("Usage: vanilla_addcvar <cvar> <newValue>");
        return Plugin_Handled;
    }

    char szCvar[CVS_CVAR_MAXLEN];
    GetCmdArg(1, szCvar, sizeof(szCvar));

    char szNewVal[CVS_CVAR_MAXLEN];
    GetCmdArg(2, szNewVal, sizeof(szNewVal));

    AddCvar(szCvar, szNewVal);
    return Plugin_Handled;
}

Action Cmd_ResetCvars(int iArgs) {
    ClearAllCvars();
    PrintToServer("Server Cvar Tracking Information Reset!");
    return Plugin_Handled;
}

void ClearAllCvars() {
    if (g_bServerShutDown)
        return;

    g_bTrackingStarted = false;
    CVSEntry CVS_Setting;
    int iLength = g_arrCvarSettings.Length;
    if (iLength == 0)
        return;

    for (int i; i < iLength; i++) {
        g_arrCvarSettings.GetArray(i, CVS_Setting);
        CVS_Setting.CVSE_ConVar.RemoveChangeHook(CVS_ConVarChange);
        CVS_Setting.CVSE_ConVar.SetString(CVS_Setting.CVSE_OldVal);
    }

    g_arrCvarSettings.Clear();
}

void SetEnforcedCvars() {
    CVSEntry CVS_Setting;
    for (int i; i < g_arrCvarSettings.Length; i++) {
        g_arrCvarSettings.GetArray(i, CVS_Setting);
        CVS_Setting.CVSE_ConVar.SetString(CVS_Setting.CVSE_NewVal);
    }
}

void AddCvar(const char[] szConVar, const char[] szNewval) {
    if (g_bTrackingStarted) {
        return;
    }

    if (strlen(szConVar) >= CVS_CVAR_MAXLEN) {
        PrintToServer("[!] CvarSettings: Cvar Specified (%s) is longer than max cvar/value length (%d)", szConVar, CVS_CVAR_MAXLEN);
        return;
    }

    if (strlen(szNewval) >= CVS_CVAR_MAXLEN) {
        PrintToServer("[!] CvarSettings: New Value Specified (%s) is longer than max cvar/value length (%d)", szNewval, CVS_CVAR_MAXLEN);
        return;
    }

    ConVar cv = FindConVar(szConVar);
    if (cv == null) {
        PrintToServer("[!] CvarSettings: Could not find Cvar specified (%s)", szConVar);
        return;
    }

    CVSEntry CVSNewEntry;
    char szCvarBuffer[CVS_CVAR_MAXLEN];
    for (int i; i < g_arrCvarSettings.Length; i++) {
        g_arrCvarSettings.GetArray(i, CVSNewEntry);
        CVSNewEntry.CVSE_ConVar.GetName(szCvarBuffer, CVS_CVAR_MAXLEN);
        if (strcmp(szConVar, szCvarBuffer, false) == 0) {
            PrintToServer("[!] CvarSettings: Attempt to track ConVar %s, which is already being tracked.", szConVar);
            return;
        }
    }

    cv.GetString(szCvarBuffer, CVS_CVAR_MAXLEN);
    CVSNewEntry.CVSE_ConVar = cv;
    strcopy(CVSNewEntry.CVSE_OldVal, CVS_CVAR_MAXLEN, szCvarBuffer);
    strcopy(CVSNewEntry.CVSE_NewVal, CVS_CVAR_MAXLEN, szNewval);
    cv.AddChangeHook(CVS_ConVarChange);
    g_arrCvarSettings.PushArray(CVSNewEntry);
}

void CVS_ConVarChange(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    if (g_bTrackingStarted) {
        CVSEntry CVS_Setting;
        for (int i; i < g_arrCvarSettings.Length; i++) {
            g_arrCvarSettings.GetArray(i, CVS_Setting);
            if (CVS_Setting.CVSE_ConVar == cv)
                break;
        }

        if (strcmp(szNewVal, CVS_Setting.CVSE_NewVal, true) != 0)
            CVS_Setting.CVSE_ConVar.SetString(CVS_Setting.CVSE_NewVal);
    }
}