#if defined __MAPINFO_MODULE__
    #endinput
#endif
#define __MAPINFO_MODULE__

static int   MI_iIsInEditMode[MAXPLAYERS + 1];

static bool  MI_bMapDataAvailable;

static float MI_vStartPoint[3];
static float MI_vEndPoint[3];
static float MI_fStartDist;
static float MI_fStartExtraDist;
static float MI_fEndDist;
static float MI_vTempLoc[MAXPLAYERS + 1][3];

KeyValues MI_kvData;

void MI_OnModuleStart() {
    MI_KV_Load();
    RegAdminCmd("confogl_midata_save",   MI_KV_Cmd_Save,    ADMFLAG_CONFIG);
    RegAdminCmd("confogl_save_location", MI_KV_Cmd_SaveLoc, ADMFLAG_CONFIG);
    HookEvent("player_disconnect", MI_Event_PlayerDisconnect);
}

void MI_APL() {
    CreateNative("LGO_IsMapDataAvailable", native_IsMapDataAvailable);
    CreateNative("LGO_GetMapValueInt",     native_GetMapValueInt);
    CreateNative("LGO_GetMapValueFloat",   native_GetMapValueFloat);
    CreateNative("LGO_GetMapValueVector",  native_GetMapValueVector);
    CreateNative("LGO_GetMapValueString",  native_GetMapValueString);
    CreateNative("LGO_CopyMapSubsection",  native_CopyMapSubsection);
}

void MI_OnMapStart() {
    MI_KV_UpdateMapInfo();
}

void MI_OnMapEnd() {
    MI_kvData.Rewind();
    MI_bMapDataAvailable = false;
    for (int i = 1; i <= MaxClients; i++) {
        MI_iIsInEditMode[i] = 0;
    }
}

void MI_Event_PlayerDisconnect(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient && iClient <= MaxClients)
        MI_iIsInEditMode[iClient] = 0;
}

Action MI_KV_Cmd_Save(int iClient, int iArgs) {
    char szCurMap[128];
    GetCurrentMap(szCurMap, sizeof(szCurMap));
    if (MI_kvData.JumpToKey(szCurMap, true)) {
        MI_kvData.SetVector("start_point",     MI_vStartPoint);
        MI_kvData.SetFloat("start_dist",       MI_fStartDist);
        MI_kvData.SetFloat("start_extra_dist", MI_fStartExtraDist);
        char szNameBuff[PLATFORM_MAX_PATH];
        BuildConfigPath(szNameBuff, sizeof(szNameBuff), "mapinfo.txt");
        MI_kvData.Rewind();
        MI_kvData.ExportToFile(szNameBuff);
        ReplyToCommand(iClient, "%s has been added to %s.", szCurMap, szNameBuff);
    }
    return Plugin_Handled;
}

Action MI_KV_Cmd_SaveLoc(int iClient, int iArgs) {
    bool bUpdateInfo;
    char szCurMap[128];
    GetCurrentMap(szCurMap, sizeof(szCurMap));

    if (!MI_iIsInEditMode[iClient]) {
        if (!iArgs) {
            ReplyToCommand(iClient, "Move to the location of the medkits, then enter the point type (start_point or end_point)");
            return Plugin_Handled;
        }

        char szBuffer[16];
        GetCmdArg(1, szBuffer, sizeof(szBuffer));

        if (strcmp(szBuffer, "start_point", true) == 0) {
            MI_iIsInEditMode[iClient] = 1;
            ReplyToCommand(iClient, "Move a few feet from the medkits and enter this command again to set the start_dist for this point");
        } else if (strcmp(szBuffer, "end_point", true) == 0) {
            MI_iIsInEditMode[iClient] = 2;
            ReplyToCommand(iClient, "Move to the farthest point in the saferoom and enter this command again to set the end_dist for this point");
        } else {
            ReplyToCommand(iClient, "Please enter the location type: start_point, end_point");
            return Plugin_Handled;
        }

        if (MI_kvData.JumpToKey(szCurMap, true)) {
            GetClientAbsOrigin(iClient, MI_vTempLoc[iClient]);
            MI_kvData.SetVector(szBuffer, MI_vTempLoc[iClient]);
        }

        bUpdateInfo = true;
    } else if (MI_iIsInEditMode[iClient] == 1) {
        float vDistLoc[3];
        GetClientAbsOrigin(iClient, vDistLoc);

        float fDistance;
        fDistance = GetVectorDistance(vDistLoc, MI_vTempLoc[iClient]);

        MI_iIsInEditMode[iClient] = 3;
        if (MI_kvData.JumpToKey(szCurMap, true))
            MI_kvData.SetFloat("start_dist", fDistance);
        ReplyToCommand(iClient, "Move to the farthest point in the saferoom and enter this command again to set start_extra_dist for this point");
        bUpdateInfo = true;
    } else if (MI_iIsInEditMode[iClient] == 2) {
        float vDistLoc[3];
        GetClientAbsOrigin(iClient, vDistLoc);

        float fDistance;
        fDistance = GetVectorDistance(vDistLoc, MI_vTempLoc[iClient]);
        MI_iIsInEditMode[iClient] = 0;
        if (MI_kvData.JumpToKey(szCurMap, true))
            MI_kvData.SetFloat("end_dist", fDistance);
        bUpdateInfo = true;
    } else if (MI_iIsInEditMode[iClient] == 3) {
        float vDistLoc[3];
        GetClientAbsOrigin(iClient, vDistLoc);

        float fDistance;
        fDistance = GetVectorDistance(vDistLoc, MI_vTempLoc[iClient]);
        MI_iIsInEditMode[iClient] = 0;
        if (MI_kvData.JumpToKey(szCurMap, true))
            MI_kvData.SetFloat("start_extra_dist", fDistance);
        bUpdateInfo = true;
    }
    if (bUpdateInfo) {
        char szNameBuff[PLATFORM_MAX_PATH];
        BuildConfigPath(szNameBuff, sizeof(szNameBuff), "mapinfo.txt");
        MI_kvData.Rewind();
        MI_kvData.ExportToFile(szNameBuff);
        ReplyToCommand(iClient, "mapinfo.txt has been updated!");
    }

    return Plugin_Handled;
}

void MI_KV_Close() {
    if (MI_kvData == null)
        return;
    delete MI_kvData;
}

void MI_KV_Load() {
    char szNameBuff[PLATFORM_MAX_PATH];
    MI_kvData = new KeyValues("MapInfo");
    BuildConfigPath(szNameBuff, sizeof(szNameBuff), "mapinfo.txt");
    // Build our filepath
    if (!MI_kvData.ImportFromFile(szNameBuff)) {
        LogError("[MI] Couldn't load MapInfo data!");
        MI_KV_Close();
    }
}

void MI_KV_UpdateMapInfo() {
    char szCurMap[128];
    GetCurrentMap(szCurMap, sizeof(szCurMap));

    if (MI_kvData.JumpToKey(szCurMap)) {
        MI_kvData.GetVector("start_point", MI_vStartPoint);
        MI_kvData.GetVector("end_point",   MI_vEndPoint);
        MI_fStartDist      = MI_kvData.GetFloat("start_dist");
        MI_fStartExtraDist = MI_kvData.GetFloat("start_extra_dist");
        MI_fEndDist        = MI_kvData.GetFloat("end_dist");
        MI_bMapDataAvailable = true;
    } else {
        MI_bMapDataAvailable = false;
        MI_fStartDist = FindStartPointHeuristic(MI_vStartPoint);
        // This is the largest Start Extra Dist we've encountered;
        // May be too much
        if (MI_fStartDist > 0.0) {
            MI_fStartExtraDist = 500.0;
        } else {
            ZeroVector(MI_vStartPoint);
            MI_fStartDist = -1.0;
            MI_fStartExtraDist = -1.0;
        }

        ZeroVector(MI_vEndPoint);
        MI_fEndDist = -1.0;
        LogMessage("[MI] MapInfo for %s is missing.", szCurMap);
    }
}

float FindStartPointHeuristic(float vResult[3]) {
    int   iKits;
    float vKitOrigin[4][3];
    float vAverageOrigin[3];
    char  szEntClass[128];
    int   iEntCount = GetEntityCount();
    for (int iEntity = 1; iEntity <= iEntCount && iKits < 4; iEntity++) {
        if (!IsValidEdict(iEntity) || !IsValidEntity(iEntity))
            continue;
        GetEdictClassname(iEntity, szEntClass, sizeof(szEntClass));
        if (strcmp(szEntClass, "weapon_first_aid_kit_spawn") == 0) {
            GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", vKitOrigin[iKits]);
            AddToVector(vAverageOrigin, vKitOrigin[iKits]);
            iKits++;
        }
    }
    if (iKits < 4)
        return -1.0;
    ScaleVector(vAverageOrigin, 0.25);
    float fGreatestDist;
    float fTempDist;
    for (int i; i < 4; i++) {
        fTempDist = GetVectorDistance(vAverageOrigin, vKitOrigin[i]);
        if (fTempDist > fGreatestDist)
            fGreatestDist = fTempDist;
    }
    CopyVector(vResult, vAverageOrigin);
    return fGreatestDist + 1.0;
}

// Old Functions (Avoid using these, use the ones below)
float GetMapStartOriginX() {
    return MI_vStartPoint[0];
}

float GetMapStartOriginY() {
    return MI_vStartPoint[1];
}

float GetMapStartOriginZ() {
    return MI_vStartPoint[2];
}

float GetMapEndOriginX() {
    return MI_vEndPoint[0];
}

float GetMapEndOriginY() {
    return MI_vEndPoint[1];
}

float GetMapEndOriginZ() {
    return MI_vEndPoint[2];
}

// New Super Awesome Functions!!!
bool IsMapFinale() {
    return L4D_IsMissionFinalMap();
}

bool IsMapDataAvailable() {
    return MI_bMapDataAvailable;
}

/**
 * Determines if an entity is in a start or end saferoom (based on mapinfo.txt or automatically generated info)
 *
 * @param iEnt          The entity to be checked
 * @param iSaferoom     START_SAFEROOM (1) = Start saferoom, END_SAFEROOM (2) = End saferoom (including finale area), 3 = both
 * @return              True if it is one of the specified saferoom(s)
 *                      False if it is not in the specified saferoom(s)
 *                      False if no saferoom specified
 */
bool IsEntityInSaferoom(int iEnt, int iSaferoom = 3) {
    float vOrigin[3];
    GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", vOrigin);
    if ((iSaferoom & START_SAFEROOM) && (GetVectorDistance(vOrigin, MI_vStartPoint) <= (MI_fStartExtraDist > MI_fStartDist ? MI_fStartExtraDist : MI_fStartDist))) {
        return true;
    } else if ((iSaferoom & END_SAFEROOM) && (GetVectorDistance(vOrigin, MI_vEndPoint) <= MI_fEndDist)) {
        return true;
    } else {
        return false;
    }
}

int GetMapValueInt(const char[] szKey, int iDefValue = 0) {
    return MI_kvData.GetNum(szKey, iDefValue);
}

float GetMapValueFloat(const char[] szKey, float fDefValue = 0.0) {
    return MI_kvData.GetFloat(szKey, fDefValue);
}

void GetMapValueVector(const char[] szKey, float vVector[3], float vDefValue[3] = NULL_VECTOR) {
    MI_kvData.GetVector(szKey, vVector, vDefValue);
}

void GetMapValueString(const char[] szKey, char[] szValue, int iMaxLength, const char[] szDefValue) {
    MI_kvData.GetString(szKey, szValue, iMaxLength, szDefValue);
}

void CopyMapSubsection(KeyValues kv, const char[] szSection) {
    if (MI_kvData.JumpToKey(szSection, false)) {
        kv.Import(MI_kvData);
        MI_kvData.GoBack();
    }
}

float GetMapEndDist() {
    return MI_fEndDist;
}

float GetMapStartDist() {
    return MI_fStartDist;
}

float GetMapStartExtraDist() {
    return MI_fStartExtraDist;
}

int native_IsMapDataAvailable(Handle hPlugin, int iNumParams) {
    return IsMapDataAvailable();
}

int native_GetMapValueInt(Handle hPlugin, int iNumParams) {
    int iLength;
    GetNativeStringLength(1, iLength);

    char[] szKey = new char[iLength + 1];
    GetNativeString(1, szKey, iLength + 1);

    int iDefVal = GetNativeCell(2);
    return GetMapValueInt(szKey, iDefVal);
}

int native_GetMapValueFloat(Handle hPlugin, int iNumParams) {
    int iLength;
    GetNativeStringLength(1, iLength);

    char[] szKey = new char[iLength + 1];
    GetNativeString(1, szKey, iLength + 1);

    float fDefVal = GetNativeCell(2);
    return view_as<int>(GetMapValueFloat(szKey, fDefVal));
}

int native_GetMapValueVector(Handle hPlugin, int iNumParams) {
    int iLength;
    GetNativeStringLength(1, iLength);

    char[] szKey = new char[iLength + 1];
    GetNativeString(1, szKey, iLength + 1);

    float vDefVal[3];
    GetNativeArray(3, vDefVal, 3);

    float vValue[3];
    GetMapValueVector(szKey, vValue, vDefVal);
    SetNativeArray(2, vValue, 3);
    return 1;
}

int native_GetMapValueString(Handle hPlugin, int iNumParams) {
    int iLength;
    GetNativeStringLength(1, iLength);

    char[] szKey = new char[iLength + 1];
    GetNativeString(1, szKey, iLength + 1);
    GetNativeStringLength(4, iLength);

    char[] szDefVal = new char[iLength + 1];
    GetNativeString(4, szDefVal, iLength + 1);
    iLength = GetNativeCell(3);

    char[] szBuf = new char[iLength + 1];
    GetMapValueString(szKey, szBuf, iLength, szDefVal);
    SetNativeString(2, szBuf, iLength);
    return 1;
}

int native_CopyMapSubsection(Handle hPlugin, int iNumParams) {
    int iLength;
    GetNativeStringLength(2, iLength);

    char[] szKey = new char[iLength + 1];
    GetNativeString(2, szKey, iLength + 1);

    KeyValues kv = GetNativeCell(1);
    CopyMapSubsection(kv, szKey);
    return 1;
}