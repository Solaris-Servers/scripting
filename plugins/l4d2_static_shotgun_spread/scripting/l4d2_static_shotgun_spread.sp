#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>

#define GAMEDATA_FILE "code_patcher"
#define KEY_SGSPREAD  "sgspread"

#define BULLET_MAX_SIZE 4

// Original code & Notes: https://github.com/Jahze/l4d2_plugins/tree/master/spread_patch
// Static Shotgun Spread leverages code_patcher (code_patcher.txt gamedata)
// to replace RNG in pellet spread with static factors.
// This plugin allows you to adjust the spread characteristics, by live patching operands in the custom ASM.

// You can use the visualise_impacts.smx plugin to test the resulting spread.
// It will render small purple boxes where the server-side pellets land.

enum {
    eWindows = 0,
    eLinux,
    ePlatform_Size
}

int
    g_ePlatform;

static const int g_BulletOffsets[ePlatform_Size][BULLET_MAX_SIZE] = {
    // Windows
    {
        0xf,
        0x21,
        0x30,
        0x3f
    },
    // Linux
    {
        0x11,
        0x22,
        0x2f,
        0x43
    }
};

static const int g_FactorOffset[ePlatform_Size] = {
    0x36,   // Windows
    0x34    // Linux
};

static const int g_CenterPelletOffset[ePlatform_Size] = {
    -0x36,  // Windows
    -0x1c   // Linux
};

MemoryPatch
    g_hPatch_sgspread;

ConVar
    g_cvRing1BulletsCvar,
    g_cvRing1FactorCvar,
    g_cvCenterPelletCvar;

public Plugin myinfo = {
    name        = "L4D2 Static Shotgun Spread",
    author      = "Jahze, Visor, A1m`, Rena",
    version     = "1.6.1",
    description = "Changes the values in the sgspread patch",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart() {
    GameData gmData = new GameData(GAMEDATA_FILE);
    if (gmData == null) {
        SetFailState("Missing gamedata \"" ... GAMEDATA_FILE ... "\"");
    }
    g_hPatch_sgspread = MemoryPatch.CreateFromConf(gmData, KEY_SGSPREAD);
    if (g_hPatch_sgspread == null || !g_hPatch_sgspread.Validate()) {
        SetFailState("Failed to validate MemoryPatch \"" ... KEY_SGSPREAD ... "\"");
    }
    if (!g_hPatch_sgspread.Enable()) {
        SetFailState("Failed to enable MemoryPatch \"" ... KEY_SGSPREAD ... "\"");
    }
    g_ePlatform = GameConfGetOffset(gmData, "OS");
    if (g_ePlatform == -1) {
        SetFailState("Failed to retrieve offset \"OS\"");
    }
    delete gmData;

    g_cvRing1BulletsCvar = CreateConVar("sgspread_ring1_bullets", "3", "Number of bullets for the first ring, the remaining bullets will be in the second ring.");
    g_cvRing1FactorCvar  = CreateConVar("sgspread_ring1_factor",  "2", "Determines how far or closer the bullets will be from the center for the first ring.");
    g_cvCenterPelletCvar = CreateConVar("sgspread_center_pellet", "1", "Center pellet: 0 - off, 1 - on.", _, true, 0.0, true, 1.0);

    g_cvRing1BulletsCvar.AddChangeHook(OnRing1BulletsChange);
    g_cvRing1FactorCvar.AddChangeHook(OnRing1FactorChange);
    g_cvCenterPelletCvar.AddChangeHook(OnCenterPelletChange);

    HotPatchBullets(g_cvRing1BulletsCvar.IntValue);
    HotPatchFactor(g_cvRing1FactorCvar.IntValue);
    HotPatchCenterPellet(g_cvCenterPelletCvar.BoolValue);
}

static void HotPatchCenterPellet(bool newValue) {
    Address pAddr    = g_hPatch_sgspread.Address;
    int currentValue = LoadFromAddress(pAddr + view_as<Address>(g_CenterPelletOffset[g_ePlatform]), NumberType_Int8);
    int bullets      = g_cvRing1BulletsCvar.IntValue;
    if (view_as<bool>(currentValue) == newValue) {
        return;
    }
    StoreToAddress(pAddr + view_as<Address>(g_CenterPelletOffset[g_ePlatform]), view_as<int>(newValue), NumberType_Int8);
    StoreToAddress(pAddr + view_as<Address>(g_BulletOffsets[g_ePlatform][0]), bullets + (1 - view_as<int>(!newValue)), NumberType_Int8);
    StoreToAddress(pAddr + view_as<Address>(g_BulletOffsets[g_ePlatform][1]), bullets + (1 - view_as<int>(!newValue)), NumberType_Int8);
    StoreToAddress(pAddr + view_as<Address>(g_BulletOffsets[g_ePlatform][2]), bullets + (2 - view_as<int>(!newValue)), NumberType_Int8);
}

static void HotPatchBullets(int nBullets) {
    bool centerpellet = !g_cvCenterPelletCvar.BoolValue;
    float degree = 0.0;
    if (g_ePlatform == eWindows) {
        degree = 360.0 / float(nBullets);
    } else {
        degree = 360.0 / (2.0 * float(nBullets));
    }
    Address pAddr = g_hPatch_sgspread.Address;
    StoreToAddress(pAddr + view_as<Address>(g_BulletOffsets[g_ePlatform][0]), nBullets + (1 - view_as<int>(centerpellet)), NumberType_Int8);
    StoreToAddress(pAddr + view_as<Address>(g_BulletOffsets[g_ePlatform][1]), nBullets + (1 - view_as<int>(centerpellet)), NumberType_Int8);
    StoreToAddress(pAddr + view_as<Address>(g_BulletOffsets[g_ePlatform][2]), nBullets + (2 - view_as<int>(centerpellet)), NumberType_Int8);
    StoreToAddress(pAddr + view_as<Address>(g_BulletOffsets[g_ePlatform][3]), view_as<int>(degree), NumberType_Int32);
}

static void HotPatchFactor(int factor) {
    Address pAddr = g_hPatch_sgspread.Address;
    if (g_ePlatform == eWindows) {
        StoreToAddress(pAddr + view_as<Address>(g_FactorOffset[eWindows]), view_as<int>(float(factor)), NumberType_Int32); //On windows need the float type !!!
        return;
    }
    StoreToAddress(pAddr + view_as<Address>(g_FactorOffset[eLinux]), factor, NumberType_Int32);
}

public void OnRing1BulletsChange(ConVar cv, const char[] oldVal, const char[] newVal) {
    int nBullets = StringToInt(newVal);
    HotPatchBullets(nBullets);
}

public void OnRing1FactorChange(ConVar cv, const char[] oldVal, const char[] newVal) {
    int factor = StringToInt(newVal);
    HotPatchFactor(factor);
}

public void OnCenterPelletChange(ConVar cv, const char[] oldVal, const char[] newVal) {
    bool value = view_as<bool>(StringToInt(newVal));
    HotPatchCenterPellet(value);
}