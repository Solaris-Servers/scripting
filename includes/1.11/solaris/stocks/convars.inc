#if defined __stocks_convars_included
    #endinput
#endif
#define __stocks_convars_included

stock void ResetConVarEx(ConVar cv) {
    if (cv == null)
        return;
    char szCvar[64];
    GetConVarName(cv, szCvar, sizeof(szCvar));
    char szBaseMode[16] = "none";
    SDK_GetGameModeBase(szBaseMode, sizeof(szBaseMode));
    if (StrEqual(szBaseMode, "none")) {
        FindConVar(szCvar).RestoreDefault();
        return;
    }
    char szGameMode[16];
    FindConVar("mp_gamemode").GetString(szGameMode, sizeof(szGameMode));
    if (StrEqual(szGameMode, "coop")) {
        cv.RestoreDefault();
        return;
    }
    char szValue[16];
    bool bFound = false;
    bool bBaseGameModeEquals = SDK_IsBaseGameModeEquals(szGameMode);
    KeyValues kv = new KeyValues("GameModes");
    if (kv.ImportFromFile("scripts/gamemodes.txt")) {
        if (kv.JumpToKey(szBaseMode, false)) {
            if (kv.JumpToKey("convar", false)) {
                kv.GetString(szCvar, szValue, sizeof(szValue), "not_found");
                if (!StrEqual(szValue, "not_found")) {
                    cv.SetString(szValue);
                    bFound = true;
                }
                kv.Rewind();
            }
            kv.Rewind();
        }
        if (!bBaseGameModeEquals && kv.JumpToKey(szGameMode, false)) {
            if (kv.JumpToKey("convar", false)) {
                kv.GetString(szCvar, szValue, sizeof(szValue), "not_found");
                if (!StrEqual(szValue, "not_found")) {
                    cv.SetString(szValue);
                    bFound = true;
                }
            }
        }
    }
    if (!bFound)
        cv.RestoreDefault();
    delete kv;
}