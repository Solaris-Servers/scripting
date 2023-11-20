#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <sceneprocessor>

#include "modules/globals.sp"
#include "modules/natives_and_forwards.sp"
#include "modules/vocalize.sp"
#include "modules/functions.sp"

public Plugin myinfo = {
    name        = "Scene Processor",
    author      = "Buster \"Mr. Zero\" Nielsen (Fork by cravenge & Dragokas)",
    description = "Provides Forwards and Natives For Scenes' Manipulation.",
    version     = "1.33.3",
    url         = "https://forums.alliedmods.net/showthread.php?t=241585"
};

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    EngineVersion evGame = GetEngineVersion();
    if (evGame != Engine_Left4Dead2) {
        strcopy(szError, iErrMax, "[SP] Plugin Supports L4D And L4D2 Only!");
        return APLRes_Failure;
    }

    if (LibraryExists("sceneprocessor")) {
        strcopy(szError, iErrMax, "[SP] You have two sceneprocessor plugins installed!");
        return APLRes_Failure;
    }

    CreateNativesAndForwards();
    return APLRes_Success;
}

public void OnPluginStart() {
    OnModuleStart_Vocalize();
    OnModuleStart_Globals();
}

public void OnMapStart() {
    g_iSkippedFrames  = 0;
    g_fStartTimeStamp = GetGameTime();
}

public void OnEntityCreated(int iEnt, const char[] szEntCls) {
    if (iEnt <= 0 || iEnt > MAXENTITIES)
        return;

    if (strcmp(szEntCls, "instanced_scripted_scene") == 0) {
        SDKHook(iEnt, SDKHook_SpawnPost, OnSpawnPost);
        SceneData_SetStage(iEnt, SceneStage_Created);
    }
}

public void OnSpawnPost(int iEnt) {
    int iActor = GetEntPropEnt(iEnt, Prop_Data, "m_hOwner");
    g_nSceneData[iEnt].iActorData = iActor;

    static char szFile[MAX_SCENEFILE_LENGTH];
    GetEntPropString(iEnt, Prop_Data, "m_iszSceneFile", szFile, MAX_SCENEFILE_LENGTH);

    strcopy(g_nSceneData[iEnt].szFileData, MAX_SCENEFILE_LENGTH, szFile);
    g_nSceneData[iEnt].fPitchData = GetEntPropFloat(iEnt, Prop_Data, "m_fPitch");

    if (iActor > 0 && iActor <= MaxClients && IsClientInGame(iActor)) {
        if (g_iVocalizeTick[iActor] == GetGameTickCount()) {
            strcopy(g_nSceneData[iEnt].szVocalizeData, MAX_VOCALIZE_LENGTH, g_szVocalizeScene[iActor]);
            g_nSceneData[iEnt].iInitiatorData = g_iVocalizeInitiator[iActor];
            g_nSceneData[iEnt].fPreDelayData  = g_fVocalizePreDelay[iActor];
            g_nSceneData[iEnt].fPitchData     = g_fVocalizePitch[iActor];
        }

        ResetClientVocalizeData(iActor);
    }

    SetEntPropFloat(iEnt, Prop_Data, "m_fPitch",     g_nSceneData[iEnt].fPitchData);
    SetEntPropFloat(iEnt, Prop_Data, "m_flPreDelay", g_nSceneData[iEnt].fPreDelayData);

    g_arrScene.Push(iEnt);
    g_bScenesUnprocessed = true;

    HookSingleEntityOutput(iEnt, "OnStart",    OnSceneStart_EntOutput);
    HookSingleEntityOutput(iEnt, "OnCanceled", OnSceneCanceled_EntOutput);

    SceneData_SetStage(iEnt, SceneStage_Spawned);
}

void OnSceneStart_EntOutput(const char[] iOutput, int iCaller, int iActivator, float fDelay) {
    if (iCaller <= 0 || iCaller > MAXENTITIES || !IsValidEntity(iCaller))
        return;

    static char szFile[MAX_SCENEFILE_LENGTH];
    strcopy(szFile, MAX_SCENEFILE_LENGTH, g_nSceneData[iCaller].szFileData);
    if (!szFile[0]) return;

    g_nSceneData[iCaller].fTimeStampData = GetEngineTime();

    if (g_nSceneData[iCaller].ssDataBit == SceneStage_Spawned) {
        g_nSceneData[iCaller].bInFakePostSpawn = true;
        SceneData_SetStage(iCaller, SceneStage_SpawnedPost);
    }

    if (g_nSceneData[iCaller].ssDataBit == SceneStage_SpawnedPost) {
        int iActor = g_nSceneData[iCaller].iActorData;
        if (iActor > 0 && iActor <= MaxClients && IsClientInGame(iActor))
            g_iScenePlaying[iActor] = iCaller;
        SceneData_SetStage(iCaller, SceneStage_Started);
    }
}

void OnSceneCanceled_EntOutput(const char[] iOutput, int iCaller, int iActivator, float fDelay) {
    if (iCaller <= 0 || iCaller > MAXENTITIES || !IsValidEntity(iCaller))
        return;

    for (int i = 1; i <= MaxClients; i++) {
        if (g_iScenePlaying[i] == iCaller) {
            g_iScenePlaying[i] = INVALID_ENT_REFERENCE;
            break;
        }
    }

    SceneData_SetStage(iCaller, SceneStage_Cancelled);
}

public void OnEntityDestroyed(int iEnt) {
    if (iEnt <= 0 || iEnt > MAXENTITIES || !IsValidEdict(iEnt))
        return;

    static char szEntCls[64];
    GetEdictClassname(iEnt, szEntCls, sizeof(szEntCls));
    if (strcmp(szEntCls, "instanced_scripted_scene") != 0)
        return;

    SDKUnhook(iEnt, SDKHook_SpawnPost, OnSpawnPost);

    SceneStages ssBit = g_nSceneData[iEnt].ssDataBit;
    if (ssBit != SceneStage_Unknown) {
        if (ssBit == SceneStage_Started)
            SceneData_SetStage(iEnt, SceneStage_Completion);
        SceneData_SetStage(iEnt, SceneStage_Killed);

        for (int i = 1; i <= MaxClients; i++) {
            if (!IsClientInGame(i))
                continue;

            if (g_iScenePlaying[i] != iEnt)
                continue;

            g_iScenePlaying[i] = INVALID_ENT_REFERENCE;
            break;
        }
    }

    SceneData_SetStage(iEnt, SceneStage_Unknown);
}

public void OnClientDisconnect(int iClient) {
    if (iClient == 0)
        return;

    g_iScenePlaying[iClient] = INVALID_ENT_REFERENCE;
}

public void OnGameFrame() {
    g_iSkippedFrames += 1;
    if (g_iSkippedFrames < 3)
        return;

    g_iSkippedFrames = 1;
    if (g_bScenesUnprocessed) {
        g_bScenesUnprocessed = false;

        int iScene;
        while (!g_arrScene.Empty) {
            g_arrScene.Pop(iScene);
            if (iScene <= 0)
                continue;

            if (iScene > MAXENTITIES)
                continue;

            if (!IsValidEntity(iScene))
                continue;

            if (g_nSceneData[iScene].ssDataBit != SceneStage_Spawned)
                continue;

            g_nSceneData[iScene].fPreDelayData = GetEntPropFloat(iScene, Prop_Data, "m_flPreDelay");
            g_nSceneData[iScene].bInFakePostSpawn = false;
            SceneData_SetStage(iScene, SceneStage_SpawnedPost);
        }
    }

    if (g_bUnvocalizedCommands) {
        int iArraySize   = g_arrVocalize.Length;
        int iCurrentTick = GetGameTickCount();

        static char szVocalize[MAX_VOCALIZE_LENGTH];
        float fPreDelay, fPitch;
        int iClient, iInitiator, iTick;

        for (int i = 0; i < iArraySize; i += 6)
        {
            iTick = g_arrVocalize.Get(i + 5);
            if (iCurrentTick != iTick)
                continue;

            iClient = g_arrVocalize.Get(i + 0);
            g_arrVocalize.GetString(i + 1, szVocalize, MAX_VOCALIZE_LENGTH);
            fPreDelay = view_as<float>(g_arrVocalize.Get(i + 2));
            fPitch = view_as<float>(g_arrVocalize.Get(i + 3));
            iInitiator = g_arrVocalize.Get(i + 4);

            Scene_Perform(iClient, szVocalize, _, fPreDelay, fPitch, iInitiator, true);

            for (int j = 0; j < 6; j++) {
                g_arrVocalize.Erase(i);
                iArraySize -= 1;
            }
        }

        if (iArraySize < 1) {
            g_arrVocalize.Clear();
            g_bUnvocalizedCommands = false;
        }
    }
}

public void OnMapEnd() {
    g_iSkippedFrames = 0;

    g_bScenesUnprocessed   = false;
    g_bUnvocalizedCommands = false;

    while (!g_arrScene.Empty)
        PopStack(g_arrScene);
    g_arrVocalize.Clear();

    for (int i = 1; i <= MAXENTITIES; i++) {
        if (!IsValidEntity(i))
            continue;

        if (!IsValidEdict(i))
            continue;

        SceneData_SetStage(i, SceneStage_Unknown);
    }

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        g_iScenePlaying[i] = INVALID_ENT_REFERENCE;
    }
}