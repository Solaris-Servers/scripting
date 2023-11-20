#if defined _l4d2lib_survivors_included
    #endinput
#endif
#define _l4d2lib_survivors_included

/* Global Vars */
static int g_iSurvivorIndex[MAXPLAYERS + 1] = {0, ...};
static int g_iSurvivorCount = 0;

void Survivors_AskPluginLoad2() {
    CreateNative("L4D2_GetSurvivorCount",   Native_GetSurvivorCount);   // never used
    CreateNative("L4D2_GetSurvivorOfIndex", Native_GetSurvivorOfIndex); // never used
}

any Native_GetSurvivorCount(Handle hPlugin, int iNumParams) {
    return g_iSurvivorCount;
}

any Native_GetSurvivorOfIndex(Handle hPlugin, int iNumParams) {
    int iClient = GetNativeCell(1);
    return g_iSurvivorIndex[iClient];
}

void Survivors_RebuildArray_Delay() {
    CreateTimer(0.3, BuildArray_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action BuildArray_Timer(Handle hTimer) {
    Survivors_RebuildArray();
    return Plugin_Stop;
}

void Survivors_RebuildArray() {
    if (!IsServerProcessing())
        return;
    g_iSurvivorCount = 0;
    for (int i = 1; i <= MaxClients; i++) {
        g_iSurvivorIndex[i] = 0;
        if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i)) {
            g_iSurvivorIndex[g_iSurvivorCount] = i;
            g_iSurvivorCount++;
        }
    }
}