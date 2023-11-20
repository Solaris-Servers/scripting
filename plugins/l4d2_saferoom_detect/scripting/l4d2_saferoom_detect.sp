/*
    To Do
    =========
        - add custom campaign: Dead Before Dawn (DC) (problematic loading...)

    Changelog
    =========

        0.0.8
            - Replace lgofnoc with confogl.

        0.0.7
            - Built in safeguard against trying to find values before keyvalues file is loaded.

        0.0.6
            - Fixed problems with entities that don't have location data

        0.0.1 - 0.0.5
            - Got rid of dependency on l4d2lib. Now falls back on lgofnoc, if loaded.
            - Now regged as 'saferoom_detect'
            - Fixed swapped start/end saferoom problem.
            - Better saferoom detection for weird saferooms (Death Toll church, Dead Air greenhouse), two-part saferoom checks.
            - Uses KeyValues file now: saferoominfo.txt in sourcemod/configs/
            - All official maps done (even Cold Stream).

*/

#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <confogl>
#define REQUIRE_PLUGIN

#define STRMAX_MAPNAME 64
#define DETMODE_LGO    0               // use mapinfo.txt (through confogl)
#define DETMODE_EXACT  1               // use exact list (coordinate-in-box)

#define SR_RADIUS      200.0           // the radius used to check distance from saferoom-coordinate (LGO mapinfo default)

#define MAPINFO_PATH "configs/saferoominfo.txt"

int g_iMode = DETMODE_LGO;

bool g_bIsConfoglAvailable;

bool g_bHasStart[2];
bool g_bHasEnd[2];

// keyvalues handle for SaferoomInfo.txt
KeyValues g_kvData;

char g_szMapname[STRMAX_MAPNAME];

float g_fStartRotate;
float g_fEndRotate;

float g_vStartLoc[4][3];
float g_vEndLoc  [4][3];

public Plugin myinfo = {
    name        = "Precise saferoom detection",
    author      = "Tabun, devilesk",
    description = "Allows checks whether a coordinate/entity/player is in start or end saferoom (uses saferoominfo.txt).",
    version     = "0.0.8",
    url         = "https://github.com/devilesk/rl4d2l-plugins"
}



/**
    Natives
            **/
public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    CreateNative("SAFEDETECT_IsEntityInStartSaferoom", Native_IsEntityInStartSaferoom);
    CreateNative("SAFEDETECT_IsPlayerInStartSaferoom", Native_IsPlayerInStartSaferoom);
    CreateNative("SAFEDETECT_IsEntityInEndSaferoom",   Native_IsEntityInEndSaferoom);
    CreateNative("SAFEDETECT_IsPlayerInEndSaferoom",   Native_IsPlayerInEndSaferoom);

    RegPluginLibrary("l4d2_saferoom_detect");

    return APLRes_Success;
}

any Native_IsEntityInStartSaferoom(Handle hPlugin, int iNumParams) {
    int iEnt = GetNativeCell(1);
    return IsEntityInStartSaferoom(iEnt);
}

any Native_IsEntityInEndSaferoom(Handle hPlugin, int iNumParams) {
    int iEnt = GetNativeCell(1);
    return IsEntityInEndSaferoom(iEnt);
}

any Native_IsPlayerInStartSaferoom(Handle hPlugin, int iNumParams) {
    int iClient = GetNativeCell(1);
    return IsPlayerInStartSaferoom(iClient);
}

any Native_IsPlayerInEndSaferoom(Handle hPlugin, int iNumParams) {
    int iClient = GetNativeCell(1);
    return IsPlayerInEndSaferoom(iClient);
}

public void OnAllPluginsLoaded() {
    g_bIsConfoglAvailable = LibraryExists("confogl");
}

public void OnLibraryRemoved(const char[] szName) {
    if (strcmp(szName, "confogl") == 0)
        g_bIsConfoglAvailable = false;
}

public void OnLibraryAdded(const char[] szName) {
    if (strcmp(szName, "confogl") == 0)
        g_bIsConfoglAvailable = true;
}



/**
    Init
            **/
public void OnPluginStart() {
    // fill a huge trie with maps that we have data for
    SI_KV_Load();
}

public void OnPluginEnd() {
    SI_KV_Close();
}

public void OnMapStart() {
    // get and store map data for this round
    GetCurrentMap(g_szMapname, sizeof(g_szMapname));
    g_iMode = (SI_KV_UpdateSaferoomInfo()) ? DETMODE_EXACT : DETMODE_LGO;
}

public void OnMapEnd() {
    g_kvData.Rewind();
}



/**
    Checks
            **/
bool IsEntityInStartSaferoom(int iEnt) {
    if (!IsValidEntity(iEnt) || GetEntSendPropOffs(iEnt, "m_vecOrigin", true) == -1)
        return false;

    // get entity location
    float vPos[3];
    GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", vPos);
    return IsPointInStartSaferoom(vPos);
}

bool IsEntityInEndSaferoom(int iEnt) {
    if (!IsValidEntity(iEnt) || GetEntSendPropOffs(iEnt, "m_vecOrigin", true) == -1)
        return false;

    // get entity location
    float vPos[3];
    GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", vPos);
    return IsPointInEndSaferoom(vPos);
}


bool IsPlayerInStartSaferoom(int iClient) {
    if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
        return false;

    // get client location and try both abs & eye
    float vPos[2][3];
    GetClientAbsOrigin(iClient,   vPos[0]);
    GetClientEyePosition(iClient, vPos[1]);

    return IsPointInStartSaferoom(vPos[0]) || IsPointInStartSaferoom(vPos[1]);
}

bool IsPlayerInEndSaferoom(int iClient) {
    if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
        return false;

    // get client location and try both abs & eye
    float vPos[2][3];
    GetClientAbsOrigin(iClient,   vPos[0]);
    GetClientEyePosition(iClient, vPos[1]);

    return IsPointInEndSaferoom(vPos[0]) || IsPointInEndSaferoom(vPos[1]);
}

bool IsPointInStartSaferoom(float vPos[3], int iEnt = -1) {
    if (g_bIsConfoglAvailable) {
        // trust confogl / mapinfo
        float fSafeRoomDistance[2];
        fSafeRoomDistance[0] = LGO_GetMapValueFloat("start_dist", SR_RADIUS);
        fSafeRoomDistance[1] = LGO_GetMapValueFloat("start_extra_dist", 0.0);

        float vSaferoom[3];
        LGO_GetMapValueVector("start_point", vSaferoom, NULL_VECTOR);

        if (iEnt != -1 && IsValidEntity(iEnt) && GetEntSendPropOffs(iEnt, "m_vecOrigin", true) != -1)
            GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", vPos);

        // distance to entity
        return GetVectorDistance(vPos, vSaferoom) <= ((fSafeRoomDistance[1] > fSafeRoomDistance[0]) ? fSafeRoomDistance[1] : fSafeRoomDistance[0]);
    }

    if (g_iMode == DETMODE_EXACT) {
        if (!g_bHasStart[0])
            return false;

        bool bSaferoom = false;

        // rotate point if necessary
        if (g_fStartRotate)
            RotatePoint(g_vStartLoc[0], vPos[0], vPos[1], g_fStartRotate);

        // check if the point is inside the box (end or start)
        float xMin;
        float xMax;
        if (g_vStartLoc[0][0] < g_vStartLoc[1][0]) {
            xMin = g_vStartLoc[0][0];
            xMax = g_vStartLoc[1][0];
        } else {
            xMin = g_vStartLoc[1][0];
            xMax = g_vStartLoc[0][0];
        }

        float yMin;
        float yMax;
        if (g_vStartLoc[0][1] < g_vStartLoc[1][1]) {
            yMin = g_vStartLoc[0][1];
            yMax = g_vStartLoc[1][1];
        } else {
            yMin = g_vStartLoc[1][1];
            yMax = g_vStartLoc[0][1];
        }

        float zMin;
        float zMax;
        if (g_vStartLoc[0][2] < g_vStartLoc[1][2]) {
            zMin = g_vStartLoc[0][2];
            zMax = g_vStartLoc[1][2];
        } else {
            zMin = g_vStartLoc[1][2];
            zMax = g_vStartLoc[0][2];
        }

        bSaferoom = vPos[0] >= xMin && vPos[0] <= xMax &&  vPos[1] >= yMin && vPos[1] <= yMax &&  vPos[2] >= zMin && vPos[2] <= zMax;
        // two-part saferooms:
        if (!bSaferoom && g_bHasStart[1]) {
            if (g_vStartLoc[2][0] < g_vStartLoc[3][0]) {
                xMin = g_vStartLoc[2][0];
                xMax = g_vStartLoc[3][0];
            } else {
                xMin = g_vStartLoc[3][0];
                xMax = g_vStartLoc[2][0];
            }

            if (g_vStartLoc[2][1] < g_vStartLoc[3][1]) {
                yMin = g_vStartLoc[2][1];
                yMax = g_vStartLoc[3][1];
            } else {
                yMin = g_vStartLoc[3][1];
                yMax = g_vStartLoc[2][1];
            }

            if (g_vStartLoc[2][2] < g_vStartLoc[3][2]) {
                zMin = g_vStartLoc[2][2];
                zMax = g_vStartLoc[3][2];
            } else {
                zMin = g_vStartLoc[3][2];
                zMax = g_vStartLoc[2][2];
            }

            bSaferoom = vPos[0] >= xMin && vPos[0] <= xMax &&  vPos[1] >= yMin && vPos[1] <= yMax &&  vPos[2] >= zMin && vPos[2] <= zMax;
        }

        return bSaferoom;
    }

    return false;
}

bool IsPointInEndSaferoom(float vPos[3], int iEnt = -1) {
    if (g_bIsConfoglAvailable) {
        // trust confogl / mapinfo
        float fSaferoomDistance = LGO_GetMapValueFloat("end_dist", SR_RADIUS);

        float vSaferoom[3];
        LGO_GetMapValueVector("end_point", vSaferoom, NULL_VECTOR);

        if (iEnt != -1 && IsValidEntity(iEnt) && GetEntSendPropOffs(iEnt, "m_vecOrigin", true) != -1)
            GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", vPos);

        // distance to entity
        return GetVectorDistance(vPos, vSaferoom) <= fSaferoomDistance;
    }

    if (g_iMode == DETMODE_EXACT) {
        if (!g_bHasEnd[0])
            return false;

        bool bSaferoom = false;

        // rotate point if necessary
        if (g_fEndRotate)
            RotatePoint(g_vEndLoc[0], vPos[0], vPos[1], g_fEndRotate);


        // check if the point is inside the box (end or start)
        float xMin;
        float xMax;
        if (g_vEndLoc[0][0] < g_vEndLoc[1][0]) {
            xMin = g_vEndLoc[0][0];
            xMax = g_vEndLoc[1][0];
        } else {
            xMin = g_vEndLoc[1][0];
            xMax = g_vEndLoc[0][0];
        }

        float yMin;
        float yMax;
        if (g_vEndLoc[0][1] < g_vEndLoc[1][1]) {
            yMin = g_vEndLoc[0][1];
            yMax = g_vEndLoc[1][1];
        } else {
            yMin = g_vEndLoc[1][1];
            yMax = g_vEndLoc[0][1];
        }

        float zMin;
        float zMax;
        if (g_vEndLoc[0][2] < g_vEndLoc[1][2]) {
            zMin = g_vEndLoc[0][2];
            zMax = g_vEndLoc[1][2];
        } else {
            zMin = g_vEndLoc[1][2];
            zMax = g_vEndLoc[0][2];
        }

        bSaferoom =  view_as<bool>(vPos[0] >= xMin && vPos[0] <= xMax &&  vPos[1] >= yMin && vPos[1] <= yMax &&  vPos[2] >= zMin && vPos[2] <= zMax );
        // two-part saferooms:
        if (!bSaferoom && g_bHasEnd[1]) {
            if (g_vEndLoc[2][0] < g_vEndLoc[3][0]) {
                xMin = g_vEndLoc[2][0];
                xMax = g_vEndLoc[3][0];
            } else {
                xMin = g_vEndLoc[3][0];
                xMax = g_vEndLoc[2][0];
            }

            if (g_vEndLoc[2][1] < g_vEndLoc[3][1]) {
                yMin = g_vEndLoc[2][1];
                yMax = g_vEndLoc[3][1];
            } else {
                yMin = g_vEndLoc[3][1];
                yMax = g_vEndLoc[2][1];
            }

            if (g_vEndLoc[2][2] < g_vEndLoc[3][2]) {
                zMin = g_vEndLoc[2][2];
                zMax = g_vEndLoc[3][2];
            } else {
                zMin = g_vEndLoc[3][2];
                zMax = g_vEndLoc[2][2];
            }

            bSaferoom =  view_as<bool>(vPos[0] >= xMin && vPos[0] <= xMax &&  vPos[1] >= yMin && vPos[1] <= yMax &&  vPos[2] >= zMin && vPos[2] <= zMax );
        }

        return bSaferoom;
    }

    return false;
}



/**
    KeyValues
                **/
void SI_KV_Close() {
    if (g_kvData == null)
        return;

    delete g_kvData;
    g_kvData = null;
}

void SI_KV_Load() {
    g_kvData = new KeyValues("SaferoomInfo");

    char szNameBuff[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, szNameBuff, sizeof(szNameBuff), MAPINFO_PATH);

    if (!g_kvData.ImportFromFile(szNameBuff)) {
        LogError("[SI] Couldn't load SaferoomInfo data!");
        SI_KV_Close();
    }
}

bool SI_KV_UpdateSaferoomInfo() {
    if (g_kvData == null) {
        LogError("[SI] No saferoom keyvalues loaded!");
        return false;
    }

    // defaults
    for (int i = 0; i < 2; i++) {
        g_bHasStart[i] = false;
        g_bHasEnd  [i] = false;
    }

    for (int i = 0; i < 4; i++) {
        g_vStartLoc[i] = NULL_VECTOR;
        g_vEndLoc  [i] = NULL_VECTOR;
    }

    g_fStartRotate = 0.0;
    g_fEndRotate   = 0.0;

    // get keyvalues
    if (g_kvData.JumpToKey(g_szMapname)) {
        g_kvData.GetVector("start_loc_a", g_vStartLoc[0]);
        g_kvData.GetVector("start_loc_b", g_vStartLoc[1]);
        g_kvData.GetVector("start_loc_c", g_vStartLoc[2]);
        g_kvData.GetVector("start_loc_d", g_vStartLoc[3]);
        g_fStartRotate = g_kvData.GetFloat("start_rotate", g_fStartRotate);
        g_kvData.GetVector("end_loc_a", g_vEndLoc[0]);
        g_kvData.GetVector("end_loc_b", g_vEndLoc[1]);
        g_kvData.GetVector("end_loc_c", g_vEndLoc[2]);
        g_kvData.GetVector("end_loc_d", g_vEndLoc[3]);
        g_fEndRotate = g_kvData.GetFloat("end_rotate", g_fEndRotate);

        // check data:
        if (g_vStartLoc[0][0] != 0.0 && g_vStartLoc[0][1] != 0.0 && g_vStartLoc[0][2] != 0.0 && g_vStartLoc[1][0] != 0.0 && g_vStartLoc[1][1] != 0.0 && g_vStartLoc[1][2] != 0.0)
            g_bHasStart[0] = true;

        if (g_vStartLoc[2][0] != 0.0 && g_vStartLoc[2][1] != 0.0 && g_vStartLoc[2][2] != 0.0 && g_vStartLoc[3][0] != 0.0 && g_vStartLoc[3][1] != 0.0 && g_vStartLoc[3][2] != 0.0)
            g_bHasStart[1] = true;

        if (g_vEndLoc[0][0] != 0.0 && g_vEndLoc[0][1] != 0.0 && g_vEndLoc[0][2] != 0.0 && g_vEndLoc[1][0] != 0.0 && g_vEndLoc[1][1] != 0.0 && g_vEndLoc[1][2] != 0.0)
            g_bHasEnd[0] = true;

        if (g_vEndLoc[2][0] != 0.0 && g_vEndLoc[2][1] != 0.0 && g_vEndLoc[2][2] != 0.0 && g_vEndLoc[3][0] != 0.0 && g_vEndLoc[3][1] != 0.0 && g_vEndLoc[3][2] != 0.0)
            g_bHasEnd[1] = true;

        // rotate if necessary:
        if (g_fStartRotate != 0.0) {
            RotatePoint(g_vStartLoc[0], g_vStartLoc[1][0], g_vStartLoc[1][1], g_fStartRotate);

            if (g_bHasStart[1]) {
                RotatePoint(g_vStartLoc[0], g_vStartLoc[2][0], g_vStartLoc[2][1], g_fStartRotate);
                RotatePoint(g_vStartLoc[0], g_vStartLoc[3][0], g_vStartLoc[3][1], g_fStartRotate);
            }
        }

        if (g_fEndRotate != 0.0) {
            RotatePoint(g_vEndLoc[0], g_vEndLoc[1][0], g_vEndLoc[1][1], g_fEndRotate);

            if (g_bHasEnd[1]) {
                RotatePoint(g_vEndLoc[0], g_vEndLoc[2][0], g_vEndLoc[2][1], g_fEndRotate);
                RotatePoint(g_vEndLoc[0], g_vEndLoc[3][0], g_vEndLoc[3][1], g_fEndRotate);
            }
        }

        return true;
    }

    LogMessage("[SI] SaferoomInfo for %s is missing.", g_szMapname);
    return false;
}



/**
    Support functions
                        **/
// rotate a point (x,y) over an angle, with ref. to an origin (x,y plane only)
void RotatePoint(float vPos[3], float &fPointX, float &fPointY, float fAng) {
    // translate angle to radians:
    float fNewPoint[2];
    fAng = fAng / 57.2957795130823;

    fNewPoint[0] = (Cosine(fAng) * (fPointX - vPos[0])) - (Sine(fAng)   * (fPointY - vPos[1])) + vPos[0];
    fNewPoint[1] = (Sine(fAng)   * (fPointX - vPos[0])) + (Cosine(fAng) * (fPointY - vPos[1])) + vPos[1];

    fPointX = fNewPoint[0];
    fPointY = fNewPoint[1];
}