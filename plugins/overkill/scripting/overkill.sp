#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CLASSNAME_LENGTH 64

bool isLateLoad;
float health[MAXPLAYERS + 1] = { -1.0, ...};
ConVar pain_pills_decay_rate;

public Plugin myinfo =
{
    name        = "Infected Overkill",
    author      = "CanadaRox",
    description = "Enables overkill damage to apply to incapped survivors",
    version     = "1.0",
    url         = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    isLateLoad = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    if (isLateLoad)
    {
        for (int client = 1; client <= MaxClients; client++)
        {
            if (IsClientInGame(client))
            {
                OnClientPutInServer(client);
            }
        }
    }

    pain_pills_decay_rate = FindConVar("pain_pills_decay_rate");
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamage,     OnTakeDamage);
    SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

public void OnClientDisconnect(int client)
{
    SDKUnhook(client, SDKHook_OnTakeDamage,     OnTakeDamage);
    SDKUnhook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

public void OnTakeDamage(int victim, int attacker, int inflictor, float damage, int damagetype)
{
    if (victim > 0 && victim <= MaxClients && GetClientTeam(victim) == 2 && attacker > 0 && attacker <= MaxClients && !IsPlayerIncap(victim))
    {
        health[victim] = GetSurvivorHealth(victim);
    }
}

public void OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
    if (GetClientTeam(victim) == 2 && IsPlayerIncap(victim) && health[victim] > 0)
    {
        char sClassname[CLASSNAME_LENGTH];
        GetEntityClassname(inflictor, sClassname, CLASSNAME_LENGTH);

        if (!StrEqual(sClassname, "prop_physics") && !StrEqual(sClassname, "witch"))
        {
            float overkillDamage = damage - health[victim];
            SDKHooks_TakeDamage(victim, attacker, attacker, overkillDamage);
        }

        health[victim] = -1.0;
    }
}

stock float GetSurvivorHealth(int client)
{
    return GetPermHealth(client) + GetTempHealth(client);
}

stock int GetPermHealth(int client)
{
    return GetEntProp(client, Prop_Send, "m_iHealth");
}

stock bool IsPlayerIncap(int client)
{
    return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}

stock float GetTempHealth(int client)
{
    return GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * pain_pills_decay_rate.FloatValue);
}