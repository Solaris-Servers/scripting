#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <colors>
#include <vip_core>
#include <l4d2_third_person_detect>

#define CONFIG_SPAWNS "data/l4d_hats.cfg"
#define MAX_HATS      128

// VIP
bool g_bVipAvailable;

// ConVars
ConVar g_cvChange;
float  g_fChange;
ConVar g_cvDetect;
float  g_fDetect;

Cookie g_cCookie;
int    g_iCount;

char   g_szNames [MAX_HATS][64];
char   g_szModels[MAX_HATS][64];
float  g_fPos    [MAX_HATS][3];
float  g_fAng    [MAX_HATS][3];
float  g_fSize   [MAX_HATS];

int    g_iHatIndex     [MAXPLAYERS + 1]; // Player hat entity reference
int    g_iHatWalls     [MAXPLAYERS + 1]; // Hidden hat entity reference
int    g_iType         [MAXPLAYERS + 1]; // Stores selected hat to give players
bool   g_bExternalCvar [MAXPLAYERS + 1]; // If thirdperson view was detected (thirdperson_shoulder cvar)
bool   g_bExternalProp [MAXPLAYERS + 1]; // If thirdperson view was detected (netprop or revive actions)
bool   g_bExternalState[MAXPLAYERS + 1]; // If thirdperson view was detected
Handle g_hTimerView    [MAXPLAYERS + 1]; // Thirdperson view when selecting hat

Handle g_hTimerDetect;

// ====================================================================================================
//                  PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo = {
    name        = "[VIP] HATS",
    author      = "SilverShot",
    description = "Attaches specified models to players above their head.",
    version     = "1.44",
    url         = "https://forums.alliedmods.net/showthread.php?t=153781"
}

public void OnPluginStart() {
    // Load config
    KeyValues kvFile = OpenConfig();
    char szTemp[64];
    for (int i = 0; i < MAX_HATS; i++) {
        IntToString(i + 1, szTemp, sizeof(szTemp));
        if (kvFile.JumpToKey(szTemp)) {
            kvFile.GetString("mod", szTemp, sizeof(szTemp));
            TrimString(szTemp);
            if (szTemp[0] == 0)
                break;
            if (FileExists(szTemp, true)) {
                kvFile.GetVector("ang", g_fAng[i]);
                kvFile.GetVector("loc", g_fPos[i]);
                g_fSize[i] = kvFile.GetFloat("size", 1.0);
                g_iCount++;
                strcopy(g_szModels[i], sizeof(g_szModels[]), szTemp);
                kvFile.GetString("name", g_szNames[i], sizeof(g_szNames[]));
                if (strlen(g_szNames[i]) == 0)
                    GetHatName(g_szNames[i], i);
            } else {
                LogError("Cannot find the model '%s'", szTemp);
            }
            kvFile.Rewind();
        }
    }
    delete kvFile;
    if (g_iCount == 0) SetFailState("No models found!");

    // Cvars
    g_cvChange = CreateConVar(
    "l4d_hats_change", "1.3",
    "0=Off. Other value puts the player into thirdperson for this many seconds when selecting a hat.",
    FCVAR_NOTIFY, true, 0.0, true, 5.0);
    g_fChange = g_cvChange.FloatValue;
    g_cvChange.AddChangeHook(ConVarChanged_Cvars);

    g_cvDetect = CreateConVar(
    "l4d_hats_detect", "0.3",
    "0.0=Off. How often to detect thirdperson view. Also uses ThirdPersonShoulder_Detect plugin if available.",
    FCVAR_NOTIFY, true, 0.0, true, 5.0);
    g_fDetect = g_cvDetect.FloatValue;
    g_cvDetect.AddChangeHook(ConVarChanged_Cvars);

    HookViewEvents();
    HookEvents();

    g_cCookie = new Cookie("l4d_hats", "Hat Type", CookieAccess_Private);

    if (VIP_IsVIPLoaded()) VIP_OnVIPLoaded();
}

public void VIP_OnVIPLoaded() {
    VIP_RegisterFeature("HATS", BOOL, SELECTABLE, OnSelectItem);
}

public void OnPluginEnd() {
    for (int i = 1; i <= MaxClients; i++) {
        RemoveHat(i);
    }
    if (g_bVipAvailable) VIP_UnregisterMe();
}

public void OnAllPluginsLoaded() {
    g_bVipAvailable = LibraryExists("vip_core");
}

public void OnLibraryAdded(const char[] szName) {
    if (strcmp(szName, "vip_core") != 0) return;
    g_bVipAvailable = true;
}

public void OnLibraryRemoved(const char[] szName) {
    if (strcmp(szName, "vip_core") != 0) return;
    g_bVipAvailable = false;
}

public bool OnSelectItem(int iClient, const char[] szFeatureName) {
    ShowMenu(iClient);
    return false;
}

// ====================================================================================================
//                  CVARS
// ====================================================================================================
void ConVarChanged_Cvars(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fChange = g_cvChange.FloatValue;
    g_fDetect = g_cvDetect.FloatValue;
}

// ====================================================================================================
//                  OTHER BITS
// ====================================================================================================
public void OnMapStart() {
    for (int i = 0; i < g_iCount; i++)
        PrecacheModel(g_szModels[i]);
    RequestFrame(OnFramePrecache);
}

void OnFramePrecache() {
    int iEntity;
    for (int i = 0; i < g_iCount; i++) {
        iEntity = CreateEntityByName("prop_dynamic");
        SetEntityModel(iEntity, g_szModels[i]);
        DispatchSpawn(iEntity);
        RemoveEdict(iEntity);
    }
}

public void VIP_OnVIPClientLoaded(int iClient) {
    if (VIP_GetClientFeatureStatus(iClient, "HATS") != NO_ACCESS) {
        char szCookie[4];
        g_cCookie.Get(iClient, szCookie, sizeof(szCookie));
        if (!szCookie[0]) {
            g_iType[iClient] = 0;
        } else {
            int iType = StringToInt(szCookie);
            g_iType[iClient] = iType;
        }
    } else {
        g_iType[iClient] = 0;
        g_cCookie.Set(iClient, "0");
    }
}

public void VIP_OnVIPClientRemoved(int iClient, const char[] szReason, int iAdmin) {
    RemoveHat(iClient);
}

public void OnClientDisconnect(int iClient) {
    delete g_hTimerView[iClient];
}

KeyValues OpenConfig() {
    char szPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, szPath, sizeof(szPath), CONFIG_SPAWNS);
    if (!FileExists(szPath))
        SetFailState("Cannot find the file: \"%s\"", CONFIG_SPAWNS);
    KeyValues kvFile = new KeyValues("models");
    if (!kvFile.ImportFromFile(szPath)) {
        delete kvFile;
        SetFailState("Cannot load the file: \"%s\"", CONFIG_SPAWNS);
    }
    return kvFile;
}

void GetHatName(char szTemp[64], int iIndex) {
    strcopy(szTemp, sizeof(szTemp), g_szModels[iIndex]);
    ReplaceString(szTemp, sizeof(szTemp), "_", " ");
    int iPos = FindCharInString(szTemp, '/', true) + 1;
    int iLen = strlen(szTemp) - iPos - 3;
    strcopy(szTemp, iLen, szTemp[iPos]);
}

bool IsValidClient(int iClient) {
    if (iClient && IsClientInGame(iClient) && GetClientTeam(iClient) == 2 && IsPlayerAlive(iClient))
        return true;
    return false;
}

// ====================================================================================================
//                  EVENTS
// ====================================================================================================
void HookEvents() {
    HookEvent("round_start",  Event_Start);
    HookEvent("round_end",    Event_RoundEnd);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_team",  Event_PlayerTeam);
}

void HookViewEvents() {
    HookEvent("revive_success",       Event_First2);
    HookEvent("player_ledge_grab",    Event_Third1);
    HookEvent("lunge_pounce",         Event_Third2);
    HookEvent("pounce_end",           Event_First1);
    HookEvent("tongue_grab",          Event_Third2);
    HookEvent("tongue_release",       Event_First1);
    HookEvent("charger_pummel_start", Event_Third2);
    HookEvent("charger_carry_start",  Event_Third2);
    HookEvent("charger_carry_end",    Event_First1);
    HookEvent("charger_pummel_end",   Event_First1);
}

void Event_Start(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (g_fDetect) {
        delete g_hTimerDetect;
        g_hTimerDetect = CreateTimer(g_fDetect, TimerDetect, _, TIMER_REPEAT);
    }
}

void Event_RoundEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    for (int i = 1; i <= MaxClients; i++)
        RemoveHat(i);
}

void Event_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (!iClient || GetClientTeam(iClient) != 2)
        return;
    RemoveHat(iClient);
    SpectatorHatHooks();
}

void Event_PlayerSpawn(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClientID = eEvent.GetInt("userid");
    int iClient   = GetClientOfUserId(iClientID);
    if (iClient) {
        RemoveHat(iClient);
        CreateTimer(0.5, TimerDelayCreate, iClientID);
    }
    SpectatorHatHooks();
}

void Event_PlayerTeam(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClientID = eEvent.GetInt("userid");
    int iClient   = GetClientOfUserId(iClientID);
    RemoveHat(iClient);
    SpectatorHatHooks();
    CreateTimer(0.1, TimerDelayCreate, iClientID);
}

void Event_First1(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("victim"));
    EventView(iClient, false);
}

void Event_First2(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("subject"));
    EventView(iClient, false);
}

void Event_Third1(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    EventView(iClient, true);
}

void Event_Third2(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("victim"));
    EventView(iClient, true);
}

void EventView(int iClient, bool bIsThirdPerson) {
    if (IsValidClient(iClient))
        SetHatView(iClient, g_bExternalCvar[iClient] ? true : bIsThirdPerson);
}

Action TimerDelayCreate(Handle timer, any iUserId) {
    int iClient = GetClientOfUserId(iUserId);
    if (IsValidClient(iClient) && !IsFakeClient(iClient)) {
        if (!VIP_IsClientVIP(iClient) || !VIP_IsClientFeatureUse(iClient, "HATS"))
            return Plugin_Continue;
        CreateHat(iClient, -1);
        RequestFrame(OnSetHatView, iUserId);
    }
    return Plugin_Continue;
}

void OnSetHatView(any iUserId) {
    int iClient = GetClientOfUserId(iUserId);
    if (IsValidClient(iClient)) SetHatView(iClient, g_bExternalCvar[iClient] ? true : false);
}

// Show hat when thirdperson view
Action TimerDetect(Handle hTimer) {
    for (int i = 1; i <= MaxClients; i++) {
        if (!g_bExternalCvar[i] && g_iHatIndex[i] && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i)) {
            if ((GetEntPropFloat(i, Prop_Send, "m_TimeForceExternalView") > GetGameTime()) || GetEntPropEnt(i, Prop_Send, "m_reviveTarget") != -1) {
                if (!g_bExternalProp[i]) {
                    g_bExternalProp[i] = true;
                    SetHatView(i, true);
                }
            } else if (g_bExternalProp[i]) {
                g_bExternalProp[i] = false;
                SetHatView(i, false);
            }
        }
    }
    return Plugin_Continue;
}

public void TP_OnThirdPersonChanged(int iClient, bool bIsThirdPerson) {
    if (g_fDetect) {
        if (bIsThirdPerson && !g_bExternalCvar[iClient]) {
            g_bExternalCvar[iClient] = true;
            SetHatView(iClient, true);
        } else if (!bIsThirdPerson && g_bExternalCvar[iClient]) {
            g_bExternalCvar[iClient] = false;
            SetHatView(iClient, false);
        }
    }
}

void SetHatView(int iClient, bool bIsThirdPerson) {
    if (bIsThirdPerson && !g_bExternalState[iClient]) {
        g_bExternalState[iClient] = true;
        int iEntity = g_iHatIndex[iClient];
        if (iEntity && (iEntity = EntRefToEntIndex(iEntity)) != INVALID_ENT_REFERENCE)
            SDKUnhook(iEntity, SDKHook_SetTransmit, Hook_SetTransmit);
    } else if (!bIsThirdPerson && g_bExternalState[iClient]) {
        g_bExternalState[iClient] = false;
        int iEntity = g_iHatIndex[iClient];
        if (iEntity && (iEntity = EntRefToEntIndex(iEntity)) != INVALID_ENT_REFERENCE)
            SDKHook(iEntity, SDKHook_SetTransmit, Hook_SetTransmit);
    }
}

// ====================================================================================================
//                  BLOCK HATS - WHEN SPECTATING IN 1ST PERSON VIEW
// ====================================================================================================
// Loop through hats, find valid ones, loop through for each client and add transmit hook for spectators
// Could be better instead of unhooking and hooking everyone each time, but quick and dirty addition...
void SpectatorHatHooks() {
    for (int i = 1; i <= MaxClients; i++ ) {
        if (IsValidEntRef(g_iHatIndex[i])) {
            for (int j = 1; j <= MaxClients; j++) {
                if (IsClientInGame(j)) {
                    SDKUnhook(g_iHatIndex[i], SDKHook_SetTransmit, Hook_SetSpecTransmit);
                    if (!IsPlayerAlive(j)) {
                        // Must hook 1 frame later because SDKUnhook first and then SDKHook doesn't work, it won't be hooked for some reason.
                        DataPack dPack = new DataPack();
                        dPack.WriteCell(GetClientUserId(j));
                        dPack.WriteCell(i);
                        RequestFrame(OnFrameHooks, dPack);
                    }
                }
            }
        }
    }
}

void OnFrameHooks(DataPack dPack) {
    dPack.Reset();
    int iClient = GetClientOfUserId(dPack.ReadCell());
    if (iClient && IsClientInGame(iClient) && !IsPlayerAlive(iClient)) {
        int iIndex = dPack.ReadCell();
        SDKHook(EntRefToEntIndex(g_iHatIndex[iIndex]), SDKHook_SetTransmit, Hook_SetSpecTransmit);
    }
    delete dPack;
}

Action Hook_SetSpecTransmit(int iEntity, int iClient) {
    if (!IsPlayerAlive(iClient) && GetEntProp(iClient, Prop_Send, "m_iObserverMode") == 4) {
        int iTarget = GetEntPropEnt(iClient, Prop_Send, "m_hObserverTarget");
        if (iTarget > 0 && iTarget <= MaxClients  && g_iHatIndex[iTarget] == EntIndexToEntRef(iEntity))
            return Plugin_Handled;
    }
    return Plugin_Continue;
}

// ====================================================================================================
//                  HAT MENU
// ====================================================================================================
void ShowMenu(int iClient, int iMenuPos = 0) {
    Menu mMenu = new Menu(HatMenuHandler);
    char szCurrentHat[64];
    Format(szCurrentHat, sizeof(szCurrentHat), "%s", g_iType[iClient] == 0 ? "None" : g_szNames[g_iType[iClient] - 1]);
    mMenu.SetTitle("Hat Selection\nYour current Hat: %s\n ", szCurrentHat);
    mMenu.AddItem("Off", "Disable Hat\n ", g_iType[iClient] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    for (int i = 0; i < g_iCount; i++) {
        mMenu.AddItem(g_szModels[i], g_szNames[i], (i == (g_iType[iClient] - 1)) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
    }
    mMenu.ExitBackButton = true;
    mMenu.ExitButton     = true;
    mMenu.DisplayAt(iClient, iMenuPos, MENU_TIME_FOREVER);
}

int HatMenuHandler(Menu mMenu, MenuAction maAction, int iClient, int iParam2) {
    if (maAction == MenuAction_End) {
        delete mMenu;
    } else if (maAction == MenuAction_Select) {
        RemoveHat(iClient);
        if (iParam2 == 0) {
            g_cCookie.Set(iClient, "0");
            g_iType[iClient] = 0;
            CPrintToChat(iClient, "{green}[{default}Hats{green}]{default} Your hat was disabled!");
        } else if (CreateHat(iClient, iParam2 - 1)) {
            ExternalView(iClient);
        }
        int iMenuPos = mMenu.Selection;
        ShowMenu(iClient, iMenuPos);
    } else if (maAction == MenuAction_Cancel) {
        if (iParam2 == MenuCancel_ExitBack)
            VIP_SendClientVIPMenu(iClient);
    }
    return 0;
}

// ====================================================================================================
//                  HAT STUFF
// ===================================================================================================
void RemoveHat(int iClient) {
    // Hat entity
    int iEntity = g_iHatIndex[iClient];
    g_iHatIndex[iClient] = 0;
    if (IsValidEntRef(iEntity))
        RemoveEntity(iEntity);
    // Hidden entity
    iEntity = g_iHatWalls[iClient];
    g_iHatWalls[iClient] = 0;
    if (IsValidEntRef(iEntity))
        RemoveEntity(iEntity);
}

bool CreateHat(int iClient, int iIndex = -1) {
    if (IsValidEntRef(g_iHatIndex[iClient]) || !IsValidClient(iClient))
        return false;
    // Saved hats
    if (iIndex == -1) {
        if (!g_iType[iClient])
            return false;
        iIndex = g_iType[iClient] - 1;
    } else {
        // Specified hat
        g_iType[iClient] = iIndex + 1;
    }
    if (!IsFakeClient(iClient)) {
        char szNum[4];
        IntToString(iIndex + 1, szNum, sizeof(szNum));
        g_cCookie.Set(iClient, szNum);
    }
    // Fix showing glow through walls, break glow inheritance by attaching hats to info_target.
    // Method by "Marttt": https://forums.alliedmods.net/showpost.php?p=2737781&postcount=21
    int iTarget = CreateEntityByName("info_target");
    DispatchSpawn(iTarget);
    int iEntity = CreateEntityByName("prop_dynamic_override");
    if (iEntity != -1) {
        SetEntityModel(iEntity, g_szModels[iIndex]);
        DispatchSpawn(iEntity);
        SetEntPropFloat(iEntity, Prop_Send, "m_flModelScale", g_fSize[iIndex]);
        SetVariantString("!activator");
        AcceptEntityInput(iEntity, "SetParent", iTarget);
        TeleportEntity(iTarget, g_fPos[iIndex], NULL_VECTOR, NULL_VECTOR);
        SetVariantString("!activator");
        AcceptEntityInput(iTarget, "SetParent", iClient);
        SetVariantString("eyes");
        AcceptEntityInput(iTarget, "SetParentAttachment");
        TeleportEntity(iTarget, g_fPos[iIndex], NULL_VECTOR, NULL_VECTOR);
        g_iHatWalls[iClient] = EntIndexToEntRef(iTarget);
        // Lux
        AcceptEntityInput(iEntity, "DisableCollision");
        SetEntProp(iEntity, Prop_Send, "m_noGhostCollision", 1, 1);
        SetEntProp(iEntity, Prop_Data, "m_CollisionGroup", 0x0004);
        SetEntPropVector(iEntity, Prop_Send, "m_vecMins", view_as<float>({0.0, 0.0, 0.0}));
        SetEntPropVector(iEntity, Prop_Send, "m_vecMaxs", view_as<float>({0.0, 0.0, 0.0}));
        // Lux
        TeleportEntity(iTarget, g_fPos[iIndex], g_fAng[iIndex], NULL_VECTOR);
        SetEntProp(iEntity, Prop_Data, "m_iEFlags", 0);
        SetEntityRenderMode(iEntity, RENDER_TRANSCOLOR);
        SetEntityRenderColor(iEntity, 255, 255, 255, 255);
        g_iHatIndex[iClient] = EntIndexToEntRef(iEntity);
        SDKHook(iEntity, SDKHook_SetTransmit, Hook_SetTransmit);
        SpectatorHatHooks();
        return true;
    }
    return false;
}

void ExternalView(int iClient) {
    if (g_fChange) {
        g_bExternalState[iClient] = false;
        EventView(iClient, true);
        delete g_hTimerView[iClient];
        g_hTimerView[iClient] = CreateTimer(g_fChange + (g_fChange >= 2.0 ? 0.4 : 0.2), TimerEventView, GetClientUserId(iClient));
        SetEntPropFloat(iClient, Prop_Send, "m_TimeForceExternalView", GetGameTime() + g_fChange);
    }
}

Action TimerEventView(Handle hTimer, any iClient) {
    iClient = GetClientOfUserId(iClient);
    if (iClient) {
        EventView(iClient, false);
        g_hTimerView[iClient] = null;
    }
    return Plugin_Continue;
}

Action Hook_SetTransmit(int iEntity, int iClient) {
    if (EntIndexToEntRef(iEntity) == g_iHatIndex[iClient])
        return Plugin_Handled;
    return Plugin_Continue;
}

bool IsValidEntRef(int iEntity) {
    if (iEntity && EntRefToEntIndex(iEntity) != INVALID_ENT_REFERENCE)
        return true;
    return false;
}