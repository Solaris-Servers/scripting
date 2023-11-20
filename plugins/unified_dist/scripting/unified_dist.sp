#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <left4dhooks>

ConVar hMapDist;

public Plugin myinfo =
{
    name        = "Map Distance Unifier",
    author      = "CanadaRox",
    description = "Sets every map to the same max distance",
    version     = "1",
    url         = "https://github.com/CanadaRox/sourcemod-plugins/unified_dist/"
};

public void OnPluginStart()
{
    hMapDist = CreateConVar("map_dist", "100", "Set custom map distance for every map");
}

public void OnMapStart()
{
    L4D_SetVersusMaxCompletionScore(hMapDist.IntValue);
}