#if defined __CLIENTSETTINGS_MODULE__
    #endinput
#endif
#define __CLIENTSETTINGS_MODULE__

#define CLS_CVAR_MAXLEN       128
#define CLIENT_CHECK_INTERVAL 5.0

enum CLSAction {
    CLSA_Kick,
    CLSA_Log
};

enum struct CLSEntry {
    bool      CLSE_HasMin;
    float     CLSE_Min;
    bool      CLSE_HasMax;
    float     CLSE_Max;
    CLSAction CLSE_Action;
    char      CLSE_ConVar[CLS_CVAR_MAXLEN];
}

int       CLSEntry_BlockSize;
ArrayList ClientSettingsArray;
Handle    ClientSettingsCheckTimer;

void CLS_OnModuleStart() {
    CLSEntry Tmp;
    CLSEntry_BlockSize  = sizeof(Tmp);
    ClientSettingsArray = new ArrayList(CLSEntry_BlockSize);

    RegConsoleCmd("confogl_clientsettings", Cmd_ClientSettings, "List Client settings enforced by confogl");

    /* Using Server Cmd instead of admin because these shouldn't really be changed on the fly */
    RegServerCmd("confogl_trackclientcvar",     Cmd_TrackClientCvar,     "Add a Client CVar to be tracked and enforced by confogl");
    RegServerCmd("confogl_resetclientcvars",    Cmd_ResetTracking,       "Remove all tracked client cvars. Cannot be called during matchmode");
    RegServerCmd("confogl_startclientchecking", Cmd_StartClientChecking, "Start checking and enforcing client cvars tracked by this plugin");
}

void ClearAllSettings() {
    if (ClientSettingsCheckTimer != null) {
        KillTimer(ClientSettingsCheckTimer);
        ClientSettingsCheckTimer = null;
    }

    ClientSettingsArray.Clear();
}

Action CS_Timer_CheckSettings(Handle hTimer) {
    if (!IsPluginEnabled()) {
        if (IsDebugEnabled()) LogMessage("[Confogl] ClientSettings: Stopping client settings tracking");
        ClientSettingsCheckTimer = null;
        return Plugin_Stop;
    }

    EnforceAllSettings();
    return Plugin_Continue;
}

void EnforceAllSettings() {
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        EnforceClientSettings(i);
    }
}

void EnforceClientSettings(int iClient) {
    int iLength = ClientSettingsArray.Length;
    if (!iLength)
        return;

    CLSEntry CLSEntry_ClientSetting;
    for (int i = 0; i < iLength; i++) {
        ClientSettingsArray.GetArray(i, CLSEntry_ClientSetting);
        QueryClientConVar(iClient, CLSEntry_ClientSetting.CLSE_ConVar, EnforceClientSettings_QueryReply, i);
    }
}

void EnforceClientSettings_QueryReply(QueryCookie qCookie, int iClient, ConVarQueryResult qResult, const char[] szCvarName, const char[] szCvarValue, any iValue) {
    // Client disconnected or got kicked already
    if (!IsClientInGame(iClient))
        return;

    if (IsClientInKickQueue(iClient))
        return;

    if (!ClientSettingsArray.Length)
        return;

    if (qResult) {
        LogMessage("[Confogl] ClientSettings: Couldn't retrieve cvar %s from %L, kicked from server", szCvarName, iClient);
        KickClient(iClient, "CVar '%s' protected or missing! Hax?", szCvarName);
        return;
    }

    float fCvarVal       = StringToFloat(szCvarValue);
    int   iClientSetting = iValue;
    CLSEntry CLSEntry_ClientSetting;
    ClientSettingsArray.GetArray(iClientSetting, CLSEntry_ClientSetting);
    if ((CLSEntry_ClientSetting.CLSE_HasMin && fCvarVal < CLSEntry_ClientSetting.CLSE_Min) || (CLSEntry_ClientSetting.CLSE_HasMax && fCvarVal > CLSEntry_ClientSetting.CLSE_Max)) {
        switch (CLSEntry_ClientSetting.CLSE_Action) {
            case CLSA_Kick: {
                LogMessage("[Confogl] ClientSettings: Kicking %L for bad %s value (%f). Min: %d %f Max: %d %f", iClient,
                                                                                                                szCvarName,
                                                                                                                fCvarVal,
                                                                                                                CLSEntry_ClientSetting.CLSE_HasMin,
                                                                                                                CLSEntry_ClientSetting.CLSE_Min,
                                                                                                                CLSEntry_ClientSetting.CLSE_HasMax,
                                                                                                                CLSEntry_ClientSetting.CLSE_Max);
                char szKickMessage[256] = "Illegal Client Value for ";
                Format(szKickMessage, sizeof(szKickMessage), "%s%s (%.2f)", szKickMessage, szCvarName, fCvarVal);
                if (CLSEntry_ClientSetting.CLSE_HasMin)
                    Format(szKickMessage, sizeof(szKickMessage), "%s, Min %.2f", szKickMessage, CLSEntry_ClientSetting.CLSE_Min);
                if (CLSEntry_ClientSetting.CLSE_HasMax)
                    Format(szKickMessage, sizeof(szKickMessage), "%s, Max %.2f", szKickMessage, CLSEntry_ClientSetting.CLSE_Max);
                KickClient(iClient, "%s", szKickMessage);
            }
            case CLSA_Log: {
                LogMessage("[Confogl] ClientSettings: Client %L has a bad %s value (%f). Min: %d %f Max: %d %f", iClient,
                                                                                                                 szCvarName,
                                                                                                                 fCvarVal,
                                                                                                                 CLSEntry_ClientSetting.CLSE_HasMin,
                                                                                                                 CLSEntry_ClientSetting.CLSE_Min,
                                                                                                                 CLSEntry_ClientSetting.CLSE_HasMax,
                                                                                                                 CLSEntry_ClientSetting.CLSE_Max);
            }
        }
    }
}

Action Cmd_ClientSettings(int iClient, int iArgs) {
    int iCount = ClientSettingsArray.Length;
    if (!iCount)
        return Plugin_Handled;

    ReplyToCommand(iClient, "[Confogl] Tracked Client CVars (Total %d)", iCount);
    for (int i = 0; i < iCount; i++) {
        static CLSEntry CLSEntry_ClientSetting;
        static char     szMessage[256];
        char            szShortBuf[64];
        ClientSettingsArray.GetArray(i, CLSEntry_ClientSetting);
        FormatEx(szMessage, sizeof(szMessage), "[Confogl] Client CVar: %s ", CLSEntry_ClientSetting.CLSE_ConVar);
        if (CLSEntry_ClientSetting.CLSE_HasMin) {
            FormatEx(szShortBuf, sizeof(szShortBuf), "Min: %f ", CLSEntry_ClientSetting.CLSE_Min);
            StrCat(szMessage,  sizeof(szMessage), szShortBuf);
        }

        if (CLSEntry_ClientSetting.CLSE_HasMax) {
            FormatEx(szShortBuf, sizeof(szShortBuf), "Max: %f ", CLSEntry_ClientSetting.CLSE_Max);
            StrCat(szMessage,  sizeof(szMessage), szShortBuf);
        }

        switch(CLSEntry_ClientSetting.CLSE_Action) {
            case CLSA_Kick: {
                StrCat(szMessage, sizeof(szMessage), "Action: Kick");
            }
            case CLSA_Log: {
                StrCat(szMessage, sizeof(szMessage), "Action: Log");
            }
        }

        ReplyToCommand(iClient, szMessage);
    }

    return Plugin_Handled;
}

Action Cmd_TrackClientCvar(int iArgs) {
    if (iArgs < 3 || iArgs == 4) {
        PrintToServer("Usage: confogl_trackclientcvar <cvar> <hasMin> <min> [<hasMax> <max> [<action>]]");
        if (IsDebugEnabled()) {
            char szCmdBuf[128];
            GetCmdArgString(szCmdBuf, sizeof(szCmdBuf));
            LogError("[confogl] Invalid track client cvar: %s", szCmdBuf);
        }

        return Plugin_Handled;
    }

    CLSAction
        CLS_Action = CLSA_Kick;

    char  szBuffer[CLS_CVAR_MAXLEN];
    char  szCvar  [CLS_CVAR_MAXLEN];
    bool  bHasMin;
    bool  bHasMax;
    float fMin;
    float fMax;

    GetCmdArg(1, szCvar, sizeof(szCvar));
    if (!strlen(szCvar)) {
        PrintToServer("Unreadable cvar");
        if (IsDebugEnabled()) {
            char szCmdBuf[128];
            GetCmdArgString(szCmdBuf, sizeof(szCmdBuf));
            LogError("[confogl] Invalid track client cvar: %s", szCmdBuf);
        }

        return Plugin_Handled;
    }

    GetCmdArg(2, szBuffer, sizeof(szBuffer));
    bHasMin = view_as<bool>(StringToInt(szBuffer));
    GetCmdArg(3, szBuffer, sizeof(szBuffer));
    fMin = StringToFloat(szBuffer);

    if (iArgs >= 5) {
        GetCmdArg(4, szBuffer, sizeof(szBuffer));
        bHasMax = view_as<bool>(StringToInt(szBuffer));
        GetCmdArg(5, szBuffer, sizeof(szBuffer));
        fMax = StringToFloat(szBuffer);
    }

    if (iArgs >= 6) {
        GetCmdArg(6, szBuffer, sizeof(szBuffer));
        CLS_Action = view_as<CLSAction>(StringToInt(szBuffer));
    }

    AddClientCvar(szCvar, bHasMin, fMin, bHasMax, fMax, CLS_Action);
    return Plugin_Handled;
}

Action Cmd_ResetTracking(int iArgs) {
    if (ClientSettingsCheckTimer != null) {
        PrintToServer("Can't reset tracking in the middle of a match");
        return Plugin_Handled;
    }

    ClearAllSettings();
    PrintToServer("Client CVar Tracking Information Reset!");
    return Plugin_Handled;
}

Action Cmd_StartClientChecking(int iArgs) {
    StartTracking();
    return Plugin_Handled;
}

void StartTracking() {
    if (IsPluginEnabled() && ClientSettingsCheckTimer == null) {
        if (IsDebugEnabled())
            LogMessage("[Confogl] ClientSettings: Starting repeating check timer");

        ClientSettingsCheckTimer = CreateTimer(CLIENT_CHECK_INTERVAL, CS_Timer_CheckSettings, _, TIMER_REPEAT);
        return;
    }

    PrintToServer("Can't start plugin tracking or tracking already started");
}

void AddClientCvar(const char[] szConVar, bool bHasMin, float fMin, bool bHasMax, float fMax, CLSAction CLS_Action) {
    if (ClientSettingsCheckTimer != null) {
        PrintToServer("Can't track new cvars in the middle of a match");
        if (IsDebugEnabled())
            LogMessage("[Confogl] ClientSettings: Attempt to track new cvar %s during a match!", szConVar);

        return;
    }

    if (!(bHasMin || bHasMax)) {
        LogError("[Confogl] ClientSettings: Client CVar %s specified without max or min", szConVar);
        return;
    }

    if (bHasMin && bHasMax && fMax < fMin) {
        LogError("[Confogl] ClientSettings: Client CVar %s specified max < min (%f < %f)", szConVar, fMax, fMin);
        return;
    }

    if (strlen(szConVar) >= CLS_CVAR_MAXLEN) {
        LogError("[Confogl] ClientSettings: CVar Specified (%s) is longer than max cvar length (%d)", szConVar, CLS_CVAR_MAXLEN);
        return;
    }

    int iLength = ClientSettingsArray.Length;
    if (!iLength)
        return;

    CLSEntry CLSNewEntry;
    for (int i = 0; i < iLength; i++) {
        ClientSettingsArray.GetArray(i, CLSNewEntry);
        if (strcmp(CLSNewEntry.CLSE_ConVar, szConVar, false) == 0) {
            LogError("[Confogl] ClientSettings: Attempt to track CVar %s, which is already being tracked.", szConVar);
            return;
        }
    }

    CLSNewEntry.CLSE_HasMin = bHasMin;
    CLSNewEntry.CLSE_Min    = fMin;
    CLSNewEntry.CLSE_HasMax = bHasMax;
    CLSNewEntry.CLSE_Max    = fMax;
    CLSNewEntry.CLSE_Action = CLS_Action;
    strcopy(CLSNewEntry.CLSE_ConVar, CLS_CVAR_MAXLEN, szConVar);
    if (IsDebugEnabled())
        LogMessage("[Confogl] ClientSettings: Tracking Cvar %s Min %d %f Max %d %f Action %d", szConVar, bHasMin, fMin, bHasMax, fMax, CLS_Action);

    ClientSettingsArray.PushArray(CLSNewEntry);
}