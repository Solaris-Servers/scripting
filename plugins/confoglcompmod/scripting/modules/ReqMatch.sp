#if defined __REQMATCH_MODULE__
    #endinput
#endif
#define __REQMATCH_MODULE__

#define MAPRESTARTTIME 3.0

#include <l4d2_source_keyvalues>

ConVar RM_cvDoRestart;
ConVar RM_cvReloaded;
ConVar RM_cvUnloaded;
ConVar RM_cvChangeMap;
ConVar RM_cvValidMap;
ConVar RM_cvForceChangeMap;
ConVar RM_cvCurrentMission;
ConVar RM_cvConfigFile_On;
ConVar RM_cvConfigFile_Plugins;
ConVar RM_cvConfigFile_Off;

bool   RM_bIsMatchModeLoaded;
bool   RM_bIsPluginsLoaded;
bool   RM_bIsMapRestarted;

GlobalForward
    RM_fwdMatchLoad,
    RM_fwdMatchUnload;

enum RestartingMapType {
    eLoading,
    eUnloading
};

StringMap RM_smExcludeMissions;

ConVar RM_cvGameMode;
char   RM_szGameMode[32];

void RM_OnModuleStart() {
    RM_cvDoRestart = CreateConVarEx(
    "match_restart", "1",
    "Sets whether the plugin will restart the map upon match mode being forced or requested",
    FCVAR_NONE, true, 0.0, true, 1.0);

    RM_cvChangeMap = CreateConVarEx(
    "match_map", "",
    "Sets the map that we'll be changing to",
    FCVAR_NONE, false, 0.0, false, 0.0);

    RM_cvValidMap = CreateConVarEx(
    "match_valid_map", "1",
    "Sets the valid map",
    FCVAR_NONE, true, 0.0, true, 1.0);

    RM_cvConfigFile_On = CreateConVarEx(
    "match_execcfg_on", "confogl.cfg",
    "Execute this config file upon match mode starts and every map after that.",
    FCVAR_NONE, false, 0.0, false, 0.0);

    RM_cvConfigFile_Plugins = CreateConVarEx(
    "match_execcfg_plugins", "confogl_plugins.cfg",
    "Execute this config file upon match mode starts. This will only get executed once and meant for plugins that needs to be loaded.",
    FCVAR_NONE, false, 0.0, false, 0.0);

    RM_cvConfigFile_Off = CreateConVarEx(
    "match_execcfg_off", "confogl_off.cfg",
    "Execute this config file upon match mode ends.",
    FCVAR_NONE, false, 0.0, false, 0.0);

    RegAdminCmd("sm_forcematch", RM_Cmd_ForceMatch, ADMFLAG_CONFIG, "Forces the game to use match mode");
    RegAdminCmd("sm_fm",         RM_Cmd_ForceMatch, ADMFLAG_CONFIG, "Forces the game to use match mode");
    RegAdminCmd("sm_resetmatch", RM_Cmd_ResetMatch, ADMFLAG_CONFIG, "Forces match mode to turn off REGRADLESS for always on or forced match");

    // Change/Restart a map after match mode was loaded
    RM_cvReloaded = FindConVarEx("match_reloaded");
    if (RM_cvReloaded == null) {
        RM_cvReloaded = CreateConVarEx(
        "match_reloaded", "0",
        "DONT TOUCH THIS CVAR! This is to prevent match feature keep looping, however the plugin takes care of it. Don't change it!",
        FCVAR_DONTRECORD|FCVAR_UNLOGGED, true, 0.0, true, 1.0);
    }

    bool bIsReloaded = RM_cvReloaded.BoolValue;
    if (bIsReloaded) {
        RM_bIsPluginsLoaded = true;
        RM_cvReloaded.SetInt(0);
        RM_Match_Load();
    }

    // Change/Restart a map after match mode was unloaded
    RM_cvUnloaded = FindConVarEx("match_unloaded");
    if (RM_cvUnloaded == null) {
        RM_cvUnloaded = CreateConVarEx(
        "match_unloaded", "0",
        "DONT TOUCH THIS CVAR! This is to prevent match feature keep looping, however the plugin takes care of it. Don't change it!",
        FCVAR_DONTRECORD|FCVAR_UNLOGGED, true, 0.0, true, 1.0);
    }

    bool bIsUnloaded = RM_cvUnloaded.BoolValue;
    if (bIsUnloaded) {
        if (!RM_bIsMapRestarted && RM_cvDoRestart.BoolValue) {
            CPrintToChatAll("{blue}[{default}Confogl{blue}]{default} Restarting the game!");
            CreateTimer(MAPRESTARTTIME, RM_Timer_Match_MapRestart, eUnloading, TIMER_FLAG_NO_MAPCHANGE);
            RM_cvUnloaded.SetInt(0);
        }
    }

    // Load a map after match mode was loaded
    RM_cvForceChangeMap = FindConVarEx("force_match_map");
    if (RM_cvForceChangeMap == null) {
        RM_cvForceChangeMap = CreateConVarEx(
        "force_match_map", "",
        "DONT TOUCH THIS CVAR! This is to store the map that we'll be changing to by sm_forcematch. Don't change it!",
        FCVAR_DONTRECORD|FCVAR_UNLOGGED, false, 0.0, false, 0.0);
    }

    // Current mission
    RM_cvCurrentMission = FindConVarEx("current_mission");
    if (RM_cvCurrentMission == null) {
        RM_cvCurrentMission = CreateConVarEx(
        "current_mission", "",
        "DONT TOUCH THIS CVAR! This is to store current mission name. Don't change it!",
        FCVAR_DONTRECORD|FCVAR_UNLOGGED, false, 0.0, false, 0.0);
    }

    // List of excluded missions
    RM_smExcludeMissions = new StringMap();
    RM_smExcludeMissions.SetValue("credits",          1);
    RM_smExcludeMissions.SetValue("HoldoutChallenge", 1);
    RM_smExcludeMissions.SetValue("HoldoutTraining",  1);
    RM_smExcludeMissions.SetValue("parishdash",       1);
    RM_smExcludeMissions.SetValue("shootzones",       1);

    RM_cvGameMode = FindConVar("mp_gamemode");
    RM_cvGameMode.GetString(RM_szGameMode, sizeof(RM_szGameMode));
    RM_cvGameMode.AddChangeHook(RM_ConVarChanged);
}

void RM_ConVarChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    RM_cvGameMode.GetString(RM_szGameMode, sizeof(RM_szGameMode));
}

void RM_APL() {
    RM_fwdMatchLoad   = new GlobalForward("LGO_OnMatchModeLoaded",   ET_Event);
    RM_fwdMatchUnload = new GlobalForward("LGO_OnMatchModeUnloaded", ET_Event);
    CreateNative("LGO_IsMatchModeLoaded", Native_IsMatchModeLoaded);
}

int Native_IsMatchModeLoaded(Handle hPlugin, int iNumParams) {
    return RM_bIsMatchModeLoaded;
}

void RM_OnMapStart() {
    GetCurrentMission();
}

void GetCurrentMission() {
    static char szMapName[256];
    GetCurrentMap(szMapName, sizeof(szMapName));

    static int iDummy;
    static char szKey[64], szMission[256], szChapter[256];
    SourceKeyValues kvDummy;
    SourceKeyValues kvMissions = kvDummy.GetAllMissions();
    for (SourceKeyValues kvSub = kvMissions.GetFirstTrueSubKey(); !kvSub.IsNull(); kvSub = kvSub.GetNextTrueSubKey()) {
        kvSub.GetName(szMission, sizeof(szMission));
        if (RM_smExcludeMissions.GetValue(szMission, iDummy))
            continue;

        FormatEx(szKey, sizeof(szKey), "modes/%s", RM_szGameMode);
        if (!kvSub.FindKey(szKey).IsNull()) {
            FormatEx(szKey, sizeof(szKey), "%s/modes/%s", szMission, RM_szGameMode);
            SourceKeyValues kvChapters = kvMissions.FindKey(szKey);
            if (!kvChapters.IsNull()) {
                for (SourceKeyValues kvSub2 = kvChapters.GetFirstTrueSubKey(); !kvSub2.IsNull(); kvSub2 = kvSub2.GetNextTrueSubKey()) {
                    kvSub2.GetString("Map", szChapter, sizeof(szChapter), "N/A");
                    if (strcmp(szMapName, szChapter) == 0) {
                        RM_cvCurrentMission.SetString(szMission);
                        return;
                    }
                }
            }
        }
    }
}

void RM_Match_Load() {
    char szBuffer[128];
    if (!RM_bIsPluginsLoaded) {
        RM_cvReloaded.SetInt(1);
        RM_cvConfigFile_Plugins.GetString(szBuffer, sizeof(szBuffer));
        ExecuteCfg(szBuffer);
        return;
    }

    RM_cvConfigFile_On.GetString(szBuffer, sizeof(szBuffer));
    ExecuteCfg(szBuffer);
    if (RM_bIsMatchModeLoaded)
        return;

    IsPluginEnabled(true, true);
    RM_bIsMatchModeLoaded = true;
    CPrintToChatAll("{blue}[{default}Confogl{blue}]{default} Match mode loaded!");

    if (!RM_bIsMapRestarted && RM_cvDoRestart.BoolValue) {
        CreateTimer(MAPRESTARTTIME, RM_Timer_Match_MapRestart, eLoading, TIMER_FLAG_NO_MAPCHANGE);
        CPrintToChatAll("{blue}[{default}Confogl{blue}]{default} Restarting the game!");
    }

    Call_StartForward(RM_fwdMatchLoad);
    Call_Finish();
}

void RM_Match_Unload() {
    char szBuffer[128];
    IsPluginEnabled(true, false);
    RM_bIsMatchModeLoaded = false;
    RM_bIsMapRestarted    = false;
    RM_bIsPluginsLoaded   = false;
    Call_StartForward(RM_fwdMatchUnload);
    Call_Finish();
    CPrintToChatAll("{blue}[{default}Confogl{blue}]{default} Match mode unloaded!");
    RM_cvUnloaded.SetInt(1);
    RM_cvConfigFile_Off.GetString(szBuffer, sizeof(szBuffer));
    ExecuteCfg(szBuffer);
}

Action RM_Timer_Match_MapRestart(Handle hTimer, RestartingMapType eType) {
    static char szBuffer[64];
    if (eType == eLoading) {
        RM_cvForceChangeMap.GetString(szBuffer, sizeof(szBuffer));
        if (strlen(szBuffer) == 0)
            RM_cvChangeMap.GetString(szBuffer, sizeof(szBuffer));

        if (strlen(szBuffer) == 0) {
            GetCurrentMap(szBuffer, sizeof(szBuffer));
            ChangeToValidMap(szBuffer);
            RM_cvForceChangeMap.SetString("");
            RM_bIsMapRestarted = true;
            return Plugin_Stop;
        }
    } else {
        GetCurrentMap(szBuffer, sizeof(szBuffer));
        ChangeToValidMap(szBuffer);
        RM_cvForceChangeMap.SetString("");
        RM_bIsMapRestarted = true;
        return Plugin_Stop;
    }

    L4D2_ChangeLevel(szBuffer);
    RM_cvForceChangeMap.SetString("");
    RM_bIsMapRestarted = true;
    return Plugin_Stop;
}

void RM_UpdateCfgOn(const char[] szCfgFile) {
    if (SetCustomCfg(szCfgFile)) CPrintToChatAll("{blue}[{default}Confogl{blue}]{default} Using \"{olive}%s{default}\" config.", szCfgFile);
    else                         CPrintToChatAll("{blue}[{default}Confogl{blue}]{default} Config \"{olive}%s{default}\" not found, using default config!", szCfgFile);
}

Action RM_Cmd_ForceMatch(int iClient, int iArgs) {
    if (RM_bIsMatchModeLoaded) {
        IsPluginEnabled(true, false);
        RM_bIsMatchModeLoaded = false;
        RM_bIsMapRestarted    = false;
        RM_bIsPluginsLoaded   = false;
        ClearAllSettings();
        ClearAllCvars();
        Call_StartForward(RM_fwdMatchUnload);
        Call_Finish();
    }

    // cfgfile specified
    if (iArgs > 0) {
        char szBuffer[128];
        GetCmdArg(1, szBuffer, sizeof(szBuffer));
        RM_UpdateCfgOn(szBuffer);
        if (iArgs > 1) {
            char szMap        [PLATFORM_MAX_PATH];
            char szDisplayName[PLATFORM_MAX_PATH];
            GetCmdArg(2, szMap, sizeof(szMap));
            if (FindMap(szMap, szDisplayName, sizeof(szDisplayName)) == FindMap_NotFound) {
                CPrintToChat(iClient, "{blue}[{default}Confogl{blue}]{default} Map '{olive}%s{default}' not found!", szMap);
                return Plugin_Handled;
            }

            GetMapDisplayName(szDisplayName, szDisplayName, sizeof(szDisplayName));
            RM_cvForceChangeMap.SetString(szDisplayName);
        }
    } else {
        SetCustomCfg("");
    }

    RM_Match_Load();
    return Plugin_Handled;
}

Action RM_Cmd_ResetMatch(int iClient, int iArgs) {
    if (!RM_bIsMatchModeLoaded)
        return Plugin_Handled;

    RM_Match_Unload();
    return Plugin_Handled;
}

void ChangeToValidMap(const char[] szMapName) {
    if (!RM_cvValidMap.BoolValue) {
        L4D2_ChangeLevel(szMapName);
        return;
    }

    static char szCurrentMission[64];
    RM_cvCurrentMission.GetString(szCurrentMission, sizeof(szCurrentMission));
    if (SDK_IsSurvival() || SDK_IsScavenge()) {
        if (IsValidMap(szMapName)) {
            L4D2_ChangeLevel(szMapName);
            return;
        }

        static int iDummy;
        static char szKey[64], szMission[256], szChapter[256];
        SourceKeyValues kvDummy;
        SourceKeyValues kvMissions = kvDummy.GetAllMissions();
        for (SourceKeyValues kvSub = kvMissions.GetFirstTrueSubKey(); !kvSub.IsNull(); kvSub = kvSub.GetNextTrueSubKey()) {
            kvSub.GetName(szMission, sizeof(szMission));
            if (strcmp(szMission, szCurrentMission) != 0)
                continue;

            FormatEx(szKey, sizeof(szKey), "modes/%s", RM_szGameMode);
            if (!kvSub.FindKey(szKey).IsNull()) {
                FormatEx(szKey, sizeof(szKey), "%s/modes/%s", szMission, RM_szGameMode);
                SourceKeyValues kvChapters = kvMissions.FindKey(szKey);
                if (!kvChapters.IsNull()) {
                    for (SourceKeyValues kvSub2 = kvChapters.GetFirstTrueSubKey(); !kvSub2.IsNull(); kvSub2 = kvSub2.GetNextTrueSubKey()) {
                        kvSub2.GetString("Map", szChapter, sizeof(szChapter), "N/A");
                        L4D2_ChangeLevel(szChapter);
                        return;
                    }
                }
            }
        }

        for (SourceKeyValues kvSub = kvMissions.GetFirstTrueSubKey(); !kvSub.IsNull(); kvSub = kvSub.GetNextTrueSubKey()) {
            kvSub.GetName(szMission, sizeof(szMission));
            if (RM_smExcludeMissions.GetValue(szMission, iDummy))
                continue;

            FormatEx(szKey, sizeof(szKey), "modes/%s", RM_szGameMode);
            if (!kvSub.FindKey(szKey).IsNull()) {
                FormatEx(szKey, sizeof(szKey), "%s/modes/%s", szMission, RM_szGameMode);
                SourceKeyValues kvChapters = kvMissions.FindKey(szKey);
                if (!kvChapters.IsNull()) {
                    for (SourceKeyValues kvSub2 = kvChapters.GetFirstTrueSubKey(); !kvSub2.IsNull(); kvSub2 = kvSub2.GetNextTrueSubKey()) {
                        kvSub2.GetString("Map", szChapter, sizeof(szChapter), "N/A");
                        L4D2_ChangeLevel(szChapter);
                    }
                }
            }
        }
    } else {
        L4D2_ChangeMission(szCurrentMission);
    }
}

bool IsValidMap(const char[] szMapName) {
    static int iDummy;
    static char szKey[64], szMission[256], szChapter[256];
    SourceKeyValues kvDummy;
    SourceKeyValues kvMissions = kvDummy.GetAllMissions();
    for (SourceKeyValues kvSub = kvMissions.GetFirstTrueSubKey(); !kvSub.IsNull(); kvSub = kvSub.GetNextTrueSubKey()) {
        kvSub.GetName(szMission, sizeof(szMission));
        if (RM_smExcludeMissions.GetValue(szMission, iDummy))
            continue;

        FormatEx(szKey, sizeof(szKey), "modes/%s", RM_szGameMode);
        if (!kvSub.FindKey(szKey).IsNull()) {
            FormatEx(szKey, sizeof(szKey), "%s/modes/%s", szMission, RM_szGameMode);
            SourceKeyValues kvChapters = kvMissions.FindKey(szKey);
            if (!kvChapters.IsNull()) {
                for (SourceKeyValues kvSub2 = kvChapters.GetFirstTrueSubKey(); !kvSub2.IsNull(); kvSub2 = kvSub2.GetNextTrueSubKey()) {
                    kvSub2.GetString("Map", szChapter, sizeof(szChapter), "N/A");
                    if (strcmp(szMapName, szChapter) == 0) {
                        return true;
                    }
                }
            }
        }
    }

    return false;
}