#pragma newdecls required
#pragma semicolon 1
#include <sourcemod>

#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))
#define MIN(%0,%1) (((%0) < (%1)) ? (%0) : (%1))

ConVar hw_max_health;
ConVar hw_cap_health;
ConVar hw_perm_gain;
ConVar hw_temp_gain;
ConVar pain_pills_decay_rate;

public Plugin myinfo =
{
    name        = "Healer Witch",
    author      = "CanadaRox",
    description = "Heals the survivor when they kill a witch",
    version     = "1",
    url         = ""
};

public void OnPluginStart()
{
    pain_pills_decay_rate = FindConVar("pain_pills_decay_rate");
    HookEvent("witch_killed", WitchKilled_Event);

    hw_max_health = CreateConVar("hw_max_health", "100", "Max health that a survivor can have after gaining health",      _, true, 100.0);
    hw_cap_health = CreateConVar("hw_cap_health", "1",   "Whether to cap the health survivors can gain from this plugin", _, true, 0.0, true, 1.0);
    hw_perm_gain  = CreateConVar("hw_perm_gain",  "5",   "Amount of perm health to gain for killing a witch",             _, true, 0.0);
    hw_temp_gain  = CreateConVar("hw_temp_gain",  "10",  "Amount of temp health to gain for killing a witch",             _, true, 0.0);
}

public void WitchKilled_Event(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !IsPlayerIncap(client))
    {
        IncreaseHealth(client);
    }
}

void IncreaseHealth(int client)
{
    bool capped      = hw_cap_health.BoolValue;
    int targetHealth = GetSurvivorPermHealth(client) + hw_perm_gain.IntValue;
    float targetTemp = GetSurvivorTempHealth(client) + hw_temp_gain.IntValue;

    if (capped)
    {
        int maxHealth = hw_max_health.IntValue;
        targetHealth  = MIN(targetHealth, maxHealth);

        float totalHealth = targetHealth + targetTemp;
        totalHealth       = MIN(totalHealth, float(maxHealth));
        targetTemp        = totalHealth - targetHealth;
    }

    SetSurvivorPermHealth(client, targetHealth);
    SetSurvivorTempHealth(client, targetTemp);
}

stock int GetSurvivorPermHealth(int client)
{
    return GetEntProp(client, Prop_Send, "m_iHealth");
}

stock void SetSurvivorPermHealth(int client, int health)
{
    SetEntProp(client, Prop_Send, "m_iHealth", health);
}

stock float GetSurvivorTempHealth(int client)
{
    float tmp = GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * pain_pills_decay_rate.FloatValue);
    return tmp > 0 ? tmp : 0.0;
}

stock void SetSurvivorTempHealth(int client, float newOverheal)
{
    SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
    SetEntPropFloat(client, Prop_Send, "m_healthBuffer",     newOverheal);
}

stock bool IsPlayerIncap(int client)
{
    return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}