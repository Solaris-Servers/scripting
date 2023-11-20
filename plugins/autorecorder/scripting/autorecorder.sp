#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sourcetv/sourcetvmanager>
#include <sourcetv/autorecorder/logic>
#include <sourcetv/autorecorder/console>

public Plugin myinfo = {
    name        = "[L4D/2] Automated Demo Recording",
    author      = "shqke",
    description = "Plugin takes control over demo recording process allowing to record only useful footage",
    version     = "1.2",
    url         = "https://github.com/shqke/sp_public"
};

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iMaxLen) {
    switch (GetEngineVersion()) {
        case Engine_Left4Dead2, Engine_Left4Dead: {
            return APLRes_Success;
        }
    }

    strcopy(szError, iMaxLen, "Game is not supported.");
    return APLRes_SilentFailure;
}

public void OnPluginStart() {
    Logic_Init();
    Console_Init();
}

public void OnLibraryRemoved(const char[] szName) {
    if (strcmp(szName, "sourcetvsupport") == 0 && SourceTV_IsRecording())
        SourceTV_StopRecording();
}