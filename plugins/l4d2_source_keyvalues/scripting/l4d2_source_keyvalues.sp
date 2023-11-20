#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

Handle g_hSDKGetName;
Handle g_hSDKSetName;
Handle g_hSDKGetDataType;
Handle g_hSDKGetString;
Handle g_hSDKSetString;
Handle g_hSDKSetStringValue;
Handle g_hSDKGetInt;
Handle g_hSDKSetInt;
Handle g_hSDKGetFloat;
Handle g_hSDKSetFloat;
Handle g_hSDKGetPtr;
Handle g_hSDKFindKey;
Handle g_hSDKGetFirstSubKey;
Handle g_hSDKGetNextKey;
Handle g_hSDKGetFirstTrueSubKey;
Handle g_hSDKGetNextTrueSubKey;
Handle g_hSDKGetFirstValue;
Handle g_hSDKGetNextValue;
Handle g_hSDKSaveToFile;
Handle g_hSDKGetAllMissions;

Address g_pFileSystem;
Address g_pMatchExtL4D;

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    if (GetEngineVersion() != Engine_Left4Dead2) {
        strcopy(szError, iErrMax, "Plugin only supports L4D2!");
        return APLRes_SilentFailure;
    }

    CreateNative("SourceKeyValues.IsNull",             Native_IsNull);
    CreateNative("SourceKeyValues.GetName",            Native_GetName);
    CreateNative("SourceKeyValues.SetName",            Native_SetName);
    CreateNative("SourceKeyValues.GetDataType",        Native_GetDataType);
    CreateNative("SourceKeyValues.GetString",          Native_GetString);
    CreateNative("SourceKeyValues.SetString",          Native_SetString);
    CreateNative("SourceKeyValues.SetStringValue",     Native_SetStringValue);
    CreateNative("SourceKeyValues.GetInt",             Native_GetInt);
    CreateNative("SourceKeyValues.SetInt",             Native_SetInt);
    CreateNative("SourceKeyValues.GetFloat",           Native_GetFloat);
    CreateNative("SourceKeyValues.SetFloat",           Native_SetFloat);
    CreateNative("SourceKeyValues.GetPtr",             Native_GetPtr);
    CreateNative("SourceKeyValues.FindKey",            Native_FindKey);
    CreateNative("SourceKeyValues.GetFirstSubKey",     Native_GetFirstSubKey);
    CreateNative("SourceKeyValues.GetNextKey",         Native_GetNextKey);
    CreateNative("SourceKeyValues.GetFirstTrueSubKey", Native_GetFirstTrueSubKey);
    CreateNative("SourceKeyValues.GetNextTrueSubKey",  Native_GetNextTrueSubKey);
    CreateNative("SourceKeyValues.GetFirstValue",      Native_GetFirstValue);
    CreateNative("SourceKeyValues.GetNextValue",       Native_GetNextValue);
    CreateNative("SourceKeyValues.SaveToFile",         Native_SaveToFile);
    CreateNative("SourceKeyValues.GetAllMissions",     Native_GetAllMissions);

    RegPluginLibrary("l4d2_source_keyvalues");
    return APLRes_Success;
}

public Plugin myinfo = {
    name        = "L4D2 Source KeyValues",
    author      = "fdxx",
    description = "Call the game's own KeyValues function",
    version     = "0.1",
    url         = "https://github.com/fdxx/l4d2_source_keyvalues"
}

public void OnPluginStart() {
    Init();
}

// public native bool IsNull();
any Native_IsNull(Handle hPlugin, int iNumParams) {
    return view_as<Address>(GetNativeCell(1)) == Address_Null;
}

// public native void GetName(char[] szName, int iMaxLength);
any Native_GetName(Handle hPlugin, int iNumParams) {
    int iMaxLength = GetNativeCell(3);
    char[] szName = new char[iMaxLength];
    SDKCall(g_hSDKGetName, GetNativeCell(1), szName, iMaxLength);
    SetNativeString(2, szName, iMaxLength);
    return 0;
}

// public native void SetName(const char[] szSetName);
any Native_SetName(Handle hPlugin, int iNumParams) {
    int iMaxLength;
    GetNativeStringLength(2, iMaxLength);
    iMaxLength += 1;
    char[] szSetName = new char[iMaxLength];
    GetNativeString(2, szSetName, iMaxLength);
    SDKCall(g_hSDKSetName, GetNativeCell(1), szSetName);
    return 0;
}

// public native DataType GetDataType(const char[] szKey);
any Native_GetDataType(Handle hPlugin, int iNumParams) {
    if (!IsNativeParamNullString(2)) {
        int iMaxLength;
        GetNativeStringLength(2, iMaxLength);
        iMaxLength += 1;
        char[] szKey = new char[iMaxLength];
        GetNativeString(2, szKey, iMaxLength);
        return SDKCall(g_hSDKGetDataType, GetNativeCell(1), szKey);
    }
    return SDKCall(g_hSDKGetDataType, GetNativeCell(1), NULL_STRING);
}

// public native void GetString(const char[] szKey, char[] szValue, int iMaxLength, const char[] szDefValue = "");
any Native_GetString(Handle hPlugin, int iNumParams) {
    int iKeyLength, iValueLength, iDefValueLength;

    iValueLength = GetNativeCell(4);
    char[] szValue = new char[iValueLength];

    GetNativeStringLength(5, iDefValueLength);
    iDefValueLength += 1;
    char[] szDefValue = new char[iDefValueLength];
    GetNativeString(5, szDefValue, iDefValueLength);

    if (!IsNativeParamNullString(2)) {
        GetNativeStringLength(2, iKeyLength);
        iKeyLength += 1;
        char[] szKey = new char[iKeyLength];
        GetNativeString(2, szKey, iKeyLength);
        SDKCall(g_hSDKGetString, GetNativeCell(1), szValue, iValueLength, szKey, szDefValue);
    } else {
        SDKCall(g_hSDKGetString, GetNativeCell(1), szValue, iValueLength, NULL_STRING, szDefValue);
    }

    SetNativeString(3, szValue, iValueLength);
    return 0;
}

// public native void SetString(const char[] szKey, const char[] szValue);
any Native_SetString(Handle hPlugin, int iNumParams) {
    int iKeyLength, iValueLength;

    GetNativeStringLength(2, iKeyLength);
    iKeyLength += 1;
    char[] szKey = new char[iKeyLength];
    GetNativeString(2, szKey, iKeyLength);

    GetNativeStringLength(3, iValueLength);
    iValueLength += 1;
    char[] szValue = new char[iValueLength];
    GetNativeString(3, szValue, iValueLength);

    SDKCall(g_hSDKSetString, GetNativeCell(1), szKey, szValue);
    return 0;
}

// public native void SetStringValue(const char[] szValue);
any Native_SetStringValue(Handle hPlugin, int iNumParams) {
    int iMaxLength;
    GetNativeStringLength(2, iMaxLength);
    iMaxLength += 1;
    char[] szValue = new char[iMaxLength];
    GetNativeString(2, szValue, iMaxLength);
    SDKCall(g_hSDKSetStringValue, GetNativeCell(1), szValue);
    return 0;
}

// public native int GetInt(const char[] szKey, int iDefValue = 0);
any Native_GetInt(Handle hPlugin, int iNumParams) {
    if (!IsNativeParamNullString(2)) {
        int iKeyLength;
        GetNativeStringLength(2, iKeyLength);
        iKeyLength += 1;
        char[] szKey = new char[iKeyLength];
        GetNativeString(2, szKey, iKeyLength);
        return SDKCall(g_hSDKGetInt, GetNativeCell(1), szKey, GetNativeCell(3));
    }
    return SDKCall(g_hSDKGetInt, GetNativeCell(1), NULL_STRING, GetNativeCell(3));
}

// public native void SetInt(const char[] szKey, int iValue);
any Native_SetInt(Handle hPlugin, int iNumParams) {
    int iKeyLength;
    GetNativeStringLength(2, iKeyLength);
    iKeyLength += 1;
    char[] szKey = new char[iKeyLength];
    GetNativeString(2, szKey, iKeyLength);
    SDKCall(g_hSDKSetInt, GetNativeCell(1), szKey, GetNativeCell(3));
    return 0;
}

// public native float GetFloat(const char[] szKey, float fDefValue = 0.0);
any Native_GetFloat(Handle hPlugin, int iNumParams) {
    if (!IsNativeParamNullString(2)) {
        int iKeyLength;
        GetNativeStringLength(2, iKeyLength);
        iKeyLength += 1;
        char[] szKey = new char[iKeyLength];
        GetNativeString(2, szKey, iKeyLength);
        return SDKCall(g_hSDKGetFloat, GetNativeCell(1), szKey, GetNativeCell(3));
    }
    return SDKCall(g_hSDKGetFloat, GetNativeCell(1), NULL_STRING, GetNativeCell(3));
}

// public native void SetFloat(const char[] szKey, float fValue);
any Native_SetFloat(Handle hPlugin, int iNumParams) {
    int iKeyLength;
    GetNativeStringLength(2, iKeyLength);
    iKeyLength += 1;
    char[] szKey = new char[iKeyLength];
    GetNativeString(2, szKey, iKeyLength);
    SDKCall(g_hSDKSetFloat, GetNativeCell(1), szKey, GetNativeCell(3));
    return 0;
}

// public native Address GetPtr(const char[] szKey, Address pDefValue = Address_Null);
any Native_GetPtr(Handle hPlugin, int iNumParams) {
    if (!IsNativeParamNullString(2)) {
        int iKeyLength;
        GetNativeStringLength(2, iKeyLength);
        iKeyLength += 1;
        char[] szKey = new char[iKeyLength];
        GetNativeString(2, szKey, iKeyLength);
        return SDKCall(g_hSDKGetPtr, GetNativeCell(1), szKey, GetNativeCell(3));
    }
    return SDKCall(g_hSDKGetPtr, GetNativeCell(1), NULL_STRING, GetNativeCell(3));
}

// public native SourceKeyValues FindKey(const char[] szKey, bool bCreate = false);
any Native_FindKey(Handle hPlugin, int iNumParams) {
    int iKeyLength;
    GetNativeStringLength(2, iKeyLength);
    iKeyLength += 1;
    char[] szKey = new char[iKeyLength];
    GetNativeString(2, szKey, iKeyLength);
    if (GetNativeCell(1)) return SDKCall(g_hSDKFindKey, GetNativeCell(1), szKey, GetNativeCell(3));
    return 0;
}

// public native SourceKeyValues GetFirstSubKey();
any Native_GetFirstSubKey(Handle hPlugin, int iNumParams) {
    if (GetNativeCell(1)) return SDKCall(g_hSDKGetFirstSubKey, GetNativeCell(1));
    return 0;
}

// public native SourceKeyValues GetNextKey();
any Native_GetNextKey(Handle hPlugin, int iNumParams) {
    if (GetNativeCell(1)) return SDKCall(g_hSDKGetNextKey, GetNativeCell(1));
    return 0;
}

// public native SourceKeyValues GetFirstTrueSubKey();
any Native_GetFirstTrueSubKey(Handle hPlugin, int iNumParams) {
    if (GetNativeCell(1)) return SDKCall(g_hSDKGetFirstTrueSubKey, GetNativeCell(1));
    return 0;
}

// public native SourceKeyValues GetNextTrueSubKey();
any Native_GetNextTrueSubKey(Handle hPlugin, int iNumParams) {
    if (GetNativeCell(1)) return SDKCall(g_hSDKGetNextTrueSubKey, GetNativeCell(1));
    return 0;
}

// public native SourceKeyValues GetFirstValue();
any Native_GetFirstValue(Handle hPlugin, int iNumParams) {
    if (GetNativeCell(1)) return SDKCall(g_hSDKGetFirstValue, GetNativeCell(1));
    return 0;
}

// public native SourceKeyValues GetNextValue();
any Native_GetNextValue(Handle hPlugin, int iNumParams) {
    if (GetNativeCell(1)) return SDKCall(g_hSDKGetNextValue, GetNativeCell(1));
    return 0;
}

// public native bool SaveToFile(const char[] szFile);
any Native_SaveToFile(Handle hPlugin, int iNumParams) {
    int iLength;
    GetNativeStringLength(2, iLength);
    iLength += 1;
    char[] szFile = new char[iLength];
    GetNativeString(2, szFile, iLength);
    return SDKCall(g_hSDKSaveToFile, GetNativeCell(1), g_pFileSystem, szFile, NULL_STRING);
}

// public native SourceKeyValues GetAllMissions();
any Native_GetAllMissions(Handle hPlugin, int iNumParams) {
    return SDKCall(g_hSDKGetAllMissions, g_pMatchExtL4D);
}

void Init() {
    char szBuffer[128];
    strcopy(szBuffer, sizeof(szBuffer), "l4d2_source_keyvalues");
    GameData gmConf = new GameData(szBuffer);
    if (gmConf == null) SetFailState("Failed to load \"%s.txt\" file", szBuffer);

    // ------- Address -------
    strcopy(szBuffer, sizeof(szBuffer), "fileSystem");
    Address fileSystem = gmConf.GetAddress(szBuffer);
    if (fileSystem == Address_Null) SetFailState("Failed to get address: \"%s\"", szBuffer);
    g_pFileSystem = fileSystem + view_as<Address>(4);

    strcopy(szBuffer, sizeof(szBuffer), "MatchExtL4D");
    g_pMatchExtL4D = gmConf.GetAddress(szBuffer);
    if (g_pMatchExtL4D == Address_Null) SetFailState("Failed to get address: \"%s\"", szBuffer);

    // ------- Prep SDKCall -------
    strcopy(szBuffer, sizeof(szBuffer), "KeyValues::GetName");
    StartPrepSDKCall(SDKCall_Raw);
    if (!PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, szBuffer))
        SetFailState("Failed to find signature: \"%s\"", szBuffer);
    PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Pointer);
    g_hSDKGetName = EndPrepSDKCall();
    if (g_hSDKGetName == null) SetFailState("Failed to create SDKCall: \"%s\"", szBuffer);

    strcopy(szBuffer, sizeof(szBuffer), "KeyValues::SetName");
    StartPrepSDKCall(SDKCall_Raw);
    if (!PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, szBuffer))
        SetFailState("Failed to find signature: \"%s\"", szBuffer);
    PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
    g_hSDKSetName = EndPrepSDKCall();
    if (g_hSDKSetName == null) SetFailState("Failed to create SDKCall: \"%s\"", szBuffer);

    strcopy(szBuffer, sizeof(szBuffer), "KeyValues::GetDataType");
    StartPrepSDKCall(SDKCall_Raw);
    if (!PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, szBuffer))
        SetFailState("Failed to find signature: \"%s\"", szBuffer);
    PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    g_hSDKGetDataType = EndPrepSDKCall();
    if (g_hSDKGetDataType == null) SetFailState("Failed to create SDKCall: \"%s\"", szBuffer);

    strcopy(szBuffer, sizeof(szBuffer), "KeyValues::GetString");
    StartPrepSDKCall(SDKCall_Raw);
    if (!PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, szBuffer))
        SetFailState("Failed to find signature: \"%s\"", szBuffer);
    PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
    PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
    PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Pointer);
    g_hSDKGetString = EndPrepSDKCall();
    if (g_hSDKGetString == null) SetFailState("Failed to create SDKCall: \"%s\"", szBuffer);

    strcopy(szBuffer, sizeof(szBuffer), "KeyValues::SetString");
    StartPrepSDKCall(SDKCall_Raw);
    if (!PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, szBuffer))
        SetFailState("Failed to find signature: \"%s\"", szBuffer);
    PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
    PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
    g_hSDKSetString = EndPrepSDKCall();
    if (g_hSDKSetString == null) SetFailState("Failed to create SDKCall: \"%s\"", szBuffer);

    strcopy(szBuffer, sizeof(szBuffer), "KeyValues::SetStringValue");
    StartPrepSDKCall(SDKCall_Raw);
    if (!PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, szBuffer))
        SetFailState("Failed to find signature: \"%s\"", szBuffer);
    PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
    g_hSDKSetStringValue = EndPrepSDKCall();
    if (g_hSDKSetStringValue == null) SetFailState("Failed to create SDKCall: \"%s\"", szBuffer);

    strcopy(szBuffer, sizeof(szBuffer), "KeyValues::GetInt");
    StartPrepSDKCall(SDKCall_Raw);
    if (!PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, szBuffer))
        SetFailState("Failed to find signature: \"%s\"", szBuffer);
    PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    g_hSDKGetInt = EndPrepSDKCall();
    if (g_hSDKGetInt == null) SetFailState("Failed to create SDKCall: \"%s\"", szBuffer);

    strcopy(szBuffer, sizeof(szBuffer), "KeyValues::SetInt");
    StartPrepSDKCall(SDKCall_Raw);
    if (!PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, szBuffer))
        SetFailState("Failed to find signature: \"%s\"", szBuffer);
    PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    g_hSDKSetInt = EndPrepSDKCall();
    if (g_hSDKSetInt == null) SetFailState("Failed to create SDKCall: \"%s\"", szBuffer);

    strcopy(szBuffer, sizeof(szBuffer), "KeyValues::GetFloat");
    StartPrepSDKCall(SDKCall_Raw);
    if (!PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, szBuffer))
        SetFailState("Failed to find signature: \"%s\"", szBuffer);
    PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
    PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
    PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
    g_hSDKGetFloat = EndPrepSDKCall();
    if (g_hSDKGetFloat == null) SetFailState("Failed to create SDKCall: \"%s\"", szBuffer);

    strcopy(szBuffer, sizeof(szBuffer), "KeyValues::SetFloat");
    StartPrepSDKCall(SDKCall_Raw);
    if (!PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, szBuffer))
        SetFailState("Failed to find signature: \"%s\"", szBuffer);
    PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
    PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
    g_hSDKSetFloat = EndPrepSDKCall();
    if (g_hSDKSetFloat == null) SetFailState("Failed to create SDKCall: \"%s\"", szBuffer);

    strcopy(szBuffer, sizeof(szBuffer), "KeyValues::GetPtr");
    StartPrepSDKCall(SDKCall_Raw);
    if (!PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, szBuffer))
        SetFailState("Failed to find signature: \"%s\"", szBuffer);
    PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Pointer);
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    g_hSDKGetPtr = EndPrepSDKCall();
    if (g_hSDKGetPtr == null) SetFailState("Failed to create SDKCall: \"%s\"", szBuffer);

    strcopy(szBuffer, sizeof(szBuffer), "KeyValues::FindKey");
    StartPrepSDKCall(SDKCall_Raw);
    if (!PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, szBuffer))
        SetFailState("Failed to find signature: \"%s\"", szBuffer);
    PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
    PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    g_hSDKFindKey = EndPrepSDKCall();
    if (g_hSDKFindKey == null) SetFailState("Failed to create SDKCall: \"%s\"", szBuffer);

    strcopy(szBuffer, sizeof(szBuffer), "KeyValues::GetFirstSubKey");
    StartPrepSDKCall(SDKCall_Raw);
    if (!PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, szBuffer))
        SetFailState("Failed to find signature: \"%s\"", szBuffer);
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    g_hSDKGetFirstSubKey = EndPrepSDKCall();
    if (g_hSDKGetFirstSubKey == null) SetFailState("Failed to create SDKCall: \"%s\"", szBuffer);

    strcopy(szBuffer, sizeof(szBuffer), "KeyValues::GetNextKey");
    StartPrepSDKCall(SDKCall_Raw);
    if (!PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, szBuffer))
        SetFailState("Failed to find signature: \"%s\"", szBuffer);
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    g_hSDKGetNextKey = EndPrepSDKCall();
    if (g_hSDKGetNextKey == null) SetFailState("Failed to create SDKCall: \"%s\"", szBuffer);

    strcopy(szBuffer, sizeof(szBuffer), "KeyValues::GetFirstTrueSubKey");
    StartPrepSDKCall(SDKCall_Raw);
    if (!PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, szBuffer))
        SetFailState("Failed to find signature: \"%s\"", szBuffer);
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    g_hSDKGetFirstTrueSubKey = EndPrepSDKCall();
    if (g_hSDKGetFirstTrueSubKey == null) SetFailState("Failed to create SDKCall: \"%s\"", szBuffer);

    strcopy(szBuffer, sizeof(szBuffer), "KeyValues::GetNextTrueSubKey");
    StartPrepSDKCall(SDKCall_Raw);
    if (!PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, szBuffer))
        SetFailState("Failed to find signature: \"%s\"", szBuffer);
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    g_hSDKGetNextTrueSubKey = EndPrepSDKCall();
    if (g_hSDKGetNextTrueSubKey == null) SetFailState("Failed to create SDKCall: \"%s\"", szBuffer);

    strcopy(szBuffer, sizeof(szBuffer), "KeyValues::GetFirstValue");
    StartPrepSDKCall(SDKCall_Raw);
    if (!PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, szBuffer))
        SetFailState("Failed to find signature: \"%s\"", szBuffer);
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    g_hSDKGetFirstValue = EndPrepSDKCall();
    if (g_hSDKGetFirstValue == null) SetFailState("Failed to create SDKCall: \"%s\"", szBuffer);

    strcopy(szBuffer, sizeof(szBuffer), "KeyValues::GetNextValue");
    StartPrepSDKCall(SDKCall_Raw);
    if (!PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, szBuffer))
        SetFailState("Failed to find signature: \"%s\"", szBuffer);
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    g_hSDKGetNextValue = EndPrepSDKCall();
    if (g_hSDKGetNextValue == null) SetFailState("Failed to create SDKCall: \"%s\"", szBuffer);

    strcopy(szBuffer, sizeof(szBuffer), "KeyValues::SaveToFile");
    StartPrepSDKCall(SDKCall_Raw);
    if (!PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, szBuffer))
        SetFailState("Failed to find signature: \"%s\"", szBuffer);
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
    PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
    PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
    g_hSDKSaveToFile = EndPrepSDKCall();
    if (g_hSDKSaveToFile == null) SetFailState("Failed to create SDKCall: \"%s\"", szBuffer);

    StartPrepSDKCall(SDKCall_Raw);
    PrepSDKCall_SetVirtual(0);
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    g_hSDKGetAllMissions = EndPrepSDKCall();
    if (g_hSDKGetAllMissions == null) SetFailState("Failed to create SDKCall: MatchExtL4D::GetAllMissions");

    delete gmConf;
}