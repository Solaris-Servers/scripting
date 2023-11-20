#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <solaris/stocks>

#define BELL "buttons/bell1.wav"

Handle g_hChoice        [MAXPLAYERS + 1];
bool   g_bPlayerRejected[MAXPLAYERS + 1];
bool   g_bRoundStarted;
ConVar g_cvTimer;

public Plugin myinfo = {
    name        = "Survivor Bot Select",
    author      = "Merudo",
    description = "Allows players to pick a bot to takeover in Left 4 Dead.",
    version     = "1.0",
    url         = "https://forums.alliedmods.net/showthread.php?p=2409064"
}

public void OnPluginStart() {
    HookEvent("round_start",        Event_RoundStart);
    HookEvent("round_end",          Event_RoundEnd);
    HookEvent("map_transition",     Event_RoundEnd);
    HookEvent("finale_win",         Event_RoundEnd);
    HookEvent("player_team",        Event_PlayerTeam);
    HookEvent("player_death",       Event_PlayerDeath);
    HookEvent("survivor_rescued",   Event_PlayerRescued);
    HookEvent("player_bot_replace", Event_PlayerBotReplace);

    RegConsoleCmd("sm_takeover", Pick_Bot, "Show menu to take a bot");
    RegConsoleCmd("sm_pickbot",  Pick_Bot, "Show menu to take a bot");
    RegConsoleCmd("sm_bot",      Pick_Bot, "Show menu to take a bot");

    g_cvTimer = CreateConVar(
    "sm_takeover_delay", "3",
    "Delay (in seconds) before take over bot menu shows to players",
    FCVAR_NONE, true, 0.0, false, 0.0);
}

public void OnMapStart() {
    PrecacheSound(BELL);
}

public void OnMapEnd() {
    g_bRoundStarted = false;
    for (int i = 1; i <= MaxClients; i++) {
        delete g_hChoice[i];
    }
}

public void OnClientConnected(int iClient) {
    g_bPlayerRejected[iClient] = false;
    delete g_hChoice[iClient];
}

public void OnClientDisconnect(int iClient) {
    g_bPlayerRejected[iClient] = false;
    delete g_hChoice[iClient];
    PrepareTimer();
}

// ------------------------------------------------------------------------
// Game Events
// ------------------------------------------------------------------------
void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bRoundStarted = true;
    for (int i = 1; i <= MaxClients; i++) {
        delete g_hChoice[i];
    }
}

void Event_RoundEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bRoundStarted = false;
    for (int i = 1; i <= MaxClients; i++) {
        delete g_hChoice[i];
    }
}

void Event_PlayerTeam(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0) return;
    delete g_hChoice[iClient];
}

void Event_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)                return;
    if (!IsClientInGame(iClient))    return;
    if (IsFakeClient(iClient))       return;
    if (GetClientTeam(iClient) != 2) return;
    g_bPlayerRejected[iClient] = false;
    PrepareTimer(iClient);
}

void Event_PlayerRescued(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iVictim = GetClientOfUserId(eEvent.GetInt("victim"));
    if (iVictim <= 0)           return;
    if (!IsFakeClient(iVictim)) return;
    PrepareTimer();
}

void Event_PlayerBotReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iBot = GetClientOfUserId(eEvent.GetInt("bot"));
    if (iBot) PrepareTimer();
}

// ------------------------------------------------------------------------
// PICK BOT MENU
// ------------------------------------------------------------------------
Action Pick_Bot(int iClient, int iArgs) {
    if (!IsClientInGame(iClient)) return Plugin_Handled;
    if (IsPlayerAlive(iClient))   return Plugin_Handled;
    ShowMenu(iClient);
    return Plugin_Handled;
}

void ShowMenu(int iClient) {
    if (!VerifyCommand(iClient))
        return;
    if (!CountAvailableSurvivorBots()){
        CPrintToChat(iClient, "{green}[{default}Take Over{green}]{default} No survivor bot available!");
        return;
    }
    char szNumber[10];
    char szTextClient[32];
    Menu mMenu = new Menu(MenuHandler1);
    mMenu.SetTitle("Select a survivor bot:");
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsSurvivorBotValid(i) || HasIdlePlayer(i))
            continue;
        Format(szNumber, sizeof(szNumber), "%i", i);
        char szHealth[MAX_TARGET_LENGTH];
        if (GetEntProp(i, Prop_Send, "m_isIncapacitated")) {
            Format(szHealth, sizeof(szHealth), "DOWN - %d HP - ", GetEntData(i, FindDataMapInfo(i, "m_iHealth"), 4));
        } else if (GetEntProp(i, Prop_Send, "m_currentReviveCount") == FindConVar("survivor_max_incapacitated_count").IntValue) {
            Format(szHealth, sizeof(szHealth), "BLWH - %d HP - ", GetEntData(i, FindDataMapInfo(i, "m_iHealth"), 4));
        } else {
            Format(szHealth, sizeof(szHealth), "%d HP - ", GetClientRealHealth(i));
        }
        Format(szTextClient, sizeof(szTextClient), "%s%N", szHealth, i);
        mMenu.AddItem(szNumber, szTextClient);
    }
    mMenu.ExitButton = true;
    mMenu.Display(iClient, MENU_TIME_FOREVER);
}

int MenuHandler1(Menu mMenu, MenuAction maAction, int iClient, int iParam2) {
    switch (maAction) {
        case MenuAction_Select: {
            char szNumber[4];
            GetMenuItem(mMenu, iParam2, szNumber, sizeof(szNumber));
            int iPickedBot = StringToInt(szNumber);
            if (!VerifyCommand(iClient))
                return 0;
            if (!iPickedBot || !IsSurvivorBotValid(iPickedBot) || HasIdlePlayer(iPickedBot)) {
                CPrintToChat(iClient, "{green}[{default}Take Over{green}]{default} This survivor bot is no longer available.");
                ShowMenu(iClient);
                return 0;
            }
            EmitSoundToAll(BELL);
            CPrintToChatAll("{green}[{default}Take Over{green}]{default} {blue}%N{default} is now playing as {olive}%N", iClient, iPickedBot);
            ChangeClientTeam(iClient, 1);
            SDK_SetHumanSpectator(iPickedBot, iClient);
            SDK_TakeOverBot(iClient);
        }
        case MenuAction_Cancel: {
            return 0;
        }
        case MenuAction_End: {
            delete mMenu;
        }
    }
    return 0;
}

// ------------------------------------------------------------------------
// Count the number of available bots
// ------------------------------------------------------------------------
int CountAvailableSurvivorBots() {
    int iCount = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsSurvivorBotValid(i)) continue;
        if (HasIdlePlayer(i))       continue;
        iCount++;
    }
    return iCount;
}

// ------------------------------------------------------------------------
// Returns true if specified bot has idle player
// ------------------------------------------------------------------------
bool HasIdlePlayer(int iBot) {
    return GetEntData(iBot, FindSendPropInfo("SurvivorBot", "m_humanSpectatorUserID")) > 0;
}

// ------------------------------------------------------------------------
// Returns if the survivor bot is valid (in game, bot, survivor, alive)
// ------------------------------------------------------------------------
bool IsSurvivorBotValid(int iBot) {
    if (!IsClientInGame(iBot))     return false;
    if (!IsFakeClient(iBot))       return false;
    if (IsClientInKickQueue(iBot)) return false;
    if (GetClientTeam(iBot) != 2)  return false;
    if (!IsPlayerAlive(iBot))      return false;
    return true;
}

// ------------------------------------------------------------------------
// Returns health of client
// ------------------------------------------------------------------------
int GetClientRealHealth(int iClient) {
    if (!iClient || !IsValidEntity(iClient) || !IsClientInGame(iClient) || !IsPlayerAlive(iClient) || IsClientObserver(iClient))
        return -1;
    if (GetClientTeam(iClient) != 2) {
        return GetClientHealth(iClient);
    }
    float fBuffer = GetEntPropFloat(iClient, Prop_Send, "m_healthBuffer");
    float fTempHealth;
    int   iPermHealth = GetClientHealth(iClient);
    if (fBuffer <= 0.0) {
        fTempHealth = 0.0;
    } else {
        float fDifference = GetGameTime() - GetEntPropFloat(iClient, Prop_Send, "m_healthBufferTime");
        float fDecay = FindConVar("pain_pills_decay_rate").FloatValue;
        float fConstant = 1.0 / fDecay;
        fTempHealth = fBuffer - (fDifference / fConstant);
    }
    if (fTempHealth < 0.0)
        fTempHealth = 0.0;
    return RoundToFloor(iPermHealth + fTempHealth);
}

// ------------------------------------------------------------------------
// Call menu for client after 3 seconds
// ------------------------------------------------------------------------
void PrepareTimer(int iClient = 0) {
    if (!g_bRoundStarted)              return;
    if (!CountAvailableSurvivorBots()) return;

    if (iClient != 0) {
        int iUserId = GetClientUserId(iClient);
        if (g_hChoice[iClient] != null) return;

        DataPack dp;
        g_hChoice[iClient] = CreateDataTimer(g_cvTimer.FloatValue, Timer_Delay, dp, TIMER_FLAG_NO_MAPCHANGE);
        dp.WriteCell(iClient);
        dp.WriteCell(iUserId);
        return;
    }

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))    continue;
        if (IsFakeClient(i))       continue;
        if (GetClientTeam(i) != 2) continue;
        if (IsPlayerAlive(i))      continue;
        if (g_bPlayerRejected[i])  continue;
        if (g_hChoice[i] != null)  continue;

        DataPack dp;
        g_hChoice[i] = CreateDataTimer(g_cvTimer.FloatValue, Timer_Delay, dp, TIMER_FLAG_NO_MAPCHANGE);
        dp.WriteCell(i);
        dp.WriteCell(GetClientUserId(i));
    }
}

Action Timer_Delay(Handle hTimer, DataPack dp) {
    dp.Reset();
    int iClient = dp.ReadCell();
    int iUserId = dp.ReadCell();
    if (!g_bRoundStarted) {
        g_hChoice[iClient] = null;
        return Plugin_Stop;
    }
    if (!CountAvailableSurvivorBots()) {
        g_hChoice[iClient] = null;
        return Plugin_Stop;
    }
    if (GetClientOfUserId(iUserId) != iClient) {
        g_hChoice[iClient] = null;
        return Plugin_Stop;
    }
    if (!IsClientInGame(iClient)) {
        g_hChoice[iClient] = null;
        return Plugin_Stop;
    }
    if (GetClientTeam(iClient) != 2) {
        g_hChoice[iClient] = null;
        return Plugin_Stop;
    }
    if (IsPlayerAlive(iClient)) {
        g_hChoice[iClient] = null;
        return Plugin_Stop;
    }
    if (GetClientMenu(iClient) != MenuSource_None) {
        g_hChoice[iClient] = null;
        return Plugin_Stop;
    }
    CreateChoice(iClient);
    g_hChoice[iClient] = null;
    return Plugin_Stop;
}

void CreateChoice(int iClient) {
    Menu mMenu = new Menu(Menu_Choice);
    mMenu.SetTitle("Do you want to takeover an alive survivor bot?", iClient);
    mMenu.AddItem("yes", "Yes");
    mMenu.AddItem("no",  "No");
    mMenu.ExitButton = true;
    mMenu.Display(iClient, MENU_TIME_FOREVER);
}

int Menu_Choice(Menu mMenu, MenuAction maAction, int iClient, int iParam2) {
    switch (maAction) {
        case MenuAction_Select: {
            switch (iParam2) {
                case 0: {
                    if (VerifyCommand(iClient)) ShowMenu(iClient);
                }
                case 1: {
                    CPrintToChat(iClient, "{green}[{default}Take Over{green}]{default} You can manually takeover {blue}an alive survivor bot{default} by using {olive}!bot{default}, {olive}!pickbot{default}, {olive}!takeover{default} in any time!");
                    g_bPlayerRejected[iClient] = true;
                }
            }
        }
        case MenuAction_End: {
            delete mMenu;
        }
    }
    return 0;
}

bool VerifyCommand(int iClient) {
    if (iClient <= 0)
        return false;
    if (!IsClientInGame(iClient) || IsFakeClient(iClient))
        return false;
    if (GetClientTeam(iClient) != 2)
        return false;
    if (IsPlayerAlive(iClient))
        return false;
    if (!g_bRoundStarted) {
        CPrintToChat(iClient, "{green}[{default}Take Over{green}]{default} Round is over!");
        return false;
    }
    if (!CountAvailableSurvivorBots()) {
        CPrintToChat(iClient, "{green}[{default}Take Over{green}]{default} No survivor bot available!");
        return false;
    }
    return true;
}