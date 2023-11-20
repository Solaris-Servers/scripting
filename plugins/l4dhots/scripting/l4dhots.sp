#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <l4d2util>
#include <solaris/stocks>

bool      g_bLeft4Dead2;

ArrayList g_aHOTPair;

ConVar    g_cvPillHot;
ConVar    g_cvPillInterval;
ConVar    g_cvPillIncrement;
ConVar    g_cvPillTotal;
ConVar    g_cvPainPillsHealthValue;

ConVar    g_cvAdrenHot;
ConVar    g_cvAdrenInterval;
ConVar    g_cvAdrenIncrement;
ConVar    g_cvAdrenTotal;
ConVar    g_cvAdrenalineHealthBuffer;

public Plugin myinfo =  {
    name        = "L4D HOTs",
    author      = "ProdigySim, CircleSquared, Forgetest",
    description = "Pills and Adrenaline heal over time",
    version     = "2.5",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    EngineVersion evGame = GetEngineVersion();
    if (evGame == Engine_Left4Dead) {
        g_bLeft4Dead2 = false;
    } else if (evGame == Engine_Left4Dead2) {
        g_bLeft4Dead2 = true;
    } else {
        strcopy(szError, iErrMax, "Plugin only supports Left 4 Dead 1 & 2.");
        return APLRes_SilentFailure;
    }
    return APLRes_Success;
}

public void OnPluginStart() {
    g_aHOTPair = new ArrayList(2);

    char szBuffer[16];
    g_cvPainPillsHealthValue = FindConVar("pain_pills_health_value");
    g_cvPainPillsHealthValue.GetString(szBuffer, sizeof(szBuffer));

    g_cvPillHot = CreateConVar(
    "l4d_pills_hot", "0",
    "Pills heal over time",
    FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0, true, 1.0);

    g_cvPillInterval = CreateConVar(
    "l4d_pills_hot_interval", "1.0",
    "Interval for pills hot",
    FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.00001);

    g_cvPillIncrement = CreateConVar(
    "l4d_pills_hot_increment", "10",
    "Increment amount for pills hot",
    FCVAR_NOTIFY|FCVAR_SPONLY, true, 1.0);

    g_cvPillTotal = CreateConVar(
    "l4d_pills_hot_total", szBuffer,
    "Total amount for pills hot",
    FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0);

    if (g_bLeft4Dead2) {
        g_cvAdrenalineHealthBuffer = FindConVar("adrenaline_health_buffer");
        g_cvAdrenalineHealthBuffer.GetString(szBuffer, sizeof(szBuffer));

        g_cvAdrenHot = CreateConVar(
        "l4d_adrenaline_hot", "0",
        "Adrenaline heals over time",
        FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0, true, 1.0);

        g_cvAdrenInterval = CreateConVar(
        "l4d_adrenaline_hot_interval", "1.0",
        "Interval for adrenaline hot",
        FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.00001);

        g_cvAdrenIncrement = CreateConVar(
        "l4d_adrenaline_hot_increment", "15",
        "Increment amount for adrenaline hot",
        FCVAR_NOTIFY|FCVAR_SPONLY, true, 1.0);

        g_cvAdrenTotal = CreateConVar(
        "l4d_adrenaline_hot_total", szBuffer,
        "Total amount for adrenaline hot",
        FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0);
    }

    CvarChg_PillHot(g_cvPillHot, "", "");
    g_cvPillHot.AddChangeHook(CvarChg_PillHot);

    if (g_bLeft4Dead2) {
        CvarChg_AdrenHot(g_cvAdrenHot, "", "");
        g_cvAdrenHot.AddChangeHook(CvarChg_AdrenHot);
    }
}

public void OnPluginEnd() {
    TogglePillHot(false);
    ToggleAdrenHot(false);
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_aHOTPair.Clear();
}

void Event_Player_BotReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    HandleSurvivorTakeover(eEvent.GetInt("player"), eEvent.GetInt("bot"));
}

void Event_Bot_PlayerReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    HandleSurvivorTakeover(eEvent.GetInt("bot"), eEvent.GetInt("player"));
}

void HandleSurvivorTakeover(int iReplacee, int iReplacer) {
    // There can be multiple HOTs happening at the same time
    int iIndex = -1;
    while ((iIndex = g_aHOTPair.FindValue(iReplacee, 0)) != -1) {
        g_aHOTPair.Set(iIndex, iReplacer, 0);
        DataPack dp = g_aHOTPair.Get(iIndex, 1);
        dp.Reset();
        dp.WriteCell(iReplacer);
    }
}

void Event_PillsUsed(Event eEvent, const char[] szName, bool bDontBroadcast) {
    HealEntityOverTime(eEvent.GetInt("userid"), g_cvPillInterval.FloatValue, g_cvPillIncrement.IntValue, g_cvPillTotal.IntValue);
}

void Event_AdrenalineUsed(Event eEvent, const char[] szName, bool bDontBroadcast) {
    HealEntityOverTime(eEvent.GetInt("userid"), g_cvAdrenInterval.FloatValue, g_cvAdrenIncrement.IntValue, g_cvAdrenTotal.IntValue);
}

void HealEntityOverTime(int iUserId, float fInterval, int iIncrement, int iTotal) {
    int iClient = GetClientOfUserId(iUserId);
    if (iClient <= 0)             return;
    if (!IsClientInGame(iClient)) return;
    if (!IsPlayerAlive(iClient))  return;
    int iMaxHP = GetEntProp(iClient, Prop_Send, "m_iMaxHealth", 2);
    if (iIncrement >= iTotal) {
        HealTowardsMax(iClient, iTotal, iMaxHP);
    } else {
        HealTowardsMax(iClient, iIncrement, iMaxHP);
        DataPack dp;
        CreateDataTimer(fInterval, HOT_ACTION, dp, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
        dp.WriteCell(iUserId);
        dp.WriteCell(iIncrement);
        dp.WriteCell(iTotal - iIncrement);
        dp.WriteCell(iMaxHP);
        static int iIdx;
        iIdx = g_aHOTPair.Push(iUserId);
        g_aHOTPair.Set(iIdx, dp, 1);
    }
}

Action HOT_ACTION(Handle hTimer, DataPack dp) {
    dp.Reset();
    int iUserId = dp.ReadCell();
    int iClient = GetClientOfUserId(iUserId);
    if (iClient && IsPlayerAlive(iClient) && !IsIncapacitated(iClient) && !IsHangingFromLedge(iClient)) {
        int iIncrement = dp.ReadCell();
        DataPackPos dpPos = dp.Position;
        int iRemaining = dp.ReadCell();
        int iMaxHP = dp.ReadCell();
        if (iIncrement < iRemaining) {
            HealTowardsMax(iClient, iIncrement, iMaxHP);
            dp.Position = dpPos;
            dp.WriteCell(iRemaining - iIncrement);
            return Plugin_Continue;
        } else {
            HealTowardsMax(iClient, iRemaining, iMaxHP);
        }
    }
    static int iIdx;
    iIdx = g_aHOTPair.FindValue(dp, 1);
    if (iIdx != -1) g_aHOTPair.Erase(iIdx);
    return Plugin_Stop;
}

void HealTowardsMax(int iClient, int iAmount, int iMax) {
    float fHB = GetEntPropFloat(iClient, Prop_Send, "m_healthBuffer") + iAmount;
    float fOverflow = fHB + GetClientHealth(iClient) - iMax;
    if (fOverflow > 0) fHB -= fOverflow;
    SetEntPropFloat(iClient, Prop_Send, "m_healthBuffer", fHB);
}

void CvarChg_PillHot(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    TogglePillHot(g_cvPillHot.BoolValue);
    SwitchGeneralEventHooks(g_cvPillHot.BoolValue || g_cvAdrenHot.BoolValue);
}

void CvarChg_AdrenHot(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    ToggleAdrenHot(g_cvAdrenHot.BoolValue);
    SwitchGeneralEventHooks(g_cvPillHot.BoolValue || g_cvAdrenHot.BoolValue);
}

void TogglePillHot(bool bEnable) {
    static bool bEnabled = false;
    static int  iOrigVal;
    if (bEnable && !bEnabled) {
        g_cvPainPillsHealthValue.Flags &= ~FCVAR_REPLICATED;
        iOrigVal = g_cvPainPillsHealthValue.IntValue;
        g_cvPainPillsHealthValue.IntValue = 0;
        HookEvent("pills_used", Event_PillsUsed);
        bEnabled = true;
    } else if (!bEnable && bEnabled) {
        g_cvPainPillsHealthValue.Flags &= FCVAR_REPLICATED;
        g_cvPainPillsHealthValue.IntValue = iOrigVal;
        UnhookEvent("pills_used", Event_PillsUsed);
        bEnabled = false;
    }
}

void ToggleAdrenHot(bool bEnable) {
    static bool bEnabled = false;
    static int  iOrigVal;
    if (bEnable && !bEnabled) {
        g_cvAdrenalineHealthBuffer.Flags &= ~FCVAR_REPLICATED;
        iOrigVal = g_cvAdrenalineHealthBuffer.IntValue;
        g_cvAdrenalineHealthBuffer.IntValue = 0;
        HookEvent("adrenaline_used", Event_AdrenalineUsed);
        bEnabled = true;
    } else if (!bEnable && bEnabled) {
        g_cvAdrenalineHealthBuffer.Flags &= FCVAR_REPLICATED;
        g_cvAdrenalineHealthBuffer.IntValue = iOrigVal;
        UnhookEvent("adrenaline_used", Event_AdrenalineUsed);
        bEnabled = false;
    }
}

void SwitchGeneralEventHooks(bool bHook) {
    static bool bHooked = false;
    if (bHook && !bHooked) {
        HookEvent("round_start",        Event_RoundStart, EventHookMode_PostNoCopy);
        HookEvent("player_bot_replace", Event_Player_BotReplace);
        HookEvent("bot_player_replace", Event_Bot_PlayerReplace);
        bHooked = true;
    } else if (!bHook && bHooked) {
        UnhookEvent("round_start",        Event_RoundStart, EventHookMode_PostNoCopy);
        UnhookEvent("player_bot_replace", Event_Player_BotReplace);
        UnhookEvent("bot_player_replace", Event_Bot_PlayerReplace);
        bHooked = false;
    }
}