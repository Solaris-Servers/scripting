#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

int g_iLastHumanTankId;

public Plugin myinfo = {
    name        = "L4D2 Profitless AI Tank",
    author      = "Visor, Forgetest",
    description = "Passing control to AI Tank will no longer be rewarded with an instant respawn",
    version     = "0.4",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart() {
    HookEvent("tank_frustrated", OnTankFrustrated, EventHookMode_Post);
}

public void OnMapStart() {
    g_iLastHumanTankId = 0;
}

void OnTankFrustrated(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_iLastHumanTankId = eEvent.GetInt("userid");
    RequestFrame(OnNextFrameReset);
}

void OnNextFrameReset() {
    g_iLastHumanTankId = 0;
}

public Action L4D_OnEnterGhostStatePre(int iClient) {
    if (g_iLastHumanTankId && GetClientUserId(iClient) == g_iLastHumanTankId) {
        g_iLastHumanTankId = 0;
        L4D_State_Transition(iClient, STATE_DEATH_ANIM);
        return Plugin_Handled;
    }
    return Plugin_Continue;
}