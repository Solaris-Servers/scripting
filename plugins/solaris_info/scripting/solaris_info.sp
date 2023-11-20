#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <colors>
#include <l4d2util>

#include "modules/natives_and_forwards.sp"
#include "modules/cmds.sp"
#include "modules/hours.sp"
#include "modules/lerps.sp"
#include "modules/loading.sp"
#include "modules/loc.sp"
#include "modules/rank.sp"

public Plugin myinfo = {
    name        = "[Solaris] Info",
    author      = "0x0c, elias",
    description = "Solaris Servers Info",
    version     = "1.0.0",
    url         = "https://solaris-servers.ru/"
};

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    if (!AskPluginLoad2_Rank()) {
        strcopy(szError, iErrMax, "Config \"hlstats\" is not present in the databases.cfg!");
        return APLRes_Failure;
    }

    CreateNativesAndForwards();
    return APLRes_Success;
}

public void OnPluginStart() {
    OnModuleStart_Cmds();
    OnModuleStart_Rank();
}

public void OnClientConnected(int iClient) {
    if (IsFakeClient(iClient))
        return;

    OnClientConnected_Rank(iClient);
    OnClientConnected_Loading(iClient);
}

public void OnClientAuthorized(int iClient, const char[] szAuth) {
    if (szAuth[0] == 'B' || szAuth[9] == 'L')
        return;

    OnClientAuthorized_Hours(iClient);
    OnClientAuthorized_Rank(iClient, szAuth);
}

public void OnClientPutInServer(int iClient) {
    if (IsFakeClient(iClient))
        return;

    OnClientPutInServer_Lerp(iClient);
}

public void OnClientPostAdminCheck(int iClient) {
    if (IsFakeClient(iClient))
        return;

    OnClientPostAdminCheck_Loading(iClient);
}

public void OnClientSettingsChanged(int iClient) {
    if (iClient <= 0)
        return;

    if (!IsClientInGame(iClient))
        return;

    if (IsFakeClient(iClient))
        return;

    OnClientSettingsChanged_Lerp(iClient);
}

public void OnClientDisconnect(int iClient) {
    OnClientDisconnect_Rank(iClient);
}