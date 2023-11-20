#if defined _l4d2lib_tanks_included
    #endinput
#endif
#define _l4d2lib_tanks_included

/* Global Vars */

static GlobalForward g_FwdFirstTankSpawn;
static GlobalForward g_FwdTankPassControl;
static GlobalForward g_FwdTankDeath;

static Handle        g_hTankDeathTimer;

static bool          g_bIsTankActive = false;

static int           g_iTankClient    = -1;
static int           g_iTankPassCount = 0;

void Tanks_AskPluginLoad2() {
    // never used
    g_FwdFirstTankSpawn = CreateGlobalForward(
    "L4D2_OnTankFirstSpawn",
    ET_Ignore, Param_Cell);
    // l4d2_tank_support & l4d2_fix_spawn_order
    g_FwdTankPassControl = CreateGlobalForward(
    "L4D2_OnTankPassControl",
    ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
    // never used
    g_FwdTankDeath = CreateGlobalForward(
    "L4D2_OnTankDeath",
    ET_Ignore, Param_Cell);
}

void Tanks_OnMapStart() {
    ResetStatus();
}

void Tanks_RoundStart() {
    ResetStatus();
}

void Tanks_TankSpawn(Event eEvent) {
    if (g_bIsTankActive) return;
    g_bIsTankActive = true;
    g_iTankClient = GetClientOfUserId(eEvent.GetInt("userid"));
    Call_StartForward(g_FwdFirstTankSpawn);
    Call_PushCell(g_iTankClient);
    Call_Finish();
}

void Tanks_ItemPickup(Event eEvent) {
    if (!g_bIsTankActive) return;
    char sItem[64];
    eEvent.GetString("item", sItem, sizeof(sItem));
    if (strcmp(sItem, "tank_claw") == 0) {
        int iPrevTank = g_iTankClient;
        g_iTankClient = GetClientOfUserId(eEvent.GetInt("userid"));
        if (g_hTankDeathTimer != null) {
            KillTimer(g_hTankDeathTimer);
            g_hTankDeathTimer = null;
        }
        Call_StartForward(g_FwdTankPassControl);
        Call_PushCell(iPrevTank);
        Call_PushCell(g_iTankClient);
        Call_PushCell(g_iTankPassCount);
        Call_Finish();
        g_iTankPassCount++;
    }
}

void Tanks_PlayerDeath(Event eEvent) {
    if (!g_bIsTankActive) return;
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient != g_iTankClient)
        return;
    g_hTankDeathTimer = CreateTimer(0.5, TankDeath_Timer);
}

Action TankDeath_Timer(Handle hTimer) {
    Call_StartForward(g_FwdTankDeath);
    Call_PushCell(g_iTankClient);
    Call_Finish();
    ResetStatus();
    return Plugin_Stop;
}

void ResetStatus() {
    g_bIsTankActive  = false;
    g_iTankClient    = -1;
    g_iTankPassCount = 0;
    if (g_hTankDeathTimer != null) {
        KillTimer(g_hTankDeathTimer);
        g_hTankDeathTimer = null;
    }
}