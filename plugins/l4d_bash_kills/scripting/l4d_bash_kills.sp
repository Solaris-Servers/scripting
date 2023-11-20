#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>

ConVar hCvarBashKills;
bool bCvarBashKills;
bool bLateLoad;

public Plugin myinfo =
{
    name        = "L4D2 Bash Kills",
    author      = "Jahze",
    version     = "1.0",
    description = "Stop special infected getting bashed to death"
}

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int errMax)
{
    bLateLoad = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    hCvarBashKills = CreateConVar("l4d_no_bash_kills", "1", "Prevent special infected from getting bashed to death");
    bCvarBashKills = hCvarBashKills.BoolValue;
    hCvarBashKills.AddChangeHook(OnCvarBashKills_Changed);

    if (bLateLoad)
    {
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i))
            {
                SDKHook(i, SDKHook_OnTakeDamage, Hurt);
            }
        }
    }
}

public void OnCvarBashKills_Changed(ConVar convar, const char[] oldValue, const char[] newValue)
{
    bCvarBashKills = hCvarBashKills.BoolValue;
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamage, Hurt);
}

public Action Hurt(int victim, int &attacker, int &inflictor, float &damage, int &damageType, int &weapon, float damageForce[3], float damagePosition[3])
{
    if (!bCvarBashKills || !IsSI(victim))
    {
        return Plugin_Continue;
    }

    if (damage == 250.0 && damageType == 128 && weapon == -1 && IsSurvivor(attacker))
    {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

bool IsSI(int client)
{
    if (client < 1 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client))
    {
        return false;
    }

    int playerClass = GetEntProp(client, Prop_Send, "m_zombieClass");

    if (playerClass == 2 || playerClass == 4)
    {
        return false;
    }

    return true;
}

bool IsSurvivor(int client)
{
    if (client < 1 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 2 || !IsPlayerAlive(client))
    {
        return false;
    }

    return true;
}