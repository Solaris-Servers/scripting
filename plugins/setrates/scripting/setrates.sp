#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>

int g_iTickrate;

public void OnPluginStart() {
    g_iTickrate = GetCommandLineParamInt("-tickrate", 30);
}

public void OnAutoConfigsBuffered() {
    SetRates();
}

void SetRates() {
    FindConVar("sv_minrate").IntValue = g_iTickrate * 1000;
    FindConVar("sv_maxrate").IntValue = g_iTickrate * 1000;

    FindConVar("sv_minupdaterate").IntValue = g_iTickrate;
    FindConVar("sv_maxupdaterate").IntValue = g_iTickrate;

    FindConVar("sv_mincmdrate").IntValue = g_iTickrate;
    FindConVar("sv_maxcmdrate").IntValue = g_iTickrate;

    FindConVar("net_splitpacket_maxrate").IntValue = g_iTickrate * 1000 / 2;

    FindConVar("sv_client_min_interp_ratio").IntValue = 0;
    FindConVar("sv_client_max_interp_ratio").IntValue = 0;

    FindConVar("sv_clockcorrection_msecs").IntValue = 25;

    if (g_iTickrate > 30) {
        FindConVar("net_splitpacket_maxrate").FloatValue = 0.00001;
        FindConVar("fps_max").IntValue = 0;
    }
}