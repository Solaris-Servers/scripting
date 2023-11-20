#if defined __GLOBALS__
    #endinput
#endif
#define __GLOBALS__

#define MAXENTITIES 2048

int   g_iSkippedFrames;
bool  g_bScenesUnprocessed;
bool  g_bUnvocalizedCommands;
float g_fStartTimeStamp;

char  g_szVocalizeScene   [MAXPLAYERS + 1][MAX_VOCALIZE_LENGTH];
int   g_iVocalizeTick     [MAXPLAYERS + 1];
bool  g_bSceneHasInitiator[MAXPLAYERS + 1];
int   g_iVocalizeInitiator[MAXPLAYERS + 1];
float g_fVocalizePreDelay [MAXPLAYERS + 1];
float g_fVocalizePitch    [MAXPLAYERS + 1];
int   g_iScenePlaying     [MAXPLAYERS + 1];

ArrayList  g_arrVocalize;
ArrayStack g_arrScene;

enum struct SceneData {
    SceneStages ssDataBit;
    bool  bInFakePostSpawn;
    float fTimeStampData;
    int   iActorData;
    int   iInitiatorData;
    char  szFileData[MAX_SCENEFILE_LENGTH];
    char  szVocalizeData[MAX_VOCALIZE_LENGTH];
    float fPreDelayData;
    float fPitchData;
}

SceneData g_nSceneData[MAXENTITIES];

void OnModuleStart_Globals() {
    g_arrScene    = new ArrayStack();
    g_arrVocalize = new ArrayList(MAX_VOCALIZE_LENGTH);

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

        ResetClientVocalizeData(i);
    }
}