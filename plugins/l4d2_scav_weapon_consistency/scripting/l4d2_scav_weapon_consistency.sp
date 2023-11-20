/*
 * changelog.
 *
 * v1.0: 8/26/23
 *  - initial build.
 *
 * v1.1: 8/27/23
 *  - use the way to remove entity and store entity from weapon_loadout_vote.sp by sir.
 *  - improved way to store datas in array.
 *
 * v1.2: 8/27/23
 *  - code optimization.
 *  - initial release.
 *
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <l4d2util>
#include <solaris/stocks>

#define MAX_ENTITY_NAME_LENGTH 64

ArrayList g_arrWeapons;

enum struct WeaponInfo {
    int   wepid;
    float pos[3];
    float ang[3];
}

static const char szRemoveWeaponNames[][] = {
    "spawn",
};

public Plugin myinfo = {
    name        = "[L4D2] Scavenge Weapon Consistency",
    description = "Makes scavenge weapons spawn at the same position and same tier in one scavenge round.",
    author      = "blueblur",
    version     = "1.2",
    url         = "https://github.com/blueblur0730/modified-plugins"
};

public void OnPluginStart() {
    HookEvent("round_start", Event_RoundStart, EventHookMode_Post);

    g_arrWeapons = new ArrayList(sizeof(WeaponInfo));
}

// check every round start
void Event_RoundStart(Event eEvent, char[] szName, bool bDontBroadcast) {
    CreateTimer(0.5, Timer_RoundStart, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_RoundStart(Handle hTimer) {
    if (!SDK_IsScavenge())
        return Plugin_Handled;

    int  iOwner = -1;
    int  iEnt   = INVALID_ENT_REFERENCE;
    char szEntName[MAX_ENTITY_NAME_LENGTH];

    // spawn the first half round weapons
    if (!InSecondHalfOfRound()) {
        // in the first half round, clear the array stored weapons from last round.
        g_arrWeapons.Clear();

        while ((iEnt = FindEntityByClassname(iEnt, "weapon_*")) != INVALID_ENT_REFERENCE) {
            if (iEnt <= MaxClients)
                continue;

            if (!IsValidEntity(iEnt))
                continue;

            GetEntityClassname(iEnt, szEntName, sizeof(szEntName));

            for (int i = 0; i < sizeof(szRemoveWeaponNames); i++) {
                if (strcmp(szEntName[7], szRemoveWeaponNames[i]) == 0) {
                    iOwner = GetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity");
                    if (iOwner == -1 || !IsClientInGame(iOwner))
                        StoreWeapons(iEnt);

                    break;
                }
            }
        }

        return Plugin_Handled;
    }

    // if the round is in second half, remove the weapons
    // from weapon_loadout_vote.sp
    while ((iEnt = FindEntityByClassname(iEnt, "weapon_*")) != INVALID_ENT_REFERENCE) {
        if (iEnt <= MaxClients)
            continue;

        if (!IsValidEntity(iEnt))
            continue;

        GetEntityClassname(iEnt, szEntName, sizeof(szEntName));

        for (int i = 0; i < sizeof(szRemoveWeaponNames); i++) {
            // weapon_ - 7
            if (strcmp(szEntName[7], szRemoveWeaponNames[i]) == 0) {
                // ignore the weapon we are handing
                iOwner = GetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity");
                if (iOwner == -1 || !IsClientInGame(iOwner))
                    RemoveEntity(iEnt);

                break;
            }
        }
    }

    ReplaceWeapons();
    return Plugin_Handled;
}

void StoreWeapons(int iEnt) {
    WeaponInfo eWeaponInfo;
    if (IdentifyWeapon(iEnt) == WEPID_NONE)
        return;

    eWeaponInfo.wepid = IdentifyWeapon(iEnt);
    GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin",   eWeaponInfo.pos);
    GetEntPropVector(iEnt, Prop_Send, "m_angRotation", eWeaponInfo.ang);
    g_arrWeapons.PushArray(eWeaponInfo, sizeof(WeaponInfo));
}

void ReplaceWeapons() {
    int iWeaponSize = g_arrWeapons.Length;

    WeaponInfo eWeaponInfo;
    for (int i = 0; i < iWeaponSize; i++) {
        g_arrWeapons.GetArray(i, eWeaponInfo, sizeof(WeaponInfo));
        if (eWeaponInfo.wepid == WEPID_NONE)
            continue;

        SpawnWeapon(eWeaponInfo.wepid, eWeaponInfo.pos, eWeaponInfo.ang, 5);
    }
}

void SpawnWeapon(int iWepId, float vPos[3], float vAng[3], int iCount) {
    if (!HasValidWeaponModel(iWepId))
        return;

    int iEnt = CreateEntityByName("weapon_spawn");
    if (!IsValidEntity(iEnt))
        return;

    char szBuffer[256];
    SetEntProp(iEnt, Prop_Send, "m_weaponID", iWepId);
    GetWeaponModel(iWepId, szBuffer, MAX_ENTITY_NAME_LENGTH);
    DispatchKeyValue(iEnt, "solid", "6");
    DispatchKeyValue(iEnt, "model", szBuffer);
    DispatchKeyValue(iEnt, "rendermode", "3");
    DispatchKeyValue(iEnt, "disableshadows", "1");
    IntToString(iCount, szBuffer, MAX_ENTITY_NAME_LENGTH);
    TeleportEntity(iEnt, vPos, vAng, NULL_VECTOR);
    DispatchKeyValue(iEnt, "count", szBuffer);
    DispatchSpawn(iEnt);
    SetEntityMoveType(iEnt, MOVETYPE_NONE);
}