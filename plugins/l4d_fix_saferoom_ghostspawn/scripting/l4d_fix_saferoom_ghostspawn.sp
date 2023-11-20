#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

Address
    g_pTheDirector;

int g_iLastSurvivorLeftStartAreaOffs;

public Plugin myinfo = {
    name        = "[L4D & 2] Fix Saferoom Ghost Spawn",
    author      = "Forgetest",
    description = "Fix a glitch that ghost can spawn in saferoom while it shouldn't.",
    version     = "2.0.1",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

public void OnPluginStart() {
    GameData gmConf = new GameData("l4d_fix_saferoom_ghostspawn");
    if (!gmConf)
        SetFailState("Missing gamedata \"l4d_fix_saferoom_ghostspawn\"");

    g_iLastSurvivorLeftStartAreaOffs = gmConf.GetOffset("CDirector::m_bLastSurvivorLeftStartArea");
    if (g_iLastSurvivorLeftStartAreaOffs == -1)
        SetFailState("Missing offset \"CDirector::m_bLastSurvivorLeftStartArea\"");

    delete gmConf;

    LateLoad();
}

public void OnAllPluginsLoaded() {
    g_pTheDirector = L4D_GetPointer(POINTER_DIRECTOR);
}

void LateLoad() {
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (GetClientTeam(i) != 3)
            continue;

        if (!L4D_IsPlayerGhost(i))
            continue;

        L4D_OnEnterGhostState(i);
    }
}

public void L4D_OnEnterGhostState(int iClient) {
    if (!IsClientInGame(iClient) || IsFakeClient(iClient))
        return;

    SDKHook(iClient, SDKHook_PreThinkPost, SDK_OnPreThink_Post);
}

void SDK_OnPreThink_Post(int iClient) {
    if (!IsClientInGame(iClient))
        return;

    if (!L4D_IsPlayerGhost(iClient)) {
        SDKUnhook(iClient, SDKHook_PreThinkPost, SDK_OnPreThink_Post);
        return;
    }

    int iSpawnState = L4D_GetPlayerGhostSpawnState(iClient);
    if (iSpawnState & L4D_SPAWNFLAG_RESTRICTEDAREA)
        return;

    Address pArea = L4D_GetLastKnownArea(iClient);
    if (pArea == Address_Null)
        return;

    if (HasLastSurvivorLeftStartArea()) // therefore free spawn in saferoom
        return;

    // Some stupid maps like Blood Harvest finale and The Passing finale have CHECKPOINT inside a FINALE marked area.
    int iSpawnAttr = L4D_GetNavArea_SpawnAttributes(pArea);
    if (~iSpawnAttr & NAV_SPAWN_CHECKPOINT || iSpawnAttr & NAV_SPAWN_FINALE)
        return;

    /**
     * Game code looks like this:
     *
     * ```cpp
     *  CNavArea* area = GetLastKnownArea();
     *  if ( area && !area->IsOverlapping(GetAbsOrigin(), 100.0) )
     *      area = NULL;
     * ```
     *
     * "area" will then be checked for in restricted area, except when it's NULL.
     */

    float vPos[3];
    GetClientAbsOrigin(iClient, vPos);
    if (NavArea_IsOverlapping(pArea, vPos)) // make sure it's the exact case
        return;

    static const float fExtendedRange = 300.0; // adjustable, 300 units should be fair enough
    if ((pArea = L4D_GetNearestNavArea(vPos, fExtendedRange, false, true, true, 2)) != Address_Null) {
        iSpawnAttr = L4D_GetNavArea_SpawnAttributes(pArea);
        if (iSpawnAttr & NAV_SPAWN_CHECKPOINT && ~iSpawnAttr & NAV_SPAWN_FINALE)
            L4D_SetPlayerGhostSpawnState(iClient, iSpawnState | L4D_SPAWNFLAG_RESTRICTEDAREA);
    }
}

bool HasLastSurvivorLeftStartArea() {
    return LoadFromAddress(g_pTheDirector + view_as<Address>(g_iLastSurvivorLeftStartAreaOffs), NumberType_Int8);
}

bool NavArea_IsOverlapping(Address pArea, const float vPos[3], float fTolerance = 100.0) {
    float vCenter[3];
    L4D_GetNavAreaCenter(pArea, vCenter);

    float vSize[3];
    L4D_GetNavAreaSize(pArea, vSize);

    return (vPos[0] + fTolerance >= vCenter[0] - vSize[0] * 0.5 && vPos[0] - fTolerance <= vCenter[0] + vSize[0] * 0.5 && vPos[1] + fTolerance >= vCenter[1] - vSize[1] * 0.5 && vPos[1] - fTolerance <= vCenter[1] + vSize[1] * 0.5);
}