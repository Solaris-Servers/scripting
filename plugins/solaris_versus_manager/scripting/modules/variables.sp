#if defined __VARIABLES__
    #endinput
#endif
#define __VARIABLES__

#include <solaris/stocks>

#define MAP_LIMIT   1

#define LASERSIGHTS "upgrade_laser_sight"
#define PILLS       "weapon_pain_pills"
#define ADRENALINE  "weapon_adrenaline"
#define VOMITJAR    "weapon_vomitjar"
#define PIPEBOMB    "weapon_pipe_bomb"

#define NONE     0
#define VERSUS   1
#define SCAVENGE 2

enum /* Settings */ {
    ePunchRockBlock,
    eJumpRockBlock,
    eNoTankRush,
    eDeadstopsBlock,
    eLaserSights,
    ePills,
    eAdrenaline,
    eVomitjar,
    ePipeBomb,
    eSettingsSize
};

char g_szSettings[][] = {
    "PunchRock",
    "JumpRock",
    "NoTankRush",
    "Deadstops",
    "LaserSights",
    "Pills",
    "Adrenaline",
    "Vomitjar",
    "PipeBomb"
};

void OnMapStart_Variables() {
    IsMapStarted(true, true);

    for (int i = 0; i < eSettingsSize; i++) {
        SettingsToApply(true, i, -1);
    }
}

void OnMapEnd_Variables() {
    IsMapStarted(true, false);
}

void OnClientConnected_Variables(int iClient) {
    for (int i = 0; i < eSettingsSize; i++) {
        ClientSettings(iClient, true, i, -1);
    }
}

void OnClientDisconnect_Variables(int iClient) {
    for (int i = 0; i < eSettingsSize; i++) {
        ClientSettings(iClient, true, i, -1);
    }
}

bool IsMapStarted(bool bSet = false, bool bVal = false) {
    static bool bIsMapStarted;

    if (bSet)
        bIsMapStarted = bVal;

    return bIsMapStarted;
}

int GetCurrentMainMode() {
    if (!IsMapStarted())
        return NONE;

    if (SDK_IsVersus())
        return VERSUS;

    if (SDK_IsScavenge())
        return SCAVENGE;

    return NONE;
}

int ClientSettings(int iClient, bool bSet = false, int iSetting = 0, int iVal = -1) {
    static int iSettings[MAXPLAYERS + 1][eSettingsSize];

    if (bSet)
        iSettings[iClient][iSetting] = iVal;

    return iSettings[iClient][iSetting];
}

int SettingsToApply(bool bSet = false, int iSetting = 0, int iVal = -1) {
    static int iSettings[eSettingsSize] = {-1, ...};

    if (bSet)
        iSettings[iSetting] = iVal;

    return iSettings[iSetting];
}