#if defined __UNPROHIBIT_BOSSES_MODULE__
    #endinput
#endif
#define __UNPROHIBIT_BOSSES_MODULE__

ConVar UB_cvEnable;
bool   UB_bEnabled;

void UB_OnModuleStart() {
    UB_cvEnable = CreateConVarEx(
    "boss_unprohibit", "1",
    "Enable bosses spawning on all maps, even through they normally aren't allowed",
    FCVAR_NONE, true, 0.0, true, 1.0);
    UB_bEnabled = UB_cvEnable.BoolValue;
    UB_cvEnable.AddChangeHook(UB_ConVarChange);
}

void UB_ConVarChange(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    UB_bEnabled = UB_cvEnable.BoolValue;
}

Action UB_OnGetScriptValueInt(const char[] szKey, int &iRetVal) {
    if (IsPluginEnabled() && UB_bEnabled) {
        if (strcmp(szKey, "DisallowThreatType") == 0) {
            iRetVal = 0;
            return Plugin_Handled;
        }

        if (strcmp(szKey, "ProhibitBosses") == 0) {
            iRetVal = 0;
            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}

Action UB_OnGetMissionVSBossSpawning() {
    if (UB_bEnabled) {
        char szMapBuf[32];
        GetCurrentMap(szMapBuf, sizeof(szMapBuf));
        if (strcmp(szMapBuf, "c7m1_docks") == 0 || strcmp(szMapBuf, "c13m2_southpinestream") == 0)
            return Plugin_Continue;

        return Plugin_Handled;
    }

    return Plugin_Continue;
}