#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>
#include <dhooks>
#include <solaris/stocks>

// =======================================
// Variables
// =======================================

#define GAMEDATA_FILE         "l4d_sweep_fist_patch"

#define KEY_SWEEPFIST_CHECK1  "CTankClaw::SweepFist::Check1"
#define KEY_SWEEPFIST_CHECK2  "CTankClaw::SweepFist::Check2"
#define KEY_GROUNDPOUND_CHECK "CTankClaw::GroundPound::Check"

#define KEY_DOSWING           "CTankClaw::DoSwing"
#define KEY_GROUNDPOUND       "CTankClaw::GroundPound"

MemoryPatch g_hPatcher_Check1;
MemoryPatch g_hPatcher_Check2;
MemoryPatch g_hPatcher_GroundPound;

Handle      g_hDetour_DoSwing;
Handle      g_hDetour_GroundPound;

bool        g_bMapStarted;

enum PatcherException {
    PATCHER_NOERROR     = 0,
    PATCHER_CHECK1      = (1 << 0),
    PATCHER_CHECK2      = (1 << 1),
    PATCHER_GROUNDPOUND = (1 << 2)
}

public Plugin myinfo = {
    name        = "[L4D & 2] Coop Tank Sweep Fist Patch",
    author      = "Forgetest (Big thanks to Crasher_3637), Dragokas",
    description = "Kinda destroyed by AIs won't be suck anymore! well nah it is.",
    version     = "2.3",
    url         = "verygood"
};

// =======================================
// Engine Detect
// =======================================

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    g_bMapStarted = bLate;
    switch (GetEngineVersion()) {
        case Engine_Left4Dead, Engine_Left4Dead2: {
            return APLRes_Success;
        }
    }
    strcopy(szError, iErrMax, "Plugin supports only Left 4 Dead & 2.");
    return APLRes_SilentFailure;
}

// =======================================
// Plugin On/Off
// =======================================
public void OnPluginStart() {
    GameData gmData = new GameData(GAMEDATA_FILE);
    if (gmData == null) SetFailState("Missing gamedata file (" ... GAMEDATA_FILE ... ")");
    g_hPatcher_Check1 = MemoryPatch.CreateFromConf(gmData, KEY_SWEEPFIST_CHECK1);
    g_hPatcher_Check2 = MemoryPatch.CreateFromConf(gmData, KEY_SWEEPFIST_CHECK2);
    g_hPatcher_GroundPound = MemoryPatch.CreateFromConf(gmData, KEY_GROUNDPOUND_CHECK);
    PatcherException eException = ValidatePatches();
    if (eException != PATCHER_NOERROR) SetFailState("Failed to validate memory patches (exception %i).", view_as<int>(eException));
    SetupDetour(gmData);
    delete gmData;
    FindConVar("mp_gamemode").AddChangeHook(OnGameModeChanged);
}

public void OnPluginEnd() {
    PatchSweepFist(false);
    PatchGroundPound(false);
    ToggleDetour(false);
}

// =======================================
// Detour Setup
// =======================================
PatcherException ValidatePatches() {
    PatcherException eException = PATCHER_NOERROR;
    if (g_hPatcher_Check1 == null || !g_hPatcher_Check1.Validate())
        eException |= PATCHER_CHECK1;
    if (g_hPatcher_Check2 == null || !g_hPatcher_Check2.Validate())
        eException |= PATCHER_CHECK2;
    if (g_hPatcher_GroundPound == null || !g_hPatcher_GroundPound.Validate())
        eException |= PATCHER_GROUNDPOUND;
    return eException;
}

void SetupDetour(GameData &gmData) {
    g_hDetour_DoSwing = DHookCreateFromConf(gmData, KEY_DOSWING);
    g_hDetour_GroundPound = DHookCreateFromConf(gmData, KEY_GROUNDPOUND);
    if (g_hDetour_DoSwing == null || g_hDetour_GroundPound == null)
        SetFailState("Missing detour settings for or signature of \"%s\"", g_hDetour_DoSwing == null ? KEY_DOSWING : KEY_GROUNDPOUND);
}

// =======================================
// Patch Control
// =======================================
public void OnMapStart() {
    g_bMapStarted = true;
}

public void OnMapEnd() {
    g_bMapStarted = false;
}

public void OnConfigsExecuted() {
    if (!g_bMapStarted)
        return;
    bool bIsCoop = SDK_IsCoop();
    if (!bIsCoop) {
        PatchSweepFist(false);
        PatchGroundPound(false);
    }
    ToggleDetour(bIsCoop);
}

public void OnGameModeChanged(ConVar cv, const char[] szOldValue, const char[] szNewValue) {
    OnConfigsExecuted();
}

// =======================================
// Patch methods
// =======================================
void PatchSweepFist(bool bPatch) {
    static bool bPatched = false;
    if (!bPatched && bPatch) {
        if (!g_hPatcher_Check1.Enable() || !g_hPatcher_Check2.Enable())
            SetFailState("Failed in patching checks for \"" ... KEY_DOSWING ... "\"");
        bPatched = true;
    } else if (bPatched && !bPatch) {
        g_hPatcher_Check1.Disable();
        g_hPatcher_Check2.Disable();
        bPatched = false;
    }
}

void PatchGroundPound(bool bPatch) {
    static bool bPatched = false;
    if (bPatched && !bPatch) {
        g_hPatcher_GroundPound.Disable();
        bPatched = false;
    } else if (!bPatched && bPatch) {
        if (g_hPatcher_GroundPound.Enable()) {
            bPatched = true;
        } else {
            SetFailState("Failed in patching checks for \"" ... KEY_GROUNDPOUND ... "\"");
        }
    }
}

void ToggleDetour(bool bEnable) {
    static bool bDetoured = false;
    if (bEnable && !bDetoured) {
        if (!DHookEnableDetour(g_hDetour_DoSwing, false, OnDoSwingPre) || !DHookEnableDetour(g_hDetour_DoSwing, true, OnDoSwingPost))
            SetFailState("Failed to enable detours for \"" ... KEY_DOSWING ... "\"");
        if (!DHookEnableDetour(g_hDetour_GroundPound, false, OnGroundPoundPre) || !DHookEnableDetour(g_hDetour_GroundPound, true, OnGroundPoundPost))
            SetFailState("Failed to enable detours for \"" ... KEY_GROUNDPOUND ... "\"");
        bDetoured = true;
    } else if (!bEnable && bDetoured) {
        if (!DHookDisableDetour(g_hDetour_DoSwing, false, OnDoSwingPre) || !DHookDisableDetour(g_hDetour_DoSwing, true, OnDoSwingPost))
            SetFailState("Failed to disable detours for \"" ... KEY_DOSWING ... "\"");
        if (!DHookDisableDetour(g_hDetour_GroundPound, false, OnGroundPoundPre) || !DHookDisableDetour(g_hDetour_GroundPound, true, OnGroundPoundPost))
            SetFailState("Failed to disable detours for \"" ... KEY_GROUNDPOUND ... "\"");
        bDetoured = false;
    }
}

// =======================================
// Detour CBs
// =======================================
public MRESReturn OnDoSwingPre(int pThis) {
    if (IsValidEntity(pThis))
        PatchSweepFist(true);
    return MRES_Ignored;
}

public MRESReturn OnDoSwingPost(int pThis) {
    if (IsValidEntity(pThis))
        PatchSweepFist(false);
    return MRES_Ignored;
}

public MRESReturn OnGroundPoundPre(int pThis) {
    if (IsValidEntity(pThis))
        PatchGroundPound(true);
    return MRES_Ignored;
}

public MRESReturn OnGroundPoundPost(int pThis) {
    if (IsValidEntity(pThis))
        PatchGroundPound(false);
    return MRES_Ignored;
}