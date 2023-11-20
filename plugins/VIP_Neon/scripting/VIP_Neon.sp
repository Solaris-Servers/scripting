#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <vip_core>

#define LASER_BEAM "materials/sprites/laserbeam.vmt"

enum {
    eNeon = 0,
    eAura,
    eTrails,
    eColorsMenu,
    eSize
};

static const char g_szFeature[][] = {
    "NEON",       // eNeon
    "AURA",       // eAura
    "TRAILS",     // eTrails
    "COLORS_MENU" // eColorsMenu
};

int  g_iClientColor[MAXPLAYERS + 1][4];
int  g_iRandomColor[MAXPLAYERS + 1][4];
int  g_iNeon       [MAXPLAYERS + 1];
int  g_iTrail      [MAXPLAYERS + 1];
int  g_iClientItem [MAXPLAYERS + 1];

bool g_bVipAvailable;

KeyValues g_kvSettings;
Menu      g_mColors;
Cookie    g_cSettings;

public Plugin myinfo = {
    name        = "[VIP] Neon/Aura/Trails",
    author      = "R1KO",
    description = "VIP Neon/Aura/Trails",
    version     = "3.0.3 R",
    url         = "https://hlmod.ru/"
}

public void OnPluginStart() {
    g_cSettings = new Cookie("VIP_Neon", "VIP_Neon", CookieAccess_Public);

    g_mColors = new Menu(Handler_ColorsMenu, MENU_ACTIONS_ALL);
    g_mColors.ExitBackButton = true;
    g_mColors.SetTitle("Neon Color\n ");

    HookEvent("round_start",        Event_RoundStart);
    HookEvent("player_team",        Event_PlayerTeam);
    HookEvent("defibrillator_used", Event_PlayerDefibUsed);
    HookEvent("survivor_rescued",   Event_PlayerRescued);
    HookEvent("player_death",       Event_PlayerDeath);

    if (VIP_IsVIPLoaded()) VIP_OnVIPLoaded();
    LoadTranslations("vip_modules.phrases");
    LoadTranslations("vip_neon.phrases");
}

public void VIP_OnVIPLoaded() {
    VIP_RegisterFeature(g_szFeature[eNeon],       BOOL,          _, OnToggleItem);
    VIP_RegisterFeature(g_szFeature[eAura],       BOOL,          _, OnToggleItem);
    VIP_RegisterFeature(g_szFeature[eTrails],     BOOL,          _, OnToggleItem);
    VIP_RegisterFeature(g_szFeature[eColorsMenu],    _, SELECTABLE, OnSelectItem, _, OnDrawItem);
}

public void OnAllPluginsLoaded() {
    g_bVipAvailable = LibraryExists("vip_core");
}

public void OnLibraryAdded(const char[] szName) {
    if (strcmp(szName, "vip_core") != 0) return;
    g_bVipAvailable = true;
}

public void OnLibraryRemoved(const char[] szName) {
    if (strcmp(szName, "vip_core") != 0) return;
    g_bVipAvailable = false;
}

public void OnPluginEnd() {
    if (g_bVipAvailable) VIP_UnregisterMe();
    for (int i = 1; i <= MaxClients; i++) {
        DisableFeatures(i, true, true, true);
    }
}

public void OnEntityCreated(int iEnt, const char[] szClsName) {
    if (strcmp(szClsName, "env_spritetrail", false) != 0) return;
    FixSpriteTrail(iEnt);
}

/**
 * Prepare stuff
**/
public void OnMapStart() {
    // Fix Sprite Trail
    int iIdx = -1;
    while ((iIdx = FindEntityByClassname(iIdx, "env_spritetrail")) != -1) {
        if (!IsValidEdict(iIdx)) continue;
        FixSpriteTrail(iIdx);
    }
    // Precache laser beam sprite
    PrecacheModel(LASER_BEAM, true);
    // Prepare Menu
    RemoveAllMenuItems(g_mColors);
    if (g_kvSettings != null)
        delete g_kvSettings;
    g_kvSettings = new KeyValues("Neon_Colors");
    if (!g_kvSettings.ImportFromFile("addons/sourcemod/data/vip/modules/neon_colors.ini")) {
        delete g_kvSettings;
        g_kvSettings = null;
        SetFailState("Couldn't parse file \"addons/sourcemod/data/vip/modules/neon_colors.ini\"");
    }
    g_kvSettings.Rewind();
    if (g_kvSettings.JumpToKey("Colors") && g_kvSettings.GotoFirstSubKey(false)) {
        char szColor[64];
        char szName [64];
        do {
            if (g_kvSettings.GetSectionName(szColor, sizeof(szColor))) {
                FormatEx(szName, sizeof(szName), "%t", szColor);
                g_mColors.AddItem(szColor, szName);
            }
        } while (g_kvSettings.GotoNextKey(false));
    }
    g_kvSettings.Rewind();
}

public void OnMapEnd() {
    for (int i = 1; i <= MaxClients; i++) {
        DisableFeatures(i, true, true, true);
    }
}

public void OnClientDisconnect(int iClient) {
    ResetClientColor(iClient);
    ResetRandomColor(iClient);
    DisableFeatures(iClient, true, true, true);
}

public void VIP_OnVIPClientLoaded(int iClient) {
    ResetClientColor(iClient);
    ResetRandomColor(iClient);
    DisableFeatures(iClient, true, true, true);

    bool bHasAccess = false;
    for (int i = 0; i < eSize; i++) {
        if (VIP_GetClientFeatureStatus(iClient, g_szFeature[i]) != NO_ACCESS) {
            bHasAccess = true;
            break;
        }
    }
    if (!bHasAccess) return;
    char szColor[64];
    g_cSettings.Get(iClient, szColor, sizeof(szColor));
    if (szColor[0] == 0 || !LoadClientColor(iClient, szColor)) {
        g_iClientItem[iClient] = 0;
        g_mColors.GetItem(g_iClientItem[iClient], szColor, sizeof(szColor));
        g_cSettings.Set(iClient, szColor);
        LoadClientColor(iClient, szColor);
    } else {
        g_iClientItem[iClient] = UTIL_GetItemIndex(szColor);
    }
}

public void VIP_OnPlayerSpawn(int iClient, int iTeam, bool bIsVIP) {
    if (!bIsVIP) return;
    bool bNeon   = VIP_IsClientFeatureUse(iClient, g_szFeature[eNeon]);
    bool bAura   = VIP_IsClientFeatureUse(iClient, g_szFeature[eAura]);
    bool bTrails = VIP_IsClientFeatureUse(iClient, g_szFeature[eTrails]);
    if (bNeon || bAura || bTrails) EnableFeatures(iClient, bNeon, bAura, bTrails);
}

public void VIP_OnVIPClientRemoved(int iClient, const char[] szReason, int iAdmin) {
    DisableFeatures(iClient, true, true, true);
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    for (int i = 1; i <= MaxClients; i++) {
        DisableFeatures(i, true, true, true);
        if (!IsClientInGame(i)) continue;
        if (IsFakeClient(i))    continue;
        RequestFrame(OnNextFrame, GetClientUserId(i));
    }
}

void Event_PlayerTeam(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (eEvent.GetBool("disconnect")) return;

    int iUserId = eEvent.GetInt("userid");
    int iClient = GetClientOfUserId(iUserId);
    if (iClient <= 0)             return;
    if (!IsClientInGame(iClient)) return;
    if (IsFakeClient(iClient))    return;

    int iTeam    = eEvent.GetInt("team");
    int iOldTeam = eEvent.GetInt("oldteam");
    if (iTeam == 2 && iOldTeam != 2) RequestFrame(OnNextFrame, iUserId);
    if (iTeam != 2 && iOldTeam == 2) DisableFeatures(iClient, true, true, true);
}

void Event_PlayerDefibUsed(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iUserId = eEvent.GetInt("subject");
    int iClient = GetClientOfUserId(iUserId);
    if (iClient <= 0) return;
    RequestFrame(OnNextFrame, iUserId);
}

void Event_PlayerRescued(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iUserId = eEvent.GetInt("victim");
    int iClient = GetClientOfUserId(iUserId);
    if (iClient <= 0) return;
    RequestFrame(OnNextFrame, iUserId);
}

void OnNextFrame(int iUserId) {
    int iClient = GetClientOfUserId(iUserId);
    if (iClient <= 0) return;
    bool bNeon   = VIP_IsClientFeatureUse(iClient, g_szFeature[eNeon]);
    bool bAura   = VIP_IsClientFeatureUse(iClient, g_szFeature[eAura]);
    bool bTrails = VIP_IsClientFeatureUse(iClient, g_szFeature[eTrails]);
    if (bNeon || bAura || bTrails) EnableFeatures(iClient, bNeon, bAura, bTrails);
}

void Event_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0) return;
    DisableFeatures(iClient, true, true, true);
}

/**
 * Menu
**/
int Handler_ColorsMenu(Menu mMenu, MenuAction maAction, int iClient, int iItem) {
    switch (maAction) {
        case MenuAction_Cancel: {
            if (iItem == MenuCancel_ExitBack)
                VIP_SendClientVIPMenu(iClient);
        }
        case MenuAction_Select: {
            char szColor[64];
            mMenu.GetItem(iItem, szColor, sizeof(szColor));
            g_iClientItem[iClient] = iItem;
            if (LoadClientColor(iClient, szColor)) {
                ResetRandomColor(iClient);
                bool bNeon   = VIP_IsClientFeatureUse(iClient, g_szFeature[eNeon]);
                bool bAura   = VIP_IsClientFeatureUse(iClient, g_szFeature[eAura]);
                bool bTrails = VIP_IsClientFeatureUse(iClient, g_szFeature[eTrails]);
                g_cSettings.Set(iClient, szColor);
                EnableFeatures(iClient, bNeon, bAura, bTrails);
            }
            g_mColors.DisplayAt(iClient, mMenu.Selection, MENU_TIME_FOREVER);
        }
        case MenuAction_DisplayItem: {
            if (g_iClientItem[iClient] == iItem) {
                char szColor[64];
                mMenu.GetItem(iItem, szColor, sizeof(szColor));
                Format(szColor, sizeof(szColor), "%t [Selected]", szColor);
                return RedrawMenuItem(szColor);
            }
        }
        case MenuAction_DrawItem: {
            if (g_iClientItem[iClient] == iItem)
                return ITEMDRAW_DISABLED;
        }
    }
    return 0;
}

Action OnToggleItem(int iClient, const char[] szFeatureName, VIP_ToggleState OldStatus, VIP_ToggleState &NewStatus) {
    if (strcmp(szFeatureName, g_szFeature[eNeon]) == 0) {
        if (NewStatus == ENABLED) EnableFeatures(iClient,  true, false, false);
        else                      DisableFeatures(iClient, true, false, false);
    }
    if (strcmp(szFeatureName, g_szFeature[eAura]) == 0) {
        if (NewStatus == ENABLED) EnableFeatures(iClient,  false, true, false);
        else                      DisableFeatures(iClient, false, true, false);
    }
    if (strcmp(szFeatureName, g_szFeature[eTrails]) == 0) {
        if (NewStatus == ENABLED) EnableFeatures(iClient,  false, false, true);
        else                      DisableFeatures(iClient, false, false, true);
    }
    return Plugin_Continue;
}

bool OnSelectItem(int iClient, const char[] szFeatureName) {
    g_mColors.Display(iClient, MENU_TIME_FOREVER);
    return false;
}

int OnDrawItem(int iClient, const char[] szFeatureName, int iStyle) {
    iStyle = ITEMDRAW_DISABLED;
    for (int i = 0; i < eSize - 1; i++) {
        if (!VIP_IsClientFeatureUse(iClient, g_szFeature[i])) continue;
        return ITEMDRAW_DEFAULT;
    }
    return iStyle;
}

/**
 * Prepare colors
**/
bool LoadClientColor(int iClient, const char[] szColor) {
    g_kvSettings.Rewind();
    if (g_kvSettings.JumpToKey("Colors")) {
        char szBuffer[64];
        g_kvSettings.GetString(szColor, szBuffer, sizeof(szBuffer));
        if (strcmp(szBuffer, "randomcolor") == 0) {
            g_iClientColor[iClient][2] = -1;
        } else {
            g_kvSettings.GetColor(szColor, g_iClientColor[iClient][0], g_iClientColor[iClient][1], g_iClientColor[iClient][2], g_iClientColor[iClient][3]);
        }
        g_kvSettings.Rewind();
        return true;
    }
    return false;
}

void ResetClientColor(int iClient) {
    for (int i = 0; i < 4; i++) {
        g_iClientColor[iClient][i] = 0;
    }
}

void ResetRandomColor(int iClient) {
    for (int i = 0; i < 4; i++) {
        g_iRandomColor[iClient][i] = 0;
    }
}

/**
 * Features
**/
void EnableFeatures(int iClient, bool bNeon = true, bool bAura = true, bool bTrails = true) {
    // Safe check
    if (iClient <= 0)                 return;
    if (!IsClientInGame(iClient))     return;
    if (GetClientTeam(iClient) != 2)  return;
    if (!IsPlayerAlive(iClient))      return;

    // Get player position
    float fOrigin[3];
    GetClientAbsOrigin(iClient, fOrigin);

    // Get color
    char szColor[16];
    int  iColor [4];
    switch (g_iClientColor[iClient][2]) {
        case -1: {
            if (g_iRandomColor[iClient][0] && g_iRandomColor[iClient][1] && g_iRandomColor[iClient][2] && g_iRandomColor[iClient][3]) {
                iColor[0] = g_iRandomColor[iClient][0];
                iColor[1] = g_iRandomColor[iClient][1];
                iColor[2] = g_iRandomColor[iClient][2];
                iColor[3] = g_iRandomColor[iClient][3];
            } else {
                g_iRandomColor[iClient][0] = iColor[0] = GetRandomInt(0, 255);
                g_iRandomColor[iClient][1] = iColor[1] = GetRandomInt(0, 255);
                g_iRandomColor[iClient][2] = iColor[2] = GetRandomInt(0, 255);
                g_iRandomColor[iClient][3] = iColor[3] = 255;
            }
            FormatEx(szColor, sizeof(szColor), "%d %d %d %d", iColor[0], iColor[1], iColor[2], iColor[3]);
        }
        default: {
            ResetRandomColor(iClient);
            iColor[0] = g_iClientColor[iClient][0];
            iColor[1] = g_iClientColor[iClient][1];
            iColor[2] = g_iClientColor[iClient][2];
            iColor[3] = g_iClientColor[iClient][3];
            FormatEx(szColor, sizeof(szColor), "%d %d %d %d", g_iClientColor[iClient][0], g_iClientColor[iClient][1], g_iClientColor[iClient][2], g_iClientColor[iClient][3]);
        }
    }

    /**
     * NEON
     **/
    if (bNeon) {
        if (g_iNeon[iClient] != 0) {
            DispatchKeyValue(g_iNeon[iClient], "_light", szColor);
        } else {
            g_iNeon[iClient] = CreateEntityByName("light_dynamic");
            DispatchKeyValue(g_iNeon[iClient], "brightness", "4");
            DispatchKeyValue(g_iNeon[iClient], "_light",           szColor);
            DispatchKeyValue(g_iNeon[iClient], "spotlight_radius", "50");
            DispatchKeyValue(g_iNeon[iClient], "distance",         "150");
            DispatchKeyValue(g_iNeon[iClient], "style",            "0");
            SetEntPropEnt(g_iNeon[iClient], Prop_Send, "m_hOwnerEntity", iClient);
            DispatchSpawn(g_iNeon[iClient]);

            AcceptEntityInput(g_iNeon[iClient], "TurnOn");
            TeleportEntity(g_iNeon[iClient], fOrigin, NULL_VECTOR, NULL_VECTOR);
            SetVariantString("!activator");
            AcceptEntityInput(g_iNeon[iClient], "SetParent", iClient, g_iNeon[iClient], 0);
        }
    }
    /**
     * AURA
     **/
    if (bAura) {
        SetEntProp(iClient, Prop_Send, "m_glowColorOverride", iColor[0] + (iColor[1] << 8) + (iColor[2] << 16));
        SetEntProp(iClient, Prop_Send, "m_iGlowType",     3);
        SetEntProp(iClient, Prop_Send, "m_nGlowRange",    99999);
        SetEntProp(iClient, Prop_Send, "m_nGlowRangeMin", 0);
    }
    /**
     * TRAILS
     **/
    if (bTrails) {
        if (g_iTrail[iClient] != 0) {
            DispatchKeyValue(g_iTrail[iClient], "rendercolor", szColor);
        } else {
            g_iTrail[iClient] = CreateEntityByName("env_spritetrail");
            DispatchKeyValue(g_iTrail[iClient], "lifetime",    "2.0");
            DispatchKeyValue(g_iTrail[iClient], "startwidth",  "8.0");
            DispatchKeyValue(g_iTrail[iClient], "endwidth",    "2.0");
            DispatchKeyValue(g_iTrail[iClient], "spritename",  LASER_BEAM);
            DispatchKeyValue(g_iTrail[iClient], "rendermode",  "5");
            DispatchKeyValue(g_iTrail[iClient], "rendercolor", szColor);
            DispatchKeyValue(g_iTrail[iClient], "renderamt",   "255");
            DispatchSpawn(g_iTrail[iClient]);

            fOrigin[2] += 10;
            TeleportEntity(g_iTrail[iClient], fOrigin, NULL_VECTOR, NULL_VECTOR);
            SetVariantString("!activator");

            AcceptEntityInput(g_iTrail[iClient], "SetParent", iClient);
            AcceptEntityInput(g_iTrail[iClient], "ShowSprite");
            AcceptEntityInput(g_iTrail[iClient], "Start");
        }
    }
}

void DisableFeatures(int iClient, bool bNeon = true, bool bAura = true, bool bTrails = true) {
    // Remove Neon
    if (bNeon) {
        if (g_iNeon[iClient] && IsValidEdict(g_iNeon[iClient])) {
            AcceptEntityInput(g_iNeon[iClient], "TurnOff");
            AcceptEntityInput(g_iNeon[iClient], "Kill");
        }
        g_iNeon[iClient] = 0; // Clear index
    }
    // Remove Aura
    if (bAura && IsClientInGame(iClient)) {
        SetEntityRenderColor(iClient, 255, 255, 255, 255);
        SetEntProp(iClient, Prop_Send, "m_glowColorOverride", 0);
        SetEntProp(iClient, Prop_Send, "m_iGlowType",         0);
        SetEntProp(iClient, Prop_Send, "m_nGlowRange",        0);
        SetEntProp(iClient, Prop_Send, "m_nGlowRangeMin",     0);
    }
    // Remove Trails
    if (bTrails) {
        if (g_iTrail[iClient] && IsValidEdict(g_iTrail[iClient])) {
            AcceptEntityInput(g_iTrail[iClient], "Kill");
        }
        g_iTrail[iClient] = 0; // Clear index
    }
}

/**
 * Stocks
**/
stock int UTIL_GetItemIndex(const char[] szItemInfo) {
    char szColor[64];
    int  iSize = g_mColors.ItemCount;
    for (int i = 0; i < iSize; i++) {
        g_mColors.GetItem(i, szColor, sizeof(szColor));
        if (strcmp(szColor, szItemInfo) == 0)
            return i;
    }
    return -1;
}

stock void FixSpriteTrail(int iEnt) {
    SetVariantString("OnUser1 !self:SetScale:2:0.5:1");
    AcceptEntityInput(iEnt, "AddOutput");
    AcceptEntityInput(iEnt, "FireUser1");
}