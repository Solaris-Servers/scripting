#if defined __LOADING__
    #endinput
#endif
#define __LOADING__

float fPlayerConnected[MAXPLAYERS + 1];
float fPlayerJoined   [MAXPLAYERS + 1];

void OnClientConnected_Loading(int iClient) {
    fPlayerConnected[iClient] = GetEngineTime();
}

void OnClientPostAdminCheck_Loading(int iClient) {
    fPlayerJoined[iClient] = GetEngineTime() - fPlayerConnected[iClient];
}

float GetPlayerLoadingTime(int iClient) {
    return fPlayerJoined[iClient];
}