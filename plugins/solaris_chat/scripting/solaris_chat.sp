#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <sourcecomms>

#undef REQUIRE_PLUGIN
#include <confogl>
#define REQUIRE_PLUGIN

#include "modules/globals.sp"
#include "modules/core.sp"
#include "modules/adminsentinel.sp"
#include "modules/specs.sp"
#include "modules/vips.sp"
#include "modules/gagspec.sp"
#include "modules/selfmute.sp"
#include "modules/forwards.sp"
#include "modules/stocks.sp"

public Plugin myinfo = {
    name        = "[Solaris] Chat",
    author      = "elias",
    description = "Solaris Servers chat manager",
    version     = "1.0.0",
    url         = "https://solaris-servers.ru/"
};

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    Forwards_AskPluginLoad2();
    RegPluginLibrary("solaris_chat");
    return APLRes_Success;
}

public void OnPluginStart() {
    Core_OnModuleStart();
    AdminSentinel_OnModuleStart();
    Vips_OnModuleStart();
    GagSpec_OnModuleStart();
    SelfMute_OnModuleStart();
    LoadTranslations("common.phrases");
}

public void OnAllPluginsLoaded() {
    GagSpec_OnAllPluginsLoaded();
}

public void OnMapStart() {
    Vips_OnMapStart();
}

public void OnClientPutInServer(int iClient) {
    Globals_OnClientPutInServer(iClient);
    AdminSentinel_OnClientPutInServer(iClient);
    SelfMute_OnClientPutInServer(iClient);
}

public void OnClientDisconnect(int iClient) {
    Globals_OnClientDisconnect(iClient);
    AdminSentinel_OnClientDisconnect(iClient);
    SelfMute_OnClientDisconnect(iClient);
}