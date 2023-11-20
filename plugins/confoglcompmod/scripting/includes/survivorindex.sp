#if defined __SURVIVORINDEX__
    #endinput
#endif
#define __FUNCTIONS__

int iSurvivorIndex[NUM_OF_SURVIVORS];

void SI_OnModuleStart() {
    HookEvent("round_start",        SI_Event_BuildIndex);
    HookEvent("round_end",          SI_Event_BuildIndex);
    HookEvent("player_spawn",       SI_Event_BuildIndex);
    HookEvent("player_disconnect",  SI_Event_BuildIndex);
    HookEvent("player_death",       SI_Event_BuildIndex);
    HookEvent("player_bot_replace", SI_Event_BuildIndex);
    HookEvent("bot_player_replace", SI_Event_BuildIndex);
    HookEvent("defibrillator_used", SI_Event_BuildIndex);
    HookEvent("player_team",        SI_Event_PlayerTeam);
}

void SI_BuildIndex() {
    if (!IsServerProcessing() || !IsPluginEnabled())
        return;
    int iFoundSurvivors = 0;
    int iCharProp;
    // Make sure kicked survivors don't freak us out.
    for (int i = 0; i < NUM_OF_SURVIVORS; i++) {
        iSurvivorIndex[i] = 0;
    }
    for (int i = 1; i <= MaxClients; i++) {
        if (iFoundSurvivors == NUM_OF_SURVIVORS)
            break;
        if (!IsClientInGame(i) || GetClientTeam(i) != 2)
            continue;
        iCharProp = GetEntProp(i, Prop_Send, "m_survivorCharacter");
        iFoundSurvivors++;
        if (iCharProp > 3 || iCharProp < 0)
            continue;
        iSurvivorIndex[iCharProp] = 0;
        if (!IsPlayerAlive(i))
            continue;
        iSurvivorIndex[iCharProp] = i;
    }
}

void SI_Event_PlayerTeam(Event eEvent, const char[] szName, bool bDontBroadcast) {
    CreateTimer(0.3, SI_Timer_PlayerTeam, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action SI_Timer_PlayerTeam(Handle hTimer) {
    SI_BuildIndex();
    return Plugin_Stop;
}

void SI_Event_BuildIndex(Event eEvent, const char[] szName, bool bDontBroadcast) {
    SI_BuildIndex();
}

stock int GetSurvivorIndex(int iIndex) {
    if (iIndex < 0 || iIndex > 3)
        return 0;
    return iSurvivorIndex[iIndex];
}

stock bool IsAnySurvivorsAlive() {
    for (int i = 0; i < NUM_OF_SURVIVORS; i++) {
        if (iSurvivorIndex[i])
            return true;
    }
    return false;
}