#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <colors>

ConVar linkCVar;

public Plugin myinfo =
{
    name        = "L4D2 Change Log Command",
    description = "Does things :)",
    author      = "Spoon",
    version     = "3.0.5",
    url         = "https://github.com/spoon-l4d2/"
};

public void OnPluginStart()
{
    linkCVar = CreateConVar("l4d2_cl_link", "https://github.com/spoon-l4d2/NextMod", "The to your change log");
    RegConsoleCmd("sm_changelog", ChangeLog_CMD);
}

public Action ChangeLog_CMD(int client, int args)
{
    char link[128];
    linkCVar.GetString(link, sizeof(link));
    CPrintToChat(client, "{blue}[{green}ChangeLog{blue}]{default} You can view the change log @ {blue}%s", link);
    return Plugin_Handled;
}