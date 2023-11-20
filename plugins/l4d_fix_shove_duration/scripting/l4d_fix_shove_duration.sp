#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>
#include <left4dhooks>

#define PLUGIN_VERSION

#define GAMEDATA_FILE "l4d_fix_shove_duration"
#define KEY_FUNCTION  "CTerrorPlayer::OnShovedByLunge"

ConVar g_cvGunSwingDuration;

public Plugin myinfo = {
    name        = "[L4D & 2] Fix Shove Duration",
    author      = "Forgetest",
    description = "Fix SI getting shoved by \"nothing\".",
    version     = "1.0",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

public void OnPluginStart() {
    GameData gmConf = new GameData(GAMEDATA_FILE);
    if (!gmConf) SetFailState("Missing gamedata \""...GAMEDATA_FILE..."\"");
    DynamicDetour dhDetour = DynamicDetour.FromConf(gmConf, KEY_FUNCTION);
    if (!dhDetour) SetFailState("Missing detour setup \""...KEY_FUNCTION..."\"");
    if (!dhDetour.Enable(Hook_Pre, DTR_OnShovedByLunge) || !dhDetour.Enable(Hook_Post, DTR_OnShovedByLunge_Post))
        SetFailState("Failed to detour \""...KEY_FUNCTION..."\"");
    delete dhDetour;
    delete gmConf;
    g_cvGunSwingDuration = FindConVar("z_gun_swing_duration");
}

MRESReturn DTR_OnShovedByLunge(DHookReturn hReturn, DHookParam hParams) {
    int iClient = hParams.Get(1);
    ITimer_OffsetTimestamp(GetShovingTimer(iClient), g_cvGunSwingDuration.FloatValue - 1.0);
    return MRES_Ignored;
}

MRESReturn DTR_OnShovedByLunge_Post(DHookReturn hReturn, DHookParam hParams) {
    int iClient = hParams.Get(1);
    ITimer_OffsetTimestamp(GetShovingTimer(iClient), 1.0 - g_cvGunSwingDuration.FloatValue);
    return MRES_Ignored;
}

public Action L4D2_OnJockeyRide(int iVictim, int iAttacker) {
    ITimer_OffsetTimestamp(GetShovingTimer(iVictim), g_cvGunSwingDuration.FloatValue - 1.0);
    return Plugin_Continue;
}

public void L4D2_OnJockeyRide_Post(int iVictim, int iAttacker) {
    ITimer_OffsetTimestamp(GetShovingTimer(iVictim), 1.0 - g_cvGunSwingDuration.FloatValue);
}

void ITimer_OffsetTimestamp(IntervalTimer iTimer, float fOffset) {
    if (ITimer_HasStarted(iTimer)) {
        float fTimeStamp = ITimer_GetTimestamp(iTimer);
        ITimer_SetTimestamp(iTimer, fTimeStamp + fOffset);
    }
}

IntervalTimer GetShovingTimer(int iClient) {
    static int iShovingTimerOffs = -1;
    if (iShovingTimerOffs == -1) iShovingTimerOffs = FindSendPropInfo("CTerrorPlayer", "m_customAbility") + 164;
    return view_as<IntervalTimer>(GetEntityAddress(iClient) + view_as<Address>(iShovingTimerOffs));
}