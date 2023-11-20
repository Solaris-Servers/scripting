#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define NULL_VELOCITY view_as<float>({0.0, 0.0, 0.0})

bool g_bLateload;

public Plugin myinfo = {
    name        = "[L4D] Minigun survivor launcher fix",
    author      = "Accelerator, Electr0, elias, 0x0c",
    description = "Minigun survivor launcher fix",
    version     = "2.1",
    url         = "http://core-ss.org"
};

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    g_bLateload = bLate;
    return APLRes_Success;
}

public void OnPluginStart() {
    if (g_bLateload) {
        char szClsName[20];
        for (int i = MaxClients + 1; i <= GetEntityCount(); i++) {
            if (!IsValidEntity(i))
                continue;

            if (!GetEdictClassname(i, szClsName, sizeof(szClsName)))
                continue;

            OnEntityCreated(i, szClsName);
        }
    }
}

public Action OnPlayerRunCmd(int iClient, int &iButtons) {
    if (iClient < 0)
        return Plugin_Continue;

    if (iClient > MaxClients)
        return Plugin_Continue;

    if (!IsClientInGame(iClient))
        return Plugin_Continue;

    if (IsFakeClient(iClient))
        return Plugin_Continue;

    if (!IsUsingMinigun(iClient))
        return Plugin_Continue;

    if (!(iButtons & IN_JUMP))
        return Plugin_Continue;
    iButtons &= ~IN_JUMP;

    TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, NULL_VELOCITY);
    return Plugin_Continue;
}

public void OnEntityCreated(int iEnt, const char[] szClsName) {
    if (!IsItCase(szClsName))
        return;

    SDKHook(iEnt, SDKHook_Use, SDKHook_OnUseMinigun);
}

Action SDKHook_OnUseMinigun(int iEnt, int iActivator, int iCaller, UseType uType, float fValue) {
    if (iCaller <= 0)
        return Plugin_Continue;

    if (iCaller > MaxClients)
        return Plugin_Continue;

    if (!IsClientInGame(iCaller))
        return Plugin_Continue;

    if (GetClientTeam(iCaller) != 2)
        return Plugin_Continue;

    if (uType != Use_Toggle)
        return Plugin_Continue;

    if (!(GetEntityFlags(iCaller) & FL_ONGROUND))
        return Plugin_Handled;

    static float vEntPos[3];
    GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", vEntPos);

    static float vCallerPos[3];
    GetEntPropVector(iCaller, Prop_Data, "m_vecOrigin", vCallerPos);

    float fHeightDifference = vEntPos[2] - vCallerPos[2];
    if (fHeightDifference < 0.0)
        fHeightDifference = FloatAbs(fHeightDifference);

    if (fHeightDifference > 10.0)
        return Plugin_Handled;

    return Plugin_Continue;
}

bool IsItCase(const char[] szBuffer) {
    static char szClsNames[][] = {
        "prop_minigun",
        "prop_minigun_l4d1",
        "prop_mounted_machine_gun"
    };

    for (int i = 0; i < sizeof(szClsNames); i++) {
        if (strcmp(szClsNames[i], szBuffer) != 0)
            continue;
        return true;
    }

    return false;
}

bool IsUsingMinigun(int iClient) {
    return ((GetEntProp(iClient, Prop_Send, "m_usingMountedWeapon") > 0) || (GetEntProp(iClient, Prop_Send, "m_usingMountedGun") > 0));
}