#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>

// https://forums.alliedmods.net/showthread.php?t=147732
#define SOLID_NONE 0
#define FSOLID_NOT_SOLID 0x0004
#define SIZE_BYTE 1

public Plugin myinfo = {
    name        = "[L4D & 2] Backjump Fix",
    author      = "Forgetest",
    description = "Fix hunter being unable to pounce off non-static props",
    version     = "2.1",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

public void OnPluginStart() {
    HookEvent("player_spawn",       Event_PlayerSpawn);
    HookEvent("player_team",        Event_PlayerTeam);
    HookEvent("player_death",       Event_PlayerDeath);
    HookEvent("player_bot_replace", Event_PlayerBotReplace);
}

void Event_PlayerSpawn(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)
        return;

    if (!IsClientInGame(iClient))
        return;

    if (GetClientTeam(iClient) == 3 && GetEntProp(iClient, Prop_Send, "m_zombieClass") == 3) {
        SDKHook(iClient, SDKHook_TouchPost, SDK_OnTouch_Post);
        return;
    }

    SDKUnhook(iClient, SDKHook_TouchPost, SDK_OnTouch_Post);
}

void Event_PlayerTeam(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)
        return;

    int iOldTeam = eEvent.GetInt("oldteam");
    if (iOldTeam != 3)
        return;

    if (iOldTeam == eEvent.GetInt("team"))
        return;

    SDKUnhook(iClient, SDKHook_TouchPost, SDK_OnTouch_Post);
}

void Event_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)
        return;

    if (!IsClientInGame(iClient))
        return;

    if (GetClientTeam(iClient) != 3)
        return;

    if (GetEntProp(iClient, Prop_Send, "m_zombieClass") != 3)
        return;

    SDKUnhook(iClient, SDKHook_TouchPost, SDK_OnTouch_Post);
}

void Event_PlayerBotReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    HandlePlayerReplace(GetClientOfUserId(eEvent.GetInt("bot")), GetClientOfUserId(eEvent.GetInt("player")));
}

void HandlePlayerReplace(int iReplacer, int iReplacee) {
    iReplacer = GetClientOfUserId(iReplacer);
    if (iReplacer <= 0)
        return;

    if (!IsClientInGame(iReplacer))
        return;

    if (GetClientTeam(iReplacer) != 3)
        return;

    if (GetEntProp(iReplacer, Prop_Send, "m_zombieClass") != 3)
        return;

    if (IsPlayerAlive(iReplacer))
        SDKHook(iReplacer, SDKHook_TouchPost, SDK_OnTouch_Post);

    if (iReplacee <= 0)
        return;

    if (!IsClientInGame(iReplacee))
        return;

    SDKUnhook(iReplacee, SDKHook_TouchPost, SDK_OnTouch_Post);
}

void SDK_OnTouch_Post(int iEnt, int iOther) {
    // the moment player is disconnecting
    if (!IsClientInGame(iEnt))
        return;

    // mysterious questionable secret that Valve gifts, jk
    int iAbility = GetEntPropEnt(iEnt, Prop_Send, "m_customAbility");
    if (iAbility == -1) {
        SDKUnhook(iEnt, SDKHook_TouchPost, SDK_OnTouch_Post);
        return;
    }

    // not bouncing
    if (GetEntPropEnt(iEnt, Prop_Send, "m_hGroundEntity") != -1)
        return;

    // not valid touch
    if (!IsValidEdict(iOther))
        return;

    // impossible to pounce off players
    if (iOther <= MaxClients)
        return;

    // not solid entity, not bounceable
    if (!Entity_IsSolid(iOther))
        return;

    // except weapon entities
    static char szClsName[64];
    if (!GetEdictClassname(iOther, szClsName, sizeof(szClsName)))
        return;

    if (strncmp(szClsName, "weapon_", 7) == 0)
        return;

    // CLunge::OnTouch()    mov     byte ptr [esi+48Ch], 1    <- +48C is the offset (near CBaseEntity.IsPlayer() check)
    static int iBlockBounceOffs = -1;
    if (iBlockBounceOffs == -1)
        iBlockBounceOffs = FindSendPropInfo("CLunge", "m_isLunging") + 16;

    // touched survivors before and therefore unable to bounce
    if (GetEntData(iAbility, iBlockBounceOffs, SIZE_BYTE))
        return;

    if (!HasEntProp(iAbility, Prop_Send, "m_lungeAgainTimer"))
        return;

    // confirm a bounce recharge
    SetEntPropFloat(iAbility, Prop_Send, "m_lungeAgainTimer", 0.5, 0);
    SetEntPropFloat(iAbility, Prop_Send, "m_lungeAgainTimer", GetGameTime() + 0.5, 1);
}

/**
 * Checks whether the entity is solid or not.
 *
 * @param iEnt            Entity index.
 * @return                True if the entity is solid, false otherwise.
 */
stock bool Entity_IsSolid(int iEnt) {
    return (GetEntProp(iEnt, Prop_Send, "m_nSolidType", 1) != SOLID_NONE && !(GetEntProp(iEnt, Prop_Send, "m_usSolidFlags", 2) & FSOLID_NOT_SOLID));
}