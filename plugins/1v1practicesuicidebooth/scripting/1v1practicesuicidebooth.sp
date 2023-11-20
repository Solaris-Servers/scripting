#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>

public void OnPluginStart() {
    RegConsoleCmd("sm_stuck",         Cmd_Kill);
    RegConsoleCmd("sm_kill",          Cmd_Kill);
    RegConsoleCmd("sm_suicide",       Cmd_Kill);
    RegConsoleCmd("sm_insertquarter", Cmd_Kill);
}

Action Cmd_Kill(int iClient, int iArgs) {
    if (GetClientTeam(iClient) != 3) {
        CPrintToChat(iClient, "{red}[{default}Suicide Booth{red}]{default} You should be in the infected team to suicide!");
        return Plugin_Handled;
    }
    if (!IsPlayerAlive(iClient)) {
        CPrintToChat(iClient, "{red}[{default}Suicide Booth{red}]{default} Wait until you're alive to suicide!");
        return Plugin_Handled;
    }
    if (L4D_IsPlayerGhost(iClient)) {
        CPrintToChat(iClient, "{red}[{default}Suicide Booth{red}]{default} You are not alive to suicide!");
        return Plugin_Handled;
    }
    ForcePlayerSuicide(iClient);
    int result_int = GetURandomInt() % 2;
    CPrintToChat(iClient, "%s", result_int ? "{red}[{default}Suicide Booth{red}]{default} You are now dead, please take your receipt." :
                                             "{red}[{default}Suicide Booth{red}]{default} You are now dead. Thank you for using Stop-and-Drop, America's favorite suicide booth since 2008!");
    return Plugin_Handled;
}

bool L4D_IsPlayerGhost(int iClient) {
    return view_as<bool>(GetEntProp(iClient, Prop_Send, "m_isGhost"));
}