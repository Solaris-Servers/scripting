#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <nextmap>
#include <l4d2_changelevel>
#include <l4d2util>
#include <solaris/stocks>

bool   g_bIsRoundLive;
bool   g_bIsFinale;
bool   g_bCanRetry;
char   g_szNextMap[256];
ConVar g_cvEnableRetry;

public Plugin myinfo = {
    name        = "Map Skipper",
    author      = "Breezy",
    description = "Skip to next map in coop when wiping",
    version     = "1.0",
    url         = "https://github.com/brxce/Gauntlet"
};

public void OnPluginStart() {
    // Make sure the 'missions' folder exists
    if (!DirExists("missions")) SetFailState("Missions directory does not exist on this server.  Map Skipper cannot continue operation");
    g_cvEnableRetry = CreateConVar(
    "enable_retry", "1",
    "Enable retry of a map if team wipes",
    FCVAR_NONE, true, 0.0, false, 1.0);
    g_bCanRetry = g_cvEnableRetry.BoolValue;

    RegConsoleCmd("sm_toggleretry", Cmd_ToggleRetry);
    HookEvent("mission_lost",          Event_MissionLost,  EventHookMode_PostNoCopy);
    HookEvent("round_start",           Event_RoundStart,   EventHookMode_PostNoCopy);
    HookEvent("player_left_safe_area", Event_LeftSafeArea, EventHookMode_PostNoCopy);
}

public void OnMapEnd() {
    SDK_ClearTransitionInfo();
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bIsRoundLive = false;
}

void Event_LeftSafeArea(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bIsRoundLive = true;
}

Action Cmd_ToggleRetry(int iClient, int iArgs) {
    if (g_bIsRoundLive) {
        CPrintToChat(iClient, "{green}[{default}Gauntlet{green}]{default} This command can only be used before the round start");
        return Plugin_Handled;
    }
    if (!IsSurvivor(iClient)) {
        CPrintToChat(iClient, "{green}[{default}Gauntlet{green}]{default} You do not have access to this command");
        return Plugin_Handled;
    }
    g_bCanRetry = !g_bCanRetry;
    PrintRetryOption();
    return Plugin_Handled;
}

void PrintRetryOption() {
    if (g_bCanRetry) CPrintToChatAll("{green}[{default}Gauntlet{green}]{default} Retry is {blue}enabled{default}! Survivors will be allowed to retry map upon death");
    else             CPrintToChatAll("{green}[{default}Gauntlet{green}]{default} Retry is {red}disabled{default}! Next map will be loaded upon death");
}

void Event_MissionLost(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!GetNextMapName()) return;
    CreateTimer(6.5, Timer_ForceNextMap, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_ForceNextMap(Handle hTimer) {
    if (g_bCanRetry) return Plugin_Stop;
    Event eEvent = CreateEvent("map_transition");
    if (g_bIsFinale) eEvent.SetBool("finale", true);
    eEvent.Fire();
    // Change level
    L4D2_ChangeLevel(g_szNextMap); // We don't need to clear transition info! Transition Fix plugin does it
    LogMessage("Force changing map to %s", g_szNextMap);
    return Plugin_Stop;
}

stock bool GetNextMapName() {
    // Open the missions directory
    DirectoryListing dMissions = OpenDirectory("missions");
    if (dMissions == null) SetFailState("Cannot open missions directory");
    // Setup strings
    char szCurrentMap[256];
    GetCurrentMap(szCurrentMap, sizeof(szCurrentMap));
    LogMessage("Current map: %s", szCurrentMap);

    char szBuffer  [256];
    char szFullPath[256];
    // Loop through all the mission text files
    while (ReadDirEntry(dMissions, szBuffer, sizeof(szBuffer))) {
        // Skip folders and credits file
        if (DirExists(szBuffer) || StrEqual(szBuffer, "credits.txt", false))
            continue;
        // Create a keyvalues structure from the current iteration's mission .txt
        Format(szFullPath, sizeof(szFullPath), "%s/%s", "missions", szBuffer);
        KeyValues kvMissions = new KeyValues("mission");
        kvMissions.ImportFromFile(szFullPath);
        // Get to "coop" section to start looping
        kvMissions.JumpToKey("modes", false);
        // Check if a "coop" section exists
        if (kvMissions.JumpToKey("coop", false)) {
            kvMissions.GotoFirstSubKey(); // first map
            do {
                char szMapName[256];
                kvMissions.GetString("map", szMapName, sizeof(szMapName));
                // If we have found the map name in this missions file, read in the next map
                if (StrEqual(szMapName, szCurrentMap, false)) {
                    // If there is a map listed next, a finale is not being played
                    if (kvMissions.GotoNextKey()) {
                        g_bIsFinale = false;
                        // Get the next map's name
                        kvMissions.GetString("map", g_szNextMap, sizeof(g_szNextMap));
                        LogMessage("Found next map: %s", g_szNextMap);
                        // Close handles
                        delete kvMissions;
                        delete dMissions;
                        return true;
                    } else {
                        LogMessage("Finale being played, map skip will restart campaign");
                        g_bIsFinale = true;
                        // Loop back to the first map
                        kvMissions.GoBack();
                        kvMissions.GotoFirstSubKey();
                        kvMissions.GetString("map", g_szNextMap, sizeof(g_szNextMap));
                        // Close handles
                        delete kvMissions;
                        delete dMissions;
                        return true;
                    }
                }
            }
            while (kvMissions.GotoNextKey());
        }
        delete kvMissions;
    }
    LogMessage("The next map could not be found. No valid missions file?");
    delete dMissions;
    return false;
}