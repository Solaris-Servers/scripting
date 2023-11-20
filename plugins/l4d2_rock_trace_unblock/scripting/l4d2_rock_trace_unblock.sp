#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <left4dhooks>
#include <dhooks>
#include <sourcescramble>

#define GAMEDATA_FILE           "l4d2_rock_trace_unblock"
#define KEY_BOUNCETOUCH         "CTankRock::BounceTouch"
#define KEY_PATCH_FOREACHPLAYER "CTankRock::ProximityThink__No_ForEachPlayer"

ConVar g_cvRockRadius;
float  g_fRockRadius;
float  g_fRockRadiusSquared;

ConVar g_cvFlags;
int    g_iFlags;

ConVar g_cvJockeyFix;
bool   g_bJockeyFix;

ConVar g_cvHurtCapper;
int    g_iHurtCapper;

Handle g_hSDKCall_BounceTouch;

DynamicHook
    g_dHook_BounceTouch;

MemoryPatch
    g_mPatch_ForEachPlayer;

public Plugin myinfo = {
    name        = "[L4D2] Rock Trace Unblock",
    author      = "Forgetest",
    description = "Prevent hunter/jockey/coinciding survivor from blocking the rock radius check.",
    version     = "1.10",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

void LoadSDK() {
    GameData gmConf = new GameData(GAMEDATA_FILE);
    if (!gmConf) SetFailState("Missing gamedata \""...GAMEDATA_FILE..."\"");

    g_mPatch_ForEachPlayer = MemoryPatch.CreateFromConf(gmConf, KEY_PATCH_FOREACHPLAYER);
    if (!g_mPatch_ForEachPlayer.Validate()) SetFailState("Missing MemPatch setup for \""...KEY_PATCH_FOREACHPLAYER..."\"");

    StartPrepSDKCall(SDKCall_Entity);
    if (!PrepSDKCall_SetFromConf(gmConf, SDKConf_Virtual, KEY_BOUNCETOUCH))
        SetFailState("Missing offset \""...KEY_BOUNCETOUCH..."\"");
    PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    g_hSDKCall_BounceTouch = EndPrepSDKCall();
    if (!g_hSDKCall_BounceTouch) SetFailState("Failed to prepare SDKCall of \""...KEY_BOUNCETOUCH..."\"");

    g_dHook_BounceTouch = DynamicHook.FromConf(gmConf, KEY_BOUNCETOUCH);
    if (!g_dHook_BounceTouch) SetFailState("Missing dhook setup for \""...KEY_BOUNCETOUCH..."\"");
    delete gmConf;
}

public void OnPluginStart() {
    LoadSDK();

    g_cvFlags = CreateConVar(
    "l4d2_rock_trace_unblock_flag", "1",
    "Prevent SI from blocking the rock radius check. 1 = Unblock from all standing SI, 2 = Unblock from pounced, 4 = Unblock from jockeyed, 8 = Unblock from pummelled, 16 = Unblock from thrower (Tank), 31 = All, 0 = Disable.",
    FCVAR_CHEAT, true, 0.0, true, 31.0);
    g_cvFlags.AddChangeHook(OnConVarChanged);

    g_cvJockeyFix = CreateConVar(
    "l4d2_rock_jockey_dismount", "0",
    "Force jockey to dismount the survivor who eats rock. 1 = Enable, 0 = Disable.",
    FCVAR_CHEAT, true, 0.0, true, 1.0);
    g_cvJockeyFix.AddChangeHook(OnConVarChanged);

    g_cvHurtCapper = CreateConVar(
    "l4d2_rock_hurt_capper", "5",
    "Hurt cappers before landing their victims. 1 = Hurt hunter, 2 = Hurt jockey, 4 = Hurt charger, 7 = All, 0 = Disable.",
    FCVAR_CHEAT, true, 0.0, true, 7.0);
    g_cvHurtCapper.AddChangeHook(OnConVarChanged);

    g_cvRockRadius = FindConVar("z_tank_rock_radius");
    g_cvRockRadius.AddChangeHook(OnConVarChanged);
}

public void OnConfigsExecuted() {
    GetCvars();
}

void OnConVarChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    GetCvars();
}

void GetCvars() {
    g_iFlags      = g_cvFlags.IntValue;
    g_fRockRadius = g_cvRockRadius.FloatValue;
    g_bJockeyFix  = g_cvJockeyFix.BoolValue;
    g_iHurtCapper = g_cvHurtCapper.IntValue;

    ApplyPatch(g_iFlags > 0);

    g_fRockRadiusSquared = g_fRockRadius * g_fRockRadius;

    static ConVar cvDifficulty = null;
    if (cvDifficulty == null)
        cvDifficulty = FindConVar("z_difficulty");

    char szBuffer[16];
    cvDifficulty.GetString(szBuffer, sizeof(szBuffer));

    if (strcmp(szBuffer, "Easy", false) == 0)
        g_fRockRadiusSquared *= 0.5625; // 0.75 ^ 2
}

void ApplyPatch(bool bPatch) {
    if (bPatch)
        g_mPatch_ForEachPlayer.Enable();
    else
        g_mPatch_ForEachPlayer.Disable();
}

public void L4D_TankRock_OnRelease_Post(int iTank, int iRock, const float vPos[3], const float vAng[3], const float vVel[3], const float vRot[3]) {
    if (g_iFlags)
        SDKHook(iRock, SDKHook_Think, SDK_OnThink);

    if (g_bJockeyFix)
        g_dHook_BounceTouch.HookEntity(Hook_Post, iRock, DHook_OnBounceTouch_Post);
}

Action SDK_OnThink(int iEnt) {
    static float vOrigin[3], vLastOrigin[3], vPos[3], vClosestPos[3];
    GetEntPropVector(iEnt, Prop_Data, "m_vecAbsOrigin", vOrigin);

    static int m_vLastPosition = -1;
    if (m_vLastPosition == -1) m_vLastPosition = FindSendPropInfo("CBaseCSGrenadeProjectile", "m_vInitialVelocity") + 24;

    GetEntDataVector(iEnt, m_vLastPosition, vLastOrigin);
    float fMinDistSqr = g_fRockRadiusSquared;
    int   iClosestSurvivor = -1;

    // Serves as a List for ignored entities in traces
    DataPack dp = new DataPack();
    dp.WriteCell(iEnt); // always self-ignored
    dp.WriteCell(GetEntPropEnt(iEnt, Prop_Send, "m_hThrower"));
    DataPackPos pos = dp.Position;

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i))
            continue;

        if (L4D_IsPlayerIncapacitated(i) || L4D_IsPlayerHangingFromLedge(i))
            continue;

        L4D_GetEntityWorldSpaceCenter(i, vPos);
        ComputeClosestPoint(vLastOrigin, vOrigin, vPos, vOrigin);

        float fDistSqr = GetVectorDistance(vOrigin, vPos, true);
        if (fDistSqr < fMinDistSqr) {
            // See if there's any obstracle in the way
            dp.Position = pos;
            dp.WriteCell(i);

            Handle hTrace = TR_TraceRayFilterEx(vOrigin, vPos, MASK_SOLID, RayType_EndPoint, ProximityThink_TraceFilter, dp);
            if (!TR_DidHit(hTrace) && TR_GetFraction(hTrace) >= 1.0) {
                fMinDistSqr = fDistSqr;
                iClosestSurvivor = i;
                vClosestPos = vOrigin;
            }

            delete hTrace;

            // Keep in mind that rock finds multiple targets basically only around the moment the Tank releases it.
            // Exit the loop if we are really gonna search for nothing.
            if (iClosestSurvivor != -1) {
                IntervalTimer it = CTankRock_GetReleaseTimer(iEnt);
                if (ITimer_GetElapsedTime(it) >= 0.1)
                    break;
            }
        }
    }

    delete dp;

    if (iClosestSurvivor != -1) {
        // Maybe "TeleportEntity" does the same, let it be.
        SetAbsOrigin(iEnt, vClosestPos);
        // Hurt attackers first, based on flag setting
        HurtCappers(iEnt, iClosestSurvivor);
        // Confirm landing
        BounceTouch(iEnt, iClosestSurvivor);
    }

    return Plugin_Continue;
}

/**
 * @brief Valve's built-in function to compute close point to potential rock victims.
 *
 * @param vLeft         Last recorded position of moving object.
 * @param vRight        Current position of moving object.
 * @param vPos          Target position to test.
 * @param fResult       Vector to store the result.
 *
 * @return              True if the closest point, false otherwise.
 */

bool ComputeClosestPoint(const float vLeft[3], const float vRight[3], const float vPos[3], float fResult[3]) {
    static float vLTarget[3], vLine[3];
    SubtractVectors(vPos,   vLeft, vLTarget);
    SubtractVectors(vRight, vLeft, vLine);

    static float fLength, fDot;
    fLength = NormalizeVector(vLine, vLine);
    fDot    = GetVectorDotProduct(vLTarget, vLine);

    // (-pi/2 < θ < pi/2)
    if (fDot >= 0.0) {
        // We can find a P on the line
        if (fDot <= fLength) {
            ScaleVector(vLine, fDot);
            AddVectors(vLeft, vLine, fResult);
            return true;
        } else {
            // Too far from T
            fResult = vRight;
            return false;
        }
    } else {
        // seems to potentially risk a hit, for tiny performance?
        fResult = vLeft;
        return false;
    }
}

bool ProximityThink_TraceFilter(int iEnt, int iContentsMask, DataPack dp) {
    dp.Reset();
    // dp[0] = rock
    // dp[1] = tank
    // dp[2] = survivor

    if (iEnt == dp.ReadCell())
        return false;

    if (iEnt == dp.ReadCell())
        return !(g_iFlags & 16);

    if (iEnt == dp.ReadCell())
        return false;

    if (iEnt > 0 && iEnt <= MaxClients && IsClientInGame(iEnt)) {
        if (GetClientTeam(iEnt) == 2) {
            // NOTE:

            // This should not be possible as radius check runs every think
            // and survivors in between must be prior to be targeted.

            // As far as I know, the only exception is that multiple survivors
            // are coinciding (like at a corner), and obstracle tracing ends up
            // with "true", kinda false positive.

            // Treated as a bug here, no options.
            return false;
        }

        switch (GetEntProp(iEnt, Prop_Send, "m_zombieClass")) {
            case 3: {
                if (GetEntPropEnt(iEnt, Prop_Send, "m_pounceVictim") != -1)
                    return !(g_iFlags & 2);
            }
            case 5: {
                if (GetEntPropEnt(iEnt, Prop_Send, "m_jockeyVictim") != -1)
                    return !(g_iFlags & 4);
            }
            case 6: {
                if (GetEntPropEnt(iEnt, Prop_Send, "m_pummelVictim") != -1)
                    return !(g_iFlags & 8);
            }
        }

        if (g_iFlags & 1)
            return false;
    }

    return true;
}

MRESReturn DHook_OnBounceTouch_Post(int pThis, DHookReturn hReturn, DHookParam hParams) {
    int iClient = -1;
    if (!hParams.IsNull(1))
        iClient = hParams.Get(1);

    if(iClient > 0 && iClient <= MaxClients && GetClientTeam(iClient) == 2 && !L4D_IsPlayerIncapacitated(iClient)) {
        int iJockey = GetEntPropEnt(iClient, Prop_Send, "m_jockeyAttacker");
        if (iJockey != -1)
            Dismount(iJockey);
    }

    return MRES_Ignored;
}

void HurtCappers(int iRock, int iClient) {
    // hunter
    if (g_iHurtCapper & 1) {
        int iHunter = GetEntPropEnt(iClient, Prop_Send, "m_pounceAttacker");
        if (iHunter != -1) {
            BounceTouch(iRock, iHunter);
            return;
        }
    }

    // jockey
    if (g_iHurtCapper & 2) {
        int iJockey = GetEntPropEnt(iClient, Prop_Send, "m_jockeyAttacker");
        if (iJockey != -1) {
            BounceTouch(iRock, iJockey);
            return;
        }
    }

    // charger
    if (g_iHurtCapper & 4) {
        int iCharger = GetEntPropEnt(iClient, Prop_Send, "m_pummelAttacker");
        if (iCharger != -1) {
            BounceTouch(iRock, iCharger);
            return;
        }
    }
}

void BounceTouch(int iRock, int iClient) {
    SDKCall(g_hSDKCall_BounceTouch, iRock, iClient);
}

void Dismount(int iClient) {
    int iFlags = GetCommandFlags("dismount");
    SetCommandFlags("dismount", iFlags & ~FCVAR_CHEAT);
    FakeClientCommand(iClient, "dismount");
    SetCommandFlags("dismount", iFlags);
}

IntervalTimer CTankRock_GetReleaseTimer(int iRock) {
    static int iReleaseTimerOffs = -1;
    if (iReleaseTimerOffs == -1)
        iReleaseTimerOffs = FindSendPropInfo("CBaseCSGrenadeProjectile", "m_vInitialVelocity") + 36;
    return view_as<IntervalTimer>(GetEntityAddress(iRock) + view_as<Address>(iReleaseTimerOffs));
}