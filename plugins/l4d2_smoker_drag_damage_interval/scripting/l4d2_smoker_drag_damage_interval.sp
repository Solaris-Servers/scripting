#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>

#define GAMEDATA "l4d2_si_ability"

#define DURATION_OFFSET  4
#define TIMESTAMP_OFFSET 8

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

ConVar g_cvTongueChokeDamageInterval;
ConVar g_cvTongueDragDamageInterval;
ConVar g_cvTongueDragFirstDamageInterval;
ConVar g_cvTongueDragFirstDamage;

int g_iTongueDragDamageTimerOffs;
int g_iTongueDragDamageTimerDurationOffs;
int g_iTongueDragDamageTimerTimeStampOffs;

public Plugin myinfo = {
    name        = "L4D2 Smoker Drag Damage Interval",
    author      = "Visor, Sir, A1m`",
    description = "Implements a native-like cvar that should've been there out of the box",
    version     = "1.0",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart() {
    InitGameData();

    char szValue[32];
    g_cvTongueChokeDamageInterval = FindConVar("tongue_choke_damage_interval");
    g_cvTongueChokeDamageInterval.GetString(szValue, sizeof(szValue));

    g_cvTongueDragDamageInterval = CreateConVar(
    "tongue_drag_damage_interval", szValue,
    "How often the drag does damage.",
    FCVAR_NONE, true, 0.0, false, 0.0);
    
    g_cvTongueDragFirstDamageInterval = CreateConVar(
    "tongue_drag_first_damage_interval", "-1.0",
    "After how many seconds do we apply our first tick of damage? | -1.0 to Disable.",
    FCVAR_NONE, true, -1.0, false, 0.0);
    
    g_cvTongueDragFirstDamage = CreateConVar(
    "tongue_drag_first_damage", "3.0",
    "How much damage do we apply on the first tongue hit? | Only applies when first_damage_interval is used",
    FCVAR_NONE, true, 0.0, false, 0.0);

    HookEvent("tongue_grab", Event_TongueGrab);
}

void InitGameData() {
    GameData gmConf = new GameData(GAMEDATA);
    if (!gmConf) SetFailState("Gamedata '%s.txt' missing or corrupt.", GAMEDATA);
    g_iTongueDragDamageTimerOffs = gmConf.GetOffset("CTerrorPlayer::m_tongueDragDamageTimer");
    if (g_iTongueDragDamageTimerOffs == -1) SetFailState("Failed to get offset 'CTerrorPlayer::m_tongueDragDamageTimer'.");
    g_iTongueDragDamageTimerDurationOffs  = g_iTongueDragDamageTimerOffs + DURATION_OFFSET;
    g_iTongueDragDamageTimerTimeStampOffs = g_iTongueDragDamageTimerOffs + TIMESTAMP_OFFSET;
    delete gmConf;
}

void Event_TongueGrab(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int   iUserId = eEvent.GetInt("victim");
    int   iClient = GetClientOfUserId(iUserId);
    float fFirst = g_cvTongueDragFirstDamageInterval.FloatValue;
    if (fFirst < 0.0) {
        FixDragInterval(iClient, iUserId);
        return;
    }
    SetDragDamageInterval(iClient, g_cvTongueDragFirstDamageInterval);
    CreateTimer(fFirst, Timer_FirstDamage, iUserId, TIMER_FLAG_NO_MAPCHANGE);
}

void FixDragInterval(int iClient, int iUserId) {
    SetDragDamageInterval(iClient, g_cvTongueDragDamageInterval);
    float fTimerUpdate = g_cvTongueDragDamageInterval.FloatValue + 0.1;
    CreateTimer(fTimerUpdate, Timer_FixDragInterval, iUserId, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_FirstDamage(Handle hTimer, any iUserId) {
    int iClient = GetClientOfUserId(iUserId);
    if (iClient > 0 && GetClientTeam(iClient) == TEAM_SURVIVOR && IsSurvivorBeingDragged(iClient)) {
        int iAttacker = GetEntPropEnt(iClient, Prop_Send, "m_tongueOwner");
        if (IsClientInGame(iAttacker) && GetClientTeam(iAttacker) == TEAM_INFECTED) {
            float fDamage = g_cvTongueDragFirstDamage.FloatValue - 1.0;
            SDKHooks_TakeDamage(iClient, iAttacker, iAttacker, fDamage);
        }
        FixDragInterval(iClient, iUserId);
        return Plugin_Stop;
    }
    return Plugin_Stop;
}

Action Timer_FixDragInterval(Handle hTimer, any iUserId) {
    int iClient = GetClientOfUserId(iUserId);
    if (iClient > 0 && GetClientTeam(iClient) == TEAM_SURVIVOR && IsSurvivorBeingDragged(iClient)) {
        SetDragDamageInterval(iClient, g_cvTongueDragDamageInterval);
        return Plugin_Continue;
    }
    return Plugin_Stop;
}

void SetDragDamageInterval(int iClient, ConVar cv) {
    float fCvarValue = cv.FloatValue;
    float fTimeStamp = GetGameTime() + fCvarValue;
    SetEntDataFloat(iClient, g_iTongueDragDamageTimerDurationOffs,  fCvarValue); // duration
    SetEntDataFloat(iClient, g_iTongueDragDamageTimerTimeStampOffs, fTimeStamp); // timestamp
}

bool IsSurvivorBeingDragged(int iClient) {
    return ((GetEntPropEnt(iClient, Prop_Send, "m_tongueOwner") > 0) && !IsSurvivorBeingChoked(iClient));
}

bool IsSurvivorBeingChoked(int iClient) {
    return (GetEntProp(iClient, Prop_Send, "m_isHangingFromTongue") > 0);
}