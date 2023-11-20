#pragma newdecls required
#pragma semicolon 1
#include <sourcemod>

ConVar wg_min_range;
float minRangeSquared;

public Plugin myinfo =
{
    name        = "Witch Glows",
    author      = "CanadaRox",
    description = "Sets glows on witches when survivors are far away",
    version     = "1.1",
    url         = "https://github.com/CanadaRox/sourcemod-plugins/tree/master/mutliwitch"
};

public void OnPluginStart()
{
    wg_min_range = CreateConVar("wg_min_range", "500", "Glows will not show if a survivor is this close to the witch", FCVAR_NONE, true, 0.0);
    minRangeSquared = wg_min_range.FloatValue;
    wg_min_range.AddChangeHook(MinRangeChange);

    HookEvent("witch_spawn",        WitchSpawn_Event);
    HookEvent("witch_harasser_set", WitchHarasserSet_Event);
}

public void MinRangeChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    minRangeSquared = wg_min_range.FloatValue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    if (IsPlayerAlive(client) && GetClientTeam(client) == 2)
    {
        int psychonic = GetEntityCount();

        float clientOrigin[3];
        GetClientAbsOrigin(client, clientOrigin);

        float witchOrigin[3];
        char buffer[32];

        for (int entity = MaxClients + 1; entity < psychonic; entity++)
        {
            if (IsValidEntity(entity) && GetEntityClassname(entity, buffer, sizeof(buffer)) && StrEqual(buffer, "witch"))
            {
                GetEntPropVector(entity, Prop_Send, "m_vecOrigin", witchOrigin);

                if (GetVectorDistance(clientOrigin, witchOrigin, true) < minRangeSquared)
                {
                    SetEntProp(entity, Prop_Send, "m_iGlowType", 0);
                }
            }
        }
    }

    return Plugin_Continue;
}

public void WitchSpawn_Event(Event event, const char[] name, bool dontBroadcast)
{
    int witch = event.GetInt("witchid");
    SetEntProp(witch, Prop_Send, "m_iGlowType", 3);
    SetEntProp(witch, Prop_Send, "m_glowColorOverride", 0xFFFFFF);
}

public void WitchHarasserSet_Event(Event event, const char[] name, bool dontBroadcast)
{
    int witch = event.GetInt("witchid");
    SetEntProp(witch, Prop_Send, "m_iGlowType", 0);
}