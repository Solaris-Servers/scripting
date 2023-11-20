#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

public Plugin myinfo = {
    name        = "Swamp Finale Fix",
    author      = "Jacob",
    description = "Fix swamp finale breaking for 2nd team",
    version     = "0.1"
}
public void OnMapStart() {
    static char szMap[64];
    GetCurrentMap(szMap, sizeof(szMap));

    static bool bEnable;
    bEnable = strcmp(szMap, "c3m4_plantation") == 0;

    ToogleEvent(bEnable);
}

void ToogleEvent(bool bEnable) {
    static bool bEnabled;
    if (bEnable && !bEnabled)
        HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
    else if (!bEnable && bEnabled)
        UnhookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
    bEnabled = bEnable;
}

void Event_RoundEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iEnt;
    while ((iEnt = FindEntityByClassname(iEnt, "trigger_finale")) != -1) {
        if (!IsValidEdict(iEnt) || !IsValidEntity(iEnt))
            continue;
        AcceptEntityInput(iEnt, "ForceFinaleStart");
    }
}