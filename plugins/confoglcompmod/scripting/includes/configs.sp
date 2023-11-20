#if defined __CONFOGL_CONFIGS__
    #endinput
#endif
#define __CONFOGL_CONFIGS__

static const char szCustomCfgDir[] = "cfgogl";

static ConVar cvCustomConfig;
static int    iDirSeparator;
static char   szConfigsPath  [PLATFORM_MAX_PATH];
static char   szCfgPath      [PLATFORM_MAX_PATH];
static char   szCustomCfgPath[PLATFORM_MAX_PATH];

void Configs_OnModuleStart() {
    InitPaths();
    cvCustomConfig = CreateConVarEx(
    "customcfg", "",
    "DONT TOUCH THIS CVAR! This is more magic bullshit!",
    FCVAR_DONTRECORD|FCVAR_UNLOGGED, false, 0.0, false, 0.0);
    char szCfgString[64];
    cvCustomConfig.GetString(szCfgString, sizeof(szCfgString));
    SetCustomCfg(szCfgString);
    cvCustomConfig.RestoreDefault();
}

void Configs_APL() {
    CreateNative("LGO_BuildConfigPath",  Native_BuildConfigPath);
    CreateNative("LGO_ExecuteConfigCfg", Native_ExecConfigCfg);
}

void InitPaths() {
    BuildPath(Path_SM, szConfigsPath, sizeof(szConfigsPath), "configs/confogl/");
    BuildPath(Path_SM, szCfgPath,     sizeof(szCfgPath),     "../../cfg/");
    iDirSeparator = szCfgPath[strlen(szCfgPath) - 1];
}

bool SetCustomCfg(const char[] szCfgName) {
    if (!strlen(szCfgName)) {
        szCustomCfgPath[0] = 0;
        cvCustomConfig.RestoreDefault();
        if (IsDebugEnabled())
            LogMessage("[Configs] Custom Config Path Reset - Using Default");
        return true;
    }
    Format(szCustomCfgPath, sizeof(szCustomCfgPath), "%s%s%c%s", szCfgPath, szCustomCfgDir, iDirSeparator, szCfgName);
    // Revert szCustomCfgPath
    if (!DirExists(szCustomCfgPath)) {
        LogError("[Configs] Custom config directory %s does not exist!", szCustomCfgPath);
        szCustomCfgPath[0] = 0;
        return false;
    }
    int iThisLen = strlen(szCustomCfgPath);
    if (iThisLen + 1 < sizeof(szCustomCfgPath)) {
        szCustomCfgPath[iThisLen]     = iDirSeparator;
        szCustomCfgPath[iThisLen + 1] = 0;
    } else {
        LogError("[Configs] Custom config directory %s path too long!", szCustomCfgPath);
        szCustomCfgPath[0] = 0;
        return false;
    }
    cvCustomConfig.SetString(szCfgName);
    return true;
}

void BuildConfigPath(char[] szBuffer, int iMaxLength, const char[] szFileName) {
    if (szCustomCfgPath[0]) {
        Format(szBuffer, iMaxLength, "%s%s", szCustomCfgPath, szFileName);
        if (FileExists(szBuffer)) {
            if (IsDebugEnabled())
                LogMessage("[Configs] Built custom config path: %s", szBuffer);
            return;
        } else if (IsDebugEnabled()) {
            LogMessage("[Configs] Custom config not available: %s", szBuffer);
        }
    }
    Format(szBuffer, iMaxLength, "%s%s", szConfigsPath, szFileName);
    if (IsDebugEnabled()) LogMessage("[Configs] Built default config path: %s", szBuffer);
}

void ExecuteCfg(const char[] szFileName) {
    if (strlen(szFileName) == 0)
        return;
    char szFilePath[PLATFORM_MAX_PATH];
    if (szCustomCfgPath[0]) {
        Format(szFilePath, sizeof(szFilePath), "%s%s", szCustomCfgPath, szFileName);
        if (FileExists(szFilePath)) {
            if (IsDebugEnabled())
                LogMessage("[Configs] Executing custom cfg file %s", szFilePath);
            ServerCommand("exec %s%s", szCustomCfgPath[strlen(szCfgPath)], szFileName);
            return;
        }
        else if (IsDebugEnabled()) {
            LogMessage("[Configs] Couldn't find custom cfg file %s, trying default", szFilePath);
        }
    }
    Format(szFilePath, sizeof(szFilePath), "%s%s", szCfgPath, szFileName);
    if (FileExists(szFilePath)) {
        if (IsDebugEnabled())
            LogMessage("[Configs] Executing default config %s", szFilePath);
        ServerCommand("exec %s", szFileName);
    } else {
        LogError("[Configs] Could not execute server config \"%s\", file not found", szFilePath);
    }
}

any Native_BuildConfigPath(Handle hPlugin, int iNumParams) {
    int iLength;
    GetNativeStringLength(3, iLength);
    char[] szFileName = new char[iLength + 1];
    GetNativeString(3, szFileName, iLength + 1);
    iLength = GetNativeCell(2);
    char[] szBuf = new char[iLength];
    BuildConfigPath(szBuf, iLength, szFileName);
    SetNativeString(1, szBuf, iLength);
    return 1;
}

any Native_ExecConfigCfg(Handle hPlugin, int iNumParams) {
    int iLength;
    GetNativeStringLength(1, iLength);
    char[] szFileName = new char[iLength + 1];
    GetNativeString(1, szFileName, iLength + 1);
    ExecuteCfg(szFileName);
    return 1;
}
