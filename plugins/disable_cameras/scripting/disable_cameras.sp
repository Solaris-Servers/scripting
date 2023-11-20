#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools_functions>
#include <sdktools_entinput>

public Plugin myinfo = {
    name        = "[L4D/2] Unlink Camera Entities",
    author      = "shqke",
    description = "Frees cached players from camera entity",
    version     = "1.1",
    url         = "https://github.com/shqke/sp_public"
};

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    switch (GetEngineVersion()) {
        case Engine_Left4Dead2, Engine_Left4Dead: {
            return APLRes_Success;
        }
    }

    strcopy(szError, iErrMax, "Plugin only supports Left 4 Dead and Left 4 Dead 2.");
    return APLRes_SilentFailure;
}

public void OnPluginStart() {
    HookEvent("round_start_pre_entity", Event_RoundStartPreEntity, EventHookMode_PostNoCopy);
}

// Fixed issues:
// - Server crash when kicking a bot who have been an active target of camera (point_viewcontrol_survivor)
// - Multiple visual spectator bugs after team swap in finale

void Event_RoundStartPreEntity(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iEnt = INVALID_ENT_REFERENCE;
    while ((iEnt = FindEntityByClassname(iEnt, "point_viewcontrol*")) != INVALID_ENT_REFERENCE) {
        // Invoke a "Disable" input on camera entities to free all players
        // Doing so on round_start_pre_entity should help to not let map logic kick in too early
        AcceptEntityInput(iEnt, "Disable");
    }
}

public void OnClientDisconnect(int iClient) {
    if (!IsClientInGame(iClient))
        return;

    int iViewEnt = GetEntPropEnt(iClient, Prop_Send, "m_hViewEntity");
    if (!IsValidEdict(iViewEnt))
        return;

    char szCls[64];
    GetEdictClassname(iViewEnt, szCls, sizeof(szCls));

    if (strncmp(szCls, "point_viewcontrol", 17) == 0) {
        // Matches CSurvivorCamera, CTriggerCamera
        if (strcmp(szCls[17], "_survivor") == 0 || szCls[17] == '\0')
            // Disable entity to prevent CMoveableCamera::FollowTarget to cause a crash
            // m_hTargetEnt EHANDLE is not checked for existence and can be NULL
            // CBaseEntity::GetAbsAngles being called on causing a crash
            AcceptEntityInput(iViewEnt, "Disable");

        // Matches CTriggerCameraMultiplayer
        if (strcmp(szCls[17], "_multiplayer") == 0)
            AcceptEntityInput(iViewEnt, "RemovePlayer", iClient);
    }
}