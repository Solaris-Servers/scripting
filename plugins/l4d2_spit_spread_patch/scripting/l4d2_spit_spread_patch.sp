#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <left4dhooks>
#include <dhooks>
#include <sourcescramble>
#include <collisionhook>

//======================================================================================================
// GameData specific
//======================================================================================================

#define GAMEDATA_FILE           "l4d2_spit_spread_patch"
#define KEY_DETONATE            "CSpitterProjectile::Detonate"
#define KEY_SOLIDMASK           "CSpitterProjectile::PhysicsSolidMaskForEntity"
#define KEY_EVENT_KILLED        "CTerrorPlayer::Event_Killed"
#define KEY_DETONATE_FLAG_PATCH "CSpitterProjectile::Detonate__TraceFlag_patch"
#define KEY_SPREAD_FLAG_PATCH   "CInferno::Spread__TraceFlag_patch"
#define KEY_SPREAD_PASS_PATCH   "CInferno::Spread__PassEnt_patch"
#define KEY_TRACEHEIGHT_PATCH   "CTerrorPlayer::Event_Killed__TraceHeight_patch"

//======================================================================================================
// clean methodmap
//======================================================================================================

// TerrorNavArea
// Bitflags for TerrorNavArea.SpawnAttributes

methodmap TerrorNavArea {
    public TerrorNavArea(const float vPos[3]) {
        return view_as<TerrorNavArea>(L4D_GetNearestNavArea(vPos));
    }
    public bool Valid() {
        return this != view_as<TerrorNavArea>(0);
    }
    public bool HasSpawnAttributes(int iBits) {
        return (this.m_spawnAttributes & iBits) == iBits;
    }
    property int m_spawnAttributes {
        public get() {
            return L4D_GetNavArea_SpawnAttributes(view_as<Address>(this));
        }
    }
}

//======================================================================================================
// Helper identifier
//======================================================================================================

int g_iDetonateObj = -1;
ArrayList g_aDetonatePuddles;

//======================================================================================================
// Spread configuration
//======================================================================================================
enum {
    SAFEROOM_SPREAD_OFF,
    SAFEROOM_SPREAD_INTRO,
    SAFEROOM_SPREAD_ALL
};

ConVar g_cvSaferoomSpread;
int    g_iSaferoomSpread;
int    g_iTmpSaferoomSpread;

ConVar g_cvTraceHeight;
float  g_fTraceHeight;

ConVar g_cvMaxFlames;
int    g_iMaxFlames;

ConVar g_cvWaterCollision;
bool   g_bWaterCollision;

ConVar g_cvPropDamage;
float  g_fPropDamage;

StringMap g_smNoSpreadMaps;
StringMap g_smFilterClasses;

//======================================================================================================
// Plugin info
//======================================================================================================

public Plugin myinfo = {
    name        = "[L4D2] Spit Spread Patch",
    author      = "Forgetest",
    description = "Fix various spit spread issues.",
    version     = "1.21",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

//======================================================================================================
// Prepare SDK
//======================================================================================================

void LoadSDK() {
    GameData gdConf = new GameData(GAMEDATA_FILE);
    if (!gdConf) SetFailState("Missing gamedata \""...GAMEDATA_FILE..."\"");

    if (!MemoryPatch.CreateFromConf(gdConf, KEY_DETONATE_FLAG_PATCH).Enable())     SetFailState("Failed to enable patch \""...KEY_DETONATE_FLAG_PATCH..."\"");
    if (!MemoryPatch.CreateFromConf(gdConf, KEY_SPREAD_FLAG_PATCH).Enable())       SetFailState("Failed to enable patch \""...KEY_SPREAD_FLAG_PATCH..."\"");
    if (!MemoryPatch.CreateFromConf(gdConf, KEY_SPREAD_FLAG_PATCH..."2").Enable()) SetFailState("Failed to enable patch \""...KEY_SPREAD_FLAG_PATCH..."2"..."\"");
    if (!MemoryPatch.CreateFromConf(gdConf, KEY_SPREAD_PASS_PATCH).Enable())       SetFailState("Failed to enable patch \""...KEY_SPREAD_PASS_PATCH..."\"");
    if (!MemoryPatch.CreateFromConf(gdConf, KEY_SPREAD_PASS_PATCH..."2").Enable()) SetFailState("Failed to enable patch \""...KEY_SPREAD_PASS_PATCH..."2"..."\"");

    MemoryPatch mpPatch = MemoryPatch.CreateFromConf(gdConf, KEY_TRACEHEIGHT_PATCH);
    if (!mpPatch.Enable()) SetFailState("Failed to enable patch \""...KEY_TRACEHEIGHT_PATCH..."\"");

    // replace with custom memory
    StoreToAddress(mpPatch.Address + view_as<Address>(4), GetAddressOfCell(g_fTraceHeight), NumberType_Int32);

    DynamicDetour dhDetour = DynamicDetour.FromConf(gdConf, KEY_DETONATE);
    if (!dhDetour) SetFailState("Missing detour setup of \""...KEY_DETONATE..."\"");
    if (!dhDetour.Enable(Hook_Pre, DTR_OnDetonate_Pre))
        SetFailState("Failed to pre-detour \""...KEY_DETONATE..."\"");
    if (!dhDetour.Enable(Hook_Post, DTR_OnDetonate_Post))
        SetFailState("Failed to post-detour \""...KEY_DETONATE..."\"");
    delete dhDetour;

    dhDetour = DynamicDetour.FromConf(gdConf, KEY_SOLIDMASK);
    if (!dhDetour) SetFailState("Missing detour setup of \""...KEY_SOLIDMASK..."\"");
    if (!dhDetour.Enable(Hook_Post, DTR_OnPhysicsSolidMaskForEntity_Post))
        SetFailState("Failed to post-detour \""...KEY_SOLIDMASK..."\"");
    delete dhDetour;

    /**
     * Spit configuration: class
     *
     * Trace doesn't touch these classes.
     */
    g_smFilterClasses = new StringMap();

    char szBuffer[64], szBuffer2[64];
    for (int i = 1;
        FormatEx(szBuffer, sizeof(szBuffer), "SpitFilterClass%i", i)
        && GameConfGetKeyValue(gdConf, szBuffer, szBuffer, sizeof(szBuffer));
        i++) {
        g_smFilterClasses.SetValue(szBuffer, 0);
        PrintToServer("[SpitPatch] Read \"SpitFilterClass\" (%s)", szBuffer);
    }

    /**
     * Spread configuration: class
     *
     * (== 0) -> No spread (2 flames)
     * (>= 2) -> Custom flames
     */
    int iMaxFlames;
    for (int i = 1;
        FormatEx(szBuffer, sizeof(szBuffer), "SpreadFilterClass%i", i)
        && GameConfGetKeyValue(gdConf, szBuffer, szBuffer, sizeof(szBuffer))
        && FormatEx(szBuffer2, sizeof(szBuffer2), "SpreadFilterClass%i_maxflames", i)
        && GameConfGetKeyValue(gdConf, szBuffer2, szBuffer2, sizeof(szBuffer2));
        i++) {
        iMaxFlames = StringToInt(szBuffer2);
        iMaxFlames = iMaxFlames >= 2 ? iMaxFlames : 2; // indeed clamped to [2, cvarMaxFlames], a part here
        g_smFilterClasses.SetValue(szBuffer, iMaxFlames);
        PrintToServer("[SpitPatch] Read \"SpreadFilterClass\" (%s) [maxflames = %i]", szBuffer, iMaxFlames);
    }
    delete gdConf;
}

public void OnPluginStart() {
    LoadSDK();

    g_cvSaferoomSpread = CreateConVar(
    "l4d2_spit_spread_saferoom", "1",
    "Decides how the spit should spread in saferoom area. 0 = No spread, 1 = Spread on intro start area, 2 = Spread on every map.",
    FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0, true, 2.0);
    g_iSaferoomSpread = g_cvSaferoomSpread.IntValue;
    g_cvSaferoomSpread.AddChangeHook(ConVarChanged_SaferoomSpread);

    g_cvTraceHeight = CreateConVar(
    "l4d2_deathspit_trace_height", "240.0",
    "Decides the height the game trace will try to test for death spits. 240.0 = Default trace length.",
    FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0, false, 0.0);
    g_fTraceHeight = g_cvTraceHeight.FloatValue;
    g_cvTraceHeight.AddChangeHook(ConVarChanged_TraceHeight);

    g_cvMaxFlames = CreateConVar(
    "l4d2_spit_max_flames", "10",
    "Decides the max puddles a normal spit will create. Minimum = 2, Game default = 10.",
    FCVAR_NOTIFY|FCVAR_SPONLY, true, 2.0, false, 0.0);
    g_iMaxFlames = g_cvMaxFlames.IntValue;
    g_cvMaxFlames.AddChangeHook(ConVarChanged_MaxFlames);

    g_cvWaterCollision = CreateConVar(
    "l4d2_spit_water_collision", "0",
    "Decides whether the spit projectile will collide with water. 0 = No collision, 1 = Enable collision.",
    FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0, true, 1.0);
    g_bWaterCollision = g_cvWaterCollision.BoolValue;
    g_cvWaterCollision.AddChangeHook(ConVarChanged_WaterCollision);

    g_cvPropDamage = CreateConVar(
    "l4d2_spit_prop_damage", "10.0",
    "Amount of damage done to props that projectile bounces on. 0 = No damage",
    FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0, false, 0.0);
    g_fPropDamage = g_cvPropDamage.FloatValue;
    g_cvPropDamage.AddChangeHook(ConVarChanged_PropDamage);

    g_smNoSpreadMaps = new StringMap();
    RegServerCmd("spit_spread_saferoom_except", Cmd_SetSaferoomSpitSpreadException);

    g_aDetonatePuddles = new ArrayList();

    HookEvent("round_start", Event_RoundStart);
}

void ConVarChanged_SaferoomSpread(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iSaferoomSpread = cv.IntValue;
    RequestFrame(OnMapStart);
}

void ConVarChanged_TraceHeight(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fTraceHeight = cv.FloatValue;
}

void ConVarChanged_MaxFlames(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iMaxFlames = cv.IntValue;
}

void ConVarChanged_WaterCollision(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bWaterCollision = cv.BoolValue;
}

void ConVarChanged_PropDamage(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fPropDamage = cv.FloatValue;
}

Action Cmd_SetSaferoomSpitSpreadException(int iArgs) {
    if (!iArgs) {
        PrintToServer("[SM] Usage: spit_spread_saferoom_except <map>");
        return Plugin_Handled;
    }

    char szMap[64];
    GetCmdArg(1, szMap, sizeof(szMap));
    String_ToLower(szMap, sizeof(szMap));
    g_smNoSpreadMaps.SetValue(szMap, 0);
    PrintToServer("[SpitPatch] Set spread exception on \"%s\"", szMap);
    return Plugin_Handled;
}

//======================================================================================================

public void OnMapStart() {
    // global default
    g_iTmpSaferoomSpread = g_iSaferoomSpread;
    if (!g_iTmpSaferoomSpread)
        return;
    char szCurrentMap[64];
    GetCurrentMapLower(szCurrentMap, sizeof(szCurrentMap));
    // forbidden map
    g_smNoSpreadMaps.GetValue(szCurrentMap, g_iTmpSaferoomSpread);
    // intro map
    if (g_iSaferoomSpread == SAFEROOM_SPREAD_INTRO && !L4D_IsFirstMapInScenario())
        g_iTmpSaferoomSpread = SAFEROOM_SPREAD_OFF;
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_aDetonatePuddles.Clear();
}

//======================================================================================================

public void OnEntityCreated(int iEntity, const char[] szClsName) {
    if (szClsName[0] == 'i' && strcmp(szClsName, "insect_swarm") == 0) {
        SDKHook(iEntity, SDKHook_SpawnPost, SDK_OnSpawnPost);
    } else if (szClsName[0] == 's' && strcmp(szClsName, "spitter_projectile") == 0) {
        SDKHook(iEntity, SDKHook_SpawnPost, SDK_OnSpawnPost_Projectile);
    }
}

void SDK_OnSpawnPost(int iEntity) {
    if (g_iDetonateObj != -1)
        g_aDetonatePuddles.Push(EntIndexToEntRef(iEntity));
    SDKHook(iEntity, SDKHook_Think, SDK_OnThink);
}

void SDK_OnSpawnPost_Projectile(int iEntity) {
    SDKHook(iEntity, SDKHook_Touch, SDK_OnTouch);
}

Action SDK_OnThink(int iEntity) {
    float vPos[3];
    GetEntPropVector(iEntity, Prop_Data, "m_vecAbsOrigin", vPos);
    // Check if in water first
    float fDepth = GetDepthBeneathWater(vPos);
    if (fDepth > 0.0) {
        vPos[2] += fDepth;
        TeleportEntity(iEntity, vPos, NULL_VECTOR, NULL_VECTOR);
    }

    int iIdx = g_aDetonatePuddles.FindValue(EntIndexToEntRef(iEntity));
    if (iIdx != -1) {
        g_aDetonatePuddles.Erase(iIdx);
        int iMaxFlames = g_iMaxFlames;
        if (L4D2Direct_GetInfernoMaxFlames(iEntity) == 2) {
            // check if max flames customized
            int  iParent = GetEntPropEnt(iEntity, Prop_Data, "m_pParent");
            char szCls[64];
            if (iParent != -1 && GetEdictClassname(iParent, szCls, sizeof(szCls))) {
                if (g_smFilterClasses.GetValue(szCls, iParent) && iParent != 0)
                    iMaxFlames = iParent <= iMaxFlames ? iParent : iMaxFlames;
            }
            TerrorNavArea tNav = TerrorNavArea(vPos);
            if (tNav.Valid() && tNav.HasSpawnAttributes(NAV_SPAWN_CHECKPOINT)) {
                bool bIsStart = tNav.HasSpawnAttributes(NAV_SPAWN_PLAYER_START);
                if (!IsSaferoomSpreadAllowed(bIsStart)) {
                    iMaxFlames = 2;
                    CreateTimer(0.3, Timer_FixInvisibleSpit, EntIndexToEntRef(iEntity), TIMER_FLAG_NO_MAPCHANGE);
                }
            }
        }

        L4D2Direct_SetInfernoMaxFlames(iEntity, iMaxFlames);
    } else {
        // Check if invisbile spit
        if (fDepth == 0.0) {
            float vEnd[3];
            vEnd[0] = vPos[0];
            vEnd[1] = vPos[1];
            vEnd[2] = vPos[2] - 46.0;
            Handle hTrace = TR_TraceRayFilterEx(vPos, vEnd, MASK_SHOT|MASK_WATER, RayType_EndPoint, TraceRayFilter_NoPlayers, iEntity);
            // NOTE:
            //
            // v1.18:
            // Seems something to do with "CNavMesh::GetNearestNavArea" called in
            // "CInferno::CreateFire" that teleports the puddle to there.
            //
            //========================================================================================
            //
            // What is invisible death spit? As far as I know it's an issue where the game
            // traces for solid surfaces within certain height, but regardless of the hitting result.
            // If the trace misses, the death spit will have its origin set to the trace end.
            // And if it's at a height over "46.0" units, it becomes invisible in the air.
            // Or, if the trace hits Survivors, the death spit is on their head, still invisible.
            //
            // Let's say the "46.0" is the extra range.
            //
            // Given a case where the spitter jumps at a height greater than the trace length and dies,
            // the death spit will set to be feets above the ground, but it would try to teleport itself
            // to the surface within units of the extra range.
            //
            // Then here comes a mystery, that is how it works like this as I didn't manage to find out,
            // and it seems not utilizing trace either.
            // Moreever, thanks to @nikita1824 letting me know that invisible death spit is still there,
            // it really seems like the self-teleporting is kinda the same as the death spit traces,
            // which means it doesn't go through Survivors, thus invisible death spit.
            //
            // So finally, I have to use `TeleportEntity` on the puddle to prevent this.
            if (!TR_DidHit(hTrace)) {
                RemoveEntity(iEntity);
            } else {
                TR_GetEndPosition(vEnd, hTrace);
                TeleportEntity(iEntity, vEnd, NULL_VECTOR, NULL_VECTOR);
                CreateTimer(0.3, Timer_FixInvisibleSpit, EntIndexToEntRef(iEntity), TIMER_FLAG_NO_MAPCHANGE);
            }

            delete hTrace;
        }
    }

    SDKUnhook(iEntity, SDKHook_Think, SDK_OnThink);
    return Plugin_Continue;
}

Action SDK_OnTouch(int iEntity, int iOther) {
    if (g_fPropDamage == 0.0)
        return Plugin_Continue;

    if (iOther <= MaxClients)
        return Plugin_Continue;

    SDKHooks_TakeDamage(iOther, iEntity, GetEntPropEnt(iEntity, Prop_Send, "m_hThrower"), g_fPropDamage, DMG_CLUB);
    return Plugin_Continue;
}

bool TraceRayFilter_NoPlayers(int iEntity, int iContentsMask, any iSelf) {
    return iEntity != iSelf && (!iEntity || iEntity > MaxClients);
}

Action Timer_FixInvisibleSpit(Handle hTimer, int iEntRef) {
    int iEntity = EntRefToEntIndex(iEntRef);
    if (!IsValidEdict(iEntity))
        return Plugin_Stop;

    // Big chance that puddles with max 2 flames get the latter one invisible.
    if (GetEntProp(iEntity, Prop_Send, "m_fireCount") == 2) {
        SetEntProp(iEntity, Prop_Send, "m_fireCount", 1);
        L4D2Direct_SetInfernoMaxFlames(iEntity, 1);
    }

    return Plugin_Stop;
}

float GetDepthBeneathWater(const float vStart[3]) {
    static const float fMaxWaterDepth = 300.0;
    float vEnd[3];
    vEnd[0] = vStart[0];
    vEnd[1] = vStart[1];
    vEnd[2] = vStart[2] + fMaxWaterDepth;
    float fFraction = 0.0;

    Handle hTrace = TR_TraceRayFilterEx(vStart, vEnd, MASK_WATER, RayType_EndPoint, TraceRayFilter_NoPlayers, -1);
    if (TR_StartSolid(hTrace))
        fFraction = TR_GetFractionLeftSolid(hTrace);
    delete hTrace;

    if (fFraction > 0.0) {
        // simple check for false positives
        hTrace = TR_TraceRayFilterEx(vEnd, vStart, MASK_SOLID, RayType_EndPoint, TraceRayFilter_NoPlayers, -1);
        if (TR_DidHit(hTrace))
            fFraction = 0.0;
        delete hTrace;
    }

    return fFraction * fMaxWaterDepth;
}

bool IsSaferoomSpreadAllowed(bool bIsStartSaferoom) {
    if (L4D2_IsScavengeMode() || L4D_IsSurvivalMode())
        return g_iTmpSaferoomSpread != SAFEROOM_SPREAD_OFF;
    if (g_iTmpSaferoomSpread == SAFEROOM_SPREAD_ALL)
        return true;
    if (g_iTmpSaferoomSpread == SAFEROOM_SPREAD_INTRO && bIsStartSaferoom)
        return true;
    return false;
}

//======================================================================================================

MRESReturn DTR_OnDetonate_Pre(int pThis) {
    g_iDetonateObj = pThis;
    return MRES_Ignored;
}

MRESReturn DTR_OnDetonate_Post(int pThis) {
    g_iDetonateObj = -1;
    return MRES_Ignored;
}

public Action CH_PassFilter(int iTouch, int iPass, bool &bResult) {
    static char szCls[64], szTouchCls[64];
    if (iPass > MaxClients) {
        // (iPass = projectile): detonate
        if (iPass != g_iDetonateObj) {
            // (iPass = insect_swarm): spit spread
            if (!GetEdictClassname(iPass, szCls, sizeof(szCls)) || strcmp(szCls, "insect_swarm") != 0)
                return Plugin_Continue;
        }
    } else if (iPass > 0) {
        // (iPass = spitter): death spit
        if (!IsClientInGame(iPass))
            return Plugin_Continue;
        if (IsPlayerAlive(iPass))
            return Plugin_Continue;
        if (GetClientTeam(iPass) != 3)
            return Plugin_Continue;
        if (GetEntProp(iPass, Prop_Send, "m_zombieClass") != 4)
            return Plugin_Continue;
    } else {
        // world, always collide
        return Plugin_Continue;
    }

    // check for filter classes
    if (iTouch > MaxClients) {
        GetEdictClassname(iTouch, szTouchCls, sizeof(szTouchCls));
        // non-filtered or a spread configuration
        if (!g_smFilterClasses.GetValue(szTouchCls, iTouch) || iTouch != 0) {
            // don't spread on weapons
            if (strncmp(szTouchCls, "weapon_", 7) != 0)
                return Plugin_Continue;
        }
    }

    bResult = false;
    return Plugin_Handled;
}

//======================================================================================================

MRESReturn DTR_OnPhysicsSolidMaskForEntity_Post(DHookReturn hReturn) {
    if (!g_bWaterCollision)
        return MRES_Ignored;
    
    hReturn.Value |= MASK_WATER;
    return MRES_Supercede;
}

//======================================================================================================
stock int GetCurrentMapLower(char[] szBuffer, int iMaxLength) {
    int iBytes = GetCurrentMap(szBuffer, iMaxLength);
    String_ToLower(szBuffer, iMaxLength);
    return iBytes;
}

// l4d2util_stocks.inc
stock void String_ToLower(char[] szBuffer, int iMaxLength) {
    // Сounts string length to zero terminator
    int iLength = strlen(szBuffer);
    // more security, so that the cycle is not endless
    for (int i = 0; i < iLength && i < iMaxLength; i++) {
        if (!IsCharUpper(szBuffer[i])) continue;
        szBuffer[i] = CharToLower(szBuffer[i]);
    }
    szBuffer[iLength] = '\0';
}