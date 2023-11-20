#pragma newdecls required
#pragma semicolon 1
#include <sourcemod>

#define REALLY_SMALL_FLOAT 0.0000008775

float defaultRate;
ConVar pain_pills_decay_rate;

public Plugin myinfo =
{
    name        = "No Tank Bleed",
    author      = "CanadaRox",
    description = "Stop temp health from decaying during a tank fight",
    version     = "3.0",
    url         = "https://github.com/CanadaRox/sourcemod-plugins/tree/master/notankbleed"
};

public void OnPluginStart()
{
    pain_pills_decay_rate = FindConVar("pain_pills_decay_rate");
    defaultRate = pain_pills_decay_rate.FloatValue;

    HookEvent("round_end",    RoundEnd_Event, EventHookMode_PostNoCopy);
    HookEvent("tank_spawn",   TankSpawn_Event);
    HookEvent("player_death", PlayerDeath_Event);
}

public void OnPluginEnd()
{
    pain_pills_decay_rate.SetFloat(defaultRate);
}

public void RoundEnd_Event(Event event, const char[] name, bool dontBroadcast)
{
    SetNewRate(defaultRate);
}

public void TankSpawn_Event(Event event, const char[] name, bool dontBroadcast)
{
    SetNewRate(REALLY_SMALL_FLOAT);
}

public void PlayerDeath_Event(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (client > 0 && client <= MaxClients && GetClientTeam(client) == 3 && GetZombieClass(client) == 8)
    {
        bool foundTank = false;

        for (int i = 1; i <= MaxClients; i++)
        {
            if (client != i && IsClientInGame(i) && GetClientTeam(i) == 3 && GetZombieClass(i) == 8)
            {
                foundTank = true;
                break;
            }
        }

        if (!foundTank)
        {
            SetNewRate(defaultRate);
        }
    }
}

stock void SetNewRate(float rate = REALLY_SMALL_FLOAT)
{
    float tempHealth;

    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !IsPlayerIncap(client))
        {
            tempHealth = GetSurvivorTempHealth(client);

            if (tempHealth > 0.0)
            {
                SetSurvivorTempHealth(client, tempHealth);
            }
        }
    }

    pain_pills_decay_rate.SetFloat(rate);
}

stock float GetSurvivorTempHealth(int client)
{
    return GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * pain_pills_decay_rate.FloatValue);
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

stock int GetZombieClass(int client)
{
    return GetEntProp(client, Prop_Send, "m_zombieClass");
}