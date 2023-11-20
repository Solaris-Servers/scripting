#if defined __NATIVES_AND_FORWARDS__
    #endinput
#endif
#define __NATIVES_AND_FORWARDS__

GlobalForward fwdSceneStage;
GlobalForward fwdVocalizeCommand;

void CreateNativesAndForwards() {
    // Natives
    CreateNative("GetSceneStage",          SP_GetSceneStage);
    CreateNative("GetSceneStartTimeStamp", SP_GetSceneStartTimeStamp);
    CreateNative("GetActorFromScene",      SP_GetSceneActor);
    CreateNative("GetSceneFromActor",      SP_GetActorScene);
    CreateNative("GetSceneInitiator",      SP_GetSceneInitiator);
    CreateNative("GetSceneFile",           SP_GetSceneFile);
    CreateNative("GetSceneVocalize",       SP_GetSceneVocalize);
    CreateNative("GetScenePreDelay",       SP_GetScenePreDelay);
    CreateNative("SetScenePreDelay",       SP_SetScenePreDelay);
    CreateNative("GetScenePitch",          SP_GetScenePitch);
    CreateNative("SetScenePitch",          SP_SetScenePitch);
    CreateNative("CancelScene",            SP_CancelScene);
    CreateNative("PerformScene",           SP_PerformScene);
    CreateNative("PerformSceneEx",         SP_PerformSceneEx);

    // Global Forwards
    fwdSceneStage = CreateGlobalForward(
    "OnSceneStageChanged",
    ET_Ignore, Param_Cell, Param_Cell);

    fwdVocalizeCommand = CreateGlobalForward(
    "OnVocalizeCommand",
    ET_Hook, Param_Cell, Param_String, Param_Cell);

    // Register plugin
    RegPluginLibrary("sceneprocessor");
}

any SP_GetSceneStage(Handle hPlugin, int iNumParams) {
    if (iNumParams == 0)
        return SceneStage_Unknown;

    int iScene = GetNativeCell(1);
    if (iScene <= 0 || iScene > MAXENTITIES || !IsValidEntity(iScene))
        return SceneStage_Unknown;

    return g_nSceneData[iScene].ssDataBit;
}

any SP_GetSceneStartTimeStamp(Handle hPlugin, int iNumParams) {
    if (iNumParams == 0)
        return 0.0;

    int iScene = GetNativeCell(1);
    if (!IsValidScene(iScene))
        return 0.0;

    return g_nSceneData[iScene].fTimeStampData;
}

any SP_GetActorScene(Handle hPlugin, int iNumParams) {
    if (iNumParams == 0)
        return INVALID_ENT_REFERENCE;

    int iActor = GetNativeCell(1);
    if (iActor <= 0 || iActor > MaxClients || !IsClientInGame(iActor) || GetClientTeam(iActor) != 2 || !IsPlayerAlive(iActor))
        return INVALID_ENT_REFERENCE;

    return g_iScenePlaying[iActor];
}

any SP_GetSceneActor(Handle hPlugin, int iNumParams) {
    if (iNumParams == 0)
        return 0;

    int iScene = GetNativeCell(1);
    if (!IsValidScene(iScene))
        return 0;

    return g_nSceneData[iScene].iActorData;
}

any SP_GetSceneInitiator(Handle hPlugin, int iNumParams) {
    if (iNumParams == 0)
        return 0;

    int iScene = GetNativeCell(1);
    if (!IsValidScene(iScene))
        return 0;

    return g_nSceneData[iScene].iInitiatorData;
}

any SP_GetSceneFile(Handle hPlugin, int iNumParams) {
    if (iNumParams != 3)
        return 0;

    int iScene = GetNativeCell(1);
    if (!IsValidScene(iScene))
        return 0;

    int iLen = GetNativeCell(3);

    int iBytesWritten;
    SetNativeString(2, g_nSceneData[iScene].szFileData, iLen, _, iBytesWritten);
    return iBytesWritten;
}

any SP_GetSceneVocalize(Handle hPlugin, int iNumParams) {
    if (iNumParams != 3)
        return 0;

    int iScene = GetNativeCell(1);
    if (!IsValidScene(iScene))
        return 0;

    int iLen = GetNativeCell(3);

    int iBytesWritten;
    SetNativeString(2, g_nSceneData[iScene].szVocalizeData, iLen, _, iBytesWritten);
    return iBytesWritten;
}

any SP_GetScenePreDelay(Handle hPlugin, int iNumParams) {
    if (iNumParams == 0)
        return 0.0;

    int iScene = GetNativeCell(1);
    if (!IsValidScene(iScene))
        return 0.0;

    return g_nSceneData[iScene].fPreDelayData;
}

any SP_SetScenePreDelay(Handle hPlugin, int iNumParams) {
    if (iNumParams != 2)
        return 0;

    int iScene = GetNativeCell(1);
    if (!IsValidScene(iScene))
        return 0;

    float fPreDelay = GetNativeCell(2);
    SetEntPropFloat(iScene, Prop_Data, "m_flPreDelay", fPreDelay);
    g_nSceneData[iScene].fPreDelayData = fPreDelay;
    return 0;
}

any SP_GetScenePitch(Handle hPlugin, int iNumParams) {
    if (iNumParams == 0)
        return 0.0;

    int iScene = GetNativeCell(1);
    if (!IsValidScene(iScene))
        return 0.0;

    return g_nSceneData[iScene].fPitchData;
}

any SP_SetScenePitch(Handle hPlugin, int iNumParams) {
    if (iNumParams != 2)
        return 0;

    int iScene = GetNativeCell(1);
    if (!IsValidScene(iScene))
        return 0;

    float fPitch = GetNativeCell(2);
    SetEntPropFloat(iScene, Prop_Data, "m_fPitch", fPitch);
    g_nSceneData[iScene].fPitchData = fPitch;
    return 0;
}

any SP_CancelScene(Handle hPlugin, int iNumParams) {
    if (iNumParams == 0)
        return 0;

    int iScene = GetNativeCell(1);
    if (iScene <= 0 || iScene > MAXENTITIES || !IsValidEntity(iScene))
        return 0;

    SceneStages ssBit = g_nSceneData[iScene].ssDataBit;
    if (ssBit == SceneStage_Unknown) {
        return 0;
    } else if (ssBit == SceneStage_Started || (ssBit == SceneStage_SpawnedPost && g_nSceneData[iScene].bInFakePostSpawn)) {
        AcceptEntityInput(iScene, "Cancel");
    } else if (ssBit != SceneStage_Cancelled && ssBit != SceneStage_Completion && ssBit != SceneStage_Killed) {
        AcceptEntityInput(iScene, "Kill");
    }

    return 0;
}

any SP_PerformScene(Handle hPlugin, int iNumParams) {
    if (iNumParams < 2)
        return 0;

    int iClient = GetNativeCell(1);
    if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient) || GetClientTeam(iClient) != 2 || !IsPlayerAlive(iClient))
        return 0;

    static char szVocalize[MAX_VOCALIZE_LENGTH];
    static char szFile    [MAX_SCENEFILE_LENGTH];

    float fPreDelay  = DEFAULT_SCENE_PREDELAY;
    float fPitch     = DEFAULT_SCENE_PITCH;
    int   iInitiator = SCENE_INITIATOR_PLUGIN;

    if (GetNativeString(2, szVocalize, MAX_VOCALIZE_LENGTH) != SP_ERROR_NONE) {
        ThrowNativeError(SP_ERROR_NATIVE, "Unknown Vocalize Parameter!");
        return 0;
    }

    if (iNumParams >= 3) {
        if (GetNativeString(3, szFile, MAX_SCENEFILE_LENGTH) != SP_ERROR_NONE) {
            ThrowNativeError(SP_ERROR_NATIVE, "Unknown File Parameter!");
            return 0;
        }
    }

    if (iNumParams >= 4)
        fPreDelay = GetNativeCell(4);

    if (iNumParams >= 5)
        fPitch = GetNativeCell(5);

    if (iNumParams >= 6)
        iInitiator = GetNativeCell(6);

    Scene_Perform(iClient, szVocalize, szFile, fPreDelay, fPitch, iInitiator);
    return 0;
}

any SP_PerformSceneEx(Handle hPlugin, int iNumParams) {
    if (iNumParams < 2)
        return 0;

    int iClient = GetNativeCell(1);
    if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient) || GetClientTeam(iClient) != 2 || !IsPlayerAlive(iClient))
        return 0;

    static char szVocalize[MAX_VOCALIZE_LENGTH];
    static char szFile    [MAX_SCENEFILE_LENGTH];

    float fPreDelay  = DEFAULT_SCENE_PREDELAY;
    float fPitch     = DEFAULT_SCENE_PITCH;
    int   iInitiator = SCENE_INITIATOR_PLUGIN;

    if (GetNativeString(2, szVocalize, MAX_VOCALIZE_LENGTH) != SP_ERROR_NONE) {
        ThrowNativeError(SP_ERROR_NATIVE, "Unknown Vocalize Parameter!");
        return 0;
    }

    if (iNumParams >= 3) {
        if (GetNativeString(3, szFile, MAX_SCENEFILE_LENGTH) != SP_ERROR_NONE) {
            ThrowNativeError(SP_ERROR_NATIVE, "Unknown File Parameter!");
            return 0;
        }
    }

    if (iNumParams >= 4)
        fPreDelay = GetNativeCell(4);

    if (iNumParams >= 5)
        fPitch = GetNativeCell(5);

    if (iNumParams >= 6)
        iInitiator = GetNativeCell(6);

    Scene_Perform(iClient, szVocalize, szFile, fPreDelay, fPitch, iInitiator, true);
    return 0;
}

void SceneStageForward(int iScene, SceneStages ssStage) {
    Call_StartForward(fwdSceneStage);
    Call_PushCell(iScene);
    Call_PushCell(ssStage);
    Call_Finish();
}

void VocalizeCommandForward(int iClient, const char[] szVocalize, Action &aResult) {
    Call_StartForward(fwdVocalizeCommand);
    Call_PushCell(iClient);
    Call_PushString(szVocalize);
    Call_PushCell(g_iVocalizeInitiator[iClient]);
    Call_Finish(aResult);
}