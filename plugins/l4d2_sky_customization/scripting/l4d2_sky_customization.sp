#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>
#include <l4d2util>
#include <l4d2lib>
#include <l4d2_penalty_bonus>
#include <left4dhooks>
#include <readyup>

#define HULK_DLC3 "models/infected/hulk_dlc3.mdl"
#define MAX_TEAM_INDEX 2

enum {
    eNone,
    eCoaster,
    eInterior,
    eTrainTunnel
}

StringMap
     g_smInfo;

bool g_bIsRoundLive;
bool g_bCorpseLootAnimationRunning[MAXPLAYERS + 1];

public Plugin myinfo = {
    name        = "Confogl Sky Customization Plugin",
    author      = "Visor, JaneDoe",
    description = "Everything Stripper can't do",
    version     = "2.0e",
    url         = "https://github.com/Attano"
}

public void OnPluginStart() {
    HookEvent("round_start",           Event_RoundStart,         EventHookMode_PostNoCopy);
    HookEvent("player_left_safe_area", Event_PlayerLeftSafeArea, EventHookMode_PostNoCopy);
    HookEvent("player_team",           Event_PlayerTeam,         EventHookMode_Post);
    HookEvent("tank_spawn",            Event_TankSpawn,          EventHookMode_Post);
    HookEvent("player_use",            Event_PlayerUse,          EventHookMode_Post);
    HookEvent("player_death",          Event_PlayerDeath,        EventHookMode_Post);
    HookEvent("player_bot_replace",    Event_PlayerBotReplace,   EventHookMode_Pre);
    HookEvent("weapon_drop",           Event_WeaponDrop,         EventHookMode_Pre);

    RegServerCmd("sm_add_canister_points", Cmd_AddPoints);
    RegServerCmd("sm_add_info_line",       Cmd_AddLine);

    g_smInfo = new StringMap();

    LoadTranslations("common.phrases");
    LoadTranslations("plugin.basecommands");
}

Action Cmd_AddPoints(int iArgs) {
    if (iArgs < 1)
        return Plugin_Handled;

    int iTeamIdx = TeamIndex();

    char szBuffer[16];
    GetCmdArg(1, szBuffer, sizeof(szBuffer));

    int iBonus = StringToInt(szBuffer);
    int iTotalPoints = ScavengeBonus(iTeamIdx) + iBonus;
    ScavengeBonus(iTeamIdx, true, iTotalPoints);
    PB_AddRoundBonus(iBonus);
    CPrintToChatAll("{blue}[{default}Scavenge Bonus{blue}]{default} Added {olive}%d{default} points.", iBonus);
    return Plugin_Handled;
}

Action Cmd_AddLine(int iArgs) {
    char szMapName[64];
    GetCmdArg(1, szMapName, sizeof(szMapName));

    char szBuffer[256];
    GetCmdArg(2, szBuffer, sizeof(szBuffer));

    g_smInfo.SetString(szMapName, szBuffer);
    return Plugin_Handled;
}

public void OnMapStart() {
    TrackingMap(true);

    LeverEventClient(true, -1);
    LeverEventEntity(true, -1);

    for (int i = 0; i < MAX_TEAM_INDEX; i++) {
        ScavengeBonus(i, true, 0);
    }

    ShouldReplaceTankModel(true);

    if (!IsModelPrecached(HULK_DLC3))
        PrecacheModel(HULK_DLC3);
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bIsRoundLive = false;
}

void Event_PlayerLeftSafeArea(Event eEvent, const char[] szName, bool bDontBroadcast) {
    OnRoundIsLive();
}

public void OnRoundIsLive() {
    if (g_bIsRoundLive)
        return;

    g_bIsRoundLive = true;

    char szMapName[64];
    GetCurrentMap(szMapName, sizeof(szMapName));

    char szBuffer[256];
    if (!g_smInfo.GetString(szMapName, szBuffer, sizeof(szBuffer)))
        return;

    CPrintToChatAll(szBuffer);
}

void Event_TankSpawn(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!ShouldReplaceTankModel())
        return;

    int iTank = eEvent.GetInt("tankid");
    SetEntityModel(iTank, HULK_DLC3);
}

public Action OnPlayerRunCmd(int iClient, int &iButtons) {
    if (TrackingMap() != eCoaster)
        return Plugin_Continue;

    if (iButtons & IN_ATTACK) {
        char szClsName[64];
        GetClientWeapon(iClient, szClsName, sizeof(szClsName));

        if (strcmp(szClsName, "weapon_pipe_bomb") == 0) {
            iButtons &= ~IN_ATTACK;
            PrintHintText(iClient, "Item cannot be used outside of its related event.");
        }
    }

    if (!(iButtons & IN_USE)) {
        if (g_bCorpseLootAnimationRunning[iClient]) {
            L4D2Direct_DoAnimationEvent(iClient, 20);
            g_bCorpseLootAnimationRunning[iClient] = false;
        }
    }

    return Plugin_Continue;
}

void Event_PlayerTeam(Event eEvent, char[] szName, bool bDontBroadcast) {
    if (TrackingMap() != eTrainTunnel)
        return;

    if (eEvent.GetInt("team") == 2)
        return;

    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));

    if (iClient <= 0)
        return;

    if (!IsClientInGame(iClient))
        return;

    char szTargetName[64];
    GetEntPropString(iClient, Prop_Data, "m_iName", szTargetName, sizeof(szTargetName));

    if (strcmp(szTargetName, "player_owner") != 0)
        return;

    ResetLeverEventStage(iClient, LeverEventEntity());
}

void Event_PlayerDeath(Event eEvent, char[] szName, bool bDontBroadcast) {
    if (TrackingMap() != eTrainTunnel)
        return;

    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)
        return;

    char szTargetName[64];
    GetEntPropString(iClient, Prop_Data, "m_iName", szTargetName, sizeof(szTargetName));

    if (strcmp(szTargetName, "player_owner") != 0)
        return;

    ResetLeverEventStage(iClient, LeverEventEntity());
}

void Event_PlayerUse(Event eEvent, const char[] szName, bool bDontBroadcast) {
    switch (TrackingMap()) {
        case eCoaster: {
            int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
            int iEnt    = eEvent.GetInt("targetid");

            char szTargetName[64];
            GetEntPropString(iEnt, Prop_Data, "m_iName", szTargetName, sizeof(szTargetName));

            if (strcmp(szTargetName, "sky_button_01") == 0) {
                if (IsValidEntity(GetPlayerWeaponSlot(iClient, 2)) && IsValidEntity(iEnt))
                    AcceptEntityInput(iEnt, "unlock");
            }

            if (strcmp(szTargetName, "sky_button_02") == 0) {
                L4D2Direct_DoAnimationEvent(iClient, 44);
                g_bCorpseLootAnimationRunning[iClient] = true;
            }
        }
        case eTrainTunnel: {
            int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
            int iEnt    = eEvent.GetInt("targetid");

            char szTargetName[64];
            GetEntPropString(iEnt, Prop_Data, "m_iName", szTargetName, sizeof(szTargetName));

            if (strcmp(szTargetName, "sky_train_lever_button") == 0) {
                int i;
                while ((i = FindEntityByClassname(i, "prop_dynamic")) != -1) {
                    GetEntPropString(i, Prop_Data, "m_iName", szTargetName, sizeof(szTargetName));
                    if (strcmp(szTargetName, "sky_train_button_model_a") == 0) {
                        LeverEventEntity(true, i);
                        break;
                    }
                }
                
                LeverEventClient(true, iClient);
            }

            if (strcmp(szTargetName, "sky_train_button") == 0) {
                GetEntPropString(iClient, Prop_Data, "m_iName", szTargetName, sizeof(szTargetName));
                if (strcmp(szTargetName, "player_owner") == 0 && IsValidEntity(iEnt))
                    AcceptEntityInput(iEnt, "unlock");
            }
        }
    }
}

void Event_WeaponDrop(Event eEvent, const char[] szName, bool bDontBroadcast) {
    switch (TrackingMap()) {
        case eCoaster: {
            int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
            int iWeapon = GetPlayerWeaponSlot(iClient, 2);

            if (!IsValidEntity(iWeapon))
                return;

            static int iColor[3] = {255, 102, 51};
            L4D2_SetEntityGlow(iWeapon, L4D2Glow_Constant, 0, 22, iColor, true);
            SDKHooks_DropWeapon(iClient, iWeapon);
        }
        case eInterior: {
            char szClsName[64];
            eEvent.GetString("item", szClsName, sizeof(szClsName));

            if (strcmp(szClsName, "cola_bottles") == 0) {
                static int iColor[3] = {220, 60, 120};
                L4D2_SetEntityGlow(eEvent.GetInt("propid"), L4D2Glow_Constant, 0, 22, iColor, true);
            }
        }
    }
}

void Event_PlayerBotReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    switch (TrackingMap()) {
        case eCoaster: {
            int iBot    = GetClientOfUserId(eEvent.GetInt("bot"));
            int iWeapon = GetPlayerWeaponSlot(iBot, 2);

            if (!IsValidEntity(iWeapon))
                return;

            static int iColor[3] = {255, 102, 51};
            L4D2_SetEntityGlow(iWeapon, L4D2Glow_Constant, 0, 22, iColor, true);
            SDKHooks_DropWeapon(iBot, iWeapon);
        }
        case eTrainTunnel: {
            int iPlayer = GetClientOfUserId(eEvent.GetInt("player"));
            if (iPlayer != LeverEventClient())
                return;

            ResetLeverEventStage(iPlayer, LeverEventEntity());
        }
    }
}

void ResetLeverEventStage(int iClient, int iEnt) {
    DispatchKeyValue(iClient, "targetname", "");

    if (IsValidEntity(iEnt)) {
        AcceptEntityInput(iEnt, "ClearParent");
        AcceptEntityInput(iEnt, "StartGlowing");
    }

    LeverEventClient(true, -1);
}

bool ShouldReplaceTankModel(bool bSet = false) {
    static bool bChange;

    if (bSet) {
        SetRandomSeed(GetTime());
        bChange = view_as<bool>(GetRandomInt(0, 1));
    }

    return bChange;
}

int ScavengeBonus(int iIdx, bool bSet = false, int iVal = 0) {
    static int iBonus[MAX_TEAM_INDEX];
    if (bSet)
        iBonus[iIdx] = iVal;
    return iBonus[iIdx];
}

int TrackingMap(bool bSet = false) {
    static char szMapName[64];
    GetCurrentMap(szMapName, sizeof(szMapName));

    static int iType;
    if (bSet) {
        iType = eNone;

        if (strcmp(szMapName, "c2m3_coaster") == 0)
            iType = eCoaster;

        if (strcmp(szMapName, "c8m4_interior") == 0)
            iType = eInterior;

        if (strcmp(szMapName, "c12m2_traintunnel") == 0)
            iType = eTrainTunnel;
    }

    return iType;
}

int TeamIndex() {
    return InSecondHalfOfRound() ? 1 : 0;
}

int LeverEventClient(bool bSet = false, int iVal = -1) {
    static int iClient = -1;
    if (bSet)
        iClient = iVal;
    return iClient;
}

int LeverEventEntity(bool bSet = false, int iVal = -1) {
    static int iEntity = -1;
    if (bSet)
        iEntity = iVal;
    return iEntity;
}