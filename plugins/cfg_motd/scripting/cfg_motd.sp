#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

ConVar hCvarMotdTitle;
ConVar hCvarMotdUrl;

public Plugin myinfo =
{
    name        = "Config Description",
    author      = "Visor",
    description = "Displays a descriptive MOTD on desire",
    version     = "0.2",
    url         = "https://github.com/Attano/smplugins"
};

public void OnPluginStart()
{
    hCvarMotdTitle = CreateConVar("sm_cfgmotd_title", "ZoneMod", "Custom MOTD title");
    hCvarMotdUrl   = CreateConVar("sm_cfgmotd_url",   "https://github.com/SirPlease/ZoneMod/blob/master/README.md", "Custom MOTD url");

    RegConsoleCmd("sm_changelog", ShowMOTD, "Show a MOTD describing the current config");
    RegConsoleCmd("sm_cfg",       ShowMOTD, "Show a MOTD describing the current config");
}

public Action ShowMOTD(int client, int args)
{
    char title[64];
    hCvarMotdTitle.GetString(title, sizeof(title));

    char url[192];
    hCvarMotdUrl.GetString(url, sizeof(url));

    ShowMOTDPanel(client, title, url, MOTDPANEL_TYPE_URL);
    return Plugin_Handled;
}