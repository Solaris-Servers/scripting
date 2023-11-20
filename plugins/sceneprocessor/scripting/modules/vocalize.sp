#if defined __VOCALIZE__
    #endinput
#endif
#define __VOCALIZE__

void OnModuleStart_Vocalize() {
    AddCommandListener(Cmd_Vocalize, "vocalize");
}

Action Cmd_Vocalize(int iClient, const char[] szCmd, int iArgs) {
    if (iClient == 0 || iArgs == 0)
        return Plugin_Continue;

    if (!IsClientInGame(iClient))
        return Plugin_Handled;

    static char szVocalize[128];
    GetCmdArg(1, szVocalize, sizeof(szVocalize));

    if (iArgs != 2) {
        JailbreakVocalize(iClient, szVocalize);
        return Plugin_Handled;
    }

    int iTick = GetGameTickCount();
    if (!g_bSceneHasInitiator[iClient] || (g_iVocalizeTick[iClient] > 0 && g_iVocalizeTick[iClient] != iTick)) {
        g_iVocalizeInitiator[iClient] = iClient;
        if (iArgs > 1 && strcmp(szVocalize, "smartlook", false) == 0) {
            static char szTime[32];
            GetCmdArg(2, szTime, sizeof(szTime));
            if (strcmp(szTime, "auto", false) == 0)
                g_iVocalizeInitiator[iClient] = SCENE_INITIATOR_WORLD;
        }
    }

    strcopy(g_szVocalizeScene[iClient], MAX_VOCALIZE_LENGTH, szVocalize);
    g_iVocalizeTick[iClient] = iTick;

    Action aResult = Plugin_Continue;
    VocalizeCommandForward(iClient, szVocalize, aResult);
    return (aResult == Plugin_Stop) ? Plugin_Handled : Plugin_Continue;
}