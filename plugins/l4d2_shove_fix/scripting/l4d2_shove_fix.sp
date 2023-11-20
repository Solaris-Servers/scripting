#pragma semicolon 1
#pragma newdecls required

#include <sdktools>
#include <actions>

public Plugin myinfo = {
    name        = "[L4D2] Shove Direction Fix",
    author      = "BHaType",
    description = "Allows to shove infected in different direction.",
    version     = "1.0",
    url         = "https://forums.alliedmods.net/showthread.php?p=2675039"
};

public void OnActionCreated(BehaviorAction action, int iOwner, const char[] szName) {
    if (strcmp(szName, "InfectedShoved") == 0)
        action.OnShoved = OnShoved;
}

public Action OnShoved(BehaviorAction action, int iActor, int iShover, ActionDesiredResult result) {
    if (IsWitch(iActor))
        return Plugin_Continue;
    return Plugin_Handled;
}

bool IsWitch(int iEnt) {
    char szClsName[8];
    if (!GetEntityClassname(iEnt, szClsName, sizeof(szClsName)))
        return false;
    return strcmp(szClsName, "witch", false) == 0;
}