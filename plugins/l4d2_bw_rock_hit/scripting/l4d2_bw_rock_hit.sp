#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

bool lateLoad;

public Plugin myinfo =
{
    name        = "L4D2 Black&White Rock Hit",
    author      = "Visor",
    description = "Stops rocks from passing through soon-to-be-dead Survivors",
    version     = "1.0",
    url         = "https://github.com/Attano/L4D2-Competitive-Framework"
};

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int errMax)
{
    lateLoad = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    if (lateLoad)
    {
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i))
            {
                OnClientPutInServer(i);
            }
        }
    }
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
    SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damageType, int &weapon, float damageForce[3], float damagePosition[3])
{
    // decl String:classname[64];
    // GetEdictClassname(inflictor, classname, sizeof(classname));
    // PrintToChatAll("Victim %d attacker %d inflictor %d damageType %d weapon %d", victim, attacker, inflictor, damageType, weapon);
    // PrintToChatAll("Victim %N(%i/%i) attacker %N classname %s", victim, GetSurvivorPermanentHealth(victim), GetSurvivorTemporaryHealth(victim), attacker, classname);

    // Not what we need
    if (!IsSurvivor(victim) || !IsTank(attacker) || !IsTankRock(inflictor))
    {
        return Plugin_Continue;
    }

    // Not b&w
    if (!IsOnCriticalStrike(victim))
    {
        return Plugin_Continue;
    }

    // Gotcha
    if (GetSurvivorTemporaryHealth(victim) <= FindConVar("vs_tank_damage").IntValue)
    {
        // SDKHooks_TakeDamage(inflictor, attacker, attacker, 300.0, DMG_CLUB, GetActiveWeapon(victim));
        // AcceptEntityInput(inflictor, "Kill");
        // StopSound(attacker, SNDCHAN_AUTO, "player/tank/attack/thrown_missile_loop_1.wav");
        CTankRock__Detonate(inflictor);
    }

    return Plugin_Continue;
}

int GetSurvivorTemporaryHealth(int client)
{
    int temphp = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * FindConVar("pain_pills_decay_rate").FloatValue)) - 1;
    return (temphp > 0 ? temphp : 0);
}

int IsOnCriticalStrike(int client)
{
    return (FindConVar("survivor_max_incapacitated_count").IntValue == GetEntProp(client, Prop_Send, "m_currentReviveCount"));
}

bool IsSurvivor(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}

bool IsTank(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8 && IsPlayerAlive(client));
}

bool IsTankRock(int entity)
{
    if (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
    {
        char classname[64];
        GetEdictClassname(entity, classname, sizeof(classname));
        return StrEqual(classname, "tank_rock");
    }

    return false;
}

void CTankRock__Detonate(int rock)
{
    static Handle call = null;

    if (call == null)
    {
        StartPrepSDKCall(SDKCall_Entity);

        if (!PrepSDKCall_SetSignature(SDKLibrary_Server, "@_ZN9CTankRock8DetonateEv", 0))
        {
            return;
        }

        call = EndPrepSDKCall();

        if (call == null)
        {
            return;
        }
    }

    SDKCall(call, rock);
}