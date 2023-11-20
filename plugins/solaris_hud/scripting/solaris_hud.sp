#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <l4d2_ems_hud>

public Plugin myinfo = {
    name        = "[Solaris] Hud",
    author      = "elias [L4D2 EMS HUD Functions by sorallll]",
    description = "Solaris Servers Hud",
    version     = "1.0.0",
    url         = "https://solaris-servers.ru/"
};

public void OnPluginStart() {
    HookEvent("round_start", Event_RoundStart);
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    static ConVar cv;
    if (cv == null)
        cv = FindConVar("sn_main_name");

    if (cv == null)
        cv = FindConVar("hostname");

    cv.AddChangeHook(CvChg_NameChanged);

    char szBuffer[32];
    cv.GetString(szBuffer, sizeof(szBuffer));
    HUDSetLayout(HUD_MID_BOX, HUD_FLAG_ALIGN_RIGHT|HUD_FLAG_NOBG, szBuffer);
    HUDPlace(HUD_MID_BOX, 0.44, 0.0, 0.55, 0.1);
}

void CvChg_NameChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    HUDSetLayout(HUD_MID_BOX, HUD_FLAG_ALIGN_RIGHT|HUD_FLAG_NOBG, szNewVal);
    HUDPlace(HUD_MID_BOX, 0.44, 0.0, 0.55, 0.1);
}