#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <colors>
#include <l4d2_third_person_detect>
#include <solaris/team_manager>

#define TEAM_SPECTATORS 1

public Plugin myinfo = {
    name        = "Thirdpersonshoulder Block",
    author      = "Don",
    description = "Spectates clients who enable the thirdpersonshoulder mode on L4D1/2 to prevent them from looking around corners, through walls etc.",
    version     = "1.4",
    url         = "http://forums.alliedmods.net/showthread.php?t=159582"
}

public void OnMixStarted() {
    IsInCaptainsMode(true, true);
}

public void OnMixStopped() {
    IsInCaptainsMode(true, false);

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;
        
        if (IsFakeClient(i))
            continue;
        
        TP_OnThirdPersonChanged(i, TP_IsInThirdPerson(i));
    }
}

public void TP_OnThirdPersonChanged(int iClient, bool bIsThirdPerson) {
    if (IsInCaptainsMode())
        return;
    
    if (!TP_IsInThirdPerson(iClient))
        return;
    
    TM_SetPlayerTeam(iClient, TEAM_SPECTATORS);
    ChangeClientTeam(iClient, TEAM_SPECTATORS);
    CPrintToChatAllEx(iClient, "{green}[{default}Third Person Block{green}] {teamcolor}%N{default} was moved to {olive}Spectators{default} due to {green}c_thirdpersonshoulder{default}, set at {olive}0{default} to play!", iClient);
}

public Action OnJoinTeamCmd(const int iClient, const int iTeam) {
    if (TP_IsInThirdPerson(iClient)) {
        CPrintToChatEx(iClient, iClient, "{green}[{default}Third Person Block{green}] {teamcolor}You{default} are not allowed to change team due to {green}c_thirdpersonshoulder{default}, set at {olive}0{default} to play!");
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}

bool IsInCaptainsMode(bool bSet = false, bool bVal = false) {
    static bool bIsInCaptainsMode;
    
    if (bSet)
        bIsInCaptainsMode = bVal;
    
    return bIsInCaptainsMode;
}