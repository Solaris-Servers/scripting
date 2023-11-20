#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

ConVar g_cvNumWitches;
int    g_iNumWitches;

ConVar g_cvSpawnRadius;
int    g_iSpawnRadius;

public Plugin myinfo = {
    name        = "Defib witches",
    author      = "epilimic, purpletreefactory",
    description = "Spawns witches in random points on a circle around the survivors when a defib is used.",
    version     = "1.0",
    url         = "http://github.com/epilimic"
}

public void OnPluginStart() {
    g_cvNumWitches = CreateConVar(
    "dw_numwitches", "3", "Number of witches to spawn when a defib is used.",
    FCVAR_NONE, true, 1.0, false, 0.0);
    g_iNumWitches = g_cvNumWitches.IntValue;
    g_cvNumWitches.AddChangeHook(CvChg_NumWitches);
    
    g_cvSpawnRadius = CreateConVar(
    "dw_spawnradius", "100",
    "Radius of the circle in which witches spawn.",
    FCVAR_NONE, true, 1.0, false, 0.0);
    g_iSpawnRadius = g_cvSpawnRadius.IntValue;
    g_cvSpawnRadius.AddChangeHook(CvChg_SpawnRadius);
    
    HookEvent("defibrillator_used", Event_Defib);
}

void CvChg_NumWitches(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iNumWitches = g_cvNumWitches.IntValue;
}

void CvChg_SpawnRadius(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iSpawnRadius = g_cvSpawnRadius.IntValue;
}

void Event_Defib(Event eEvent, const char[] name, bool dontBroadcast) {
    static float PI      = 3.14159265359;
    static float ProxVal = 0.21;
    static int   Chg     = 10;

    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));

    float vRndVals[3];

    float vSurvPos[3];
    GetClientAbsOrigin(iClient, vSurvPos);

    // generate 3 random floats for witch positions
    for (int i = 0; i < 3; i++) {
        float fTmp;
        int   iValid = -1;

        while (iValid == -1) {
            fTmp = GetRandomFloat(0.0, 2.0 * PI);
            iValid = 0;

            for (int j = 0; j < i; j++) {
                if (FloatAbs(fTmp - vRndVals[j]) < ProxVal || (2 * PI - FloatAbs(fTmp - vRndVals[j])) < ProxVal)
                    iValid = -1;
            }
        }

        vRndVals[i] = fTmp;
    }

    int   iNumWitches = 0;
    float vPos[3];
    while (iNumWitches < g_iNumWitches) {
        vPos[0] = vSurvPos[0] + Sine(vRndVals[iNumWitches])   * g_iSpawnRadius;
        vPos[1] = vSurvPos[1] + Cosine(vRndVals[iNumWitches]) * g_iSpawnRadius;
        vPos[2] = vSurvPos[2] + Chg;

        int iEnt = CreateEntityByName("witch");
        DispatchSpawn(iEnt);
        TeleportEntity(iEnt, vPos, NULL_VECTOR, NULL_VECTOR);
        iNumWitches++;
    }
}