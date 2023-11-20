#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>

bool bLateLoad;

public Plugin myinfo =
{
    name        = "L4D2 Explosion Damage Prevention",
    author      = "Sir",
    version     = "1.0",
    description = "No more explosion damage from attacker (world)",
    url         = ""
};

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int errMax)
{
    bLateLoad = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    if (bLateLoad)
    {
        for (int i = 1; i <= MaxClients; i++)
        {
            if (!IsClientInGame(i))
            {
                continue;
            }

            OnClientPutInServer(i);
        }
    }
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    // Is the Victim an infected molested by Explosive damage caused by a non-client?
    if (!IsInfected(victim) || IsValidClient(attacker) || !(damagetype & DMG_BLAST))
    {
        return Plugin_Continue;
    }

    return Plugin_Handled;
}

bool IsInfected(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3;
}

bool IsValidClient(int client)
{
    if (client <= 0 || client > MaxClients)
    {
        return false;
    }

    return (IsClientInGame(client));
}