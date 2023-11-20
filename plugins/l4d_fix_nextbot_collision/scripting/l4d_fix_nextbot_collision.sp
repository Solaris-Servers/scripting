#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>

#define GAMEDATA_FILE "l4d_fix_nextbot_collision"
#define PATCH_NAME    "ZombieBotLocomotion::ResolveZombieCollisions__result_multiple_dummypatch"

ConVar g_cvResolveScale;
float  g_fResolveScale;

public Plugin myinfo = {
    name        = "[L4D & 2] Fix Nextbot Collision",
    author      = "Forgetest",
    description = "Reduce the possibility that commons jiggle around when close to each other.",
    version     = "1.0",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

public void OnPluginStart() {
    g_cvResolveScale = CreateConVar(
    "l4d_nextbot_collision_resolve_scale", "0.33333333",
    "How much to scale the move vector as a result of resolving zombie collision.",
    FCVAR_CHEAT, true, 0.0, false, 0.0);
    g_fResolveScale = 3.0 * g_cvResolveScale.FloatValue;
    g_cvResolveScale.AddChangeHook(CvChg_ResolveScale);

    InitGameData();
}

void InitGameData() {
    GameData gmConf = new GameData(GAMEDATA_FILE);
    if (!gmConf)
        SetFailState("Missing gamedata \""...GAMEDATA_FILE..."\"");

    MemoryPatch mPatch = MemoryPatch.CreateFromConf(gmConf, PATCH_NAME);
    if (!mPatch.Enable())
        SetFailState("Failed to patch \"%s\"", PATCH_NAME);

    delete gmConf;

    Address pResultMultiple = mPatch.Address + view_as<Address>(4);
    StoreToAddress(pResultMultiple, GetAddressOfCell(g_fResolveScale), NumberType_Int32);
}

void CvChg_ResolveScale(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fResolveScale = 3.0 * g_cvResolveScale.FloatValue;
}