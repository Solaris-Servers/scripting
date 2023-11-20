#if defined __ITEMTRACKING_MODULE__
    #endinput
#endif
#define __ITEMTRACKING_MODULE__

// Item lists for tracking/decoding/etc
enum eItemList {
    IL_PainPills,
    IL_Adrenaline,
    IL_PipeBomb,
    IL_Molotov,
    IL_VomitJar,
    IL_Size
};

StringMap IT_ItemListTrie;

// Names for cvars, kv, descriptions
// [ItemIndex][shortname=0, fullname=1, spawnname=2]
enum eItemNames {
    IN_ShortName,
    IN_LongName,
    IN_OfficialName,
    IN_ModelName,
    IN_Size
};

char IT_szItemNames[IL_Size][IN_Size][] = {
    { "pills",      "pain pills",       "pain_pills", "painpills"  },
    { "adrenaline", "adrenaline shots", "adrenaline", "adrenaline" },
    { "pipebomb",   "pipe bombs",       "pipe_bomb",  "pipebomb"   },
    { "molotov",    "molotovs",         "molotov",    "molotov"    },
    { "vomitjar",   "bile bombs",       "vomitjar",   "bile_flask" }
};

// Settings for item limiting.
enum struct eItemLimitSettings {
    ConVar cv;
    int iLimitNum;
}

// For spawn entires adt_array
enum struct eItemTracking {
    int   IT_entity;
    float IT_origins;
    float IT_origins1;
    float IT_origins2;
    float IT_angles;
    float IT_angles1;
    float IT_angles2;
}

// Current item limits array
int IT_iItemLimits[view_as<int>(IL_Size)];

int IT_iSaferoomCount[2];
int IT_iSurvivorLimit;

// ADT Array Handle for actual item spawns
ArrayList IT_ItemSpawnsArray[view_as<int>(IL_Size)];

// CVAR Handle Array for item limits
ConVar IT_cvLimits[view_as<int>(IL_Size)];

ConVar IT_cvEnabled;
ConVar IT_cvConsistentSpawns;
ConVar IT_cvMapSpecificSpawns;
ConVar IT_cvSurvivorLimit;

bool IsModuleEnabled() {
    return IsPluginEnabled() && IT_cvEnabled.BoolValue;
}

bool UseConsistentSpawns() {
    return IT_cvConsistentSpawns.BoolValue;
}

int GetMapInfoMode() {
    return IT_cvMapSpecificSpawns.IntValue;
}

int ItemTracking_BlockSize;

void IT_OnModuleStart() {
    IT_cvEnabled = CreateConVarEx(
    "enable_itemtracking", "0",
    "Enable the itemtracking module",
    FCVAR_NONE, true, 0.0, true, 1.0);

    IT_cvConsistentSpawns = CreateConVarEx(
    "itemtracking_savespawns", "0",
    "Keep item spawns the same on both rounds",
    FCVAR_NONE, true, 0.0, true, 1.0);

    IT_cvMapSpecificSpawns = CreateConVarEx(
    "itemtracking_mapspecific", "0",
    "Change how mapinfo.txt overrides work. 0 = ignore mapinfo.txt, 1 = allow limit reduction, 2 = allow limit increases, ",
    FCVAR_NONE, true, 0.0, true, 1.0);

    // Create itemlimit cvars
    char szNameBuf[64];
    char szCvarDescBuf[256];
    for (int i = 0; i < view_as<int>(IL_Size); i++) {
        FormatEx(szNameBuf,     sizeof(szNameBuf),     "%s_limit",                                                                    IT_szItemNames[i][IN_ShortName]);
        FormatEx(szCvarDescBuf, sizeof(szCvarDescBuf), "Limits the number of %s on each map. -1: no limit; >=0: limit to cvar value", IT_szItemNames[i][IN_LongName]);
        IT_cvLimits[i] = CreateConVarEx(szNameBuf, "-1", szCvarDescBuf);
    }

    // Create name translation trie
    IT_ItemListTrie = CreateItemListTrie();

    // Create item spawns array;
    eItemTracking Tmp;
    ItemTracking_BlockSize = sizeof(Tmp);
    for (int i = 0; i < view_as<int>(IL_Size); i++) {
        IT_ItemSpawnsArray[i] = new ArrayList(ItemTracking_BlockSize);
    }

    IT_cvSurvivorLimit = FindConVar("survivor_limit");
    IT_iSurvivorLimit  = IT_cvSurvivorLimit.IntValue;
    IT_cvSurvivorLimit.AddChangeHook(IT_SurvivorLimit_Change);

    HookEvent("round_start", IT_Event_RoundStart, EventHookMode_PostNoCopy);
}

void IT_Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!IsModuleEnabled())
        return;

    IT_iSaferoomCount[START_SAFEROOM - 1] = 0;
    IT_iSaferoomCount  [END_SAFEROOM - 1] = 0;

    // We don't want to have conflicts with EntityRemover.
    CreateTimer(1.0, IT_Timer_RoundStart, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action IT_Timer_RoundStart(Handle hTimer) {
    if (!InSecondHalfOfRound()) {
        for (int i; i < view_as<int>(IL_Size); i++) {
            IT_iItemLimits[i] = IT_cvLimits[i].IntValue;
        }

        if (GetMapInfoMode()) {
            int iLimit;
            KeyValues kv = new KeyValues("ItemLimits");
            CopyMapSubsection(kv, "ItemLimits");
            for (int i = 0; i < view_as<int>(IL_Size); i++) {
                iLimit = IT_cvLimits[i].IntValue;
                int iTmp = kv.GetNum(IT_szItemNames[i][IN_OfficialName], iLimit);
                if (((IT_iItemLimits[i] > iTmp) && (GetMapInfoMode() & 1)) || ((IT_iItemLimits[i] < iTmp) && (GetMapInfoMode() & 2)))
                    IT_iItemLimits[i] = iTmp;
                IT_ItemSpawnsArray[i].Clear();
            }

            delete kv;
        }

        EnumAndElimSpawns();
        return Plugin_Stop;
    }

    if (UseConsistentSpawns()) {
        GenerateStoredSpawns();
        return Plugin_Stop;
    }

    EnumAndElimSpawns();
    return Plugin_Stop;
}

void IT_SurvivorLimit_Change(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    IT_iSurvivorLimit = StringToInt(szNewVal);
}

void EnumAndElimSpawns() {
    if (IsDebugEnabled())
        LogMessage("[IT] Resetting IT_iSaferoomCount and Enumerating and eliminating spawns...");

    EnumerateSpawns();
    RemoveToLimits();
}

void GenerateStoredSpawns() {
    KillRegisteredItems();
    SpawnItems();
}

// Produces the lookup trie for weapon spawn entities
// to translate to our ADT array of spawns
StringMap CreateItemListTrie() {
    StringMap Trie = new StringMap();
    Trie.SetValue("weapon_pain_pills_spawn", IL_PainPills);
    Trie.SetValue("weapon_pain_pills",       IL_PainPills);
    Trie.SetValue("weapon_adrenaline_spawn", IL_Adrenaline);
    Trie.SetValue("weapon_adrenaline",       IL_Adrenaline);
    Trie.SetValue("weapon_pipe_bomb_spawn",  IL_PipeBomb);
    Trie.SetValue("weapon_pipe_bomb",        IL_PipeBomb);
    Trie.SetValue("weapon_molotov_spawn",    IL_Molotov);
    Trie.SetValue("weapon_molotov",          IL_Molotov);
    Trie.SetValue("weapon_vomitjar_spawn",   IL_VomitJar);
    Trie.SetValue("weapon_vomitjar",         IL_VomitJar);
    return Trie;
}

void KillRegisteredItems() {
    eItemList eItemIndex;
    int iEntCount = GetEntityCount();
    for (int i = 0; i <= iEntCount; i++) {
        if (IsValidEntity(i)) {
            eItemIndex = GetItemIndexFromEntity(i);
            if (eItemIndex >= view_as<eItemList>(0)) {
                if (IsEntityInSaferoom(i, START_SAFEROOM) && IT_iSaferoomCount[START_SAFEROOM - 1] < IT_iSurvivorLimit) {
                    IT_iSaferoomCount[START_SAFEROOM - 1]++;
                } else if (IsEntityInSaferoom(i, END_SAFEROOM) && IT_iSaferoomCount[END_SAFEROOM - 1] < IT_iSurvivorLimit) {
                    IT_iSaferoomCount[END_SAFEROOM - 1]++;
                } else {
                    // Kill items we're tracking;
                    RemoveEntity(i);
                }
            }
        }
    }
}

void SpawnItems() {
    float vPos[3];
    float vAng[3];
    int   iArrSize;
    int   iItem;
    char  szModelname[PLATFORM_MAX_PATH];

    eWeaponIDs eWepId;
    eItemTracking eCurItem;
    for (int ItemIdx = 0; ItemIdx < view_as<int>(IL_Size); ItemIdx++) {
        FormatEx(szModelname, sizeof(szModelname), "models/w_models/weapons/w_eq_%s.mdl", IT_szItemNames[ItemIdx][IN_ModelName]);
        iArrSize = IT_ItemSpawnsArray[ItemIdx].Length;
        for (int Idx = 0; Idx < iArrSize; Idx++) {
            IT_ItemSpawnsArray[ItemIdx].GetArray(Idx, eCurItem);
            GetSpawnOrigins(vPos, eCurItem);
            GetSpawnAngles(vAng,   eCurItem);
            eWepId = GetWeaponIDFromItemList(view_as<eItemList>(ItemIdx));
            if (IsDebugEnabled()) {
                LogMessage("[IT] Spawning an instance of item %s (%d, wepid %d), number %d, at %.02f %.02f %.02f",
                IT_szItemNames[ItemIdx][IN_OfficialName], ItemIdx, eWepId, Idx, vPos[0], vPos[1], vPos[2]);
            }

            iItem = CreateEntityByName("weapon_spawn");
            SetEntProp(iItem, Prop_Send, "m_weaponID", eWepId);
            SetEntityModel(iItem, szModelname);
            DispatchKeyValue(iItem, "count", "1");
            TeleportEntity(iItem, vPos, vAng, NULL_VECTOR);
            DispatchSpawn(iItem);
            SetEntityMoveType(iItem, MOVETYPE_NONE);
        }
    }
}

void EnumerateSpawns() {
    int   iEntCount = GetEntityCount();
    float vPos[3];
    float vAng[3];
    eItemList eItemIndex;
    eItemTracking eCurItem;
    for (int i = 0; i <= iEntCount; i++) {
        if (IsValidEntity(i)) {
            eItemIndex = GetItemIndexFromEntity(i);
            if (eItemIndex >= view_as<eItemList>(0)) {
                if (IsEntityInSaferoom(i, START_SAFEROOM)) {
                    if (IT_iSaferoomCount[START_SAFEROOM - 1] < IT_iSurvivorLimit) {
                        IT_iSaferoomCount[START_SAFEROOM - 1]++;
                    } else {
                        RemoveEntity(i);
                    }
                } else if (IsEntityInSaferoom(i, END_SAFEROOM)) {
                    if (IT_iSaferoomCount[END_SAFEROOM - 1] < IT_iSurvivorLimit) {
                        IT_iSaferoomCount[END_SAFEROOM - 1]++;
                    } else {
                        RemoveEntity(i);
                    }
                } else {
                    int iLimit = GetItemLimit(eItemIndex);
                    if (IsDebugEnabled())
                        LogMessage("[IT] Found an instance of item %s (%d), with limit %d", IT_szItemNames[eItemIndex][IN_LongName], eItemIndex, iLimit);
                    // Item limit is zero, justkill it as we find it
                    if (!iLimit) {
                        if (IsDebugEnabled())
                            LogMessage("[IT] Killing spawn");
                        RemoveEntity(i);
                    } else {
                        // Store entity, angles, origin
                        eCurItem.IT_entity = i;
                        GetEntPropVector(i, Prop_Send, "m_vecOrigin",   vPos);
                        GetEntPropVector(i, Prop_Send, "m_angRotation", vAng);
                        if (IsDebugEnabled())
                            LogMessage("[IT] Saving spawn #%d at %.02f %.02f %.02f", IT_ItemSpawnsArray[eItemIndex], vPos[0], vPos[1], vPos[2]);
                        SetSpawnOrigins(vPos, eCurItem);
                        SetSpawnAngles(vAng,   eCurItem);
                        // Push this instance onto our array for that item
                        IT_ItemSpawnsArray[eItemIndex].PushArray(eCurItem);
                    }
                }
            }
        }
    }
}

void RemoveToLimits() {
    int iCurLimit;
    eItemTracking eCurItem;
    for (int iIdx = 0; iIdx < view_as<int>(IL_Size); iIdx++) {
        iCurLimit = GetItemLimit(view_as<eItemList>(iIdx));
        if (iCurLimit > 0) {
            // Kill off item spawns until we've reduced the item to the limit
            while (IT_ItemSpawnsArray[iIdx].Length > iCurLimit) {
                // Pick a random
                int iKillIdx = GetURandomIntRange(0, IT_ItemSpawnsArray[iIdx].Length - 1);
                if (IsDebugEnabled())
                    LogMessage("[IT] Killing randomly chosen %s (%d) #%d", IT_szItemNames[iIdx][IN_LongName], iIdx, iKillIdx);
                IT_ItemSpawnsArray[iIdx].GetArray(iKillIdx, eCurItem);
                if (IsValidEntity(eCurItem.IT_entity))
                    RemoveEntity(eCurItem.IT_entity);
                IT_ItemSpawnsArray[iIdx].Erase(iKillIdx);
            }
        }
    }
}

void SetSpawnOrigins(const float vBuf[3], eItemTracking eSpawn) {
    eSpawn.IT_origins  = vBuf[0];
    eSpawn.IT_origins1 = vBuf[1];
    eSpawn.IT_origins2 = vBuf[2];
}

void SetSpawnAngles(const float vBuf[3], eItemTracking eSpawn) {
    eSpawn.IT_angles  = vBuf[0];
    eSpawn.IT_angles1 = vBuf[1];
    eSpawn.IT_angles2 = vBuf[2];
}

void GetSpawnOrigins(float vBuf[3], eItemTracking eSpawn) {
    vBuf[0] = eSpawn.IT_origins;
    vBuf[1] = eSpawn.IT_origins1;
    vBuf[2] = eSpawn.IT_origins2;
}

void GetSpawnAngles(float vBuf[3], eItemTracking eSpawn) {
    vBuf[0] = eSpawn.IT_angles;
    vBuf[1] = eSpawn.IT_angles1;
    vBuf[2] = eSpawn.IT_angles2;
}

int GetItemLimit(eItemList eItemIdx) {
    return IT_iItemLimits[eItemIdx];
}

eWeaponIDs GetWeaponIDFromItemList(eItemList eId) {
    switch (eId) {
        case IL_PainPills:  return WEPID_PAIN_PILLS;
        case IL_Adrenaline: return WEPID_ADRENALINE;
        case IL_PipeBomb:   return WEPID_PIPE_BOMB;
        case IL_Molotov:    return WEPID_MOLOTOV;
        case IL_VomitJar:   return WEPID_VOMITJAR;
    }
    return view_as<eWeaponIDs>(-1);
}

eItemList GetItemIndexFromEntity(int iEntity) {
    static char szClassName[128];
    GetEdictClassname(iEntity, szClassName, sizeof(szClassName));
    eItemList eIndex;
    if (IT_ItemListTrie.GetValue(szClassName, eIndex))
        return eIndex;
    if (strcmp(szClassName, "weapon_spawn") == 0 || strcmp(szClassName, "weapon_item_spawn") == 0) {
        eWeaponIDs Id = view_as<eWeaponIDs>(GetEntProp(iEntity, Prop_Send, "m_weaponID"));
        switch (Id) {
            case WEPID_VOMITJAR:   return IL_VomitJar;
            case WEPID_PIPE_BOMB:  return IL_PipeBomb;
            case WEPID_MOLOTOV:    return IL_Molotov;
            case WEPID_PAIN_PILLS: return IL_PainPills;
            case WEPID_ADRENALINE: return IL_Adrenaline;
        }
    }
    return view_as<eItemList>(-1);
}