#if defined __ENTITY_REMOVER_MODULE__
    #endinput
#endif
#define __ENTITY_REMOVER_MODULE__

#define ER_KV_ACTION_KILL        1

#define ER_KV_PROPTYPE_INT       1
#define ER_KV_PROPTYPE_FLOAT     2
#define ER_KV_PROPTYPE_BOOL      3
#define ER_KV_PROPTYPE_STRING    4

#define ER_KV_CONDITION_EQUAL    1
#define ER_KV_CONDITION_NEQUAL   2
#define ER_KV_CONDITION_LESS     3
#define ER_KV_CONDITION_GREAT    4
#define ER_KV_CONDITION_CONTAINS 5

KeyValues kvERData;

void ER_OnModuleStart() {
    ER_KV_Load();
    RegAdminCmd("confogl_erdata_reload", ER_KV_Cmd_Reload, ADMFLAG_CONFIG);
    HookEvent("round_start", ER_Event_RoundStart);
}

void ER_OnModuleEnd() {
    ER_KV_Close();
}

void ER_KV_Close() {
    if (kvERData == null)
        return;

    delete kvERData;
}

void ER_KV_Load() {
    char szNameBuff[PLATFORM_MAX_PATH];
    char szDescBuff[256];
    char szValBuff[32];
    kvERData = new KeyValues("EntityRemover");

    // Build our filepath
    BuildConfigPath(szNameBuff, sizeof(szNameBuff), "entityremove.txt");
    if (!kvERData.ImportFromFile(szNameBuff)) {
        ER_KV_Close();
        return;
    }

    // Create cvars for all entity removes
    kvERData.GotoFirstSubKey();
    do {
        kvERData.GotoFirstSubKey();
        do {
            kvERData.GetString("cvar",      szNameBuff, sizeof(szNameBuff));
            kvERData.GetString("cvar_desc", szDescBuff, sizeof(szDescBuff));
            kvERData.GetString("cvar_val",  szValBuff,  sizeof(szValBuff));
            CreateConVarEx(szNameBuff, szValBuff, szDescBuff);
        } while (kvERData.GotoNextKey());
        kvERData.GoBack();
    } while (kvERData.GotoNextKey());
    kvERData.Rewind();
}

Action ER_KV_Cmd_Reload(int iClient, int iArgs) {
    if (!IsPluginEnabled())
        return Plugin_Continue;

    ReplyToCommand(iClient, "[ER] Reloading EntityRemoveData");
    ER_KV_Reload();
    return Plugin_Handled;
}

void ER_KV_Reload() {
    ER_KV_Close();
    ER_KV_Load();
}

bool ER_KV_TestCondition(int iLHSVal, int iRHSVal, int iCondition) {
    switch (iCondition) {
        case ER_KV_CONDITION_EQUAL: {
            return iLHSVal == iRHSVal;
        }
        case ER_KV_CONDITION_NEQUAL: {
            return iLHSVal != iRHSVal;
        }
        case ER_KV_CONDITION_LESS: {
            return iLHSVal < iRHSVal;
        }
        case ER_KV_CONDITION_GREAT: {
            return iLHSVal > iRHSVal;
        }
    }

    return false;
}

bool ER_KV_TestConditionFloat(float fLHSVal, float fRHSVal, int iCondition) {
    switch (iCondition) {
        case ER_KV_CONDITION_EQUAL: {
            return fLHSVal == fRHSVal;
        }
        case ER_KV_CONDITION_NEQUAL: {
            return fLHSVal != fRHSVal;
        }
        case ER_KV_CONDITION_LESS: {
            return fLHSVal < fRHSVal;
        }
        case ER_KV_CONDITION_GREAT: {
            return fLHSVal > fRHSVal;
        }
    }

    return false;
}

bool ER_KV_TestConditionString(char[] szLHSVal, char[] szRHSVal, int iCondition) {
    switch (iCondition) {
        case ER_KV_CONDITION_EQUAL: {
            return strcmp(szLHSVal, szRHSVal) == 0;
        }
        case ER_KV_CONDITION_NEQUAL: {
            return strcmp(szLHSVal, szRHSVal) != 0;
        }
        case ER_KV_CONDITION_CONTAINS: {
            return StrContains(szLHSVal, szRHSVal) != -1;
        }
    }

    return false;
}

// Returns true if the entity is still alive (not killed)
int ER_KV_ParseEntity(KeyValues kv, int iEntity) {
    char szBuffer[64];
    char szMapName[64];
    // Check CVAR for this entry
    kv.GetString("cvar", szBuffer, sizeof(szBuffer));
    if (strlen(szBuffer) && !FindConVarEx(szBuffer).BoolValue)
        return true;
    // Check MapName for this entry
    GetCurrentMap(szMapName, sizeof(szMapName));
    kv.GetString("map", szBuffer, sizeof(szBuffer));
    if (strlen(szBuffer) && StrContains(szBuffer, szMapName) == -1)
        return true;
    kv.GetString("excludemap", szBuffer, sizeof(szBuffer));
    if (strlen(szBuffer) && StrContains(szBuffer, szMapName) != -1)
        return true;
    // Do property check for this entry
    kv.GetString("property", szBuffer, sizeof(szBuffer));
    if (strlen(szBuffer)) {
        int iPropType = kv.GetNum("proptype");
        switch (iPropType) {
            case ER_KV_PROPTYPE_INT, ER_KV_PROPTYPE_BOOL: {
                int iRHSVal = kv.GetNum("propval");
                int iLHSVal = GetEntProp(iEntity, view_as<PropType>(kv.GetNum("propdata")), szBuffer);
                if (!ER_KV_TestCondition(iLHSVal, iRHSVal, kv.GetNum("condition")))
                    return true;
            }
            case ER_KV_PROPTYPE_FLOAT: {
                float fRHSVal = kv.GetFloat("propval");
                float fLHSVal = GetEntPropFloat(iEntity, view_as<PropType>(kv.GetNum("propdata")), szBuffer);
                if (!ER_KV_TestConditionFloat(fLHSVal, fRHSVal, kv.GetNum("condition")))
                    return true;
            }
            case ER_KV_PROPTYPE_STRING: {
                char szRHSVal[64];
                char szLHSVal[64];
                kv.GetString("propval", szRHSVal, sizeof(szRHSVal));
                GetEntPropString(iEntity, view_as<PropType>(kv.GetNum("propdata")), szBuffer, szLHSVal, sizeof(szLHSVal));
                if (!ER_KV_TestConditionString(szLHSVal, szRHSVal, kv.GetNum("condition")))
                    return true;
            }
        }
    }

    return ER_KV_TakeAction(kv.GetNum("action"), iEntity);
}

// Returns true if the entity is still alive (not killed)
int ER_KV_TakeAction(int iAction, int iEntity) {
    switch (iAction) {
        case ER_KV_ACTION_KILL: {
            RemoveEntity(iEntity);
            return false;
        }
        default: {
            LogError("[ER] ParseEntity Encountered bad action!");
        }
    }
    return true;
}

void ER_Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    CreateTimer(0.3,  ER_Timer_RoundStart, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action ER_Timer_RoundStart(Handle hTimer) {
    if (!IsPluginEnabled())
        return Plugin_Stop;

    char szBuffer[64];
    if (kvERData != null)
        kvERData.Rewind();

    int iEntCount = GetEntityCount();
    for (int i = MaxClients + 1; i <= iEntCount; i++) {
        if (IsValidEntity(i)) {
            GetEdictClassname(i, szBuffer, sizeof(szBuffer));
            if (kvERData != null && kvERData.JumpToKey(szBuffer)) {
                kvERData.GotoFirstSubKey();
                do {
                    // Parse each entry for this entity's classname
                    // Stop if we run out of entries or we have killed the entity
                    if (!ER_KV_ParseEntity(kvERData, i))
                        break;
                } while (kvERData.GotoNextKey());
                kvERData.Rewind();
            }
        }
    }

    return Plugin_Stop;
}