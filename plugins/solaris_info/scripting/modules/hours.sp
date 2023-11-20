#if defined __HOURS__
    #endinput
#endif
#define __HOURS__

#include <SteamWorks>

void OnClientAuthorized_Hours(int iClient) {
    SteamWorks_RequestStats(iClient, 550);
}

float GetPlayerHours(int iClient) {
    int iTime;
    if (!SteamWorks_GetStatCell(iClient, "Stat.TotalPlayTime.Total", iTime))
        return 0.0;

    static float fHours;
    fHours = 0.0
    fHours = (float(iTime) / 3600.0);
    return fHours;
}