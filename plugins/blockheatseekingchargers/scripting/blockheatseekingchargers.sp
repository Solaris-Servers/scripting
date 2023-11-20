/* -------------------CHANGELOG--------------------
 1.2
 - Implemented new method of blocking charger`s auto-aim, now it just continues charging instead of stopping the attack (thanks to dcx2)

 1.1
 - Fixed possible non-changer infected detecting as heatseeking charger

 1.0
 - Initial release
^^^^^^^^^^^^^^^^^^^^CHANGELOG^^^^^^^^^^^^^^^^^^^^ */

#pragma newdecls required
#pragma semicolon 1
#include <sourcemod>

bool IsInCharge[MAXPLAYERS + 1];

public Plugin myinfo =
{
    name    = "Blocks heatseeking chargers",
    version = "1.2",
    author  = "sheo",
}

public void OnPluginStart()
{
    HookEvent("player_bot_replace",   BotReplacesPlayer);
    HookEvent("charger_charge_start", Event_ChargeStart);
    HookEvent("charger_charge_end",   Event_ChargeEnd);
    HookEvent("player_spawn",         Event_OnPlayerSpawn);
    HookEvent("player_death",         Event_OnPlayerDeath);
}

public void Event_ChargeStart(Event event, const char[] name, bool dontBroadcast)
{
    IsInCharge[GetClientOfUserId(event.GetInt("userid"))] = true;
}

public void Event_ChargeEnd(Event event, const char[] name, bool dontBroadcast)
{
    IsInCharge[GetClientOfUserId(event.GetInt("userid"))] = false;
}

public void BotReplacesPlayer(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("player"));

    if (IsInCharge[client])
    {
        int bot = GetClientOfUserId(event.GetInt("bot"));
        SetEntProp(bot, Prop_Send, "m_fFlags", GetEntProp(bot, Prop_Send, "m_fFlags") | FL_FROZEN); //New method, by dcx2
        IsInCharge[client] = false;
    }
}

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    IsInCharge[GetClientOfUserId(event.GetInt("userid"))] = false;
}

public void Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    IsInCharge[GetClientOfUserId(event.GetInt("userid"))] = false;
}