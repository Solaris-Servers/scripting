#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

StringMap g_smPluginsMatched;
bool g_bPluginsLoaded = false;

public Plugin myinfo =
{
    name        = "Sourcemod List",
    author      = "0x0c",
    description = "",
    version     = "1.0.0",
    url         = "https://solaris-servers.ru/"
}

public void OnPluginStart()
{
    g_smPluginsMatched = new StringMap();
    RegAdminCmd("sm_ls",    Cmd_SMList, ADMFLAG_RCON);
    RegAdminCmd("sm_list",  Cmd_SMList, ADMFLAG_RCON);
}

public void OnAllPluginsLoaded()
{
    g_bPluginsLoaded = true;
}

public Action Cmd_SMList(int iClient, int iArgs)
{
    if (!g_bPluginsLoaded)
    {
        ReplyToCommand(iClient, "[sm_list] Please wait until all plugins have loaded");
        return Plugin_Handled;
    }

    char szMatch[512];
    GetCmdArg(1, szMatch, sizeof(szMatch));

    Handle hIterator = GetPluginIterator();
    Handle hPlugin = null;
    int iPluginCount = 0;
    bool bMatchAll = iArgs < 1;
    char szFilename[PLATFORM_MAX_PATH];
    char szPluginInfo[1024];
    char szKey[32];

    while(MorePlugins(hIterator))
    {
        hPlugin = ReadPlugin(hIterator);
        Format(szKey, sizeof(szKey), "%d", g_smPluginsMatched.Size);
        GetPluginFilename(hPlugin, szFilename, sizeof(szFilename));
        iPluginCount++;
        if (bMatchAll || StrContains(szFilename, szMatch, false) > -1)
        {
            Format(szPluginInfo, sizeof(szPluginInfo), "%s%s%s%s%s%s%s %s",
                   GetPluginStatus(hPlugin) == Plugin_Running    ? "[Running]   " : "",
                   GetPluginStatus(hPlugin) == Plugin_Paused     ? "[Paused]    " : "",
                   GetPluginStatus(hPlugin) == Plugin_Error      ? "[Error]     " : "",
                   GetPluginStatus(hPlugin) == Plugin_Loaded     ? "[Loaded]    " : "",
                   GetPluginStatus(hPlugin) == Plugin_Failed     ? "[Failed]    " : "",
                   GetPluginStatus(hPlugin) == Plugin_Created    ? "[Created]   " : "",
                   GetPluginStatus(hPlugin) == Plugin_Uncompiled ? "[Uncompiled]" : "",
                   szFilename
            );
            g_smPluginsMatched.SetString(szKey, szPluginInfo, true);
        }
    }
    delete hIterator;

    if (bMatchAll) {
        ReplyToCommand(iClient, "\n[sm_list] %d plugins currently loaded\n", iPluginCount);
    } else {
        ReplyToCommand(iClient, "\n[sm_list] %d/%d matched plugins for string \"%s\"\n", g_smPluginsMatched.Size, iPluginCount, szMatch);
    }
    int i = 0;
    while(i < g_smPluginsMatched.Size)
    {
        Format(szKey, sizeof(szKey), "%d", i);
        g_smPluginsMatched.GetString(szKey, szFilename, sizeof(szFilename));
        ReplyToCommand(iClient, "- %s", szFilename);
        i++;
    }
    if (g_smPluginsMatched.Size)
    {
        ReplyToCommand(iClient, "");
    }

    g_smPluginsMatched.Clear();

    return Plugin_Handled;
}
