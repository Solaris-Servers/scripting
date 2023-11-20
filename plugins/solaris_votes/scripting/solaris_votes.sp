#pragma semicolon 1
#pragma newdecls required

#include <colors>
#include <nativevotes>
#include <l4d2_changelevel>
#include <connecthook>
#include <SteamWorks>
#include <readyup>

#include <solaris/team_manager>
#include <solaris/stocks>

#undef REQUIRE_PLUGIN
#include <confogl>
#define REQUIRE_PLUGIN

// Modules
#include "modules/globals.sp"
#include "modules/pools.sp"
#include "modules/voting.sp"
#include "modules/natives.sp"
// Votes
#include "votes/callvote.sp"
#include "votes/match.sp"
#include "votes/password.sp"
#include "votes/setscores.sp"
#include "votes/slots.sp"

public Plugin myinfo = {
    name        = "[Solaris] Votes",
    author      = "0x0c, elias",
    description = "Solaris Servers Vote Manager",
    version     = "1.0.0",
    url         = "https://solaris-servers.ru/"
};

public APLRes AskPluginLoad2(Handle hMe, bool bLate, char[] szErr, int iErrSize) {
    return Natives_AskPluginLoad2();
}

public void OnPluginStart() {
    Globals_OnPluginStart();
    Voting_OnPluginStart();

    // initiate voting modules
    CallVote_OnPluginStart();
    Match_OnPluginStart();
    Password_OnPluginStart();
    Scores_OnPluginStart();
    Slots_OnPluginStart();

    LoadTranslations("l4d360ui.phrases");
}

public void OnAllPluginsLoaded() {
    Globals_OnAllPluginsLoaded();
}

public void OnLibraryAdded(const char[] szName) {
    Globals_OnLibraryAdded(szName);
}

public void OnLibraryRemoved(const char[] szName) {
    Globals_OnLibraryRemoved(szName);
}

public void OnPluginEnd() {
    Password_OnPluginEnd();
}

public void OnConfigsExecuted() {
    Globals_OnConfigsExecuted();
    Password_OnConfigsExecuted();
}

public void OnMapStart() {
    Globals_OnMapStart();
    CallVote_OnMapStart();
}

public void OnMapEnd() {
    Globals_OnMapEnd();
}

public void OnClientConnected(int iClient) {
    Globals_OnClientConnected(iClient);
}

public void OnClientDisconnect(int iClient) {
    Globals_OnClientDisconnect(iClient);
}

public void OnRoundIsLive() {
    Globals_OnRoundIsLive();
}

public void OnMixStarted() {
    Globals_OnMixStarted();
}

public void OnMixStopped() {
    Globals_OnMixStopped();
}

// - Prevent players from joining in some circumstances -
public Action OnClientPreConnect(const char[] szName, const char[] szPw, const char[] szIp, const char[] szSteamId, char szRejectReason[255]) {
    if (Password_OnClientPreConnect(szPw, szSteamId, szRejectReason) == Plugin_Stop)
        return Plugin_Stop;
    if (CallVote_OnClientPreConnect(szSteamId, szRejectReason) == Plugin_Stop)
        return Plugin_Stop;
    return Plugin_Continue;
}