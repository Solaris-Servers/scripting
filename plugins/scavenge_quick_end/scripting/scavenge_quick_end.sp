#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <colors>
#include <sdktools>
#include <solaris/stocks>

float g_flDefaultLossTime;
bool g_bInScavengeRound;
bool g_bInSecondHalf;

#define GetRoundTime(%0,%1,%2) %1 = GameRules_GetRoundDuration(%2); %0 = RoundToFloor(%1)/60; %1 -= 60 * %0
#define boolalpha(%0) (%0 ? "true" : "false")

public Plugin myinfo =
{
    name        = "Scavenge Quick End",
    author      = "ProdigySim",
    description = "Checks various tiebreaker win conditions mid-round and ends the round as necessary.",
    version     = "1.2",
    url         = "http://bitbucket.org/ProdigySim/misc-sourcemod-plugins/"
}

public void OnPluginStart()
{
    HookEvent("scavenge_round_start",  RoundStart);
    HookEvent("gascan_pour_completed", OnCanPoured, EventHookMode_PostNoCopy);
    HookEvent("round_end",             RoundEnd,    EventHookMode_PostNoCopy);
    RegConsoleCmd("sm_time", TimeCmd);
}

public Action TimeCmd(int client, int args)
{
    if (!g_bInScavengeRound)
    {
        return Plugin_Handled;
    }

    if (g_bInSecondHalf)
    {
        float lastRoundTime;
        int lastRoundMinutes;
        GetRoundTime(lastRoundMinutes,lastRoundTime,3);
        CPrintToChat(client, "First Round: {blue}%d{default} in {blue}%d:%05.2f", GameRules_GetScavengeTeamScore(3), lastRoundMinutes, lastRoundTime);
    }

    float thisRoundTime;
    int thisRoundMinutes;

    GetRoundTime(thisRoundMinutes,thisRoundTime,2);
    CPrintToChat(client, "This Round: {blue}%d{default} in {blue}%d:%05.2f", GameRules_GetScavengeTeamScore(2), thisRoundMinutes, thisRoundTime);

    return Plugin_Handled;
}

public void OnGameFrame()
{
    if (g_flDefaultLossTime != 0.0 && GetGameTime() > g_flDefaultLossTime)
    {
        SDK_ScenarioEnd();
        g_flDefaultLossTime = 0.0;
    }
}

public void RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (g_bInScavengeRound)
    {
        PrintRoundEndTimeData(g_bInSecondHalf);
    }

    g_flDefaultLossTime = 0.0;
    g_bInScavengeRound  = false;
    g_bInSecondHalf     = false;
}

public void RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_bInSecondHalf     = !event.GetBool("firsthalf");
    g_bInScavengeRound  = true;
    g_flDefaultLossTime = 0.0;

    if (g_bInScavengeRound && g_bInSecondHalf)
    {
        int lastRoundScore = GameRules_GetScavengeTeamScore(3);

        if (lastRoundScore == 0 || lastRoundScore == GameRules_GetProp("m_nScavengeItemsGoal"))
        {
            g_flDefaultLossTime = GameRules_GetPropFloat("m_flRoundStartTime") + GameRules_GetRoundDuration(3) + 1.0;
        }
    }
}

public void OnCanPoured(Event event, const char[] name, bool dontBroadcast)
{
    if (g_bInScavengeRound && g_bInSecondHalf)
    {
        int remaining = GameRules_GetProp("m_nScavengeItemsRemaining");

        if (remaining > 0)
        {
            int scoreA = GameRules_GetScavengeTeamScore(2);
            int scoreB = GameRules_GetScavengeTeamScore(3);

            if (scoreA == scoreB && GameRules_GetRoundDuration(2) < GameRules_GetRoundDuration(3))
            {
                SDK_ScenarioEnd();
            }
        }
    }
}

void PrintRoundEndTimeData(bool secondHalf)
{
    float time;
    int minutes;

    if (secondHalf)
    {
        GetRoundTime(minutes,time,3);
        CPrintToChatAll("First Round: {blue}%d{default} in {blue}%d:%05.2f", GameRules_GetScavengeTeamScore(3), minutes, time);
    }

    GetRoundTime(minutes,time,2);
    CPrintToChatAll("This Round: {blue}%d{default} in {blue}%d:%05.2f", GameRules_GetScavengeTeamScore(2), minutes, time);
}

stock float GameRules_GetRoundDuration(int team)
{
    float flRoundStartTime = GameRules_GetPropFloat("m_flRoundStartTime");

    if (team == 2 && flRoundStartTime != 0.0 && GameRules_GetPropFloat("m_flRoundEndTime") == 0.0)
    {
        return GetGameTime() - flRoundStartTime;
    }

    team = L4D2_TeamNumberToTeamIndex(team);

    if (team == -1)
    {
        return -1.0;
    }

    return GameRules_GetPropFloat("m_flRoundDuration", team);
}

stock int GameRules_GetScavengeTeamScore(int team, int round = -1)
{
    team = L4D2_TeamNumberToTeamIndex(team);

    if (team == -1)
    {
        return -1;
    }

    if (round <= 0 || round > 5)
    {
        round = GameRules_GetProp("m_nRoundNumber");
    }

    --round;

    return GameRules_GetProp("m_iScavengeTeamScore", _, (2*round)+team);
}

stock int L4D2_TeamNumberToTeamIndex(int team)
{
    if (team != 2 && team != 3)
    {
        return -1;
    }

    bool flipped = view_as<bool>(GameRules_GetProp("m_bAreTeamsFlipped", 1));

    if (flipped)
    {
        ++team;
    }

    return team % 2;
}