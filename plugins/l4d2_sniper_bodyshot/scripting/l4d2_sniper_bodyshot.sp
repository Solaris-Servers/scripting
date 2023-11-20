#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <left4dhooks>

#define HITGROUP_STOMACH 3

bool bLateLoad;

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int errMax)
{
    bLateLoad = late;
    return APLRes_Success;
}

public Plugin myinfo =
{
    name        = "L4D2 Sniper Hunter Bodyshot",
    author      = "Visor",
    description = "Remove sniper weapons' stomach hitgroup damage multiplier against hunters",
    version     = "1.1",
    url         = "https://github.com/Attano/L4D2-Competitive-Framework"
};

public void OnPluginStart()
{
    if (bLateLoad)
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
    SDKHook(client, SDKHook_TraceAttack, TraceAttack);
}

public Action TraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
    if (!IsHunter(victim) || !IsSurvivor(attacker) || IsFakeClient(attacker))
    {
        return Plugin_Continue;
    }

    int weapon = GetClientActiveWeapon(attacker);

    if (!IsValidSniper(weapon))
    {
        return Plugin_Continue;
    }

    if (hitgroup == HITGROUP_STOMACH)
    {
        damage = GetWeaponDamage(weapon) / 1.25;
        return Plugin_Changed;
    }

    return Plugin_Continue;
}

int GetClientActiveWeapon(int client)
{
    return GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
}

int GetWeaponDamage(int weapon)
{
    char classname[64];
    GetEdictClassname(weapon, classname, sizeof(classname));
    return L4D2_GetIntWeaponAttribute(classname, view_as<L4D2IntWeaponAttributes>(L4D2IWA_Damage));
}

bool IsValidSniper(int weapon)
{
    if (weapon > 0 && IsValidEntity(weapon))
    {
        char classname[64];
        GetEdictClassname(weapon, classname, sizeof(classname));
        return (StrEqual(classname, "weapon_sniper_scout") || StrEqual(classname, "weapon_sniper_awp"));
    }
    else
    {
        return false;
    }
}

bool IsSurvivor(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}

bool IsHunter(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 3 && GetEntProp(client, Prop_Send, "m_isGhost") != 1);
}