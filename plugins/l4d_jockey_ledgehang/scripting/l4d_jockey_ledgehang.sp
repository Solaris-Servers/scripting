#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#include <l4d2util/stocks>
#include <l4d2util/survivors>

float fLedgeHangInterval;
ConVar hCvarJockeyLedgeHang;

public Plugin myinfo =
{
    name        = "L4D2 Jockey Ledge Hang Recharge",
    author      = "Jahze",
    version     = "1.0",
    description = "Adds a cvar to adjust the recharge timer of a jockey after he ledge hangs a survivor."
};

public void OnPluginStart()
{
    hCvarJockeyLedgeHang = CreateConVar("z_leap_interval_post_ledge_hang", "10", "How long before a jockey can leap again after a ledge hang");
    fLedgeHangInterval   = hCvarJockeyLedgeHang.FloatValue;
    hCvarJockeyLedgeHang.AddChangeHook(JockeyLedgeHangChange);
    HookEvent("jockey_ride_end", JockeyRideEnd);
}

public void JockeyLedgeHangChange(ConVar cvar, const char[] oldValue, const char[] newValue)
{
    fLedgeHangInterval = StringToFloat(newValue);
}

public void JockeyRideEnd(Event event, const char[] name, bool dontBroadcast)
{
    int jockeyAttacker = GetClientOfUserId(event.GetInt("userid"));
    int jockeyVictim   = GetClientOfUserId(event.GetInt("victim"));

    if (IsHangingFromLedge(jockeyVictim))
    {
        FixupJockeyTimer(jockeyAttacker);
    }
}

void FixupJockeyTimer(int client)
{
    int iEntity = -1;

    while ((iEntity = FindEntityByClassname(iEntity, "ability_leap")) != -1)
    {
        if (GetEntPropEnt(iEntity, Prop_Send, "m_owner") == client)
        {
            break;
        }
    }

    if (iEntity == -1)
    {
        return;
    }

    SetEntPropFloat(iEntity, Prop_Send, "m_timestamp", GetGameTime() + fLedgeHangInterval);
    SetEntPropFloat(iEntity, Prop_Send, "m_duration",  fLedgeHangInterval);
}