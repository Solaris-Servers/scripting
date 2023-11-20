#if defined __ITEMS__
    #endinput
#endif
#define __ITEMS__

/*======================================================================================
    Plugin Info:

*   Name    :   Universal Item Management
*   Author  :   Stabby
*   Descrp  :   Allows for some dynamic non-stripper control over entity spawns.

========================================================================================*/

#include <l4d2_saferoom_detect>

#define START_LIMIT 0
#define MAP_LIMIT   1
#define END_LIMIT   2
#define TOTAL_LIMIT 3

#define CLASS_NAME  3
#define DISPATCH    4

#define BUF_SZ      64

StringMap g_smItemSettings;  // stores an adt_array for every item
ArrayList g_arrItemSettings; // for iterating through the eponymous trie
ArrayList g_arrItemsToSpawn; // for spawning wanted items on both rounds

void OnModuleStart_ItemManager() {
    RegServerCmd("solaris_item_limit", Cmd_Limit, "Sets limits for an entity.");

    g_smItemSettings  = new StringMap();
    g_arrItemsToSpawn = new ArrayList(BUF_SZ / 4);
    g_arrItemSettings = new ArrayList(BUF_SZ / 4);
}

Action Cmd_Limit(int iArgs) {
    if (iArgs < 4) {
        PrintToServer("Syntax: uim_limit <item name> <startsaferoom limit> <map limit> <endsaferoom limit>");
        return Plugin_Handled;
    }

    static char szItem[BUF_SZ];
    GetCmdArg(1, szItem, BUF_SZ);

    static char szBuffer[BUF_SZ];
    for (int i = 2; i <= 4; i++) {
        GetCmdArg(i, szBuffer, BUF_SZ);
        UIM_SetItemLimit(i - 2, szItem, StringToInt(szBuffer));
    }

    return Plugin_Handled;
}

public void OnEntityCreated(int iEnt, const char[] szClsName) {
    if (StrContains(szClsName, "_spawn") <= 0)
        return;

    SetEntityFlags(iEnt, GetEntityFlags(iEnt) | 2);
}

void Evt_RoundStart_Items() {
    CreateTimer(1.0, Timer_RoundStart, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_RoundStart(Handle hTimer) {
    if (!InSecondHalfOfRound()) {
        g_arrItemsToSpawn.Clear();
        SelectWantedItems();
    }

    RemoveAllItems();
    SpawnWantedItems();
    return Plugin_Stop;
}



/**
    LIMIT ENFORCEMENT
                        **/

void GetSpawnCoords(ArrayList arrSpawn, float vPos[3], float vAng[3]) {
    ArrayList arrCoord = arrSpawn.Get(1);
    arrCoord.GetArray(0, vPos);
    arrCoord.GetArray(1, vAng);
}

void GetItemName(ArrayList arrSpawn, char[] szItem) {
    ArrayList arrItemName = arrSpawn.Get(0);
    arrItemName.GetString(0, szItem, BUF_SZ);
}

void GetMeleeScriptName(ArrayList arrSpawn, char[] szName) {
    ArrayList arrMeleeScriptName = arrSpawn.Get(2);
    arrMeleeScriptName.GetString(0, szName, BUF_SZ);
}

void AddToWantedList(char[] szItem, int iEnt, char[] szName = "") {
    float vPos[3];
    GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", vPos);

    float vAng[3];
    GetEntPropVector(iEnt, Prop_Send, "m_angRotation", vAng);

    ArrayList arrSpawn    = new ArrayList();
    ArrayList arrItemName = new ArrayList(BUF_SZ / 4);

    arrItemName.PushString(szItem);
    arrSpawn.Push(arrItemName);

    ArrayList arrCoord = new ArrayList(3);

    arrCoord.PushArray(vPos);
    arrCoord.PushArray(vAng);
    arrSpawn.Push(arrCoord);

    ArrayList arrMeleeScriptName = new ArrayList(BUF_SZ / 4);

    arrMeleeScriptName.PushString(szName);
    arrSpawn.Push(arrMeleeScriptName);
    g_arrItemsToSpawn.Push(arrSpawn);
}

void SelectWantedItems() {
    int  iEnt;
    int  iItems;
    char szClsName[BUF_SZ];
    char szBuffer [BUF_SZ];
    char szItem   [BUF_SZ];
    int  iCount   [TOTAL_LIMIT];
    int  iLimit   [TOTAL_LIMIT];
    for (int i = 0; i < g_arrItemSettings.Length; i++) {
        g_arrItemSettings.GetString(i, szItem, BUF_SZ);
        UIM_GetItemClassname(szItem, szClsName);

        for (iItems = 0; iItems < TOTAL_LIMIT; iItems++) {
            iLimit[iItems] = UIM_GetItemLimit(iItems, szItem);
            iCount[iItems] = 0;
        }

        iEnt = -1;
        ArrayList arrEntities[TOTAL_LIMIT];
        for (iItems = 0; iItems < TOTAL_LIMIT; iItems++) {
            arrEntities[iItems] = new ArrayList();
        }

        while ((iEnt = FindEntityByClassName(iEnt, szClsName)) != -1) {
            if (SAFEDETECT_IsEntityInStartSaferoom(iEnt)) {
                arrEntities[START_LIMIT].Push(iEnt);
                iCount[START_LIMIT]++;
            } else if (SAFEDETECT_IsEntityInEndSaferoom(iEnt)) {
                arrEntities[END_LIMIT].Push(iEnt);
                iCount[END_LIMIT]++;
            } else {
                arrEntities[MAP_LIMIT].Push(iEnt);
                iCount[MAP_LIMIT]++;
            }
        }

        for (iItems = 0; iItems < TOTAL_LIMIT; iItems++) {
            iCount[iItems] = 0;
            while (arrEntities[iItems].Length > 0 && iCount[iItems] < iLimit[iItems]) {
                int iRndIdx = GetRandomInt(0, arrEntities[iItems].Length - 1);
                if (!GetMeleeWeaponNameFromEntity(arrEntities[iItems].Get(iRndIdx), szBuffer, BUF_SZ))
                    szBuffer = "";
                AddToWantedList(szItem, arrEntities[iItems].Get(iRndIdx), szBuffer);
                arrEntities[iItems].Erase(iRndIdx);
                iCount[iItems]++;
            }
        }

        for (iItems = 0; iItems < TOTAL_LIMIT; iItems++) {
            arrEntities[iItems].Clear();
            delete arrEntities[iItems];
        }
    }
}

int FindEntityByClassName(int iEnt, char[] szClsName) {
    if (StrContains(szClsName, "weapon_") == 0) {
        int iCount = GetEntityCount();
        for (int i = iEnt + 1; i < iCount; i++) {
            if (WeaponNameToId(szClsName) == IdentifyWeapon(i))
                return i;
        }
        return -1;
    }

    return FindEntityByClassname(iEnt, szClsName);
}

void RemoveAllItems() {
    int  iEnt;
    char szClsName[BUF_SZ];
    char szItem   [BUF_SZ];
    for (int i = 0; i < g_arrItemSettings.Length; i++) {
        g_arrItemSettings.GetString(i, szItem, BUF_SZ);
        UIM_GetItemClassname(szItem, szClsName);
        iEnt = -1;

        while ((iEnt = FindEntityByClassName(iEnt, szClsName)) != -1) {
            RemoveEntity(iEnt);
        }
    }
}

void DispatchAllKeyValues(int iEnt, char[] szItem) {
    char szKey  [BUF_SZ];
    char szValue[BUF_SZ];
    ArrayList arrPair;
    ArrayList arrSpawnValues = UIM_GetSpawnValuesArray(szItem);
    for (int i = 0; i < arrSpawnValues.Length; i++) {
        arrPair = arrSpawnValues.Get(i);
        arrPair.GetString(0, szKey,   BUF_SZ);
        arrPair.GetString(1, szValue, BUF_SZ);
        DispatchKeyValue(iEnt, szKey, szValue);
    }
}

void SpawnWantedItems() {
    char  szClsName[BUF_SZ];
    char  szItem[BUF_SZ];
    char  szMelee[BUF_SZ];
    int   iEnt;
    float vPos[3];
    float vAng[3];
    ArrayList arrSpawn;

    for (int i = 0; i < g_arrItemsToSpawn.Length; i++) {
        arrSpawn = g_arrItemsToSpawn.Get(i);
        GetSpawnCoords(arrSpawn, vPos, vAng);
        GetItemName(arrSpawn, szItem);
        UIM_GetItemClassname(szItem, szClsName);

        if ((iEnt = CreateEntityByName(szClsName)) < 0)
            continue;

        GetMeleeScriptName(arrSpawn, szMelee);
        if (strcmp(szMelee, "") != 0)
            DispatchKeyValue(iEnt, "melee_script_name", szMelee);

        DispatchKeyValueVector(iEnt, "origin", vPos);
        DispatchKeyValueVector(iEnt, "angles", vAng);
        DispatchAllKeyValues(iEnt, szItem);
        DispatchSpawn(iEnt);
        SetEntityMoveType(iEnt, MOVETYPE_NONE);
    }
}



/**
    LIMIT SETTING AFTER THIS POINT
                                    **/

ArrayList UIM_CreateItemArray() {
    ArrayList arrItems = new ArrayList();
    arrItems.Push(-1);  // START_LIMIT
    arrItems.Push(-1);  // MAP_LIMIT
    arrItems.Push(-1);  // END_LIMIT

    ArrayList arrClsName = new ArrayList(BUF_SZ / 4);
    arrClsName.PushString("");
    arrItems.Push(arrClsName); // CLASS_NAME

    arrItems.Push(new ArrayList()); // DISPATCH
    return arrItems;
}

ArrayList UIM_GetItemArray(char[] szItem) {
    ArrayList arrItems;

    if (!g_smItemSettings.GetValue(szItem, arrItems)) {
        g_smItemSettings.SetValue(szItem, arrItems = UIM_CreateItemArray(), false);
        UIM_SetItemClassname(szItem, szItem);
        g_arrItemSettings.PushString(szItem);
    }

    return arrItems;
}

ArrayList UIM_GetSpawnValuesArray(char[] szItem) {
    return UIM_GetItemArray(szItem).Get(DISPATCH);
}

int UIM_GetItemLimit(int iPlace, char[] szItem) {
    return UIM_GetItemArray(szItem).Get(iPlace);
}

void UIM_SetItemLimit(int iPlace, char[] szItem, int iLimit) {
    UIM_GetItemArray(szItem).Set(iPlace, iLimit);
}

void UIM_GetItemClassname(char[] szItem, char[] szClsName) {
    view_as<ArrayList>(UIM_GetItemArray(szItem).Get(CLASS_NAME)).GetString(0, szClsName, BUF_SZ);
}

void UIM_SetItemClassname(char[] szItem, char[] szClsName) {
    view_as<ArrayList>(UIM_GetItemArray(szItem).Get(CLASS_NAME)).SetString(0, szClsName);
}