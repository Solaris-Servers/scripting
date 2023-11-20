#if defined __Globals__
    #endinput
#endif
#define __Globals__

#define ANTIFLOOD           0.75
#define MAXLENGTH_NAME      64     // This is backwords math to get compability.  Sourcemod has it set at 32, but there is room for more.
#define MAXLENGTH_MESSAGE   256    // This is based upon the SDK and the length of the entire message, including tags, name, : etc.

#define TEAM_NOTEAM      0
#define TEAM_SPECTATORS  1
#define TEAM_SURVIVORS   2
#define TEAM_INFECTED    3

bool  g_bIsConfoglEnabled;
float g_fLastMessage[MAXPLAYERS + 1];

void Globals_OnClientPutInServer(int iClient) {
    g_fLastMessage[iClient] = 0.0;
}

void Globals_OnClientDisconnect(int iClient) {
    g_fLastMessage[iClient] = 0.0;
}

public void LGO_OnMatchModeLoaded() {
    g_bIsConfoglEnabled = true;
}

public void LGO_OnMatchModeUnloaded() {
    g_bIsConfoglEnabled = false;
}