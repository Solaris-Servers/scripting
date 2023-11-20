#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>
#include <left4dhooks>
#include <l4d2_changelevel>
#include <l4d2util/rounds>
#include <solaris/stocks>

StringMap g_smMapTransitionPair;
bool      g_bRoundStarted;

public void OnPluginStart() {
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("round_end",   Event_RoundEnd,   EventHookMode_PostNoCopy);

    RegServerCmd("sm_add_map_transition", Cmd_AddMapTransition);

    g_smMapTransitionPair = new StringMap();

    LoadTranslations("l4d360ui.phrases");
}

Action Cmd_AddMapTransition(int iArgs) {
    if (iArgs != 2) {
        PrintToServer("Usage: sm_add_map_transition <starting map name> <ending map name>");
        return Plugin_Handled;
    }

    // Read map pair names
    char szMapStart[64];
    GetCmdArg(1, szMapStart, sizeof(szMapStart));

    char szMapEnd[64];
    GetCmdArg(2, szMapEnd,   sizeof(szMapEnd));

    g_smMapTransitionPair.SetString(szMapStart, szMapEnd, true);
    return Plugin_Handled;
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bRoundStarted = true;
}

void Event_RoundEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!g_bRoundStarted) return;
    g_bRoundStarted = false;
    // If map is in last half, attempt a transition
    if (InSecondHalfOfRound()) {
        CreateTimer(10.0, Timer_RoundEndPrint, _, TIMER_FLAG_NO_MAPCHANGE);
        CreateTimer(15.0, Timer_RoundEndPost,  _, TIMER_FLAG_NO_MAPCHANGE);
    }
}

Action Timer_RoundEndPrint(Handle hTimer) {
    // Check if map has been registered for a map transition
    char szCurrentMapName[64];
    char szNextMapName[64];
    GetCurrentMap(szCurrentMapName, sizeof(szCurrentMapName));
    // We have a map to transition to
    // Inform about it!
    if (g_smMapTransitionPair.GetString(szCurrentMapName, szNextMapName, sizeof(szNextMapName))) {
        char g_gmBase[16];
        SDK_GetGameModeBase(g_gmBase, sizeof(g_gmBase));
        char szGmBaseUpper[16];
        ST_StrToUpper(g_gmBase, szGmBaseUpper, sizeof(szGmBaseUpper));
        char szCurrentMapNameUpper[16];
        ST_StrToUpper(szCurrentMapName, szCurrentMapNameUpper, sizeof(szCurrentMapNameUpper));
        SplitString(szCurrentMapNameUpper, "_", szCurrentMapNameUpper, sizeof(szCurrentMapNameUpper));
        char szNextMapNameUpper[16];
        ST_StrToUpper(szNextMapName, szNextMapNameUpper, sizeof(szNextMapNameUpper));
        SplitString(szNextMapNameUpper, "_", szNextMapNameUpper, sizeof(szNextMapNameUpper));
        char szUICurrentChaptername[64];
        Format(szUICurrentChaptername, sizeof(szUICurrentChaptername), "#L4D360UI_LevelName_%s_%s", szGmBaseUpper, szCurrentMapNameUpper);
        char szUINextChaptername[64];
        Format(szUINextChaptername, sizeof(szUINextChaptername), "#L4D360UI_LevelName_%s_%s", szGmBaseUpper, szNextMapNameUpper);
        CPrintToChatAll("{blue}[{default}Map Transitions{blue}]{default} Starting transition from: {blue}%t{default} to: {blue}%t", szUICurrentChaptername[1], szUINextChaptername[1]);
    }
    return Plugin_Handled;
}

Action Timer_RoundEndPost(Handle hTimer) {
    // Check if map has been registered for a map transition
    char szCurrentMapName[64];
    GetCurrentMap(szCurrentMapName, sizeof(szCurrentMapName));
    // We have a map to transition to
    char szNextMapName[64];
    if (g_smMapTransitionPair.GetString(szCurrentMapName, szNextMapName, sizeof(szNextMapName)))
        L4D2_ChangeLevel(szNextMapName, false); // We don't need to clear transition info! We save our scores
    return Plugin_Handled;
}