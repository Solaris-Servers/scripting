#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>

#define GAMEDATA_FILE            "l4d_static_punch_getup"
#define PATCH_IGNORE_BUTTONS     "HandleActivity_PunchedByTank__ignore_buttons"
#define PATCH_EARLY_EXIT_PERCENT "HandleActivity_PunchedByTank__early_exit_percent"
#define OFFS_OPCODE_SIZE         "early_exit_percent__opcode_size"

MemoryBlock g_memEarlyExitPercent;

public Plugin myinfo = {
    name        = "[L4D & 2] Static Punch Get-up",
    author      = "Forgetest",
    description = "Fix punch get-up varying in length, along with flexible setting to it.",
    version     = "1.0",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

public void OnPluginStart() {
    GetGameData();
    ConVar cv = CreateConVar(
    "tank_punch_getup_scale", "0.5",
    "How many the length of landing get-up of tank punch is scaled. Range [0.01 - 0.99]",
    FCVAR_SPONLY, true, 0.01, true, 0.99);
    CvarChgGetupScale(cv, "", "");
    cv.AddChangeHook(CvarChgGetupScale);
}

void GetGameData() {
    GameData gmConf = new GameData(GAMEDATA_FILE);
    if (!gmConf) SetFailState("Missing gamedata \""...GAMEDATA_FILE..."\"");
    MemoryPatch mPatch = MemoryPatch.CreateFromConf(gmConf, PATCH_IGNORE_BUTTONS);
    if (!mPatch.Validate()) SetFailState("Failed to validate \""...PATCH_IGNORE_BUTTONS..."\"");
    if (!mPatch.Enable())   SetFailState("Failed to patch \""...PATCH_IGNORE_BUTTONS..."\"");
    mPatch = MemoryPatch.CreateFromConf(gmConf, PATCH_EARLY_EXIT_PERCENT);
    if (!mPatch.Validate()) SetFailState("Failed to validate \""...PATCH_EARLY_EXIT_PERCENT..."\"");
    if (!mPatch.Enable())   SetFailState("Failed to patch \""...PATCH_EARLY_EXIT_PERCENT..."\"");
    int iOffs = gmConf.GetOffset(OFFS_OPCODE_SIZE);
    if (iOffs == -1) SetFailState("Missing offset \""...OFFS_OPCODE_SIZE..."\"");
    g_memEarlyExitPercent = new MemoryBlock(4); // 32-bit pointer size
    StoreToAddress(mPatch.Address + view_as<Address>(iOffs), view_as<int>(g_memEarlyExitPercent.Address), NumberType_Int32);
    delete gmConf;
}

void CvarChgGetupScale(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_memEarlyExitPercent.StoreToOffset(0, view_as<int>(cv.FloatValue), NumberType_Int32);
}