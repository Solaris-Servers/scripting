#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <colors>

public Plugin myinfo =
{
    name        = "Witch on incap.",
    author      = "epilimic",
    version     = "1.0",
    description = "Spawns a witch anytime someone goes down!",
    url         = "http://buttsecs.org"
};

public void OnPluginStart()
{
    HookEvent("player_incapacitated", Event_Incap);
}

public void Event_Incap(Event event, char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (IsClientInGame(client) && GetClientTeam(client) == 2)
    {
        int flags = GetCommandFlags("z_spawn_old");
        SetCommandFlags("z_spawn_old", flags & ~FCVAR_CHEAT);
        FakeClientCommand(client, "z_spawn_old witch auto");
        CPrintToChatAll("{green}[{default}!{green}] {blue}%N{default} went down and spawned a witch!", client);
        SetCommandFlags("z_spawn_old", flags);
    }
}