#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <dhooks>

#undef REQUIRE_PLUGIN
#include <l4d2_hittable_control>
#define REQUIRE_PLUGIN

#define Z_TANK          8
#define TEAM_INFECTED   3
#define TEAM_SPECTATOR  1

#define MAX_EDICTS 2048 // (1 << 11)

ConVar g_cvTankPropFade;

ConVar g_cvTankPropsGlow;
bool   g_bTankPropsGlow;

ConVar g_cvRange;
int    g_iRange;

ConVar g_cvRangeMin;
int    g_iRangeMin;

ConVar g_cvColor;
int    g_iColor;

ConVar g_cvTankOnly;
bool   g_bTankOnly;

ConVar g_cvTankSpec;
bool   g_bTankSpec;

ConVar g_cvTankPropsBeGone;
float  g_fTankPropsBeGone;

ArrayList g_arrTankProps;
ArrayList g_arrTankPropsHit;

int g_iEntityList[MAX_EDICTS] = {-1, ...};
int g_iTankClient = -1;

bool g_bTankSpawned;
bool g_bHittableControlExists;

public Plugin myinfo = {
    name        = "L4D2 Tank Hittable Glow",
    author      = "Harry Potter, Sir, A1m`, Derpduck",
    version     = "2.5",
    description = "Stop tank props from fading whilst the tank is alive + add Hittable Glow.",
    url         = "https://forums.alliedmods.net/showthread.php?t=312447"
};

public void OnPluginStart() {
    g_cvTankPropFade = FindConVar("sv_tankpropfade");

    g_cvTankPropsGlow = CreateConVar(
    "l4d_tank_props_glow", "1",
    "Show Hittable Glow for infected team while the tank is alive",
    FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvTankPropsGlow.AddChangeHook(ConVarChanged_Allow);

    g_cvColor = CreateConVar(
    "l4d2_tank_prop_glow_color", "255 255 255",
    "Prop Glow Color, three values between 0-255 separated by spaces. RGB Color255 - Red Green Blue.",
    FCVAR_NOTIFY, false, 0.0, false, 0.0);
    g_cvColor.AddChangeHook(ConVarChanged_Glow);

    g_cvRange = CreateConVar(
    "l4d2_tank_prop_glow_range", "4500",
    "How near to props do players need to be to enable their glow.",
    FCVAR_NOTIFY, true, 0.0, false, 0.0);
    g_cvRange.AddChangeHook(ConVarChanged_Range);

    g_cvRangeMin = CreateConVar(
    "l4d2_tank_prop_glow_range_min", "256",
    "How near to props do players need to be to disable their glow.",
    FCVAR_NOTIFY, true, 0.0, false, 0.0);
    g_cvRangeMin.AddChangeHook(ConVarChanged_RangeMin);

    g_cvTankOnly = CreateConVar(
    "l4d2_tank_prop_glow_only", "0",
    "Only Tank can see the glow",
    FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvTankOnly.AddChangeHook(ConVarChanged_Cvars);

    g_cvTankSpec = CreateConVar(
    "l4d2_tank_prop_glow_spectators", "1",
    "Spectators can see the glow too",
    FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvTankSpec.AddChangeHook(ConVarChanged_Cvars);

    g_cvTankPropsBeGone = CreateConVar(
    "l4d2_tank_prop_dissapear_time", "10.0",
    "Time it takes for hittables that were punched by Tank to dissapear after the Tank dies.",
    FCVAR_NOTIFY, true, 0.0, false, 0.0);
    g_cvTankPropsBeGone.AddChangeHook(ConVarChanged_Cvars);

    GetCvars();

    PluginEnable();
}

void PluginEnable() {
    g_cvTankPropFade.SetBool(false);

    g_arrTankProps    = new ArrayList();
    g_arrTankPropsHit = new ArrayList();

    HookEvent("round_start",  Event_RoundStart,  EventHookMode_PostNoCopy);
    HookEvent("tank_spawn",   Event_TankSpawn,   EventHookMode_PostNoCopy);
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_PostNoCopy);
    HookEvent("player_team",  Event_PlayerTeam,  EventHookMode_PostNoCopy);

    char szColor[16];
    g_cvColor.GetString(szColor, sizeof(szColor));

    g_iColor    = GetColor(szColor);
    g_iRange    = g_cvRange.IntValue;
    g_iRangeMin = g_cvRangeMin.IntValue;
    g_bTankOnly = g_cvTankOnly.BoolValue;
}

void PluginDisable() {
    g_cvTankPropFade.SetBool(true);

    UnhookEvent("round_start",  Event_RoundStart,  EventHookMode_PostNoCopy);
    UnhookEvent("tank_spawn",   Event_TankSpawn,   EventHookMode_PostNoCopy);
    UnhookEvent("player_death", Event_PlayerDeath, EventHookMode_PostNoCopy);
    UnhookEvent("player_team",  Event_PlayerTeam,  EventHookMode_PostNoCopy);

    if (!g_bTankSpawned) return;

    int iRef  = INVALID_ENT_REFERENCE;
    int iEnt  = -1;
    int iSize = g_arrTankPropsHit.Length;

    for (int i = 0; i < iSize; i++) {
        iEnt = g_arrTankPropsHit.Get(i);
        if (IsValidEntity(iEnt)) {
            iRef = g_iEntityList[iEnt];
            if (IsValidEntRef(iRef)) RemoveEntity(iRef);
        }
    }

    g_bTankSpawned = false;

    delete g_arrTankProps;
    delete g_arrTankPropsHit;
}

public void OnAllPluginsLoaded() {
    g_bHittableControlExists = LibraryExists("l4d2_hittable_control");
}

public void OnLibraryAdded(const char[] name) {
    if (strcmp(name, "l4d2_hittable_control") == 0)
        g_bHittableControlExists = true;
}

public void OnLibraryRemoved(const char[] name) {
    if (strcmp(name, "l4d2_hittable_control") == 0)
        g_bHittableControlExists = false;
}

void ConVarChanged_Cvars(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    GetCvars();
}

void GetCvars() {
    g_bTankOnly        = g_cvTankOnly.BoolValue;
    g_bTankSpec        = g_cvTankSpec.BoolValue;
    g_iRange           = g_cvRange.IntValue;
    g_iRangeMin        = g_cvRangeMin.IntValue;
    g_fTankPropsBeGone = g_cvTankPropsBeGone.FloatValue;

    char szColor[16];
    g_cvColor.GetString(szColor, sizeof(szColor));
    g_iColor = GetColor(szColor);
}

void ConVarChanged_Allow(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    if (g_bTankPropsGlow) PluginEnable();
    else                  PluginDisable();
}

void ConVarChanged_Glow(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    GetCvars();

    if (!g_bTankSpawned) return;

    int iRef   = INVALID_ENT_REFERENCE;
    int iValue = 0;
    int iSize  = g_arrTankPropsHit.Length;

    for (int i = 0; i < iSize; i++) {
        iValue = g_arrTankPropsHit.Get(i);
        if (iValue > 0 && IsValidEdict(iValue)) {
            iRef = g_iEntityList[iValue];
            if (IsValidEntRef(iRef)) {
                SetEntProp(iRef, Prop_Send, "m_iGlowType", 3);
                SetEntProp(iRef, Prop_Send, "m_glowColorOverride", g_iColor);
            }
        }
    }
}

void ConVarChanged_Range(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    GetCvars();

    if (!g_bTankSpawned) return;

    int iRef   = INVALID_ENT_REFERENCE;
    int iValue = 0;
    int iSize  = g_arrTankPropsHit.Length;

    for (int i = 0; i < iSize; i++) {
        iValue = g_arrTankPropsHit.Get(i);
        if (iValue > 0 && IsValidEdict(iValue)) {
            iRef = g_iEntityList[iValue];
            if (IsValidEntRef(iRef)) {
                SetEntProp(iRef, Prop_Send, "m_nGlowRange", g_iRange);
            }
        }
    }
}

void ConVarChanged_RangeMin(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    GetCvars();

    if (!g_bTankSpawned) return;

    int iRef   = INVALID_ENT_REFERENCE;
    int iValue = 0;
    int iSize  = g_arrTankPropsHit.Length;
    
    for (int i = 0; i < iSize; i++) {
        iValue = g_arrTankPropsHit.Get(i);
        if (iValue > 0 && IsValidEdict(iValue)) {
            iRef = g_iEntityList[iValue];
            if (IsValidEntRef(iRef)) {
                SetEntProp(iRef, Prop_Send, "m_nGlowRangeMin", g_iRangeMin);
            }
        }
    }
}

public void OnMapEnd() {
    DHookRemoveEntityListener(ListenType_Created, PossibleTankPropCreated);
    g_arrTankProps.Clear();
    g_arrTankPropsHit.Clear();
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    DHookRemoveEntityListener(ListenType_Created, PossibleTankPropCreated);
    g_bTankSpawned = false;
    UnhookTankProps();
    g_arrTankPropsHit.Clear();
}

void Event_TankSpawn(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (g_bTankSpawned) return;
    UnhookTankProps();
    g_arrTankPropsHit.Clear();
    HookTankProps();
    DHookAddEntityListener(ListenType_Created, PossibleTankPropCreated);
    g_bTankSpawned = true;
}

void Event_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (g_bTankSpawned) CreateTimer(0.5, TankDeadCheck, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action TankDeadCheck(Handle hTimer) {
    if (GetTankClient() == -1) {
        CreateTimer(g_fTankPropsBeGone, TankPropsBeGone, _, TIMER_FLAG_NO_MAPCHANGE);
        DHookRemoveEntityListener(ListenType_Created, PossibleTankPropCreated);
        g_bTankSpawned = false;
    }
    return Plugin_Stop;
}

Action TankPropsBeGone(Handle hTimer) {
    UnhookTankProps();
    return Plugin_Stop;
}

void Event_PlayerTeam(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!g_bTankSpawned) return;

    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)             return;
    if (!IsClientInGame(iClient)) return;
    if (IsFakeClient(iClient))    return;

    // Reproduce glows to clear vision of transferred players
    RequestFrame(KillClones);
    RequestFrame(RecreateHittableClones);
}

void KillClones() {
    int iRef  = INVALID_ENT_REFERENCE;
    int iEnt  = -1;
    int iSize = g_arrTankPropsHit.Length;

    for (int i = 0; i < iSize; i++) {
        iEnt = g_arrTankPropsHit.Get(i);
        if (IsValidEntity(iEnt)) {
            iRef = g_iEntityList[g_arrTankPropsHit.Get(i)];
            if (IsValidEntRef(iRef)) RemoveEntity(iRef);
        }
    }
}

void RecreateHittableClones() {
    int iEnt  = -1;
    int iSize = g_arrTankPropsHit.Length;

    for (int i = 0; i < iSize; i++) {
        iEnt = g_arrTankPropsHit.Get(i);
        if (IsValidEntity(iEnt)) CreateTankPropGlow(iEnt);
    }
}

void PropDamaged(int iVictim, int iAttacker, int iInflictor, float fDamage, int iDamageType) {
    if (IsValidAliveTank(iAttacker) || g_arrTankPropsHit.FindValue(iInflictor) != -1) {
        if (g_arrTankPropsHit.FindValue(iVictim) == -1) {
            g_arrTankPropsHit.Push(iVictim);
            CreateTankPropGlow(iVictim);
        }
    }
}

void CreateTankPropGlow(int iTarget) {
    // Spawn dynamic prop entity
    int iEnt = CreateEntityByName("prop_dynamic_override");
    if (iEnt == -1) return;

    // Get position of hittable
    float vOrigin[3];
    GetEntPropVector(iTarget, Prop_Send, "m_vecOrigin", vOrigin);
    float vAngles[3];
    GetEntPropVector(iTarget, Prop_Data, "m_angRotation", vAngles);

    // Get Client Model
    char szModelName[PLATFORM_MAX_PATH];
    GetEntPropString(iTarget, Prop_Data, "m_ModelName", szModelName, sizeof(szModelName));

    // Set new fake model
    SetEntityModel(iEnt, szModelName);
    DispatchSpawn(iEnt);

    // Set outline glow color
    SetEntProp(iEnt, Prop_Send, "m_CollisionGroup", 0);
    SetEntProp(iEnt, Prop_Send, "m_nSolidType", 0);
    SetEntProp(iEnt, Prop_Send, "m_nGlowRange", g_iRange);
    SetEntProp(iEnt, Prop_Send, "m_nGlowRangeMin", g_iRangeMin);
    SetEntProp(iEnt, Prop_Send, "m_iGlowType", 2);
    SetEntProp(iEnt, Prop_Send, "m_glowColorOverride", g_iColor);
    AcceptEntityInput(iEnt, "StartGlowing");

    // Set model invisible
    SetEntityRenderMode(iEnt, RENDER_NONE);
    SetEntityRenderColor(iEnt, 0, 0, 0, 0);

    // Set model to hittable position
    TeleportEntity(iEnt, vOrigin, vAngles, NULL_VECTOR);

    // Set model attach to client, and always synchronize
    SetVariantString("!activator");
    AcceptEntityInput(iEnt, "SetParent", iTarget);

    SDKHook(iEnt, SDKHook_SetTransmit, OnTransmit);
    g_iEntityList[iTarget] = EntIndexToEntRef(iEnt);
}

Action OnTransmit(int iEnt, int iClient) {
    switch (GetClientTeam(iClient)) {
        case TEAM_INFECTED: {
            if (!g_bTankOnly) {
                return Plugin_Continue;
            }
            if (IsTank(iClient)) {
                return Plugin_Continue;
            }
            return Plugin_Handled;
        }
        case TEAM_SPECTATOR: {
            return (g_bTankSpec) ? Plugin_Continue : Plugin_Handled;
        }
    }
    return Plugin_Handled;
}

bool IsTankProp(int iEnt) {
    if (!IsValidEdict(iEnt))
        return false;
    // CPhysicsProp only
    if (!HasEntProp(iEnt, Prop_Send, "m_hasTankGlow"))
        return false;
    bool bHasTankGlow = (GetEntProp(iEnt, Prop_Send, "m_hasTankGlow", 1) == 1);
    if (!bHasTankGlow)
        return false;
    // Exception
    bool bAreForkliftsUnbreakable;
    if (g_bHittableControlExists) {
        bAreForkliftsUnbreakable = L4D2_AreForkliftsUnbreakable();
    } else {
        bAreForkliftsUnbreakable = false;
    }
    char sModel[PLATFORM_MAX_PATH];
    GetEntPropString(iEnt, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
    if (strcmp("models/props/cs_assault/forklift.mdl", sModel) == 0 && !bAreForkliftsUnbreakable) {
        return false;
    }
    return true;
}

void HookTankProps() {
    int iEntCount = GetMaxEntities();
    for (int i = MaxClients; i < iEntCount; i++) {
        if (IsTankProp(i)) {
            SDKHook(i, SDKHook_OnTakeDamagePost, PropDamaged);
            g_arrTankProps.Push(i);
        }
    }
}

void UnhookTankProps() {
    int iValue = 0;
    int iSize  = g_arrTankProps.Length;
    for (int i = 0; i < iSize; i++) {
        iValue = g_arrTankProps.Get(i);
        SDKUnhook(iValue, SDKHook_OnTakeDamagePost, PropDamaged);
    }
    iValue = 0;
    iSize  = g_arrTankPropsHit.Length;
    for (int i = 0; i < iSize; i++) {
        iValue = g_arrTankPropsHit.Get(i);
        if (iValue > 0 && IsValidEdict(iValue)) {
            RemoveEntity(iValue);
        }
    }
    g_arrTankProps.Clear();
    g_arrTankPropsHit.Clear();
}

void PossibleTankPropCreated(int iEnt, const char[] szClsName) {
    if (szClsName[0] != 'p')
        return;
    // Hooks c11m4_terminal World Sphere
    if (strcmp(szClsName, "prop_physics") != 0)
        return;
    // Use SpawnPost to just push it into the Array right away.
    // These entities get spawned after the Tank has punched them, so doing anything here will not work smoothly.
    SDKHook(iEnt, SDKHook_SpawnPost, Hook_PropSpawned);
}

void Hook_PropSpawned(int iEnt) {
    if (iEnt < MaxClients)    return;
    if (!IsValidEntity(iEnt)) return;
    if (g_arrTankProps.FindValue(iEnt) == -1) {
        char szModelName[PLATFORM_MAX_PATH];
        GetEntPropString(iEnt, Prop_Data, "m_ModelName", szModelName, sizeof(szModelName));
        if (StrContains(szModelName, "atlas_break_ball") != -1 || StrContains(szModelName, "forklift_brokenlift.mdl") != -1) {
            g_arrTankProps.Push(iEnt);
            g_arrTankPropsHit.Push(iEnt);
            CreateTankPropGlow(iEnt);
        } else if (StrContains(szModelName, "forklift_brokenfork.mdl") != -1) {
            RemoveEntity(iEnt);
        }
    }
}

bool IsValidEntRef(int iRef) {
    return (iRef > 0 && EntRefToEntIndex(iRef) != INVALID_ENT_REFERENCE);
}

int GetColor(char[] szTmp) {
    if (strcmp(szTmp, "") == 0)
        return 0;
    char szColors[3][4];
    int  iColor = ExplodeString(szTmp, " ", szColors, 3, 4);
    if (iColor != 3) return 0;
    iColor  = StringToInt(szColors[0]);
    iColor += 256 * StringToInt(szColors[1]);
    iColor += 65536 * StringToInt(szColors[2]);
    return iColor;
}

int GetTankClient() {
    if (g_iTankClient == -1 || !IsValidAliveTank(g_iTankClient))
        g_iTankClient = FindTank();
    return g_iTankClient;
}

int FindTank() {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsAliveTank(i))
            return i;
    }
    return -1;
}

bool IsValidAliveTank(int iClient) {
    return (iClient > 0 && iClient <= MaxClients && IsAliveTank(iClient));
}

bool IsAliveTank(int iClient) {
    return (IsClientInGame(iClient) && GetClientTeam(iClient) == TEAM_INFECTED && IsTank(iClient));
}

bool IsTank(int iClient) {
    return (GetEntProp(iClient, Prop_Send, "m_zombieClass") == Z_TANK && IsPlayerAlive(iClient));
}