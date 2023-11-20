#if defined _l4d2lib_rounds_included
    #endinput
#endif
#define _l4d2lib_rounds_included

/* Global Vars */
static GlobalForward g_FwdRoundStart;
static GlobalForward g_FwdRoundEnd;

static bool g_bInRound = false;
static int  g_iRoundNumber = 0;

void Rounds_AskPluginLoad2() {
    CreateNative("L4D2_GetCurrentRound", Native_GetCurrentRound);   // never used
    CreateNative("L4D2_CurrentlyInRound", Native_CurrentlyInRound); // never used
    // Commented out in Confoglcompmod (ItemTracking);
    g_FwdRoundStart = CreateGlobalForward(
    "L4D2_OnRealRoundStart",
    ET_Ignore, Param_Cell);
    // never used
    g_FwdRoundEnd = CreateGlobalForward(
    "L4D2_OnRealRoundEnd",
    ET_Ignore, Param_Cell);
}

any Native_GetCurrentRound(Handle hPlugin, int iNumParams) {
    return g_iRoundNumber;
}

any Native_CurrentlyInRound(Handle hPlugin, int iNumParams) {
    return g_bInRound;
}

void Rounds_OnRoundStart_Update() {
    if (!g_bInRound) {
        g_bInRound = true;
        g_iRoundNumber++;
        Call_StartForward(g_FwdRoundStart);
        Call_PushCell(g_iRoundNumber);
        Call_Finish();
    }
}

void Rounds_OnRoundEnd_Update() {
    if (g_bInRound) {
        g_bInRound = false;
        Call_StartForward(g_FwdRoundEnd);
        Call_PushCell(g_iRoundNumber);
        Call_Finish();
    }
}

void Rounds_OnMapEnd_Update() {
    g_iRoundNumber = 0;
    g_bInRound = false;
}