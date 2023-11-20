#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#define MAX_ENTITY_NAME_SIZE 64
#define MAX_INT_STRING_SIZE 8

#define TICK_TIME 0.2
#define TEAM_SURVIVOR 2

#define DMG_TYPE_SPIT (DMG_RADIATION|DMG_ENERGYBEAM)

enum struct PuddleInfo {
    int     iCount;
    bool    bAltTick;
    float   fDamageTime;
    float   fResetTime;
    Address pLastArea;
}

ConVar g_cvDamagePerTick;
char   g_szDamagePerTick[128];
float  g_fDamageCurve[20];

ConVar g_cvAlternateDamage;
float  g_fAlternateDamage;

ConVar g_cvMaxTicks;
int    g_iMaxTicks;

ConVar g_cvGodFrameTicks;
int    g_iGodFrameTicks;

ConVar g_cvIndividualCalc;
bool   g_bIndividualCalc;

ConVar g_cvResumeTicks;
int    g_iResumeTicks;

bool      g_bLateLoad;
StringMap g_smPuddles;

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    g_bLateLoad = bLate;
    return APLRes_Success;
}

public Plugin myinfo = {
    name        = "L4D2 Uniform Spit",
    author      = "Visor, Sir, A1m`, Forgetest",
    description = "Make the spit deal a set amount of DPS under all circumstances",
    version     = "2.1.0",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

public void OnPluginStart() {
    g_cvDamagePerTick = CreateConVar(
    "l4d2_spit_dmg", "0.0/1.0/2.0/4.0/6.0/6.0/4.0/1.4",
    "Linear curve of damage per second that the spit inflicts (separated by \"/\"). -1 to skip damage adjustments",
    FCVAR_NONE, false, 0.0, false, 0.0);
    g_cvDamagePerTick.AddChangeHook(CvarsChanged);

    g_cvAlternateDamage = CreateConVar(
    "l4d2_spit_alternate_dmg", "-1.0",
    "Damage per alternate tick. -1 to disable",
    FCVAR_NONE, true, -1.0, false, 0.0);
    g_cvAlternateDamage.AddChangeHook(CvarsChanged);

    g_cvMaxTicks = CreateConVar(
    "l4d2_spit_max_ticks", "28",
    "Maximum number of acid damage ticks",
    FCVAR_NONE, true, 0.0, true, 28.0);
    g_cvMaxTicks.AddChangeHook(CvarsChanged);

    g_cvGodFrameTicks = CreateConVar(
    "l4d2_spit_godframe_ticks", "4",
    "Number of initial godframed acid ticks",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_cvGodFrameTicks.AddChangeHook(CvarsChanged);

    g_cvIndividualCalc = CreateConVar(
    "l4d2_spit_individual_calc", "0",
    "Individual damage calculation for every player.",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_cvIndividualCalc.AddChangeHook(CvarsChanged);

    g_cvResumeTicks = CreateConVar(
    "l4d2_spit_resume_ticks", "6",
    "Tolerance window of ticks that individual damage calculation can resume from last state.",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_cvResumeTicks.AddChangeHook(CvarsChanged);

    CvarsToType();
    PrepareStringMap();
    PrepareEvents();

    if (g_bLateLoad) {
        for (int i = 1; i <= MaxClients; i++) {
            if (!IsClientInGame(i)) continue;
            OnClientPutInServer(i);
        }
    }
}

void CvarsChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    CvarsToType();
}

void PrepareStringMap() {
    g_smPuddles = new StringMap();
}

void PrepareEvents() {
    HookEvent("round_start", Event_RoundReset, EventHookMode_PostNoCopy);
}

void CvarsToType() {
    g_cvDamagePerTick.GetString(g_szDamagePerTick, sizeof(g_szDamagePerTick));
    StringToFloatArray(g_szDamagePerTick, "/", g_fDamageCurve, sizeof(g_fDamageCurve), true);
    g_fAlternateDamage = g_cvAlternateDamage.FloatValue;
    g_iMaxTicks        = g_cvMaxTicks.IntValue;
    g_iGodFrameTicks   = g_cvGodFrameTicks.IntValue;
    g_bIndividualCalc  = g_cvIndividualCalc.BoolValue;
    g_iResumeTicks     = g_cvResumeTicks.IntValue;
}

int StringToFloatArray(const char[] szBuffer, const char[] szSplit, float[] fArray, int iSize, bool bFill = false) {
    static const int iMaxFloatStringSize = 16;

    char[][] szBuffers = new char[iSize][iMaxFloatStringSize];
    int iNumStrings = ExplodeString(szBuffer, szSplit, szBuffers, iSize, iMaxFloatStringSize, true);

    if (iNumStrings == 0) return 0;
    if (iNumStrings > iSize) iNumStrings = iSize;

    for (int i = 0; i < iNumStrings; ++i) {
        fArray[i] = StringToFloat(szBuffers[i]);
    }
    if (bFill) {
        float fLastElement = fArray[iNumStrings - 1];
        for (int i = iNumStrings; i < iSize; ++i) {
            fArray[i] = fLastElement;
        }
    }
    return iNumStrings;
}

void Event_RoundReset(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_smPuddles.Clear();
}

public void OnMapEnd() {
    g_smPuddles.Clear();
}

public void OnClientPutInServer(int iClient) {
    SDKHook(iClient, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
}

public void OnClientDisconnect(int iClient) {
    SDKUnhook(iClient, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
}

public void OnEntityCreated(int iEntity, const char[] szClassName) {
    if (szClassName[0] != 'i') return;
    if (strcmp(szClassName, "insect_swarm") == 0) {
        char szTrieKey[MAX_INT_STRING_SIZE];
        IntToString(iEntity, szTrieKey, sizeof(szTrieKey));
        PuddleInfo[] iVictimArray = new PuddleInfo[MaxClients + 1];
        g_smPuddles.SetArray(szTrieKey, iVictimArray[0], ((MaxClients + 1) * sizeof(PuddleInfo)));
    }
}

public void OnEntityDestroyed(int iEntity) {
    if (IsInsectSwarm(iEntity)) {
        char szTrieKey[MAX_INT_STRING_SIZE];
        IntToString(iEntity, szTrieKey, sizeof(szTrieKey));
        g_smPuddles.Remove(szTrieKey);
    }
}

Action Hook_OnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &fDamageType) {
    // for performance
    if (!(fDamageType & DMG_TYPE_SPIT)) return Plugin_Continue;
    if (!IsInsectSwarm(iInflictor))     return Plugin_Continue;
    if (!IsSurvivor(iVictim))           return Plugin_Continue;

    char szTrieKey[MAX_INT_STRING_SIZE];
    IntToString(iInflictor, szTrieKey, sizeof(szTrieKey));

    PuddleInfo[] iVictimArray = new PuddleInfo[MaxClients + 1];
    if (g_smPuddles.GetArray(szTrieKey, iVictimArray[0], ((MaxClients+1) * sizeof(PuddleInfo)))) {
        iVictimArray[iVictim].iCount++;
        // Check to see if it's a godframed tick
        if ((GetPuddleLifetime(iInflictor) >= g_iGodFrameTicks * TICK_TIME) && iVictimArray[iVictim].iCount < g_iGodFrameTicks)
            iVictimArray[iVictim].iCount = g_iGodFrameTicks + 1;
        float fActiveSince = ITimer_GetTimestamp(GetInfernoActiveTimer(iInflictor));
        if (g_bIndividualCalc) {
            // Area check to help determine if the victim was godframed
            Address aArea = L4D_GetLastKnownArea(iVictim);
            Address aLastArea = iVictimArray[iVictim].pLastArea;
            if (aLastArea == Address_Null || aArea != aLastArea)
                iVictimArray[iVictim].pLastArea = aArea;
            float fNow = GetGameTime();
            if (iVictimArray[iVictim].fDamageTime == 0.0 || (aArea != aLastArea && fNow > iVictimArray[iVictim].fResetTime))
                iVictimArray[iVictim].fDamageTime = fNow;
            iVictimArray[iVictim].fResetTime = fNow + TICK_TIME * g_iResumeTicks;
            fActiveSince = iVictimArray[iVictim].fDamageTime;
        }
        // Let's see what do we have here
        float fDamageThisTick = GetDamagePerTick(fActiveSince);
        if (fDamageThisTick > -1.0) {
            if (g_fAlternateDamage > -1.0 && iVictimArray[iVictim].bAltTick) {
                iVictimArray[iVictim].bAltTick = false;
                fDamage = g_fAlternateDamage;
            } else {
                fDamage = fDamageThisTick;
                iVictimArray[iVictim].bAltTick = true;
            }
        }
        // Update the array with stored tickcounts
        g_smPuddles.SetArray(szTrieKey, iVictimArray[0], ((MaxClients + 1) * sizeof(PuddleInfo)));
        if (g_iGodFrameTicks >= iVictimArray[iVictim].iCount) fDamage = 0.0;
        if (iVictimArray[iVictim].iCount > g_iMaxTicks) {
            fDamage = 0.0;
            RemoveEntity(iInflictor);
        }
        return Plugin_Changed;
    }
    return Plugin_Continue;
}

float GetDamagePerTick(float fStartTimestamp) {
    if (g_fDamageCurve[0] == -1.0) return -1.0;

    float fElaspedTime = GetGameTime() - fStartTimestamp;
    int   iElaspedTime = RoundToFloor(fElaspedTime);

    if (iElaspedTime >= sizeof(g_fDamageCurve)) return g_fDamageCurve[sizeof(g_fDamageCurve) - 1];

    float fFraction = fElaspedTime - iElaspedTime;
    float fDmgBase  = g_fDamageCurve[iElaspedTime];
    float fDmgFrac  = g_fDamageCurve[iElaspedTime + 1] - fDmgBase;

    return fDmgFrac * fFraction + fDmgBase;
}

float GetPuddleLifetime(int iPuddle) {
    return ITimer_GetElapsedTime(GetInfernoActiveTimer(iPuddle));
}

IntervalTimer GetInfernoActiveTimer(int iInferno) {
    static int iActiveTimerOffset = -1;
    if (iActiveTimerOffset == -1) iActiveTimerOffset = FindSendPropInfo("CInferno", "m_fireCount") + 344;
    return view_as<IntervalTimer>(GetEntityAddress(iInferno) + view_as<Address>(iActiveTimerOffset));
}

bool IsInsectSwarm(int iEntity) {
    if (iEntity <= MaxClients)  return false;
    if (!IsValidEdict(iEntity)) return false;
    char szClassName[MAX_ENTITY_NAME_SIZE];
    GetEdictClassname(iEntity, szClassName, sizeof(szClassName));
    return (strcmp(szClassName, "insect_swarm") == 0);
}

bool IsSurvivor(int iClient) {
    return (iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient) && GetClientTeam(iClient) == TEAM_SURVIVOR);
}