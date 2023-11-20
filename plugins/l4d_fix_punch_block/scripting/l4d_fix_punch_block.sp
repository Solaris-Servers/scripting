#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>
#include <collisionhook>
#include <left4dhooks/lux_library>

#define GAMEDATA_FILE     "l4d_fix_punch_block"
#define KEY_SWEEPFIST     "CTankClaw::SweepFist"
#define KEY_PATCH_SURFIX  "__AddEntityToIgnore_dummypatch"
#define KEY_SETPASSENTITY "CTraceFilterSimple::SetPassEntity"

int g_iTankClass;

public Plugin myinfo = {
    name        = "[L4D & 2] Fix Punch Block",
    author      = "Forgetest",
    description = "Fix common infected blocking the punch tracing.",
    version     = "1.2.1",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    switch (GetEngineVersion()) {
        case Engine_Left4Dead:  g_iTankClass = 5;
        case Engine_Left4Dead2: g_iTankClass = 8;
        default: {
            strcopy(szError, iErrMax, "Plugin supports Left 4 Dead & 2 only.");
            return APLRes_SilentFailure;
        }
    }
    return APLRes_Success;
}

public void OnPluginStart() {
    GameData gmData = new GameData(GAMEDATA_FILE);
    if (!gmData) SetFailState("Missing gamedata \""...GAMEDATA_FILE..."\"");
    MemoryPatch mPatch = MemoryPatch.CreateFromConf(gmData, KEY_SWEEPFIST...KEY_PATCH_SURFIX);
    if (!mPatch.Enable()) SetFailState("Failed to enable patch \""...KEY_SWEEPFIST...KEY_PATCH_SURFIX..."\"");
    int iOffs = GameConfGetOffset(gmData, "OS");
    if (iOffs == -1) SetFailState("Failed to get offset of \"OS\"");
    Address aAddr = gmData.GetAddress(KEY_SETPASSENTITY);
    if (aAddr == Address_Null) SetFailState("Failed to get address of \""...KEY_SETPASSENTITY..."\"");
    // windows
    if (iOffs == 0) {
        aAddr = view_as<Address>(LoadFromAddress(aAddr, NumberType_Int32));
        if (aAddr == Address_Null) SetFailState("Failed to deref pointer to \""...KEY_SETPASSENTITY..."\"");
    }
    delete gmData;
    PatchNearJump(0xE8, mPatch.Address, aAddr);
}

public Action CH_PassFilter(int iTouch, int iPass, bool &bResult) {
    if (iPass <= 0 || iPass > MaxClients || iTouch <= MaxClients)
        return Plugin_Continue;
    if (!IsClientInGame(iPass))
        return Plugin_Continue;
    if (GetClientTeam(iPass) != 3 || GetEntProp(iPass, Prop_Send, "m_zombieClass") != g_iTankClass)
        return Plugin_Continue;
    static char szCls[64];
    if (!GetEdictClassname(iTouch, szCls, sizeof(szCls)) || strcmp(szCls, "infected") != 0)
        return Plugin_Continue;
    if (!IsPlayerAlive(iPass) || GetEntProp(iPass, Prop_Send, "m_isIncapacitated"))
        return Plugin_Continue;
    int iWeapon = GetEntPropEnt(iPass, Prop_Send, "m_hActiveWeapon");
    if (iWeapon != -1 && GetEntPropFloat(iWeapon, Prop_Send, "m_swingTimer", 1) >= GetGameTime()) {
        static int m_vSwingPosition = -1;
        if (m_vSwingPosition == -1) m_vSwingPosition = FindSendPropInfo("CTankClaw", "m_lowAttackDurationTimer") + 32;
        static float vPos[3], vSwingPos[3], vEntPos[3];
        GetClientEyePosition(iPass, vPos);
        GetAbsOrigin(iTouch, vEntPos, true);
        GetEntDataVector(iWeapon, m_vSwingPosition, vSwingPos);
        float fRadius2 = GetEntPropFloat(iTouch, Prop_Data, "m_flRadius");
        fRadius2 = fRadius2 * fRadius2;
        if (GetVectorDistance(vPos, vEntPos, true) <= fRadius2 || GetVectorDistance(vSwingPos, vEntPos, true) <= fRadius2) {
            bResult = false;
            return Plugin_Handled;
        }
    }
    return Plugin_Continue;
}

void PatchNearJump(int iInstruction, Address aSrc, Address aDest) {
    StoreToAddress(aSrc, iInstruction, NumberType_Int8);
    StoreToAddress(aSrc + view_as<Address>(1), view_as<int>(aDest - aSrc) - 5, NumberType_Int32);
}