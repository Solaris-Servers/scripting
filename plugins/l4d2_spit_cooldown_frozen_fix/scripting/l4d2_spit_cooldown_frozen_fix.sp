#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

ConVar    g_cvSpitInterval;
float     g_fSpitInterval;
ArrayList g_arrWaitList;

public Plugin myinfo = {
    name        = "[L4D2] Spit Cooldown Frozen Fix",
    author      = "Forgetest",
    description = "Simple fix for spit cooldown being \"frozen\".",
    version     = "1.2",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

public void OnPluginStart() {
    g_cvSpitInterval = FindConVar("z_spit_interval");
    g_fSpitInterval  = g_cvSpitInterval.FloatValue;
    g_cvSpitInterval.AddChangeHook(ConVarChanged_SpitInterval);

    HookEvent("round_start", Event_RoundStart);
    HookEvent("ability_use", Event_AbilityUse);

    g_arrWaitList = new ArrayList(2);
}

void ConVarChanged_SpitInterval(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fSpitInterval = g_cvSpitInterval.FloatValue;
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_arrWaitList.Clear();
}

void Event_AbilityUse(Event eEvent, const char[] szName, bool bDontBroadcast) {
    char szAbility[16];
    eEvent.GetString("ability", szAbility, sizeof(szAbility));
    // duration of spit animation seems to vary from [1.160003, 1.190002] on 100t sv
    if (strcmp(szAbility[8], "spit") == 0) g_arrWaitList.Set(g_arrWaitList.Push(eEvent.GetInt("userid")), GetGameTime() + 1.2, 1);
}

public void OnGameFrame() {
    while (g_arrWaitList.Length && GetGameTime() >= g_arrWaitList.Get(0, 1)) {
        CheckSpitAbility(g_arrWaitList.Get(0, 0));
        g_arrWaitList.Erase(0);
    }
}

void CheckSpitAbility(int iUserId) {
    int iClient = GetClientOfUserId(iUserId);
    if (iClient <= 0 || !IsPlayerAlive(iClient))
        return;

    if (GetEntProp(iClient, Prop_Send, "m_zombieClass") != 4)
        return;

    int iAbility = GetEntPropEnt(iClient, Prop_Send, "m_customAbility");
    if (iAbility == -1)
        return;

    // potential freezing detected
    if (GetEntPropFloat(iAbility, Prop_Send, "m_nextActivationTimer", 0) == 3600.0) {
        SetEntPropFloat(iAbility, Prop_Send, "m_nextActivationTimer", g_fSpitInterval, 0);
        SetEntPropFloat(iAbility, Prop_Send, "m_nextActivationTimer", GetGameTime() + g_fSpitInterval, 1);
        SetEntProp(iAbility, Prop_Send, "m_bHasBeenActivated", false);
    }
}