#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <readyup>

ConVar g_cvGhostHurtType;
bool   g_bIsRoundLive;

public Plugin myinfo = {
    name        = "Ghost Hurt Management",
    author      = "Jacob",
    description = "Allows for modifications of trigger_hurt_ghost",
    version     = "1.1",
    url         = "github.com/jacob404/myplugins"
}

public void OnPluginStart() {
    g_cvGhostHurtType = CreateConVar(
    "ghost_hurt_type", "0",
    "When should trigger_hurt_ghost be enabled? 0 = Never, 1 = On Round Start",
    FCVAR_NONE, true, 0.0, true, 1.0);

    HookEvent("round_start",           Event_RoundStart,         EventHookMode_PostNoCopy);
    HookEvent("player_left_safe_area", Event_PlayerLeftSafeArea, EventHookMode_PostNoCopy);

    RegServerCmd("sm_reset_ghost_hurt", Cmd_ResetGhostHurt, "Used to reset trigger_hurt_ghost between matches.  This should be in confogl_off.cfg or equivalent for your system");
}

public void OnMapStart() {
    DisableGhostHurt();
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bIsRoundLive = false;
    DisableGhostHurt();
}

void Event_PlayerLeftSafeArea(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bIsRoundLive = true;
    if (!g_cvGhostHurtType.BoolValue) return;
    if (g_bIsRoundLive)               return;
    EnableGhostHurt();
}

public void OnRoundIsLive() {
    g_bIsRoundLive = true;
    if (!g_cvGhostHurtType.BoolValue) return;
    EnableGhostHurt();
}

Action Cmd_ResetGhostHurt(int iArgs) {
    DisableGhostHurt();
    return Plugin_Handled;
}

void DisableGhostHurt() {
    ModifyEntity("trigger_hurt_ghost", "Disable");
}

void EnableGhostHurt() {
    ModifyEntity("trigger_hurt_ghost", "Enable");
}

void ModifyEntity(char[] szName, char[] szInput) {
    int iEntity;
    while ((iEntity = FindEntityByClassname(iEntity, szName)) != -1) {
        if (!IsValidEdict(iEntity))  continue;
        if (!IsValidEntity(iEntity)) continue;
        AcceptEntityInput(iEntity, szInput);
    }
}