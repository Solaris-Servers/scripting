#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

bool g_bPlayerSpawn;
bool g_bRoundStart;
int  g_iRagdollFader;

public Plugin myinfo = {
    name        = "[L4D2] Ragdolls be gone",
    author      = "SilverShot",
    description = "Make ragdolls infected vanish into thin air server-side on death.",
    version     = "1.1",
    url         = "https://forums.alliedmods.net/showthread.php?p=2587658"
};

public void OnPluginStart() {
    HookEvent("round_start",  Event_RoundStart,  EventHookMode_PostNoCopy);
    HookEvent("round_end",    Event_RoundEnd,    EventHookMode_PostNoCopy);
    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_PostNoCopy);
}

public void OnPluginEnd() {
    DeleteFader();
}

public void OnConfigsExecuted() {
    CreateFader();
}

public void OnMapEnd() {
    DeleteFader();
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (g_bPlayerSpawn && !g_bRoundStart)
        CreateTimer(2.0, Timer_CreateFader, _, TIMER_FLAG_NO_MAPCHANGE);
    g_bRoundStart = true;
}

void Event_PlayerSpawn(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!g_bPlayerSpawn && g_bRoundStart)
        CreateTimer(2.0, Timer_CreateFader, _, TIMER_FLAG_NO_MAPCHANGE);
    g_bPlayerSpawn = true;
}

void Event_RoundEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    DeleteFader();
}

Action Timer_CreateFader(Handle timer) {
    CreateFader();
    return Plugin_Stop;
}

void CreateFader() {
    if (g_iRagdollFader && EntRefToEntIndex(g_iRagdollFader) != INVALID_ENT_REFERENCE )
        return;

    g_iRagdollFader = CreateEntityByName("func_ragdoll_fader");
    if (g_iRagdollFader != -1) {
        DispatchSpawn(g_iRagdollFader);
        SetEntPropVector(g_iRagdollFader, Prop_Send, "m_vecMaxs", view_as<float>({  999999.0,  999999.0,  999999.0 }));
        SetEntPropVector(g_iRagdollFader, Prop_Send, "m_vecMins", view_as<float>({ -999999.0, -999999.0, -999999.0 }));
        SetEntProp(g_iRagdollFader, Prop_Send, "m_nSolidType", 2);
        g_iRagdollFader = EntIndexToEntRef(g_iRagdollFader);
    }
}

void DeleteFader() {
    if (g_iRagdollFader && EntRefToEntIndex(g_iRagdollFader) != INVALID_ENT_REFERENCE ) {
        AcceptEntityInput(g_iRagdollFader, "Kill");
        g_iRagdollFader = 0;
    }

    g_bRoundStart  = false;
    g_bPlayerSpawn = false;
}