#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <colors>

#include <l4d2util/stocks>
#include <l4d2util/tanks>

ConVar cvarSmallRefill;

public Plugin myinfo =
{
    name        = "L4D2 Tank Hittable Refill",
    author      = "Sir",
    version     = "1.0",
    description = "Refill Tank's frustration whenever a hittable hits a Survivor"
};

public void OnPluginStart()
{
    cvarSmallRefill = CreateConVar("l4d_tank_hittable_small", "0", "Do we allow Small hittables such as Garbage Bins and Tables to refill frustration?");
    HookEvent("player_hurt",          PlayerHurt);
    HookEvent("player_incapacitated", PlayerIncap);
}

public void PlayerHurt(Event event, char[] name, bool dontBroadcast)
{
    int Victim   = GetClientOfUserId(event.GetInt("userid"));
    int Attacker = GetClientOfUserId(event.GetInt("attacker"));
    int dmg      = event.GetInt("dmg_health");

    //Is player actually a Tank?
    if (!CheckForTank(Attacker, Victim))
    {
        return;
    }

    //Do we allow small hittables?
    if (dmg < 5 && cvarSmallRefill.IntValue == 0)
    {
        return;
    }

    //Refill that Frustration!
    SetTankFrustration(Attacker, 100);
}

public void PlayerIncap(Event event, char[] name, bool dontBroadcast)
{
    int Victim   = GetClientOfUserId(event.GetInt("userid"));
    int Attacker = GetClientOfUserId(event.GetInt("attacker"));

    //Is player actually a Tank?
    if (!CheckForTank(Attacker, Victim))
    {
        return;
    }

    //Refill that Frustration!
    SetTankFrustration(Attacker, 100);
}

bool IsLegitClient(int client)
{
    if (client > 0 && client <= MaxClients && IsClientInGame(client))
    {
        return true;
    }

    return false;
}

bool CheckForTank(int Attacker, int Victim)
{
    if (!IsLegitClient(Victim) || !IsLegitClient(Attacker))
    {
        return false;
    }

    if (GetClientTeam(Victim) != 2 || GetClientTeam(Attacker) != 3)
    {
        return false;
    }

    if (GetEntProp(Attacker, Prop_Send, "m_zombieClass") != 8)
    {
        return false;
    }

    return true;
}