#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

bool lateLoad;
ConVar z_witch_damage;

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int errMax)
{
    lateLoad = late;
    return APLRes_Success;
}

public Plugin myinfo =
{
    name        = "L4D2 Ultra Witch",
    author      = "Visor",
    description = "The Witch's hit deals a set amount of damage instead of instantly incapping, while also sending the survivor flying. Fixes convar z_witch_damage",
    version     = "1.1",
    url         = "https://github.com/Attano/Equilibrium"
};

public void OnPluginStart()
{
    z_witch_damage = FindConVar("z_witch_damage");

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
    if (!IsSurvivor(victim) || !IsWitch(attacker))
    {
        return Plugin_Continue;
    }

    if (IsIncapped(victim))
    {
        return Plugin_Continue;
    }

    float witchDamage = z_witch_damage.FloatValue;

    if (witchDamage >= (GetSurvivorPermanentHealth(victim) + GetSurvivorTemporaryHealth(victim)))
    {
        return Plugin_Continue;
    }

    // Replication of tank punch throw algorithm from CTankClaw::OnPlayerHit()
    float victimPos[3];
    GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimPos);
    NormalizeVector(victimPos, victimPos);

    float witchPos[3];
    GetEntPropVector(attacker, Prop_Send, "m_vecOrigin", witchPos);
    NormalizeVector(witchPos,  witchPos);

    float throwForce[3];
    throwForce[0] = Clamp((360000.0 * (victimPos[0] - witchPos[0])), -400.0, 400.0);
    throwForce[1] = Clamp((90000.0 * (victimPos[1] - witchPos[1])), -400.0, 400.0);
    throwForce[2] = 300.0;

    ApplyAbsVelocityImpulse(victim, throwForce);
    L4D2Direct_DoAnimationEvent(victim, 96);
    damage = witchDamage;
    return Plugin_Changed;
}

int GetSurvivorTemporaryHealth(int client)
{
    int temphp = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * FindConVar("pain_pills_decay_rate").FloatValue)) - 1;
    return (temphp > 0 ? temphp : 0);
}

int GetSurvivorPermanentHealth(int client)
{
    return GetEntProp(client, Prop_Send, "m_currentReviveCount") > 0 ? 0 : (GetEntProp(client, Prop_Send, "m_iHealth") > 0 ? GetEntProp(client, Prop_Send, "m_iHealth") : 0);
}

bool IsIncapped(int client)
{
    return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}

bool IsWitch(int entity)
{
    if (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
    {
        char strClassName[64];
        GetEdictClassname(entity, strClassName, sizeof(strClassName));
        return StrEqual(strClassName, "witch");
    }

    return false;
}

bool IsSurvivor(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}

float Clamp(float value, float min, float max)
{
    if (value > max)
    {
        return max;
    }

    if (value < min)
    {
        return min;
    }

    return value;
}

void ApplyAbsVelocityImpulse(int client, const float impulseForce[3])
{
    static Handle call = null;

    if (call == null)
    {
        StartPrepSDKCall(SDKCall_Player);

        if (!PrepSDKCall_SetSignature(SDKLibrary_Server, "@_ZN11CBaseEntity23ApplyAbsVelocityImpulseERK6Vector", 0))
        {
            return;
        }

        PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
        call = EndPrepSDKCall();

        if (call == null)
        {
            return;
        }
    }

    SDKCall(call, client, impulseForce);
}