#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

// source-sdk: src/game/server/nav.h
#define HumanHeight 71

int g_iEstIkOffs;

public Plugin myinfo =  {
    name        = "[L4D2] Fix Jockey Hitbox",
    author      = "Forgetest",
    description = "Fix jockey hitbox issues when riding survivors.",
    version     = "2.1",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

public void OnPluginStart() {
    g_iEstIkOffs = FindSendPropInfo("CBaseAnimating", "m_flModelScale") + 24;

    HookEvent("jockey_ride",     Event_JockeyRide);
    HookEvent("jockey_ride_end", Event_JockeyRideEnd);
}

void Event_JockeyRide(Event event, const char[] name, bool dontBroadcast) {
    int iVictim = GetClientOfUserId(event.GetInt("victim"));
    if (iVictim <= 0)
        return;

    if (!IsClientInGame(iVictim))
        return;

    SDKHook(iVictim, SDKHook_PostThinkPost, SDK_OnPostThink_Post);

    int iAttacker = GetClientOfUserId(event.GetInt("userid"));
    if (iAttacker <= 0)
        return;

    if (!IsClientInGame(iAttacker))
        return;

    // https://github.com/ValveSoftware/source-sdk-2013/blob/master/sp/src/game/server/baseanimating.cpp#L1800
    /**
     *   // adjust hit boxes based on IK driven offset
     *   Vector adjOrigin = GetAbsOrigin() + Vector( 0, 0, m_flEstIkOffset );
     */
    int iCharacter = GetEntProp(iVictim, Prop_Send, "m_survivorCharacter");

    float flModelScale = GetCharacterScale(iCharacter);
    SetEstIkOffset(iAttacker, HumanHeight * (flModelScale - 1.0));
}

void SDK_OnPostThink_Post(int iClient) {
    if (!IsClientInGame(iClient))
        return;

    if (!FixBoundingBox(iClient))
        SDKUnhook(iClient, SDKHook_PostThinkPost, SDK_OnPostThink_Post);
}

bool FixBoundingBox(int iClient) {
    if (GetClientTeam(iClient) != 2)
        return false;

    // in all circumstances this should make sure the client is being jockeyed
    if (GetEntPropEnt(iClient, Prop_Send, "m_jockeyAttacker") == -1)
        return false;

    // Fix bounding box
    int iFlags = GetEntityFlags(iClient);
    if (iFlags & FL_DUCKING)
        SetEntityFlags(iClient, iFlags & ~FL_DUCKING);

    return true;
}

void Event_JockeyRideEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iAttacker = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iAttacker <= 0)
        return;

    if (!IsClientInGame(iAttacker))
        return;

    SetEstIkOffset(iAttacker, 0.0);
}

void SetEstIkOffset(int iClient, float fVal) {
    SetEntDataFloat(iClient, g_iEstIkOffs, fVal);
}

float GetCharacterScale(int iSurvCharacter) {
    static const float fScales[] = {
        0.888,  // Rochelle
        1.05,   // Coach
        0.955,  // Ellis
        1.0,    // Bill
        0.888   // Zoey
    };

    int iIdx = ConvertToExternalCharacter(iSurvCharacter) - 1;
    return (iIdx >= 0 && iIdx < sizeof(fScales)) ? fScales[iIdx] : 1.0;
}

int ConvertToExternalCharacter(int iSurvCharacter) {
    if (L4D2_GetSurvivorSetMod() == 1) {
        if (iSurvCharacter >= 0) {
            switch (iSurvCharacter) {
                case 2  : return 7;
                case 3  : return 6;
                default : return iSurvCharacter + 4;
            }
        }
    }
    return iSurvCharacter;
}