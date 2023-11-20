#pragma newdecls required
#pragma semicolon 1
#include <sourcemod>

ConVar hCvarMaxZombies;

public Plugin myinfo =
{
    name        = "Character Fix",
    author      = "someone",
    version     = "0.1",
    description = "Fixes character change exploit in 1v1, 2v2, 3v3"
};

public void OnPluginStart()
{
    AddCommandListener(TeamCmd, "jointeam");
    hCvarMaxZombies = FindConVar("z_max_player_zombies");
}

public Action TeamCmd(int client, const char[] command, int argc)
{
    if (client && argc > 0)
    {
        static char sBuffer[128];
        GetCmdArg(1, sBuffer, sizeof(sBuffer));
        int newteam = StringToInt(sBuffer);

        if (GetClientTeam(client) == 2 && (StrEqual("Infected", sBuffer, false) || newteam == 3))
        {
            int zombies = 0;

            for (int i = 1; i <= MaxClients; i++)
            {
                if (IsClientInGame(i) && GetClientTeam(i)==3)
                {
                    zombies++;
                }
            }

            if (zombies >= hCvarMaxZombies.IntValue)
            {
                return Plugin_Handled;
            }
        }
    }

    return Plugin_Continue;
}