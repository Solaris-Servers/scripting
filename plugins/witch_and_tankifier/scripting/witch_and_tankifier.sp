#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2lib>
#include <l4d2util/rounds>

#define SIZE_OF_INT 2147483647 // without 0

// ======================================
// Variables
// ======================================

ConVar    g_cvBossBuffer;
ConVar    g_cvBossFlowMin;
ConVar    g_cvBossFlowMax;

ConVar    g_cvTankCanSpawn;
ConVar    g_cvWitchCanSpawn;
ConVar    g_cvWitchAvoidTank;

StringMap g_smStaticTankMaps;
StringMap g_smStaticWitchMaps;

ArrayList g_arrValidTankFlows;
ArrayList g_arrValidWitchFlows;

char      g_szCurrentMap[64];

GlobalForward g_fwdTankWasSet;
GlobalForward g_fwdWitchWasSet;

public Plugin myinfo = {
    name        = "Tank and Witch ifier!",
    author      = "CanadaRox, Sir, devilesk, Derpduck, Forgetest",
    version     = "2.4.1",
    description = "Sets a tank spawn and has the option to remove the witch spawn point on every map",
    url         = "https://github.com/devilesk/rl4d2l-plugins"
};

// ======================================
// Natives
// ======================================

any Native_IsStaticTankMap(Handle hPlugin, int iNumParams) {
    int iBytes = 0;

    char szMapName[64];
    GetNativeString(1, szMapName, sizeof szMapName, iBytes);

    if (iBytes) {
        StrToLower(szMapName);
        return IsStaticTankMap(szMapName);
    } else {
        return IsStaticTankMap(g_szCurrentMap);
    }
}

any Native_IsStaticWitchMap(Handle hPlugin, int iNumParams) {
    int iBytes = 0;

    char szMapName[64];
    GetNativeString(1, szMapName, sizeof szMapName, iBytes);

    if (iBytes) {
        StrToLower(szMapName);
        return IsStaticWitchMap(szMapName);
    } else {
        return IsStaticWitchMap(g_szCurrentMap);
    }
}

any Native_IsTankPercentValid(Handle hPlugin, int iNumParams) {
    int iFlow = GetNativeCell(1);
    return IsTankPercentValid(iFlow);
}

any Native_IsWitchPercentValid(Handle hPlugin, int iNumParams) {
    int  iFlow        = GetNativeCell(1);
    bool bIgnoreBlock = GetNativeCell(2);

    if (bIgnoreBlock) {
        ArrayList arrValidFlows = g_arrValidWitchFlows.Clone(), p_hTemp = g_arrValidWitchFlows;
        int iInterval[2];
        if (GetTankAvoidInterval(iInterval) && IsValidInterval(iInterval)) {
            // Restore the avoidance flow
            arrValidFlows.PushArray(iInterval);
            MergeIntervals(arrValidFlows);
            g_arrValidWitchFlows = arrValidFlows;
        }
        bool bResult = IsWitchPercentValid(iFlow);
        g_arrValidWitchFlows = p_hTemp;
        delete arrValidFlows;
        return bResult;
    }

    return IsWitchPercentValid(iFlow);
}

any Native_IsWitchPercentBlockedForTank(Handle hPlugin, int iNumParams) {
    int iInterval[2];
    if (GetTankAvoidInterval(iInterval) && IsValidInterval(iInterval)) {
        int iFlow = GetNativeCell(1);
        return (iInterval[0] <= iFlow <= iInterval[1]);
    }
    return false;
}

any Native_SetTankPercent(Handle hPlugin, int iNumParams) {
    int iFlow = GetNativeCell(1);
    if (!IsTankPercentValid(iFlow))
        return false;
    DynamicAdjustWitchFlow(iFlow);
    SetTankPercent(iFlow);
    return true;
}

any Native_SetWitchPercent(Handle hPlugin, int iNumParams) {
    int iFlow = GetNativeCell(1);
    if (!IsWitchPercentValid(iFlow))
        return false;
    SetWitchPercent(iFlow);
    return true;
}

// ======================================
// Plugin Setup
// ======================================

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    CreateNative("IsStaticTankMap",              Native_IsStaticTankMap);
    CreateNative("IsStaticWitchMap",             Native_IsStaticWitchMap);
    CreateNative("IsTankPercentValid",           Native_IsTankPercentValid);
    CreateNative("IsWitchPercentValid",          Native_IsWitchPercentValid);
    CreateNative("IsWitchPercentBlockedForTank", Native_IsWitchPercentBlockedForTank);
    CreateNative("SetTankPercent",               Native_SetTankPercent);
    CreateNative("SetWitchPercent",              Native_SetWitchPercent);

    g_fwdTankWasSet  = new GlobalForward("OnTankFlowWasApplied",  ET_Ignore);
    g_fwdWitchWasSet = new GlobalForward("OnWitchFlowWasApplied", ET_Ignore);

    RegPluginLibrary("witch_and_tankifier");
    return APLRes_Success;
}

public void OnPluginStart() {
    g_cvTankCanSpawn = CreateConVar(
    "sm_tank_can_spawn", "1",
    "Tank and Witch ifier enables tanks to spawn",
    FCVAR_NOTIFY, true, 0.0, true, 1.0);

    g_cvWitchCanSpawn = CreateConVar(
    "sm_witch_can_spawn", "1",
    "Tank and Witch ifier enables witches to spawn",
    FCVAR_NOTIFY, true, 0.0, true, 1.0);

    g_cvWitchAvoidTank = CreateConVar(
    "sm_witch_avoid_tank_spawn", "20",
    "Minimum flow amount witches should avoid tank spawns by, by half the value given on either side of the tank spawn",
    FCVAR_NOTIFY, true, 0.0, true, 100.0);

    g_cvBossBuffer  = FindConVar("versus_boss_buffer");
    g_cvBossFlowMin = FindConVar("versus_boss_flow_min");
    g_cvBossFlowMax = FindConVar("versus_boss_flow_max");

    g_smStaticTankMaps   = new StringMap();
    g_smStaticWitchMaps  = new StringMap();
    g_arrValidTankFlows  = new ArrayList(2);
    g_arrValidWitchFlows = new ArrayList(2);

    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

    RegServerCmd("static_tank_map",   Cmd_StaticTank);
    RegServerCmd("static_witch_map",  Cmd_StaticWitch);
    RegServerCmd("reset_static_maps", Cmd_Reset);
}

// ======================================
// Boss Spawn Control
// ======================================

public Action L4D_OnSpawnTank(const float vPos[3], const float vAng[3]) {
    return g_cvTankCanSpawn.BoolValue ? Plugin_Continue : Plugin_Handled;
}

public Action L4D_OnSpawnWitch(const float vPos[3], const float vAng[3]) {
    return g_cvWitchCanSpawn.BoolValue ? Plugin_Continue : Plugin_Handled;
}

public Action L4D2_OnSpawnWitchBride(const float vPos[3], const float vAng[3]) {
    return g_cvWitchCanSpawn.BoolValue ? Plugin_Continue : Plugin_Handled;
}

// ======================================
// Current Map Cache
// ======================================

public void OnMapStart() {
    GetCurrentMapLower(g_szCurrentMap, sizeof g_szCurrentMap);
}

// ======================================
// Flow Handling
// ======================================

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
    CreateTimer(0.5, Timer_AdjustBossFlow, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_AdjustBossFlow(Handle timer) {
    if (InSecondHalfOfRound()) {
        return Plugin_Stop;
    }

    g_arrValidTankFlows.Clear();
    g_arrValidWitchFlows.Clear();

    int iMinFlow = RoundToCeil(g_cvBossFlowMin.FloatValue  * 100);
    int iMaxFlow = RoundToFloor(g_cvBossFlowMax.FloatValue * 100);

    // mapinfo override
    iMinFlow = L4D2_GetMapValueInt("versus_boss_flow_min", iMinFlow);
    iMaxFlow = L4D2_GetMapValueInt("versus_boss_flow_max", iMaxFlow);

    if (!IsStaticTankMap(g_szCurrentMap) && g_cvTankCanSpawn.BoolValue) {
        ArrayList arrBannedFlows = new ArrayList(2);

        int iInterval[2];
        iInterval[0] = 0, iInterval[1] = iMinFlow - 1;
        if (IsValidInterval(iInterval)) arrBannedFlows.PushArray(iInterval);
        iInterval[0] = iMaxFlow + 1, iInterval[1] = 100;
        if (IsValidInterval(iInterval)) arrBannedFlows.PushArray(iInterval);

        KeyValues kv = new KeyValues("tank_ban_flow");
        L4D2_CopyMapSubsection(kv, "tank_ban_flow");

        if (kv.GotoFirstSubKey()) {
            do {
                iInterval[0] = kv.GetNum("min", -1);
                iInterval[1] = kv.GetNum("max", -1);
                if (IsValidInterval(iInterval)) arrBannedFlows.PushArray(iInterval);
            } while (kv.GotoNextKey());
        }
        delete kv;

        MergeIntervals(arrBannedFlows);
        MakeComplementaryIntervals(arrBannedFlows, g_arrValidTankFlows);

        delete arrBannedFlows;

        // check each array index to see if it is within a ban range
        int iValidSpawnTotal = g_arrValidTankFlows.Length;
        if (iValidSpawnTotal == 0) {
            SetTankPercent(0);
        } else {
            int iTankFlow = GetRandomIntervalNum(g_arrValidTankFlows);
            SetTankPercent(iTankFlow);
        }
    }
    else {
        SetTankPercent(0);
    }

    if (!IsStaticWitchMap(g_szCurrentMap) && g_cvWitchCanSpawn.BoolValue) {
        ArrayList arrBannedFlows = new ArrayList(2);

        int iInterval[2];
        iInterval[0] = 0, iInterval[1] = iMinFlow - 1;
        if (IsValidInterval(iInterval)) arrBannedFlows.PushArray(iInterval);
        iInterval[0] = iMaxFlow + 1, iInterval[1] = 100;
        if (IsValidInterval(iInterval)) arrBannedFlows.PushArray(iInterval);

        KeyValues kv = new KeyValues("witch_ban_flow");
        L4D2_CopyMapSubsection(kv, "witch_ban_flow");

        if (kv.GotoFirstSubKey()) {
            do {
                iInterval[0] = kv.GetNum("min", -1);
                iInterval[1] = kv.GetNum("max", -1);
                if (IsValidInterval(iInterval)) arrBannedFlows.PushArray(iInterval);
            } while (kv.GotoNextKey());
        }
        delete kv;

        if (GetTankAvoidInterval(iInterval)) {
            if (IsValidInterval(iInterval)) arrBannedFlows.PushArray(iInterval);
        }

        MergeIntervals(arrBannedFlows);
        MakeComplementaryIntervals(arrBannedFlows, g_arrValidWitchFlows);

        delete arrBannedFlows;

        // check each array index to see if it is within a ban range
        int iValidSpawnTotal = g_arrValidWitchFlows.Length;
        if (iValidSpawnTotal == 0) {
            SetWitchPercent(0);
        } else {
            int iWitchFlow = GetRandomIntervalNum(g_arrValidWitchFlows);
            SetWitchPercent(iWitchFlow);
        }
    }
    else {
        SetWitchPercent(0);
    }

    return Plugin_Stop;
}

// ======================================
// Dynamic Adjust Witch
// ======================================

// Must be called before tank flow is changed
void DynamicAdjustWitchFlow(int iNewTankFlow) {
    if (!g_cvWitchCanSpawn.BoolValue) return;

    int iInterval[2];
    if (!GetTankAvoidInterval(iInterval)) return;
    if (!IsValidInterval(iInterval))      return;

    // Restore the avoidance flow
    g_arrValidWitchFlows.PushArray(iInterval);
    MergeIntervals(g_arrValidWitchFlows);

    // Convert valid flows into banned flows
    ArrayList arrBannedFlows = new ArrayList(2);
    MakeComplementaryIntervals(g_arrValidWitchFlows, arrBannedFlows);

    // New avoidance flow
    iInterval[0] = RoundToFloor(iNewTankFlow - (g_cvWitchAvoidTank.FloatValue / 2));
    iInterval[1] = RoundToCeil(iNewTankFlow  + (g_cvWitchAvoidTank.FloatValue / 2));
    if (IsValidInterval(iInterval)) arrBannedFlows.PushArray(iInterval);

    // Convert it back
    MakeComplementaryIntervals(arrBannedFlows, g_arrValidWitchFlows);

    // You're done here
    delete arrBannedFlows;

    // Sanity checks
    int iValidSpawnTotal = g_arrValidWitchFlows.Length;
    if (iValidSpawnTotal == 0) {
        SetWitchPercent(0);
    } else {
        // Check if old witch flow is banned this time
        int iWitchFlow = RoundFloat(L4D2Direct_GetVSWitchFlowPercent(0) * 100);
        if (iInterval[0] <= iWitchFlow <= iInterval[1]) {
            // Change it next to the borders first
            if (!IsWitchPercentValid((iWitchFlow = iInterval[1] + 1)) && !IsWitchPercentValid((iWitchFlow = iInterval[0] - 1))) {
                // Move onto a random flow otherwise
                iWitchFlow = GetRandomIntervalNum(g_arrValidWitchFlows);
            }
            // Just do it
            SetWitchPercent(iWitchFlow);
        }
    }
}

// ======================================
// Tank Avoid Flow
// ======================================

bool GetTankAvoidInterval(int iInterval[2]) {
    if (g_cvWitchAvoidTank.FloatValue == 0.0)
        return false;

    float fFlow = L4D2Direct_GetVSTankFlowPercent(0);
    if (fFlow == 0.0) return false;

    iInterval[0] = RoundToFloor((fFlow * 100) - (g_cvWitchAvoidTank.FloatValue / 2));
    iInterval[1] = RoundToCeil((fFlow * 100)  + (g_cvWitchAvoidTank.FloatValue / 2));

    return true;
}

// ======================================
// Interval Methods
//   - based on ArrayList and int[2]
// ======================================

bool IsValidInterval(int iInterval[2]) {
    return iInterval[0] > -1 && iInterval[1] >= iInterval[0];
}

void MergeIntervals(ArrayList arrMerged) {
    if (arrMerged.Length < 2) return;

    ArrayList arrIntervals = arrMerged.Clone();
    SortADTArray(arrIntervals, Sort_Ascending, Sort_Integer);

    arrMerged.Clear();

    int iCurrent[2];
    arrIntervals.GetArray(0, iCurrent);
    arrMerged.PushArray(iCurrent);

    int iIntervalsSize = arrIntervals.Length;
    for (int i = 1; i < iIntervalsSize; i++) {
        arrIntervals.GetArray(i, iCurrent);

        int iBackIdx = arrMerged.Length - 1;
        int iBackR = arrMerged.Get(iBackIdx, 1);

        if (iBackR < iCurrent[0]) {
            // not coincide
            arrMerged.PushArray(iCurrent);
        } else {
            iBackR = (iBackR > iCurrent[1] ? iBackR : iCurrent[1]); // override the right value with maximum
            arrMerged.Set(iBackIdx, iBackR, 1);
        }
    }

    delete arrIntervals;
}

void MakeComplementaryIntervals(ArrayList arrIntervals, ArrayList arrDest) {
    int iIntervalsSize = arrIntervals.Length;
    if (iIntervalsSize < 2) return;

    int iInteval[2];
    for (int i = 1; i < iIntervalsSize; i++) {
        iInteval[0] = arrIntervals.Get(i - 1, 1) + 1;
        iInteval[1] = arrIntervals.Get(i, 0) - 1;
        if (IsValidInterval(iInteval)) arrDest.PushArray(iInteval);
    }
}

int GetRandomIntervalNum(ArrayList aList) {
    int iTotalLength = 0, iSize = aList.Length;
    int[] iArrLength = new int[iSize];
    for (int i = 0; i < iSize; i++) {
        iArrLength[i] = aList.Get(i, 1) - aList.Get(i, 0) + 1;
        iTotalLength += iArrLength[i];
    }

    int iRnd = Math_GetRandomInt(0, iTotalLength - 1);
    for (int i = 0; i < iSize; i++) {
        if (iRnd < iArrLength[i]) {
            return aList.Get(i, 0) + iRnd;
        } else {
            iRnd -= iArrLength[i];
        }
    }
    return 0;
}

// ======================================
// Boss Spawn Scheme Commands
// ======================================

Action Cmd_StaticTank(int args) {
    char szMap[64];
    GetCmdArg(1, szMap, sizeof(szMap));
    StrToLower(szMap);
    g_smStaticTankMaps.SetValue(szMap, true);
    return Plugin_Handled;
}

Action Cmd_StaticWitch(int args) {
    char szMap[64];
    GetCmdArg(1, szMap, sizeof(szMap));
    StrToLower(szMap);
    g_smStaticWitchMaps.SetValue(szMap, true);
    return Plugin_Handled;
}

Action Cmd_Reset(int iArgs) {
    g_smStaticTankMaps.Clear();
    g_smStaticWitchMaps.Clear();
    return Plugin_Handled;
}

// ======================================
// Helper Functions
// ======================================

bool IsStaticTankMap(const char[] szMap) {
    bool iDummy;
    return g_smStaticTankMaps.GetValue(szMap, iDummy);
}

bool IsStaticWitchMap(const char[] szMap) {
    bool iDummy;
    return g_smStaticWitchMaps.GetValue(szMap, iDummy);
}

bool IsTankPercentValid(int fFlow) {
    if (fFlow == 0) return true;

    int iSize = g_arrValidTankFlows.Length;
    if (!iSize) return false;

    // out of bounds
    if (fFlow > g_arrValidTankFlows.Get(iSize - 1, 1) || fFlow < g_arrValidTankFlows.Get(0, 0)){
        return false;
    }

    for (int i = 0; i < iSize; i++) {
        if (fFlow <= g_arrValidTankFlows.Get(i, 1)) {
            return fFlow >= g_arrValidTankFlows.Get(i, 0);
        }
    }

    return false;
}

bool IsWitchPercentValid(int fFlow){
    if (fFlow == 0) return true;

    int iSize = g_arrValidWitchFlows.Length;
    if (!iSize) return false;

    // out of bounds
    if (fFlow > g_arrValidWitchFlows.Get(iSize - 1, 1) || fFlow < g_arrValidWitchFlows.Get(0, 0))
        return false;

    for (int i = 0; i < iSize; i++) {
        if (fFlow <= g_arrValidWitchFlows.Get(i, 1)) {
            return fFlow >= g_arrValidWitchFlows.Get(i, 0);
        }
    }

    return false;
}

void SetTankPercent(int iPrcnt) {
    if (iPrcnt == 0) {
        L4D2Direct_SetVSTankFlowPercent(0, 0.0);
        L4D2Direct_SetVSTankFlowPercent(1, 0.0);
        L4D2Direct_SetVSTankToSpawnThisRound(0, false);
        L4D2Direct_SetVSTankToSpawnThisRound(1, false);
    } else {
        float iNewPrcnt = (float(iPrcnt) / 100);
        L4D2Direct_SetVSTankFlowPercent(0, iNewPrcnt);
        L4D2Direct_SetVSTankFlowPercent(1, iNewPrcnt);
        L4D2Direct_SetVSTankToSpawnThisRound(0, true);
        L4D2Direct_SetVSTankToSpawnThisRound(1, true);
    }

    Call_StartForward(g_fwdTankWasSet);
    Call_Finish();
}

void SetWitchPercent(int iPrcnt) {
    if (iPrcnt == 0) {
        L4D2Direct_SetVSWitchFlowPercent(0, 0.0);
        L4D2Direct_SetVSWitchFlowPercent(1, 0.0);
        L4D2Direct_SetVSWitchToSpawnThisRound(0, false);
        L4D2Direct_SetVSWitchToSpawnThisRound(1, false);
    } else {
        float iNewPrcnt = (float(iPrcnt) / 100);
        L4D2Direct_SetVSWitchFlowPercent(0, iNewPrcnt);
        L4D2Direct_SetVSWitchFlowPercent(1, iNewPrcnt);
        L4D2Direct_SetVSWitchToSpawnThisRound(0, true);
        L4D2Direct_SetVSWitchToSpawnThisRound(1, true);
    }

    Call_StartForward(g_fwdWitchWasSet);
    Call_Finish();
}

// ======================================
// Stock Functions
// ======================================

stock float GetTankProgressFlow(int iRound) {
    return L4D2Direct_GetVSTankFlowPercent(iRound) - GetBossBuffer();
}

stock float GetWitchProgressFlow(int iRound) {
    return L4D2Direct_GetVSWitchFlowPercent(iRound) - GetBossBuffer();
}

stock float GetBossBuffer() {
    return g_cvBossBuffer.FloatValue / L4D2Direct_GetMapMaxFlowDistance();
}

stock int Math_GetRandomInt(int iMin, int iMax) {
    int iRnd = GetURandomInt();
    if (iRnd == 0) iRnd++;
    return RoundToCeil(float(iRnd) / (float(SIZE_OF_INT) / float(iMax - iMin + 1))) + iMin - 1;
}

stock void StrToLower(char[] iArg) {
    int iLen = strlen(iArg);
    for (int i = 0; i < iLen; i++) {
        iArg[i] = CharToLower(iArg[i]);
    }
}

stock int GetCurrentMapLower(char[] szBuffer, int iLen) {
    int iBytesWritten = GetCurrentMap(szBuffer, iLen);
    StrToLower(szBuffer);
    return iBytesWritten;
}