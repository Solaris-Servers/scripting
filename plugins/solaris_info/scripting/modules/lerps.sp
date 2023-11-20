#if defined __LERPS__
    #endinput
#endif
#define __LERPS__

float fLastLerp[MAXPLAYERS + 1];

void OnClientPutInServer_Lerp(int iClient) {
    fLastLerp[iClient] = GetPlayerLerp(iClient);
}

void OnClientSettingsChanged_Lerp(int iClient) {
    float fNewLerp = GetPlayerLerp(iClient);
    if (fNewLerp == fLastLerp[iClient])
        return;

    PlayerLerpChanged(iClient, fNewLerp, fLastLerp[iClient]);
    fLastLerp[iClient] = fNewLerp;
}

float GetPlayerLerp(int iClient) {
    static char szLerp[64];
    GetClientInfo(iClient, "cl_interp", szLerp, sizeof(szLerp));
    return StringToFloat(szLerp) * 1000;
}