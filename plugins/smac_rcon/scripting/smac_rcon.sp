#pragma newdecls required
#pragma semicolon 1

/* SM Includes */
#include <sourcemod>
#include <sdktools>
#include <smac>

/* Globals */
bool   g_bRconLocked;
ConVar g_cvRconPass;
char   g_szRconRealPass[128];

/* Plugin Info */
public Plugin myinfo = {
    name        = "SMAC Rcon Locker",
    author      = SMAC_AUTHOR,
    description = "Protects against rcon crashes and exploits",
    version     = SMAC_VERSION,
    url         = SMAC_URL
};

/* Plugin Functions */
public void OnPluginStart() {
    // Convars.
    g_cvRconPass = FindConVar("rcon_password");
    g_cvRconPass.AddChangeHook(OnRconPassChanged);
}

public void OnConfigsExecuted() {
    if (g_bRconLocked)
        return;
    
    g_cvRconPass.GetString(g_szRconRealPass, sizeof(g_szRconRealPass));
    g_bRconLocked = true;
}

void OnRconPassChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    if (!g_bRconLocked)
        return;
    
    if (StrEqual(szNewVal, g_szRconRealPass))
        return;
    
    SMAC_Log("Rcon password changed to \"%s\". Reverting back to original config value.", szNewVal);
    g_cvRconPass.SetString(g_szRconRealPass);
}

public Action SMRCon_OnAuth(int iRconId, const char[] szAddress, const char[] szPassword, bool &bAllow) {
    SMAC_Log("Unauthorized RCON Login Detected! Failed auth from address: \"%s\", attempted password: \"%s\"", szAddress, szPassword);
    bAllow = false;
    return Plugin_Changed;
}

public Action SMRCon_OnCommand(int iRconId, const char[] szAddress, const char[] szCommand, bool &bAllow) {
    SMAC_Log("Unauthorized RCON command use detected! Failed auth from address: \"%s\", attempted command: \"%s\"", szAddress, szCommand);
    bAllow = false;
    return Plugin_Changed;
}