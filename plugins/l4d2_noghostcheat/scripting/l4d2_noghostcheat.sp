#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>

public Plugin myinfo =
{
    name        = "L4D2 Ghost-Cheat Preventer",
    author      = "Sir",
    description = "Don't broadcast Infected entities to Survivors while in ghost mode, disabling them from hooking onto the entities with 3rd party programs.",
    version     = "1.0",
    url         = "Nawl."
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_SetTransmit, Hook_SetTransmit);
}

public void OnPluginStart()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsValidClient(client))
        {
            SDKHook(client, SDKHook_SetTransmit, Hook_SetTransmit);
        }
    }
}

public Action Hook_SetTransmit(int client, int entity)
{
    // By default Valve still transmits the entities to Survivors, even when not in sight or in ghost mode.
    // Detecting if a player is actually in someone's sight is likely impossible to implement without issues, but blocking ghosts from being transmitted has no downsides.
    // This code will prevent 3rd party programs from hooking onto unspawned Infected.
    if (IsValidClient(client) && IsValidClient(entity) && GetClientTeam(client) == 3 && GetClientTeam(entity) == 2 && GetEntProp(client, Prop_Send, "m_isGhost") == 1)
    {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

bool IsValidClient(int client)
{
    if (client <= 0 || client > MaxClients || !IsClientConnected(client))
    {
        return false;
    }

    return IsClientInGame(client);
}