#pragma newdecls required
#pragma semicolon 1

#if !defined(DEBUG_ALL)
    #define DEBUG_ALL 0
#endif

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <l4d2_changelevel>
#include <colors>
#include <solaris/stocks>

// includes
#include "includes/constants.sp"
#include "includes/functions.sp"
#include "includes/debug.sp"
#include "includes/survivorindex.sp"
#include "includes/configs.sp"
#include "includes/customtags.sp"
#include "includes/forwards.sp"

// modules
#include "modules/MapInfo.sp"
#include "modules/WeaponInformation.sp"
#include "modules/ReqMatch.sp"
#include "modules/CvarSettings.sp"
#include "modules/GhostTank.sp"
#include "modules/UnprohibitBosses.sp"
#include "modules/BotKick.sp"
#include "modules/EntityRemover.sp"
#include "modules/FinaleSpawn.sp"
#include "modules/BossSpawning.sp"
#include "modules/ClientSettings.sp"
#include "modules/ItemTracking.sp"

public Plugin myinfo = {
    name        = "Confogl's Competitive Mod",
    author      = "Confogl Team",
    description = "A competitive mod for L4D2",
    version     = "2.4.2",
    url         = "http://confogl.googlecode.com/"
}

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    RM_APL();
    Configs_APL();
    MI_APL();
    RegPluginLibrary("confogl");
    return APLRes_Success;
}

public void OnPluginStart() {
    Debug_OnModuleStart();
    Configs_OnModuleStart();
    MI_OnModuleStart();
    SI_OnModuleStart();
    WI_OnModuleStart();
    RM_OnModuleStart();
    CVS_OnModuleStart();
    ER_OnModuleStart();
    GT_OnModuleStart();
    UB_OnModuleStart();
    BK_OnModuleStart();
    FS_OnModuleStart();
    BS_OnModuleStart();
    CLS_OnModuleStart();
    IT_OnModuleStart();
    AddCustomServerTag("confogl");
}

public void OnPluginEnd() {
    CVS_OnModuleEnd();
    ER_OnModuleEnd();
    RemoveCustomServerTag("confogl");
}

public void OnMapStart() {
    MI_OnMapStart();
    RM_OnMapStart();
    BS_OnMapStart();
}

public void OnMapEnd() {
    MI_OnMapEnd();
    WI_OnMapEnd();
}

public void OnConfigsExecuted() {
    CVS_OnConfigsExecuted();
}