#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

float block_square[4];
StringMap hSpitBlockSquares;
bool lateLoad;

public Plugin myinfo =
{
    name        = "L4D2 Spit Blocker",
    author      = "ProdigySim + Estoopi + Jacob, Visor (:D)",
    description = "Blocks spit damage on various maps",
    version     = "2.0",
    url         = "https://github.com/Attano/Equilibrium"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    lateLoad = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    RegServerCmd("spit_block_square", AddSpitBlockSquare);
    hSpitBlockSquares = new StringMap();

    if (lateLoad)
    {
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i))
            {
                SDKHook(i, SDKHook_OnTakeDamage, stop_spit_dmg);
            }
        }
    }
}

public Action AddSpitBlockSquare(int args)
{
    if (args < 1)
    {
        return Plugin_Handled;
    }

    char mapname[64];
    GetCmdArg(1, mapname, sizeof(mapname));

    float square[4];
    char buf[32];

    for (int i = 0; i < 4; i++)
    {
        GetCmdArg(2 + i, buf, sizeof(buf));
        square[i] = StringToFloat(buf);
    }

    hSpitBlockSquares.SetArray(mapname, square, 4);
    OnMapStart();
    return Plugin_Handled;
}

public void OnMapStart()
{
    char mapname[64];
    GetCurrentMap(mapname, sizeof(mapname));

    if (!hSpitBlockSquares.GetArray(mapname, block_square, 4))
    {
        block_square[0] = 0.0;
        block_square[1] = 0.0;
        block_square[2] = 0.0;
        block_square[3] = 0.0;
    }
}

public void OnClientPostAdminCheck(int client)
{
    SDKHook(client, SDKHook_OnTakeDamage, stop_spit_dmg);
}

public Action stop_spit_dmg(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if (victim <= 0 || victim > MaxClients)
    {
        return Plugin_Continue;
    }

    if (!IsValidEdict(inflictor))
    {
        return Plugin_Continue;
    }

    char sInflictor[64];
    GetEdictClassname(inflictor, sInflictor, sizeof(sInflictor));

    if (StrEqual(sInflictor, "insect_swarm"))
    {
        float origin[3];
        GetClientAbsOrigin(victim, origin);

        if (isPointIn2DBox(origin[0], origin[1], block_square[0], block_square[1], block_square[2], block_square[3]))
        {
            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}

// Is x0,y0 in the box defined by x1,y1 and x2,y2
stock bool isPointIn2DBox(float x0, float y0, float x1, float y1, float x2, float y2)
{
    if (x1 > x2)
    {
        if (y1 > y2)
        {
            return x0 <= x1 && x0 >= x2 && y0 <= y1 && y0 >= y2;
        }
        else
        {
            return x0 <= x1 && x0 >= x2 && y0 >= y1 && y0 <= y2;
        }
    }
    else
    {
        if (y1 > y2)
        {
            return x0 >= x1 && x0 <= x2 && y0 <= y1 && y0 >= y2;
        }
        else
        {
            return x0 >= x1 && x0 <= x2 && y0 >= y1 && y0 <= y2;
        }
    }
}