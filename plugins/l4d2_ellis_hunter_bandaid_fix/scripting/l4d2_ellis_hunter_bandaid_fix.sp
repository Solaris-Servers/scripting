#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <l4d2util>
#include <left4dhooks>

#define ANIM_ELLIS_HUNTER_GETUP 625

/**
  * Modify m_flPlaybackRate based on the following:
  *
  * Ellis Hunter Pounce Getup Anim:    79 Frames.
  * Other Survivors Pounce Getup Anim: 64 Frames.
  * 79 / 64 = 1.234375
*/
#define ANIM_PLAYBACK_RATE_MULTIPLIER 1.234375

public Plugin myinfo = {
    name        = "L4D2 Ellis Hunter Band aid Fix",
    author      = "Sir (with pointers from Rena)",
    description = "Band-aid fix for Ellis' getup not matching the other Survivors",
    version     = "1.1",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart() {
    HookEvent("pounce_end", Event_PounceEnd);
}

void Event_PounceEnd(Event eEvent, char[] szName, bool bDontBroadcast) {
    int iClient  = GetClientOfUserId(eEvent.GetInt("victim"));
    if (iClient <= 0)
        return;

    if (!IsClientInGame(iClient))
        return;

    int iCharIdx = IdentifySurvivorFast(iClient);
    if (iCharIdx != SurvivorCharacter_Ellis)
        return;

    AnimHookEnable(iClient, INVALID_FUNCTION, EllisPostPounce);
}

void UpdateThink(int iClient) {
    // We can assume client is valid as SDKUnhook is called automatically on disconnect.
    // Check the team and sequence, should suffice.
    int iSequence = GetEntProp(iClient, Prop_Send, "m_nSequence");
    if (GetClientTeam(iClient) == L4D2Team_Survivor && iSequence == ANIM_ELLIS_HUNTER_GETUP) {
        SetEntPropFloat(iClient, Prop_Send, "m_flPlaybackRate", ANIM_PLAYBACK_RATE_MULTIPLIER);
        return;
    }

    SDKUnhook(iClient, SDKHook_PostThinkPost, UpdateThink);
}

Action EllisPostPounce(int iClient, int &iSequence) {
    // Ellis Hunter get up animation?
    if (iSequence == ANIM_ELLIS_HUNTER_GETUP) {
        SDKHook(iClient, SDKHook_PostThinkPost, UpdateThink);
        AnimHookDisable(iClient, INVALID_FUNCTION, EllisPostPounce);
    }

    return Plugin_Continue;
}