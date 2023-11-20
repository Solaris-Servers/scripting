#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <solaris/stocks>

float SurvivorStart[3];

public Plugin myinfo =
{
    name        = "No Safe Room Medkits",
    author      = "Blade",
    description = "Removes Safe Room Medkits",
    version     = "0.1.1",
    url         = "nope"
}

public void OnPluginStart()
{
    HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
}

// On every round,
public void Event_RoundStart(Event event, char[] name, bool dontBroadcast)
{
    if (SDK_IsVersus() || SDK_IsCoop())
    {
        // find where the survivors start so we know which medkits to replace,
        FindSurvivorStart();
        // and replace the medkits with pills.
        ReplaceMedkits();
    }
}

public void FindSurvivorStart()
{
    int EntityCount = GetEntityCount();
    char EdictClassName[128];
    float Location[3];
    //Search entities for either a locked saferoom door,
    for (int i = 0; i <= EntityCount; i++)
    {
        if (IsValidEntity(i))
        {
            GetEdictClassname(i, EdictClassName, sizeof(EdictClassName));

            if ((StrContains(EdictClassName, "prop_door_rotating_checkpoint", false) != -1) && (GetEntProp(i, Prop_Send, "m_bLocked")==1))
            {
                GetEntPropVector(i, Prop_Send, "m_vecOrigin", Location);
                SurvivorStart = Location;
                return;
            }
        }
    }

    //or a survivor start point.
    for (int i = 0; i <= EntityCount; i++)
    {
        if (IsValidEntity(i))
        {
            GetEdictClassname(i, EdictClassName, sizeof(EdictClassName));

            if (StrContains(EdictClassName, "info_survivor_position", false) != -1)
            {
                GetEntPropVector(i, Prop_Send, "m_vecOrigin", Location);
                SurvivorStart = Location;
                return;
            }
        }
    }
}

public void ReplaceMedkits()
{
    int EntityCount = GetEntityCount();
    char EdictClassName[128];
    float NearestMedkit[3];
    float Location[3];

    //Look for the nearest medkit from where the survivors start,
    for (int i = 0; i <= EntityCount; i++)
    {
        if (IsValidEntity(i))
        {
            GetEdictClassname(i, EdictClassName, sizeof(EdictClassName));

            if (StrContains(EdictClassName, "weapon_first_aid_kit", false) != -1)
            {
                GetEntPropVector(i, Prop_Send, "m_vecOrigin", Location);

                //If NearestMedkit is zero, then this must be the first medkit we found.
                if ((NearestMedkit[0] + NearestMedkit[1] + NearestMedkit[2]) == 0.0)
                {
                    NearestMedkit = Location;
                    continue;
                }

                //If this medkit is closer than the last medkit, record its location.
                if (GetVectorDistance(SurvivorStart, Location, false) < GetVectorDistance(SurvivorStart, NearestMedkit, false))
                {
                    NearestMedkit = Location;
                }
            }
        }
    }
    //then remove the kits
    for (int i = 0; i <= EntityCount; i++)
    {
        if (IsValidEntity(i))
        {
            GetEdictClassname(i, EdictClassName, sizeof(EdictClassName));

            if (StrContains(EdictClassName, "weapon_first_aid_kit", false) != -1)
            {
                GetEntPropVector(i, Prop_Send, "m_vecOrigin", Location);

                if (GetVectorDistance(NearestMedkit, Location, false) < 400)
                {
                    AcceptEntityInput(i, "Kill");
                }
            }
        }
    }
}