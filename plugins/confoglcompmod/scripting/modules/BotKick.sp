#if defined __BOT_KICK_MODULE__
    #endinput
#endif
#define __BOT_KICK_MODULE__

#define CHECKALLOWEDTIME    0.1
#define BOTREPLACEVALIDTIME 0.2

int    BK_iEnable;
ConVar BK_cvEnable;

void BK_OnModuleStart() {
    BK_cvEnable = CreateConVarEx(
    "blockinfectedbots", "0",
    "Blocks infected bots from joining the game, minus when a tank spawns (1 allows bots from tank spawns, 2 removes all infected bots)",
    FCVAR_NONE, true, 0.0, true, 2.0);
    BK_iEnable = BK_cvEnable.IntValue;
    BK_cvEnable.AddChangeHook(BK_ConVarChange);
    HookEvent("player_bot_replace", BK_Event_PlayerBotReplace);
}

void BK_ConVarChange(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    BK_iEnable = BK_cvEnable.IntValue;
}

void BK_Event_PlayerBotReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iBot = GetClientOfUserId(eEvent.GetInt("bot"));
    if (BK_iEnable != 2)
        return;

    if (!IsPluginEnabled())
        return;

    if (!IsClientInGame(iBot))
        return;

    if (!IsFakeClient(iBot))
        return;

    if (GetClientTeam(iBot) != 3)
        return;

    RequestFrame(BK_OnNextFrame, GetClientUserId(iBot));
}

void BK_OnNextFrame(any iUserId) {
    int iBot = GetClientOfUserId(iUserId);
    if (iBot <= 0)
        return;

    if (!IsClientInGame(iBot))
        return;

    if (GetClientTeam(iBot) != 3)
        return;

    if (!IsFakeClient(iBot))
        return;

    ForcePlayerSuicide(iBot);
}

public Action L4D_OnSpawnSpecial(int &iZombieClass, const float vPos[3], const float vAng[3]) {
    if (!BK_iEnable || !IsPluginEnabled())
        return Plugin_Continue;

    return Plugin_Handled;
}