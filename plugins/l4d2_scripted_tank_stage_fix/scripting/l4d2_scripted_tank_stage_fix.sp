#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>
#include <left4dhooks>

#define GAMEDATA_FILE    "l4d2_scripted_tank_stage_fix"
#define FUNCTION_NAME    "CDirectorScriptedEventManager::UpdateScriptedTankStage"
#define FUNCTION2_NAME   "ZombieManager::ReplaceTank"
#define OFFSET_SPAWN     "CDirectorScriptedEventManager::m_tankSpawning"
#define OFFSET_TANKCOUNT "m_iTankCount"

int  g_iTankSpawningOffs;
int  g_iTankCountOffs;
bool g_bIsReplaceInProgress;
bool g_bIsLeft4Dead2;
bool g_bTankSpawnCencalled;
int  g_iSpawnCount;

methodmap EventManager {
    public EventManager(Address ptr) {
        return view_as<EventManager>(ptr);
    }
    property bool m_tankSpawning {
        public get() {
            return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iTankSpawningOffs), NumberType_Int8);
        }
        public set(bool bVal) {
            StoreToAddress(view_as<Address>(this) + view_as<Address>(g_iTankSpawningOffs), bVal, NumberType_Int8);
        }
    }
};

methodmap CDirector {
    public CDirector(Address ptr) {
        return view_as<CDirector>(ptr);
    }
    property int m_iTankCount {
        public get() {
            return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iTankCountOffs), NumberType_Int32);
        }
        public set(int iVal) {
            StoreToAddress(view_as<Address>(this) + view_as<Address>(g_iTankCountOffs), iVal, NumberType_Int32);
        }
    }
};

CDirector TheDirector;

public Plugin myinfo =  {
    name        = "[L4D & 2] Scripted Tank Stage Fix",
    author      = "Forgetest",
    description = "Fix some issues of skipping stages regarding Tanks in finale.",
    version     = "2.1",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    switch (GetEngineVersion()) {
        case Engine_Left4Dead : g_bIsLeft4Dead2 = false;
        case Engine_Left4Dead2: g_bIsLeft4Dead2 = true;
        default: {
            strcopy(szError, iErrMax, "Plugin supports L4D & 2 only");
            return APLRes_SilentFailure;
        }
    }
    return APLRes_Success;
}

public void OnPluginStart() {
    GameData gmConf = new GameData(GAMEDATA_FILE);
    if (!gmConf) SetFailState("Missing gamedata \""...GAMEDATA_FILE..."\"");

    g_iTankCountOffs = gmConf.GetOffset(OFFSET_TANKCOUNT);
    if (g_iTankCountOffs == -1)
        SetFailState("Missing offset \""...OFFSET_TANKCOUNT..."\"");

    DynamicDetour hDetour = DynamicDetour.FromConf(gmConf, FUNCTION2_NAME);
    if (!hDetour)
        SetFailState("Missing detour setup \""...FUNCTION2_NAME..."\"");
    if (!hDetour.Enable(Hook_Pre, DTR_ReplaceTank) || !hDetour.Enable(Hook_Post, DTR_ReplaceTank_Post))
        SetFailState("Failed to detour \""...FUNCTION2_NAME..."\"");

    delete hDetour;

    if (g_bIsLeft4Dead2) {
        g_iTankSpawningOffs = gmConf.GetOffset(OFFSET_SPAWN);
        if (g_iTankSpawningOffs == -1)
            SetFailState("Missing offset \""...OFFSET_SPAWN..."\"");

        hDetour = DynamicDetour.FromConf(gmConf, FUNCTION_NAME);
        if (!hDetour)
            SetFailState("Missing detour setup \""...FUNCTION_NAME..."\"");
        if (!hDetour.Enable(Hook_Pre, DTR_UpdateScriptedTankStage) || !hDetour.Enable(Hook_Post, DTR_UpdateScriptedTankStage_Post))
            SetFailState("Failed to detour \""...FUNCTION_NAME..."\"");

        delete hDetour;
    }

    delete gmConf;

    HookEvent("round_start",        Event_RoundStart);
    HookEvent("player_bot_replace", Event_Player_BotReplace);
}

public void OnConfigsExecuted() {
    TheDirector = CDirector(L4D_GetPointer(POINTER_DIRECTOR));
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bIsReplaceInProgress = false;
}

MRESReturn DTR_ReplaceTank_Post(DHookReturn hReturn, DHookParam hParams) {
    if (hReturn.Value == 0)
        return MRES_Ignored;

    int iNewTank;
    if (!hParams.IsNull(2))
        iNewTank = hParams.Get(2);

    if (!iNewTank || !IsClientInGame(iNewTank))
        return MRES_Ignored;

    g_bIsReplaceInProgress = true;
    CreateTimer(0.1, Timer_ResetReplaceStatus, _, TIMER_FLAG_NO_MAPCHANGE);

    return MRES_Ignored;
}

void Event_Player_BotReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("bot"));
    if (iClient <= 0)
        return;

    if (GetClientTeam(iClient) != 3)
        return;

    if (GetEntProp(iClient, Prop_Send, "m_zombieClass") != (g_bIsLeft4Dead2 ? 8 : 5))
        return;

    g_bIsReplaceInProgress = true;
    CreateTimer(0.1, Timer_ResetReplaceStatus, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_ResetReplaceStatus(Handle hTimer) {
    g_bIsReplaceInProgress = false;
    return Plugin_Stop;
}

public void OnGameFrame() {
    if (!g_bIsReplaceInProgress)
        return;

    if (TheDirector.m_iTankCount == 0)
        TheDirector.m_iTankCount++;
}

public void L4D_OnSpawnTank_PostHandled(int iClient, const float vPos[3], const float vAng[3]) {
    g_bTankSpawnCencalled = true;
}

MRESReturn DTR_UpdateScriptedTankStage(Address pEventManager, DHookReturn hReturn, DHookParam hParams) {
    g_iSpawnCount = LoadFromAddress(hParams.Get(1), NumberType_Int32);
    g_bTankSpawnCencalled = false;
    return MRES_Ignored;
}

MRESReturn DTR_UpdateScriptedTankStage_Post(Address pEventManager, DHookReturn hReturn, DHookParam hParams) {
    EventManager evtMgr = EventManager(pEventManager);
    Address pCount = hParams.Get(1);

    int iCount = LoadFromAddress(pCount, NumberType_Int32);
    if (g_iSpawnCount == iCount + 1) {
        if (!evtMgr.m_tankSpawning && !g_bTankSpawnCencalled)
            StoreToAddress(pCount, g_iSpawnCount, NumberType_Int32);
        return MRES_Ignored;
    }

    return MRES_Ignored;
}

MRESReturn DTR_ReplaceTank(DHookReturn hReturn, DHookParam hParams) {
    int iTank, iNewTank;
    if (!hParams.IsNull(1))
        iTank = hParams.Get(1);
    if (!hParams.IsNull(2))
        iNewTank = hParams.Get(2);

    if (!iTank || !iNewTank || iTank != iNewTank)
        return MRES_Ignored;

    hReturn.Value = 0;
    return MRES_Supercede;
}