#pragma newdecls required
#pragma semicolon 1

/* SM Includes */
#include <sourcemod>
#include <sdktools>
#include <smac>
#include <solaris/stocks>

int m_nTickBase;

/* Plugin Info */
public Plugin myinfo = {
    name        = "SMAC L4D2 Exploit Fixes",
    author      = SMAC_AUTHOR,
    description = "Blocks general Left 4 Dead 2 cheats & exploits",
    version     = SMAC_VERSION,
    url         = SMAC_URL
};

/* Plugin Functions */
public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    if (GetEngineVersion() != Engine_Left4Dead2) {
        strcopy(szError, iErrMax, SMAC_MOD_ERROR);
        return APLRes_SilentFailure;
    }
    return APLRes_Success;
}

public void OnPluginStart() {
    if ((m_nTickBase = FindSendPropInfo("CCSPlayer", "m_nTickBase")) == -1)
        SetFailState("Property not found CCSPlayer::m_nTickBase");
    int iFlags = GetCommandFlags("spec_goto");
    SetCommandFlags("spec_goto", iFlags|FCVAR_CHEAT);
    // Hooks.
    HookEvent("player_team", Event_PlayerTeam);
}

void Event_PlayerTeam(Event eEvent, const char[] szName, bool bDontBroadcast) {
    bool bDisconnect = eEvent.GetBool("disconnect");
    if (bDisconnect)
        return;

    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0)
        return;

    if (!IsClientInGame(iClient))
        return;

    if (!IsPlayerAlive(iClient))
        return;

    SDK_PhysicsRemoveTouchedList(iClient);
}

public void OnPlayerRunCmdPre(int iClient, int iButtons) {
    // Ignore bots and not valid clients
    if (iClient <= 0)
        return;

    if (iClient > MaxClients)
        return;

    if (!IsClientInGame(iClient))
        return;

    if (IsFakeClient(iClient))
        return;

    if (GetEntData(iClient, m_nTickBase) < 0) {
        KeyValues kvInfo = new KeyValues("");
        kvInfo.SetNum("TickBase", GetEntData(iClient, m_nTickBase));
        if (SMAC_CheatDetected(iClient, Detection_TickBaseManipulation, kvInfo) == Plugin_Continue) {
            SMAC_LogAction(iClient, "was banned for using m_nTickBase manipulation (m_nTickBase = %d)", GetEntData(iClient, m_nTickBase));
            SMAC_Ban(iClient, "Banned for using m_nTickBase manipulation.");
        }
        delete kvInfo;
    }
}