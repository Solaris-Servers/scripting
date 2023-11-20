#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

public Plugin myinfo = {
    name        = "Byebye Door",
    description = "Time to kill Saferoom Doors.",
    author      = "Sir",
    version     = "1.0",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart() {
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

void Event_RoundStart(Event eEvent, char[] szName, bool bDontBroadcast) {
    char szEdictClassName[128];
    int  iEntityCount = GetEntityCount();
    for (int i = 0; i <= iEntityCount; i++) {
        if (!IsValidEntity(i)) continue;
        GetEdictClassname(i, szEdictClassName, sizeof(szEdictClassName));
        if (StrContains(szEdictClassName, "prop_door_rotating_checkpoint", false) != -1 && GetEntProp(i, Prop_Send, "m_bLocked", 4) == 1)
            RemoveEntity(i);
    }
}