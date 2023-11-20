#if defined _l4d2lib_mapinfo_included
    #endinput
#endif
#define _l4d2lib_mapinfo_included

#define MAPINFO_PATH "configs/l4d2lib/mapinfo.txt"

/* Saferoom */
enum {
    eSaferoom_Neither = 0,
    eSaferoom_Start   = 1,
    eSaferoom_End     = 2,
    eSaferoom_Both    = 3
};

static bool  g_bMapDataAvailable = false;
static float g_fStartPoint[3] = {0.0, ...};
static float g_fEndPoint[3] = {0.0, ...};
static float g_fStartDist = 0.0;
static float g_fStartExtraDist = 0.0;
static float g_fEndDist = 0.0;
static float g_fLocTemp[MAXPLAYERS + 1][3];
static int   g_iIsInEditMode[MAXPLAYERS + 1] = {0, ...};

static KeyValues g_kvMIData;

void MapInfo_AskPluginLoad2() {
    CreateNative("L4D2_IsMapDataAvailable",       Native_IsMapDataAvailable);   // never used
    CreateNative("L4D2_IsEntityInSaferoom",       Native_IsEntityInSaferoom);   // never used
    CreateNative("L4D2_GetMapStartOrigin",        Native_GetMapStartOrigin);    // never used
    CreateNative("L4D2_GetMapEndOrigin",          Native_GetMapEndOrigin);      // never used
    CreateNative("L4D2_GetMapStartDistance",      Native_GetMapStartDist);      // never used
    CreateNative("L4D2_GetMapStartExtraDistance", Native_GetMapStartExtraDist); // never used
    CreateNative("L4D2_GetMapEndDistance",        Native_GetMapEndDist);        // never used
    CreateNative("L4D2_GetMapValueInt",           Native_GetMapValueInt);       // scoremod2, eq2_scoremod, l4d2_horde_equaliser, witch_and_tankifier, l4d2_scoremod, l4d2_hybrid_scoremod_zone, l4d2_hybrid_scoremod
    CreateNative("L4D2_GetMapValueFloat",         Native_GetMapValueFloat);     // never used
    CreateNative("L4D2_GetMapValueVector",        Native_GetMapValueVector);    // never used
    CreateNative("L4D2_GetMapValueString",        Native_GetMapValueString);    // never used
    CreateNative("L4D2_CopyMapSubsection",        Native_CopyMapSubsection);    // witch_and_tankifier (rework version)
}

any Native_IsMapDataAvailable(Handle hPlugin, int iNumParams) {
    return g_bMapDataAvailable;
}

any Native_IsEntityInSaferoom(Handle hPlugin, int iNumParams) {
    return IsEntityInSaferoom(GetNativeCell(1));
}

any Native_GetMapStartOrigin(Handle hPlugin, int iNumParams) {
    float fOrigin[3];
    GetNativeArray(1, fOrigin, sizeof(fOrigin));
    for (int i = 0; i < sizeof(fOrigin); i++) {
        fOrigin[i] = g_fStartPoint[i];
    }
    SetNativeArray(1, fOrigin, sizeof(fOrigin));
    return 1;
}

any Native_GetMapEndOrigin(Handle hPlugin, int iNumParams) {
    float fOrigin[3];
    GetNativeArray(1, fOrigin, sizeof(fOrigin));
    for (int i = 0; i < sizeof(fOrigin); i++) {
        fOrigin[i] = g_fEndPoint[i];
    }
    SetNativeArray(1, fOrigin, sizeof(fOrigin));
    return 1;
}

any Native_GetMapStartDist(Handle hPlugin, int iNumParams) {
    return view_as<int>(g_fStartDist);
}

any Native_GetMapStartExtraDist(Handle hPlugin, int iNumParams) {
    return view_as<int>(g_fStartExtraDist);
}

any Native_GetMapEndDist(Handle hPlugin, int iNumParams) {
    return view_as<int>(g_fEndDist);
}

any Native_GetMapValueInt(Handle hPlugin, int iNumParams) {
    int iLen;
    GetNativeStringLength(1, iLen);
    int iNewLen = iLen + 1;
    char[] sKey = new char[iNewLen];
    GetNativeString(1, sKey, iNewLen);
    int iDefVal = GetNativeCell(2);
    return KvGetNum(g_kvMIData, sKey, iDefVal);
}

any Native_GetMapValueFloat(Handle hPlugin, int iNumParams) {
    int iLen;
    GetNativeStringLength(1, iLen);
    int iNewLen = iLen + 1;
    char[] sKey = new char[iNewLen];
    GetNativeString(1, sKey, iNewLen);
    float fDefVal = GetNativeCell(2);
    return view_as<int>(KvGetFloat(g_kvMIData, sKey, fDefVal));
}

any Native_GetMapValueVector(Handle hPlugin, int iNumParams) {
    int iLen;
    GetNativeStringLength(1, iLen);
    int iNewLen = iLen + 1;
    char[] sKey = new char[iNewLen];
    GetNativeString(1, sKey, iNewLen);
    float fDefval[3], fValue[3];
    GetNativeArray(3, fDefval, 3);
    KvGetVector(g_kvMIData, sKey, fValue, fDefval);
    SetNativeArray(2, fValue, 3);
    return 1;
}

any Native_GetMapValueString(Handle hPlugin, int iNumParams) {
    int iLen;
    GetNativeStringLength(1, iLen);
    int iNewLen = iLen + 1;
    char[] sKey = new char[iNewLen];
    GetNativeString(1, sKey, iNewLen);
    GetNativeStringLength(4, iLen);
    iNewLen = iLen + 1;
    char[] sDefVal = new char[iNewLen];
    GetNativeString(4, sDefVal, iNewLen);
    iLen = GetNativeCell(3);
    iNewLen = iLen + 1;
    char[] sBuf = new char[iNewLen];
    KvGetString(g_kvMIData, sKey, sBuf, iNewLen, sDefVal);
    SetNativeString(2, sBuf, iNewLen);
    return 1;
}

any Native_CopyMapSubsection(Handle hPlugin, int iNumParams) {
    int iLen;
    GetNativeStringLength(2, iLen);
    int iNewLen = iLen + 1;
    char[] sKey = new char[iNewLen];
    GetNativeString(2, sKey, iNewLen);
    KeyValues kv = GetNativeCell(1);
    if (KvJumpToKey(g_kvMIData, sKey, false)) {
        kv.Import(g_kvMIData);
        g_kvMIData.GoBack();
    }
    return 1;
}

void MapInfo_Init() {
    MI_KV_Load();
    RegAdminCmd("confogl_midata_save",   MI_KV_CmdSave,    ADMFLAG_CONFIG);
    RegAdminCmd("confogl_save_location", MI_KV_CmdSaveLoc, ADMFLAG_CONFIG);
}

void MapInfo_OnMapStart_Update() {
    MI_KV_UpdateMapInfo();
}

void MapInfo_OnMapEnd_Update() {
    KvRewind(g_kvMIData);
    g_bMapDataAvailable = false;
    for (int i = 0; i <= MAXPLAYERS; i++) {
        g_iIsInEditMode[i] = 0;
    }
}

void MapInfo_OnPluginEnd() {
    MI_KV_Close();
}

void MapInfo_Reload() {
    MI_KV_Close();
    MI_KV_Load();
}

void MapInfo_PlayerDisconnect(Event eEvent) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient >= 0 && iClient <= MaxClients) {
        g_iIsInEditMode[iClient] = 0;
    }
}

public Action MI_KV_CmdSave(int iClient, int iArgs) {
    char szCurMap[128];
    GetCurrentMap(szCurMap, sizeof(szCurMap));
    if (KvJumpToKey(g_kvMIData, szCurMap, true)) {
        KvSetVector(g_kvMIData, "start_point",      g_fStartPoint);
        KvSetFloat(g_kvMIData,  "start_dist",       g_fStartDist);
        KvSetFloat(g_kvMIData,  "start_extra_dist", g_fStartExtraDist);
        char szNameBuff[PLATFORM_MAX_PATH];
        if (g_bConfogl) {
            LGO_BuildConfigPath(szNameBuff, sizeof(szNameBuff), "mapinfo.txt");
        } else {
            BuildPath(Path_SM, szNameBuff, sizeof(szNameBuff), MAPINFO_PATH);
        }
        KvRewind(g_kvMIData);
        KeyValuesToFile(g_kvMIData, szNameBuff);
        ReplyToCommand(iClient, "%s has been added to %s.", szCurMap, szNameBuff);
    }
    return Plugin_Handled;
}

public Action MI_KV_CmdSaveLoc(int iClient, int iArgs) {
    bool bUpdateInfo;
    char szCurMap[128];
    GetCurrentMap(szCurMap, sizeof(szCurMap));
    if (!g_iIsInEditMode[iClient]) {
        if (!iArgs) {
            ReplyToCommand(iClient, "Move to the location of the medkits, then enter the point type (start_point or end_point)");
            return Plugin_Handled;
        }
        char szBuffer[16];
        GetCmdArg(1, szBuffer, sizeof(szBuffer));
        if (strcmp(szBuffer, "start_point", true) == 0) {
            g_iIsInEditMode[iClient] = 1;
            ReplyToCommand(iClient, "Move a few feet from the medkits and enter this command again to set the start_dist for this point");
        } else if (strcmp(szBuffer, "end_point", true) == 0) {
            g_iIsInEditMode[iClient] = 2;
            ReplyToCommand(iClient, "Move to the farthest point in the saferoom and enter this command again to set the end_dist for this point");
        } else {
            ReplyToCommand(iClient, "Please enter the location type: start_point, end_point");
            return Plugin_Handled;
        }
        if (KvJumpToKey(g_kvMIData, szCurMap, true)) {
            GetClientAbsOrigin(iClient, g_fLocTemp[iClient]);
            KvSetVector(g_kvMIData, szBuffer, g_fLocTemp[iClient]);
        }
        bUpdateInfo = true;
    } else if (g_iIsInEditMode[iClient] == 1) {
        g_iIsInEditMode[iClient] = 3;
        float fDistLoc[3];
        GetClientAbsOrigin(iClient, fDistLoc);
        float fDistance = GetVectorDistance(fDistLoc, g_fLocTemp[iClient]);
        if (KvJumpToKey(g_kvMIData, szCurMap, true))
            KvSetFloat(g_kvMIData, "start_dist", fDistance);
        ReplyToCommand(iClient, "Move to the farthest point in the saferoom and enter this command again to set start_extra_dist for this point");
        bUpdateInfo = true;
    } else if (g_iIsInEditMode[iClient] == 2) {
        g_iIsInEditMode[iClient] = 0;
        float fDistLoc[3];
        GetClientAbsOrigin(iClient, fDistLoc);
        float fDistance = GetVectorDistance(fDistLoc, g_fLocTemp[iClient]);
        if (KvJumpToKey(g_kvMIData, szCurMap, true))
            KvSetFloat(g_kvMIData, "end_dist", fDistance);
        bUpdateInfo = true;
    } else if (g_iIsInEditMode[iClient] == 3) {
        g_iIsInEditMode[iClient] = 0;
        float fDistLoc[3];
        GetClientAbsOrigin(iClient, fDistLoc);
        float fDistance = GetVectorDistance(fDistLoc, g_fLocTemp[iClient]);
        if (KvJumpToKey(g_kvMIData, szCurMap, true))
            KvSetFloat(g_kvMIData, "start_extra_dist", fDistance);
        bUpdateInfo = true;
    }
    if (bUpdateInfo) {
        char szNameBuff[PLATFORM_MAX_PATH];
        if (g_bConfogl) {
            LGO_BuildConfigPath(szNameBuff, sizeof(szNameBuff), "mapinfo.txt");
        } else {
            BuildPath(Path_SM, szNameBuff, sizeof(szNameBuff), MAPINFO_PATH);
        }
        KvRewind(g_kvMIData);
        KeyValuesToFile(g_kvMIData, szNameBuff);
        ReplyToCommand(iClient, "mapinfo.txt has been updated!");
    }
    return Plugin_Handled;
}

void MI_KV_Close() {
    if (g_kvMIData != null) {
        delete g_kvMIData;
    }
}

void MI_KV_Load() {
    char szNameBuff[PLATFORM_MAX_PATH];
    g_kvMIData = CreateKeyValues("MapInfo");
    if (g_bConfogl) {
        LGO_BuildConfigPath(szNameBuff, sizeof(szNameBuff), "mapinfo.txt");
    } else {
        BuildPath(Path_SM, szNameBuff, sizeof(szNameBuff), MAPINFO_PATH);
    }
    if (!FileToKeyValues(g_kvMIData, szNameBuff)) {
        LogError("[MI] Couldn't load MapInfo data!");
        MI_KV_Close();
    }
}

void MI_KV_UpdateMapInfo() {
    char szCurMap[128];
    GetCurrentMap(szCurMap, sizeof(szCurMap));
    if (KvJumpToKey(g_kvMIData, szCurMap)) {
        KvGetVector(g_kvMIData, "start_point", g_fStartPoint);
        KvGetVector(g_kvMIData, "end_point", g_fEndPoint);
        g_fStartDist = KvGetFloat(g_kvMIData, "start_dist");
        g_fStartExtraDist = KvGetFloat(g_kvMIData, "start_extra_dist");
        g_fEndDist = KvGetFloat(g_kvMIData, "end_dist");
        g_bMapDataAvailable = true;
    } else {
        g_bMapDataAvailable = false;
        g_fStartDist = FindStartPointHeuristic(g_fStartPoint);
        if (g_fStartDist > 0.0) {
            g_fStartExtraDist = 500.0;
        } else {
            g_fStartPoint = NULL_VECTOR;
            g_fStartDist = -1.0;
            g_fStartExtraDist = -1.0;
        }
        g_fEndPoint = NULL_VECTOR;
        g_fEndDist = -1.0;
        LogMessage("[MI] MapInfo for %s is missing.", szCurMap);
    }
}

float FindStartPointHeuristic(float fResult[3]) {
    float fKitOrigin[4][3], fAverageOrigin[3];
    int   iKitsCount = 0, iEntityTotalCount = GetEntityCount();
    char  szEntityName[128];
    for (int iEntity = (MaxClients + 1); iEntity <= iEntityTotalCount && iKitsCount < 4; iEntity++) {
        if (!IsValidEdict(iEntity))
            continue;
        GetEdictClassname(iEntity, szEntityName, sizeof(szEntityName));
        if (strcmp(szEntityName, "weapon_first_aid_kit_spawn") == 0) {
            GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fKitOrigin[iKitsCount]);
            fAverageOrigin[0] += fKitOrigin[iKitsCount][0];
            fAverageOrigin[1] += fKitOrigin[iKitsCount][1];
            fAverageOrigin[2] += fKitOrigin[iKitsCount][2];
            iKitsCount++;
        }
    }
    if (iKitsCount < 4) return -1.0;
    ScaleVector(fAverageOrigin, 0.25);
    float fGreatestDist, fTempDist;
    for (int i = 0; i < 4; i++) {
        fTempDist = GetVectorDistance(fAverageOrigin, fKitOrigin[i]);
        if (fTempDist > fGreatestDist)
            fGreatestDist = fTempDist;
    }
    fResult = fAverageOrigin;
    return fGreatestDist + 1.0;
}

/**
 * Determines if an entity is in a start or end saferoom (based on mapinfo.txt or automatically generated info)
 *
 * @param iEntity       The entity to be checked
 * @return              eSaferoom_Neither if entity is not in any saferoom
 *                      eSaferoom_Start if it is in the starting saferoom
 *                      eSaferoom_End if it is in the ending saferoom
 *                      eSaferoom_Start | eSaferoom_End if it is in both saferooms (probably won't happen)
 */
stock int IsEntityInSaferoom(int iEntity) {
    int   iResult = eSaferoom_Neither;
    float fOrigins[3];
    GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fOrigins);
    if ((GetVectorDistance(fOrigins, g_fStartPoint) <= (g_fStartExtraDist > g_fStartDist ? g_fStartExtraDist : g_fStartDist)))
        iResult |= eSaferoom_Start;
    if (GetVectorDistance(fOrigins, g_fEndPoint) <= g_fEndDist)
        iResult |= eSaferoom_End;
    return iResult;
}