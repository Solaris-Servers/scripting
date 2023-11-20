#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

bool isLateLoad;
ConVar pain_pills_decay_rate;

public Plugin myinfo =
{
    name        = "Witch Always Incaps",
    author      = "epilimic, canadarox, tab, dr gregory house",
    description = "Makes the witch always incap!",
    version     = "1",
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
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i))
            {
                OnClientPutInServer(i);
            }
        }
    }

    pain_pills_decay_rate = FindConVar("pain_pills_decay_rate");
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if (victim > 0 && victim <= MaxClients && !IsPlayerIncap(victim))
    {
        if (IsWitch(attacker))
        {
            damage = GetSurvivorHealth(victim);
            return Plugin_Changed;
        }
    }

    return Plugin_Continue;
}

stock bool IsWitch(int entity)
{
    if (!IsValidEntity(entity) || !IsValidEdict(entity))
    {
        return false;
    }

    char classname[24];
    GetEntityClassname(entity, classname, sizeof(classname));

    if (!StrEqual(classname, "witch"))
    {
        return false;
    }

    return true;
}

stock int GetPermHealth(int client)
{
    return GetEntProp(client, Prop_Send, "m_iHealth");
}

stock float GetTempHealth(int client)
{
    float tmp = GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * pain_pills_decay_rate.FloatValue);
    return tmp > 0 ? tmp : 0.0;
}

stock float GetSurvivorHealth(int client)
{
    return GetPermHealth(client) + GetTempHealth(client) + 1;
}

stock bool IsPlayerIncap(int client)
{
    return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}