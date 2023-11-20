#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <left4dhooks>

float g_fOrigin[3];
float g_fAngles[3];

public Plugin myinfo =
{
    name        = "L4D2 Witch Restore",
    author      = "Visor",
    description = "Witch is restored at the same spot if she gets killed by a Tank.",
    version     = "1.0",
    url         = "https://github.com/Attano/smplugins"
};

public void OnPluginStart()
{
    HookEvent("witch_killed", OnWitchKilled, EventHookMode_Pre);
}

public void OnWitchKilled(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    int witch  = event.GetInt("witchid");

    if (IsValidTank(client))
    {
        GetEntPropVector(witch, Prop_Send, "m_vecOrigin",   g_fOrigin);
        GetEntPropVector(witch, Prop_Send, "m_angRotation", g_fAngles);
        CreateTimer(3.0, RestoreWitch, _, TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action RestoreWitch(Handle timer)
{
    L4D2_SpawnWitch(g_fOrigin, g_fAngles);
    return Plugin_Stop;
}

bool IsValidTank(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8);
}