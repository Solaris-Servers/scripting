#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo = {
    name        = "[L4D & 2] Tongue Float Fix",
    author      = "Forgetest",
    description = "Fix tongue instant choking survivors.",
    version     = "2.0",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

public void OnPluginStart() {
    ConVar cv;
    cv = FindConVar("tongue_vertical_choke_height");
    cv.SetInt(99999);
    cv.AddChangeHook(ConVarChanged);

    HookEvent("tongue_grab", Event_TongueGrab);
}

public void OnPluginEnd() {
    ConVar cv;
    cv = FindConVar("tongue_vertical_choke_height");
    cv.RemoveChangeHook(ConVarChanged);
    cv.RestoreDefault();
}

void ConVarChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    if (strcmp(szOldVal, szNewVal) == 0)
        return;
    cv.RemoveChangeHook(ConVarChanged);
    cv.SetString(szOldVal);
    cv.AddChangeHook(ConVarChanged);
}

/**
 * ```cpp
 * void CTongue::UpdateAirChoke(CTongue *this)
 * {
 *   ...
 *
 *   if ( gpGlobals->curtime - m_tongueVictimLastOnGroundTime <= tongue_vertical_choke_time_off_ground.GetFloat() )
 *   {
 *     if ( ground height within cvar value )
 *     {
 *       pVictim->OnStopHangingFromTongue();
 *       return;
 *     }
 *   }
 *
 *   if ( pVictim->IsHangingFromLedge() )
 *   {
 *     pVictim->OnStopHangingFromTongue();
 *     return;
 *   }
 *
 *   pVictim->OnStartHangingFromTongue();
 *   ...
 * }
 * ```
 */
void Event_TongueGrab(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)
        return;

    if (!IsClientInGame(iClient))
        return;

    int iAbility = GetEntPropEnt(iClient, Prop_Send, "m_customAbility");
    if (!IsValidEdict(iAbility))
        return;

    if (!HasEntProp(iAbility, Prop_Send, "m_tongueVictimLastOnGroundTime"))
        return;

    SetEntPropFloat(iAbility, Prop_Send, "m_tongueVictimLastOnGroundTime", GetGameTime());
}