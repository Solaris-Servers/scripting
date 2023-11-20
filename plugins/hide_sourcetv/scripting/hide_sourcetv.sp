#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools_functions>
#include <sdkhooks>

static int g_iSourceBot = -1;

public Plugin myinfo = {
    name        = "[L4D/2] Hide SourceTV Bot",
    author      = "shqke",
    description = "Hides SourceTV bot from scoreboard",
    version     = "1.2",
    url         = "https://github.com/shqke/sp_public"
};

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    switch (GetEngineVersion()) {
        case Engine_Left4Dead2, Engine_Left4Dead: {
            return APLRes_Success;
        }
    }

    strcopy(szError, iErrMax, "Plugin only supports Left 4 Dead and Left 4 Dead 2.");
    return APLRes_SilentFailure;
}

public void OnPluginStart() {
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (!IsClientSourceTV(i))
            continue;

        OnClientPutInServer(i);
        break;
    }
}

public void OnClientPutInServer(int iClient) {
    if (!IsClientSourceTV(iClient))
        return;

    g_iSourceBot = iClient;

    int entPlayerResource = FindEntityByClassname(INVALID_ENT_REFERENCE, "terror_player_manager");
    if (!IsValidEdict(entPlayerResource))
        return;

    SDKHook(entPlayerResource, SDKHook_ThinkPost, Handler_ResourceThink);
}

public void OnClientDisconnect_Post(int client) {
    if (g_iSourceBot == -1)
        return;

    if (g_iSourceBot == client)
        g_iSourceBot = -1;
}

void Handler_ResourceThink(int iEnt) {
    if (g_iSourceBot == -1) {
        SDKUnhook(iEnt, SDKHook_ThinkPost, Handler_ResourceThink);
        return;
    }

    SetEntProp(iEnt, Prop_Send, "m_bConnected", 0, .element = g_iSourceBot);
}