//SourcePawn

/*          Changelog
*   29/08/2014 Version 1.0 – Released.
*   28/12/2016 Version 1.1 – Changed syntax.
*   22/10/2017 Version 1.2 – Fixed jump after vomitjar-boost and after "TakeOverBot" event.
*   08/11/2018 Version 1.2.1 – Fixed incorrect flags initializing; some changes in syntax.
*   25/04/2019 Version 1.2.2 – Command "sm_autobhop" has fixed for localplayer in order to work properly in console.
*   16/11/2019 Version 1.3.2 – At the moment CBasePlayer specific flags (or rather FL_ONGROUND bit) aren't longer fixed, by reason
*                           player's jump animation during boost is incorrect (it's must be ACT_RUN_CROUCH_* sequence always!);
*                           removed 'm_nWaterLevel' check (we cannot swim in this game anyway) to avoid problems with jumping
*                           on some deep water maps.
*/

#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <colors>

bool g_bAutoBhop[MAXPLAYERS + 1] = {true, ...};

public Plugin myinfo = {
    name        = "Auto Bunnyhop",
    author      = "noa1mbot",
    description = "Allows jump easier.",
    version     = "1.3.2",
    url         = "https://steamcommunity.com/groups/noa1mbot"
}

//============================================================
//============================================================

public void OnPluginStart() {
    RegConsoleCmd("sm_autobhop", Cmd_Autobhop);
}

public void OnClientPutInServer(int iClient) {
    g_bAutoBhop[iClient] = true;
}

public void OnClientDisconnect(int iClient) {
    g_bAutoBhop[iClient] = true;
}

Action Cmd_Autobhop(int iClient, int iArgs) {
    g_bAutoBhop[iClient] = !g_bAutoBhop[iClient];
    if (g_bAutoBhop[iClient]) CPrintToChat(iClient, "{green}[{default}!{green}] {olive}AutoBhop {blue}ON{default}!");
    else                      CPrintToChat(iClient, "{green}[{default}!{green}] {olive}AutoBhop {red}OFF{default}!");
    return Plugin_Handled;
}

public Action OnPlayerRunCmd(int iClient, int &iButtons) {
    if (!g_bAutoBhop[iClient])   return Plugin_Continue;
    if (!IsPlayerAlive(iClient)) return Plugin_Continue;
    if (!(iButtons & IN_JUMP))   return Plugin_Continue;
    if (GetEntPropEnt(iClient, Prop_Send, "m_hGroundEntity") == -1) {
        if (GetEntityMoveType(iClient) != MOVETYPE_LADDER)
            iButtons &= ~IN_JUMP;
    }
    return Plugin_Continue;
}