#if defined __EVENTS__
    #endinput
#endif
#define __EVENTS__

void Events_OnModuleStart() {
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    AllowJingle(true, true);
    CreateTimer(3.0, Timer_CreateXmasStuff, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_CreateXmasStuff(Handle hTimer) {
    MakeSnow();
    TreeSpawnByFile();
    return Plugin_Handled;
}