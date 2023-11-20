#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <dhooks>

#define SIZE_BYTE     1
#define Z_HUNTER      3
#define TEAM_INFECTED 3

#define GAMEDATA "l4d2_si_ability"

DynamicHook
       g_hCLunge_ActivateAbility;

int    g_iBlockBounceOffs;
int    g_iLungeActivateAbilityOffs;

ConVar g_cvPounceCrouchDelay;
float  g_fPounceCrouchDelay;

bool   g_bWasLunging         [MAXPLAYERS + 1];
float  g_fNextActivationFixed[MAXPLAYERS + 1];

public Plugin myinfo = {
    name        = "L4D2 No Backjump",
    author      = "Visor, A1m`, Forgetest",
    description = "Look at the title",
    version     = "1.4",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart() {
    InitGameData();

    g_iBlockBounceOffs = FindSendPropInfo("CLunge", "m_isLunging") + 16;
    g_hCLunge_ActivateAbility = new DynamicHook(g_iLungeActivateAbilityOffs, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity);

    g_cvPounceCrouchDelay = FindConVar("z_pounce_crouch_delay");
    g_fPounceCrouchDelay  = g_cvPounceCrouchDelay.FloatValue;
    g_cvPounceCrouchDelay.AddChangeHook(CvChg_PounceCrouchDelay);
}

void InitGameData() {
    GameData gmConf = new GameData(GAMEDATA);
    if (!gmConf)
        SetFailState("Gamedata '%s.txt' missing or corrupt.", GAMEDATA);

    g_iLungeActivateAbilityOffs = gmConf.GetOffset("CBaseAbility::ActivateAbility");
    if (g_iLungeActivateAbilityOffs == -1)
        SetFailState("Failed to get offset 'CBaseAbility::ActivateAbility'.");

    delete gmConf;
}

void CvChg_PounceCrouchDelay(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fPounceCrouchDelay = g_cvPounceCrouchDelay.FloatValue;
}

public void OnEntityCreated(int iEnt, const char[] szClsName) {
    if (strcmp(szClsName, "ability_lunge") == 0) {
        SDKHook(iEnt, SDKHook_SpawnPost, SDK_OnSpawn_Post);
        g_hCLunge_ActivateAbility.HookEntity(Hook_Pre, iEnt, CLunge_ActivateAbility);
    }
}

void SDK_OnSpawn_Post(int iEnt) {
    int iOwner = GetEntPropEnt(iEnt, Prop_Data, "m_hOwnerEntity");
    if (iOwner != -1) {
        g_bWasLunging[iOwner] = false;
        g_fNextActivationFixed[iOwner] = -1.0;
        SDKHook(iOwner, SDKHook_PostThinkPost, SDK_OnPostThink_Post);
    }

    SDKUnhook(iEnt, SDKHook_SpawnPost, SDK_OnSpawn_Post);
}

// take care ladder case
MRESReturn CLunge_ActivateAbility(int iAbility) {
    int iOwner = GetEntPropEnt(iAbility, Prop_Send, "m_owner");
    if (iOwner == -1)
        return MRES_Ignored;

    if (GetEntityMoveType(iOwner) != MOVETYPE_LADDER)
        return MRES_Ignored;

    // only allow if crouched and fully charged
    if (g_fNextActivationFixed[iOwner] != -1.0 && GetGameTime() >= g_fNextActivationFixed[iOwner])
        return MRES_Ignored;

    return MRES_Supercede;
}

void SDK_OnPostThink_Post(int iClient) {
    if (!IsClientInGame(iClient))
        return;

    int iAbility = GetEntPropEnt(iClient, Prop_Send, "m_customAbility");
    if (iAbility == -1 || !IsHunter(iClient)) {
        SDKUnhook(iClient, SDKHook_PostThinkPost, SDK_OnPostThink_Post);
        return;
    }

    if (IsGhost(iClient)) {
        g_fNextActivationFixed[iClient] = -1.0;
        return;
    }

    if (GetEntProp(iAbility, Prop_Send, "m_isLunging")) {
        g_fNextActivationFixed[iClient] = -1.0;
        g_bWasLunging[iClient] = true;
        return;
    }

    // Ducking, set our own timer for next pounce
    if (GetClientButtons(iClient) & IN_DUCK) {
        if (g_fNextActivationFixed[iClient] == -1.0) {
            // assumes hunter was bouncing
            float fNow = GetGameTime();
            g_fNextActivationFixed[iClient] = fNow;

            // 1. not bouncing
            // 2. starts on ground, or pounce not landing ladder
            if (fNow > GetEntPropFloat(iAbility, Prop_Send, "m_lungeAgainTimer", 1) && (!g_bWasLunging[iClient] || GetEntityMoveType(iClient) != MOVETYPE_LADDER))
                g_fNextActivationFixed[iClient] += g_fPounceCrouchDelay;
        }
    } else {
        // not ducking
        g_fNextActivationFixed[iClient] = -1.0;
    }

    g_bWasLunging[iClient] = false;

    // A flag to block hunter back jumping,
    // which is set whenever hunter has touched survivors
    if (GetEntData(iAbility, g_iBlockBounceOffs, 1))
        return;

    SetEntData(iAbility, g_iBlockBounceOffs, 1, SIZE_BYTE);
}

bool IsHunter(int client) {
    return (IsPlayerAlive(client) && GetClientTeam(client) == TEAM_INFECTED && GetEntProp(client, Prop_Send, "m_zombieClass") == Z_HUNTER);
}

bool IsGhost(int client) {
    return view_as<bool>(GetEntProp(client, Prop_Send, "m_isGhost", 1));
}


/**
    Keep old code for any situiations
                                        **/

/*
#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>

#define SIZE_BYTE     1
#define Z_HUNTER      3
#define TEAM_INFECTED 3

public void OnPlayerRunCmdPost(int iClient, int iButtons) {
    if (iClient <= 0)
        return;

    if (!IsClientInGame(iClient))
        return;

    if (IsFakeClient(iClient))
        return;

    if (!IsPlayerAlive(iClient))
        return;

    if (IsGhost(iClient))
        return;

    if (!IsHunter(iClient))
        return;

    int iAbility = MakeCompatEntRef(GetEntProp(iClient, Prop_Send, "m_customAbility"));
    if (!IsValidEntity(iAbility))
        return;

    ToggleAbility(iClient, iAbility);

}

void ToggleAbility(int iClient, int iAbility) {
    static int m_isLungingOffs = -1;
    if (m_isLungingOffs == -1)
        m_isLungingOffs = FindSendPropInfo("CLunge", "m_isLunging");

    // CLunge::OnTouch()    mov     byte ptr [esi+48Ch], 1    <- +48C is the offset (near CBaseEntity.IsPlayer() check)
    static int m_isWallJumpBlockedOffs = -1;
    if (m_isWallJumpBlockedOffs == -1)
        m_isWallJumpBlockedOffs = m_isLungingOffs + 16;

    static int iVal;
    iVal = (GetEntityMoveType(iClient) == MOVETYPE_LADDER || GetEntData(iAbility, m_isLungingOffs, SIZE_BYTE));

    SetEntData(iAbility, m_isWallJumpBlockedOffs, iVal, SIZE_BYTE);
}

bool IsGhost(int iClient) {
    return view_as<bool>(GetEntProp(iClient, Prop_Send, "m_isGhost"));
}

bool IsHunter(int iClient) {
    if (GetClientTeam(iClient) != TEAM_INFECTED)
        return false;

    return GetEntProp(iClient, Prop_Send, "m_zombieClass") == Z_HUNTER;
}
*/