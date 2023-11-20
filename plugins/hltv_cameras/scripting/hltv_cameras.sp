#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools_functions>
#include <sdktools_engine>
#include <sdktools_entinput>

#include <sourcetv/hltv_cameras/sdk>
#include <sourcetv/hltv_cameras/cache>
#include <sourcetv/hltv_cameras/parser>
#include <sourcetv/util/vector>

public Plugin myinfo = {
    name        = "Manage HLTV Cameras",
    author      = "shqke",
    description = "Manage point_viewcontrol entities used by HLTV Director on the fly",
    version     = "1.6",
    url         = "https://github.com/shqke/sp_public"
};

public void OnPluginStart() {
    GameConfig_LoadOrFail();
    CameraCache_Init();

    RegAdminCmd("sm_addhltvcamera",     Cmd_Add_HLTV_Camera,  ADMFLAG_ROOT, "sm_addhltvcamera [name|*] [origin] - place unique camera entity at given or current position");
    RegAdminCmd("sm_sethltvcamera",     Cmd_Set_HLTV_Camera,  ADMFLAG_ROOT, "sm_sethltvcamera [name] [origin] - replace existing camera entity with given or current position");
    RegAdminCmd("sm_delhltvcamera",     Cmd_Del_HLTV_Camera,  ADMFLAG_ROOT, "sm_delhltvcamera [name] - remove camera entity from config");
    RegAdminCmd("sm_clearhltvcameras",  Cmd_Clr_HLTV_Cameras, ADMFLAG_ROOT, "sm_clearhltvcameras - clear (empty) config");
    RegAdminCmd("sm_reloadhltvcameras", Cmd_Rld_HLTV_Cameras, ADMFLAG_ROOT, "sm_reloadhltvcameras - reload from config");
    RegAdminCmd("sm_listhltvcameras",   Cmd_Lst_HLTV_Cameras, ADMFLAG_ROOT, "sm_listhltvcameras - list cameras in cache");
}

public void OnPluginEnd() {
    CameraCache_Clear();
}

public void OnMapStart() {
    // With point_viewcontrol being in preserved list, OnMapStart should be enough
    CameraCache_Parse();
}

Action Cmd_Add_HLTV_Camera(int iClient, int iArgs) {
    char szBaseCameraName[MAX_CAMERA_NAME];
    GetCmdArg(1, szBaseCameraName, sizeof(szBaseCameraName));

    if (szBaseCameraName[0] == '\0' || szBaseCameraName[0] == '*')
        strcopy(szBaseCameraName, sizeof(szBaseCameraName), "camera");

    // Autogenerate camera name
    char szCameraName[MAX_CAMERA_NAME];
    CameraCache_GenerateName(szCameraName, sizeof(szCameraName), szBaseCameraName);

    float vOrigin[3];
    if (iArgs >= 2) {
        char szValue[32];
        GetCmdArg(2, szValue, sizeof(szValue));
        StringToVector(szValue, vOrigin);
    } else if (iClient != 0) {
        GetClientEyePosition(iClient, vOrigin);
    }

    if (!CameraCache_AddCamera(szCameraName, vOrigin)) {
        ReplyToCommand(iClient, "Couldn't add a new camera (engine supports up to %d).", MAX_NUM_CAMERAS);
        return Plugin_Handled;
    }

    CameraCache_Save();
    HLTVDirector_BuildCameraList();
    ReplyToCommand(iClient, "Successfully added new camera \"%s\".", szCameraName);
    LogAction(iClient, -1, "Added camera \"%s\" (origin: %f %f %f) by %L", szCameraName, vOrigin[0], vOrigin[1], vOrigin[2], iClient);
    return Plugin_Handled;
}

Action Cmd_Set_HLTV_Camera(int iClient, int iArgs) {
    char szCameraName[MAX_CAMERA_NAME];
    GetCmdArg(1, szCameraName, sizeof(szCameraName));

    int iIdx = CameraCache_IndexFromName(szCameraName);
    if (iIdx == -1) {
        ReplyToCommand(iClient, "Camera \"%s\" doesn't exist.", szCameraName);
        return Plugin_Handled;
    }

    float vOrigin[3];
    if (iArgs >= 2) {
        char value[32];
        GetCmdArg(2, value, sizeof(value));
        StringToVector(value, vOrigin);
    } else if (iClient != 0) {
        GetClientEyePosition(iClient, vOrigin);
    }

    CameraCache_MoveCamera(iIdx, vOrigin);
    CameraCache_Save();
    ReplyToCommand(iClient, "Successfully moved camera \"%s\" to %f %f %f.", szCameraName, vOrigin[0], vOrigin[1], vOrigin[2]);
    LogAction(iClient, -1, "Added camera \"%s\" (origin: %f %f %f) by %L", szCameraName, vOrigin[0], vOrigin[1], vOrigin[2], iClient);
    return Plugin_Handled;
}

Action Cmd_Del_HLTV_Camera(int iClient, int iArgs) {
    char szCameraName[MAX_CAMERA_NAME];
    GetCmdArg(1, szCameraName, sizeof(szCameraName));

    int iIdx = CameraCache_IndexFromName(szCameraName);
    if (iIdx == -1) {
        ReplyToCommand(iClient, "Camera \"%s\" doesn't exist.", szCameraName);
        return Plugin_Handled;
    }

    float vOrigin[3];
    CameraCache_GetOrigin(iIdx, vOrigin);
    CameraCache_DeleteCamera(iIdx);
    CameraCache_Save();
    ReplyToCommand(iClient, "Successfully removed camera \"%s\".", szCameraName);
    LogAction(iClient, -1, "Removed camera \"%s\" (origin: %f %f %f) by %L", szCameraName, vOrigin[0], vOrigin[1], vOrigin[2], iClient);
    return Plugin_Handled;
}

Action Cmd_Clr_HLTV_Cameras(int iClient, int iArgs) {
    // TODO: log removed cameras
    CameraCache_Clear();
    CameraCache_Save();
    ReplyToCommand(iClient, "Successfully cleared camera cache.");
    LogAction(iClient, -1, "Cleared camera cache by %L", iClient);
    return Plugin_Handled;
}

Action Cmd_Rld_HLTV_Cameras(int iClient, int iArgs) {
    CameraCache_Parse();
    ReplyToCommand(iClient, "Successfully reloaded from camera config.");
    return Plugin_Handled;
}

Action Cmd_Lst_HLTV_Cameras(int iClient, int iArgs) {
    CameraCache_List(iClient);
    return Plugin_Handled;
}