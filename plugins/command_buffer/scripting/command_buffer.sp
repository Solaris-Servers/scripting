/*======================================================================================
    Plugin Info:

*   Name    :   [ANY] Command and ConVar - Buffer Overflow Fixer
*   Author  :   SilverShot and Peace-Maker
*   Descrp  :   Fixes incorrect ConVars values due to 'Cbuf_AddText: buffer overflow' console error on servers.
*   Link    :   https://forums.alliedmods.net/showthread.php?t=309656
*   Plugins :   https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
    Change Log:

2.8 (19-Jan-2022)
    - Fixed leaking handles when triggered to fix buffer issues.

2.7 (06-Dec-2021)
    - Fixed the last version breaking plugin functionality. Thanks to "sorallll" for reporting.

2.6 (27-Nov-2021)
    - Fixed "Failed to grow array" error. Thanks to "azureblue" for reporting.

2.5a (16-Jun-2021)
    - L4D2: Compatibility update for "2.2.1.3" update. Thanks to "ProjectSky" for reporting and "bedildewo" for fixing.
    - GameData .txt file and plugin updated.

2.5 (03-May-2021)
    - Fixed errors when inputting a string with format specifiers. Thanks to "sorallll" for reporting and "Dragokas" for fix.

2.4 (10-May-2020)
    - Added better error log message when gamedata file is missing.
    - Various changes to tidy up code.

2.3 (03-Feb-2020)
    - Fixed debugging using the wrong methodmap. Thanks to "Caaine" for reporting.

2.2 (03-Feb-2020) by Dragokas
    - Added delete to an unused handle.
    - Changed "char" to "static char" in "OnNextFrame" to optimize performance.

2.1 (07-Aug-2018)
    - Added support for GoldenEye and other games using the OrangeBox engine on Windows and Linux.
    - Added support for Left4Dead2 Windows - not required from my testing on a Dedicated Server.
    - Gamedata .txt and plugin updated.

2.0.1 (02-Aug-2018)
    - Turned off debugging.

2.0 (02-Aug-2018)
    - Now fixes all ConVars from being set to incorrect values.
    - Supports CSGO (win/nix), L4D1 (win/nix) and L4D2 (nix).
    - Other games with issues please request support.

1.0 (27-Jun-2018)
    - Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>

#define ARGS_BUFFER_LENGTH 8192

char      g_szCurrentCommand[ARGS_BUFFER_LENGTH];
bool      g_bNextFrame;
ArrayList g_arrCommandList;

public Plugin myinfo = {
    name        = "[ANY] Command and ConVar - Buffer Overflow Fixer",
    author      = "SilverShot and Peace-Maker",
    description = "Fixes the 'Cbuf_AddText: buffer overflow' console error on servers, which causes ConVars to use their default value.",
    version     = "2.8",
    url         = "https://forums.alliedmods.net/showthread.php?t=309656"
}

public void OnPluginStart() {
    g_arrCommandList = new ArrayList(ByteCountToCells(ARGS_BUFFER_LENGTH));
    // ====================================================================================================
    // Detour - Anytime convars are added to the buffer this will fire
    // ====================================================================================================
    GameData gmConf = new GameData("command_buffer.games");
    if (gmConf == null) SetFailState("Failed to load \"command_buffer.games.txt\" gamedata.");

    DynamicDetour hDetour = DynamicDetour.FromConf(gmConf, "CCommandBuffer::InsertCommand");
    if (!hDetour)                                              SetFailState("Failed to find \"CCommandBuffer::InsertCommand\" signature.");
    if (!DHookEnableDetour(hDetour, false, InsertCommand))     SetFailState("Failed to detour \"CCommandBuffer::InsertCommand\".");
    if (!DHookEnableDetour(hDetour, true,  InsertCommandPost)) SetFailState("Failed to detour post \"CCommandBuffer::InsertCommand\".");

    delete gmConf;
    delete hDetour;
}

// ====================================================================================================
// Detour
// ====================================================================================================
public MRESReturn InsertCommand(Handle hReturn, Handle hParams) {
    // Get command argument.
    DHookGetParamString(hParams, 1, g_szCurrentCommand, sizeof(g_szCurrentCommand));
    return MRES_Ignored;
}

public MRESReturn InsertCommandPost(Handle hReturn, Handle hParams) {
    // See if the server was able to insert the command just fine.
    bool bSuccess = DHookGetReturn(hReturn);
    if (bSuccess) return MRES_Ignored;
    // The command buffer overflowed. Add the commands again on the next frame.
    if (!g_bNextFrame) {
        g_bNextFrame = true;
        RequestFrame(OnNextFrame);
    }
    g_arrCommandList.PushString(g_szCurrentCommand);
    // Prevent "Cbuf_AddText: buffer overflow" message
    DHookSetReturn(hReturn, true);
    return MRES_Override;
}

// ====================================================================================================
// Reinsert the convars/commands that failed to be executed on the last frame now.
// Doesn't get called when servers hibernating, eg on first start up, until server wakes.
// ====================================================================================================
void OnNextFrame() {
    // Remove next frame so if they fail it will create the request and execute again on next frame
    g_bNextFrame = false;
    // Swap the buffers so we don't add to the list we're currently processing in our InsertServerCommand hook.
    // Executes the ConVars/commands in the order they were.
    ArrayList arrCmdList = g_arrCommandList.Clone();
    g_arrCommandList.Clear();
    static char szCommand[ARGS_BUFFER_LENGTH];
    int iLength = arrCmdList.Length;
    for (int i = 0; i < iLength; i++) {
        // Insert
        arrCmdList.GetString(i, szCommand, sizeof(szCommand));
        InsertServerCommand("%s", szCommand);
        // Flush the command buffer now. Outside of loop doesn't work - the convars would remain incorrect.
        ServerExecute();
    }
    delete arrCmdList;
}