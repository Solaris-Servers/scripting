#if defined __FUNCS__
    #endinput
#endif
#define __FUNCS__

void ResetClientVocalizeData(int iClient) {
    g_szVocalizeScene   [iClient] = "\0";
    g_iVocalizeTick     [iClient] = 0;
    g_bSceneHasInitiator[iClient] = false;
    g_iVocalizeInitiator[iClient] = SCENE_INITIATOR_WORLD;
    g_fVocalizePreDelay [iClient] = DEFAULT_SCENE_PREDELAY;
    g_fVocalizePitch    [iClient] = DEFAULT_SCENE_PITCH;
}

void SceneData_SetStage(int iScene, SceneStages ssStage) {
    g_nSceneData[iScene].ssDataBit = ssStage;
    if (ssStage != SceneStage_Unknown) {
        SceneStageForward(iScene, ssStage);
    } else {
        g_nSceneData[iScene].bInFakePostSpawn = false;
        g_nSceneData[iScene].fTimeStampData = 0.0;
        g_nSceneData[iScene].iActorData = 0;
        g_nSceneData[iScene].iInitiatorData = 0;
        strcopy(g_nSceneData[iScene].szFileData, MAX_SCENEFILE_LENGTH, "\0");
        strcopy(g_nSceneData[iScene].szVocalizeData, MAX_VOCALIZE_LENGTH, "\0");
        g_nSceneData[iScene].fPreDelayData = DEFAULT_SCENE_PREDELAY;
        g_nSceneData[iScene].fPitchData = DEFAULT_SCENE_PITCH;
    }
}

void Scene_Perform(int iClient, const char[] szVocalizeParam, const char[] szFileParam = "", float fScenePreDelay = DEFAULT_SCENE_PREDELAY, float fScenePitch = DEFAULT_SCENE_PITCH, int iSceneInitiator = SCENE_INITIATOR_PLUGIN, bool bVocalizeNow = false) {
    if (szFileParam[0] && FileExists(szFileParam, true)) {
        int iScene = CreateEntityByName("instanced_scripted_scene");
        DispatchKeyValue(iScene, "SceneFile", szFileParam);

        SetEntPropEnt(iScene, Prop_Data, "m_hOwner", iClient);
        g_nSceneData[iScene].iActorData = iClient;
        SetEntPropFloat(iScene, Prop_Data, "m_flPreDelay", fScenePreDelay);
        g_nSceneData[iScene].fPreDelayData = fScenePreDelay;
        SetEntPropFloat(iScene, Prop_Data, "m_fPitch", fScenePitch);
        g_nSceneData[iScene].fPitchData = fScenePitch;

        g_nSceneData[iScene].iInitiatorData = iSceneInitiator;
        strcopy(g_nSceneData[iScene].szVocalizeData, MAX_VOCALIZE_LENGTH, szVocalizeParam);

        DispatchSpawn(iScene);
        ActivateEntity(iScene);

        AcceptEntityInput(iScene, "Start", iClient, iClient);
    } else if (szVocalizeParam[0]) {
        if (bVocalizeNow) {
            g_bSceneHasInitiator[iClient] = true;
            g_iVocalizeInitiator[iClient] = iSceneInitiator;
            g_fVocalizePreDelay [iClient] = fScenePreDelay;
            g_fVocalizePitch    [iClient] = fScenePitch;
            JailbreakVocalize(iClient, szVocalizeParam);
        } else {
            g_arrVocalize.Push(iClient);
            g_arrVocalize.PushString(szVocalizeParam);
            g_arrVocalize.Push(fScenePreDelay);
            g_arrVocalize.Push(fScenePitch);
            g_arrVocalize.Push(iSceneInitiator);
            g_arrVocalize.Push(GetGameTickCount() + 10 - 1);
            g_bUnvocalizedCommands = true;
        }
    }
}

void JailbreakVocalize(int iClient, const char[] szVocalize) {
    char szBuffer[2][32];
    FloatToString((GetGameTime() - g_fStartTimeStamp) + 2.0, szBuffer[0], 32);
    ExplodeString(szBuffer[0], ".", szBuffer, 2, 32);
    Format(szBuffer[1], 2, "%s\0", szBuffer[1][0]);
    FakeClientCommandEx(iClient, "vocalize %s #%s%s", szVocalize, szBuffer[0], szBuffer[1]);
}