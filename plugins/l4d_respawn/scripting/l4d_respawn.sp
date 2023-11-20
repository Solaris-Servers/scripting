#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

static float  g_fPos[3];
static Handle g_hRoundRespawn;
static Handle g_hBecomeGhost;
static Handle g_hStateTransition;

public Plugin myinfo = {
    name        = "L4D Respawn",
    author      = "AtomicStryker & Ivailosp",
    description = "Let's you respawn Players by console",
    version     = "1.9.3",
    url         = "http://forums.alliedmods.net/showthread.php?t=96249"
}

public void OnPluginStart() {
    InitGameData();
    RegAdminCmd("sm_respawn", Cmd_Respawn, ADMFLAG_BAN,
    "sm_respawn <player1> [player2] ... [playerN] - respawn all listed players and teleport them where you aim");
    LoadTranslations("common.phrases");
}

void InitGameData() {
    GameData gmData = new GameData("l4d_respawn");
    if (gmData == null) SetFailState("Could not find gamedata file at addons/sourcemod/gamedata/l4d_respawn.txt!");

    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(gmData, SDKConf_Signature, "RoundRespawn");
    g_hRoundRespawn = EndPrepSDKCall();
    if (g_hRoundRespawn == null) SetFailState("L4D_Respawn: RoundRespawn Signature broken");

    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(gmData, SDKConf_Signature, "BecomeGhost");
    PrepSDKCall_AddParameter(SDKType_PlainOldData , SDKPass_Plain);
    g_hBecomeGhost = EndPrepSDKCall();
    if (g_hBecomeGhost == null) SetFailState("L4D_Respawn: BecomeGhost Signature broken");

    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(gmData, SDKConf_Signature, "State_Transition");
    PrepSDKCall_AddParameter(SDKType_PlainOldData , SDKPass_Plain);
    g_hStateTransition = EndPrepSDKCall();
    if (g_hStateTransition == null) SetFailState("L4D_Respawn: State_Transition Signature broken");

    delete gmData;
}

Action Cmd_Respawn(int iClient, int iArgs) {
    if (iArgs < 1) {
        ReplyToCommand(iClient, "[SM] Usage: sm_respawn <player1> [player2] ... [playerN] - respawn all listed players");
        return Plugin_Handled;
    }
    int[] iTargetList = new int[MaxClients + 1];
    char szArg       [MAX_TARGET_LENGTH];
    char szTargetName[MAX_TARGET_LENGTH];
    int  iTargetCount;
    bool bTnIsMl;
    GetCmdArg(1, szArg, sizeof(szArg));
    if ((iTargetCount = ProcessTargetString(szArg, iClient, iTargetList, MaxClients + 1, 0, szTargetName, sizeof(szTargetName), bTnIsMl)) <= 0) {
        ReplyToTargetError(iClient, iTargetCount); // This function replies to the admin with a failure message
        return Plugin_Handled;
    }
    for (int i = 0; i < iTargetCount; i++) {
        RespawnPlayer(iClient, iTargetList[i]);
    }
    ShowActivity2(iClient, "[SM] ", "Respawned target '%s'", szTargetName);
    return Plugin_Handled;
}

void RespawnPlayer(int iClient, int iTarget) {
    switch (GetClientTeam(iTarget)) {
        case 2: {
            bool bCanTeleport = SetTeleportEndPoint(iClient);
            SDKCall(g_hRoundRespawn, iTarget);
            CheatCommand(iTarget, "give", "first_aid_kit");
            CheatCommand(iTarget, "give", "smg");
            if (bCanTeleport) PerformTeleport(iClient, iTarget, g_fPos);
        }
        case 3: {
            SDKCall(g_hStateTransition, iTarget, 8);
            SDKCall(g_hBecomeGhost,     iTarget, 1);
            SDKCall(g_hStateTransition, iTarget, 6);
            SDKCall(g_hBecomeGhost,     iTarget, 1);
        }
    }
}

bool SetTeleportEndPoint(int iClient) {
    float vOrigin[3];
    GetClientEyePosition(iClient,vOrigin);
    float vAngles[3];
    GetClientEyeAngles(iClient, vAngles);
    // get endpoint for teleport
    Handle hTrace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
    if (TR_DidHit(hTrace)) {
        float vBuffer[3];
        float vStart[3];
        TR_GetEndPosition(vStart, hTrace);
        GetVectorDistance(vOrigin, vStart, false);
        float fDistance = -35.0;
        GetAngleVectors(vAngles, vBuffer, NULL_VECTOR, NULL_VECTOR);
        g_fPos[0] = vStart[0] + (vBuffer[0] * fDistance);
        g_fPos[1] = vStart[1] + (vBuffer[1] * fDistance);
        g_fPos[2] = vStart[2] + (vBuffer[2] * fDistance);
    } else {
        PrintToChat(iClient, "[SM] %s", "Could not teleport player after respawn");
        delete hTrace;
        return false;
    }
    delete hTrace;
    return true;
}

bool TraceEntityFilterPlayer(int iEnt, int iContentsMask) {
    return iEnt > MaxClients || iEnt < 0;
}

void PerformTeleport(int iClient, int iTarget, float vPos[3]) {
    vPos[2] += 40.0;
    TeleportEntity(iTarget, vPos, NULL_VECTOR, NULL_VECTOR);
    LogAction(iClient, iTarget, "\"%L\" teleported \"%L\" after respawning him" , iClient, iTarget);
}

void CheatCommand(int iClient, char[] szCommand, char[] szArguments = "") {
    int iUserFlags = GetUserFlagBits(iClient);
    SetUserFlagBits(iClient, ADMFLAG_ROOT);
    int iFlags = GetCommandFlags(szCommand);
    SetCommandFlags(szCommand, iFlags & ~FCVAR_CHEAT);
    FakeClientCommand(iClient, "%s %s", szCommand, szArguments);
    SetCommandFlags(szCommand, iFlags);
    SetUserFlagBits(iClient, iUserFlags);
}