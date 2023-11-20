#if defined __CVARSETTINGS_MODULE__
    #endinput
#endif
#define __CVARSETTINGS_MODULE__

#define CVS_CVAR_MAXLEN 256
#define CVARS_DEBUG     0

bool bServerShutDown = false;

enum struct CVSEntry {
    ConVar CVSE_ConVar;
    char   CVSE_OldVal[CVS_CVAR_MAXLEN];
    char   CVSE_NewVal[CVS_CVAR_MAXLEN];
}

int       CVSEntry_BlockSize;
ArrayList CvarSettingsArray;
bool      bTrackingStarted;

void CVS_OnModuleStart() {
    CVSEntry Tmp;
    CVSEntry_BlockSize = sizeof(Tmp);
    CvarSettingsArray  = new ArrayList(CVSEntry_BlockSize);

    RegConsoleCmd("confogl_cvarsettings", Cmd_CvarSettings, "List all ConVars being enforced by Confogl");
    RegConsoleCmd("confogl_cvardiff",     Cmd_CvarDiff,     "List any ConVars that have been changed from their initialized values");

    RegServerCmd("confogl_addcvar",    Cmd_AddCvar,    "Add a ConVar to be set by Confogl");
    RegServerCmd("confogl_setcvars",   Cmd_SetCvars,   "Starts enforcing ConVars that have been added.");
    RegServerCmd("confogl_resetcvars", Cmd_ResetCvars, "Resets enforced ConVars. Cannot be used during a match!");

    AddCommandListener(ServerShutDown_Listener, "quit");
    AddCommandListener(ServerShutDown_Listener, "_restart");
}

Action ServerShutDown_Listener(int iClient, const char[] szCommand, int iArgs) {
    bServerShutDown = true;
    return Plugin_Continue;
}

void CVS_OnModuleEnd() {
    if (!bServerShutDown)
        ClearAllCvars();
}

void CVS_OnConfigsExecuted() {
    if (bTrackingStarted)
        SetEnforcedCvars();
}

Action Cmd_SetCvars(int iArgs) {
    if (IsPluginEnabled()) {
        if (bTrackingStarted) {
            PrintToServer("Tracking has already been started");
            return Plugin_Handled;
        }

        #if CVARS_DEBUG
            LogMessage("[Confogl] CvarSettings: No longer accepting new ConVars");
        #endif

        SetEnforcedCvars();
        bTrackingStarted = true;
    }

    return Plugin_Handled;
}

Action Cmd_AddCvar(int iArgs) {
    if (iArgs != 2) {
        PrintToServer("Usage: confogl_addcvar <cvar> <newValue>");
        if (IsDebugEnabled()) {
            char szCmdBuf[MAX_NAME_LENGTH];
            GetCmdArgString(szCmdBuf, sizeof(szCmdBuf));
            LogError("[Confogl] Invalid Cvar Add: %s", szCmdBuf);
        }

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
    if (IsPluginEnabled()) {
        PrintToServer("Can't reset tracking in the middle of a match");
        return Plugin_Handled;
    }

    ClearAllCvars();
    PrintToServer("Server Cvar Tracking Information Reset!");
    return Plugin_Handled;
}

Action Cmd_CvarSettings(int iClient, int iArgs) {
    if (!IsPluginEnabled())
        return Plugin_Handled;

    if (!bTrackingStarted) {
        ReplyToCommand(iClient, "[Confogl] Cvar tracking has not been started!! THIS SHOULD NOT OCCUR DURING A MATCH!");
        return Plugin_Handled;
    }

    CVSEntry CVS_Setting;
    int  iCount = CvarSettingsArray.Length;
    char szBuffer[CVS_CVAR_MAXLEN];
    char szName  [CVS_CVAR_MAXLEN];
    ReplyToCommand(iClient, "[Confogl] Enforced Server Cvars (Total %d)", iCount);
    GetCmdArg(1, szBuffer, sizeof(szBuffer));

    int iOffset = StringToInt(szBuffer);
    if (iOffset < 0 || iOffset > iCount)
        return Plugin_Handled;

    int iTmp = iCount;
    if (iOffset + 20 < iCount)
        iTmp = iOffset + 20;

    for (int i = iOffset; i < iTmp && i < iCount; i++) {
        CvarSettingsArray.GetArray(i, CVS_Setting);
        CVS_Setting.CVSE_ConVar.GetString(szBuffer, sizeof(szBuffer));
        CVS_Setting.CVSE_ConVar.GetName(szName, sizeof(szName));
        ReplyToCommand(iClient, "[Confogl] Server Cvar: %s, Desired Value: %s, Current Value: %s", szName, CVS_Setting.CVSE_NewVal, szBuffer);
    }

    if (iOffset + 20 < iCount)
        ReplyToCommand(iClient, "[Confogl] To see more Cvars, use confogl_cvarsettings %d", iOffset + 20);

    return Plugin_Handled;
}

Action Cmd_CvarDiff(int iClient, int iArgs) {
    if (!IsPluginEnabled())
        return Plugin_Handled;

    if (!bTrackingStarted) {
        ReplyToCommand(iClient, "[Confogl] Cvar tracking has not been started!! THIS SHOULD NOT OCCUR DURING A MATCH!");
        return Plugin_Handled;
    }

    CVSEntry CVS_Setting;
    int  iCount = CvarSettingsArray.Length;
    char szBuffer[CVS_CVAR_MAXLEN];
    char szName[CVS_CVAR_MAXLEN];
    GetCmdArg(1, szBuffer, sizeof(szBuffer));

    int iOffset = StringToInt(szBuffer);
    if (iOffset > iCount)
        return Plugin_Handled;

    int iFoundCvars;
    while (iOffset < iCount && iFoundCvars < 20) {
        CvarSettingsArray.GetArray(iOffset, CVS_Setting);
        CVS_Setting.CVSE_ConVar.GetString(szBuffer, sizeof(szBuffer));
        CVS_Setting.CVSE_ConVar.GetName(szName, sizeof(szName));
        if (strcmp(CVS_Setting.CVSE_NewVal, szBuffer) != 0) {
            ReplyToCommand(iClient, "[Confogl] Server Cvar: %s, Desired Value: %s, Current Value: %s", szName, CVS_Setting.CVSE_NewVal, szBuffer);
            iFoundCvars++;
        }

        iOffset++;
    }

    if (iOffset < iCount)
        ReplyToCommand(iClient, "[Confogl] To see more Cvars, use confogl_cvarsettings %d", iOffset);

    return Plugin_Handled;
}

void ClearAllCvars() {
    bTrackingStarted = false;
    CVSEntry CVS_Setting;
    for (int i; i < CvarSettingsArray.Length; i++) {
        CvarSettingsArray.GetArray(i, CVS_Setting);
        CVS_Setting.CVSE_ConVar.RemoveChangeHook(CVS_ConVarChange);
        CVS_Setting.CVSE_ConVar.SetString(CVS_Setting.CVSE_OldVal);
    }

    CvarSettingsArray.Clear();
}

void SetEnforcedCvars() {
    CVSEntry CVS_Setting;
    for (int i; i < CvarSettingsArray.Length; i++) {
        CvarSettingsArray.GetArray(i, CVS_Setting);

        #if CVARS_DEBUG
            char szDebugBuffer[CVS_CVAR_MAXLEN];
            CVS_Setting.CVSE_ConVar.GetName(szDebugBuffer, sizeof(szDebugBuffer));
            LogMessage("cvar = %s, newval = %s", szDebugBuffer, CVS_Setting.CVSE_NewVal);
        #endif

        CVS_Setting.CVSE_ConVar.SetString(CVS_Setting.CVSE_NewVal);
    }
}

void AddCvar(const char[] szConVar, const char[] szNewval) {
    if (bTrackingStarted) {
        #if CVARS_DEBUG
            LogMessage("[Confogl] CvarSettings: Attempt to track new cvar %s during a match!", szConVar);
        #endif
        return;
    }

    if (strlen(szConVar) >= CVS_CVAR_MAXLEN) {
        LogError("[Confogl] CvarSettings: Cvar Specified (%s) is longer than max cvar/value length (%d)", szConVar, CVS_CVAR_MAXLEN);
        return;
    }

    if (strlen(szNewval) >= CVS_CVAR_MAXLEN) {
        LogError("[Confogl] CvarSettings: New Value Specified (%s) is longer than max cvar/value length (%d)", szNewval, CVS_CVAR_MAXLEN);
        return;
    }

    ConVar cv = FindConVar(szConVar);
    if (cv == null) {
        LogError("[Confogl] CvarSettings: Could not find Cvar specified (%s)", szConVar);
        return;
    }

    CVSEntry CVSNewEntry;
    char szCvarBuffer[CVS_CVAR_MAXLEN];
    for (int i; i < CvarSettingsArray.Length; i++) {
        CvarSettingsArray.GetArray(i, CVSNewEntry);
        CVSNewEntry.CVSE_ConVar.GetName(szCvarBuffer, CVS_CVAR_MAXLEN);
        if (strcmp(szConVar, szCvarBuffer, false) == 0) {
            LogError("[Confogl] CvarSettings: Attempt to track ConVar %s, which is already being tracked.", szConVar);
            return;
        }
    }

    cv.GetString(szCvarBuffer, CVS_CVAR_MAXLEN);
    CVSNewEntry.CVSE_ConVar = cv;
    strcopy(CVSNewEntry.CVSE_OldVal, CVS_CVAR_MAXLEN, szCvarBuffer);
    strcopy(CVSNewEntry.CVSE_NewVal, CVS_CVAR_MAXLEN, szNewval);
    cv.AddChangeHook(CVS_ConVarChange);

    #if CVARS_DEBUG
        LogMessage("[Confogl] CvarSettings: cvar = %s, newval = %s, oldval = %s", szConVar, szNewval, szCvarBuffer);
    #endif

    CvarSettingsArray.PushArray(CVSNewEntry);
}

void CVS_ConVarChange(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    if (bTrackingStarted) {
        CVSEntry CVS_Setting;
        for (int i; i < CvarSettingsArray.Length; i++) {
            CvarSettingsArray.GetArray(i, CVS_Setting);
            if (CVS_Setting.CVSE_ConVar == cv)
                break;
        }

        if (strcmp(szNewVal, CVS_Setting.CVSE_NewVal, true) != 0)
            CVS_Setting.CVSE_ConVar.SetString(CVS_Setting.CVSE_NewVal);
    }
}