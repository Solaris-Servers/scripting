#if defined __NATIVES__
    #endinput
#endif
#define __NATIVES__

APLRes Natives_AskPluginLoad2(char[] szError, int iErrMax) {
    if (GetEngineVersion() != Engine_Left4Dead2) {
        strcopy(szError, iErrMax, "Plugin only supports Left 4 Dead 2");
        return APLRes_SilentFailure;
    }

    CreateNative("L4D2_ChangeLevel",   Native_ChangeLevel);
    CreateNative("L4D2_ChangeMission", Native_ChangeMission);

    RegPluginLibrary("l4d2_changelevel");
    return APLRes_Success;
}

any Native_ChangeLevel(Handle hPlugin, int iNumParams) {
    if (iNumParams == 0) {
        PrintToServer("[Change Level] Map is not specified!");
        return 0;
    }

    char szMap[PLATFORM_MAX_PATH];
    GetNativeString(1, szMap, sizeof(szMap));

    char szTmp[2];
    if (szMap[0] == '\0' || FindMap(szMap, szTmp, sizeof(szTmp)) == FindMap_NotFound) {
        PrintToServer("[Change Level] Unable to change to that map \"%s\"", szMap);
        return 0;
    }

    Clear(true, true);
    if (iNumParams >= 2)
        Clear(true, view_as<bool>(GetNativeCell(2)));

    SDK_ChangeLevel(szMap, Clear());
    return 0;
}

any Native_ChangeMission(Handle hPlugin, int iNumParams) {
    if (iNumParams == 0) {
        PrintToServer("[Change Level] Campaign is not specified!");
        return 0;
    }

    char szMission[PLATFORM_MAX_PATH];
    GetNativeString(1, szMission, sizeof(szMission));

    SDK_ChangeMission(szMission);
    return 0;
}