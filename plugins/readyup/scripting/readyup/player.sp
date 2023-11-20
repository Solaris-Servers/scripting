#if defined _readyup_player_included
    #endinput
#endif
#define _readyup_player_included

#define AFK_DURATION 15.0

static bool  bIsTeamReady  [L4D2Team_Size];
static bool  bIsPlayerReady[MAXPLAYERS + 1];
static bool  bHiddenPanel  [MAXPLAYERS + 1];
static float fButtonTime   [MAXPLAYERS + 1];

bool IsPlayerReady(int iClient) {
    return bIsPlayerReady[iClient];
}

bool IsTeamReady(int iTeam) {
    return bIsTeamReady[iTeam];
}

bool SetPlayerReady(int iClient, bool bReady) {
    bool bPrev;
    switch (g_iReadyUpMode) {
        case ReadyMode_PlayerReady: {
            bPrev = bIsPlayerReady[iClient];
            bIsPlayerReady[iClient] = bReady;
        }
        default: {
            return false;
        }
    }

    if ((bPrev != bIsPlayerReady[iClient]) && bReady) {
        if (g_fwdPlayerReady.FunctionCount) {
            Call_StartForward(g_fwdPlayerReady);
            Call_PushCell(iClient);
            Call_Finish();
        }
    } else if ((bPrev != bIsPlayerReady[iClient]) && !bReady) {
        if (g_fwdPlayerUnready.FunctionCount) {
            Call_StartForward(g_fwdPlayerUnready);
            Call_PushCell(iClient);
            Call_Finish();
        }
    }

    return (bPrev != bIsPlayerReady[iClient]);
}

bool SetTeamReady(int iTeam, bool bReady) {
    bool bPrev;
    switch (g_iReadyUpMode) {
        case ReadyMode_TeamReady: {
            bPrev = bIsTeamReady[iTeam];
            bIsTeamReady[iTeam] = bReady;
        }
        default: {
            return false;
        }
    }

    if ((bPrev != bIsTeamReady[iTeam]) && bReady) {
        if (g_fwdTeamReady.FunctionCount) {
            Call_StartForward(g_fwdTeamReady);
            Call_PushCell(iTeam);
            Call_Finish();
        }
    } else if ((bPrev != bIsTeamReady[iTeam]) && !bReady) {
        if (g_fwdTeamUnready.FunctionCount) {
            Call_StartForward(g_fwdTeamUnready);
            Call_PushCell(iTeam);
            Call_Finish();
        }
    }

    return (bPrev != bIsTeamReady[iTeam]);
}

bool IsPlayerHiddenPanel(int iClient) {
    return bHiddenPanel[iClient];
}

bool SetPlayerHiddenPanel(int iClient, bool bHidden) {
    bool bPrev = bHiddenPanel[iClient];
    bHiddenPanel[iClient] = bHidden;
    return bPrev;
}

void SetButtonTime(int iClient) {
    fButtonTime[iClient] = GetEngineTime();
}

bool IsPlayerAfk(int iClient) {
    return GetEngineTime() - fButtonTime[iClient] > AFK_DURATION;
}

void GetClientFixedName(int iClient, char[] szName, int iLength) {
    GetClientName(iClient, szName, iLength);
    if (szName[0] == '[') {
        char szTmp[MAX_NAME_LENGTH];
        strcopy(szTmp, sizeof(szTmp), szName);
        szTmp[sizeof(szTmp) - 2] = 0;
        strcopy(szName[1], iLength - 1, szTmp);
        szName[0] = ' ';
    }
}

void SetClientFrozen(int iClient, bool bFreeze) {
    SetEntityMoveType(iClient, bFreeze ? MOVETYPE_NONE : (GetClientTeam(iClient) == L4D2Team_Spectator ? MOVETYPE_NOCLIP : MOVETYPE_WALK));
}

bool IsPlayer(int iClient) {
    if (TM_IsPlayerRespectating(iClient))
        return false;

    int iTeam = GetClientTeam(iClient);
    return (iTeam == L4D2Team_Survivor || iTeam == L4D2Team_Infected);
}

void ReturnPlayerToSaferoom(int iClient, bool bFlagsSet = true) {
    int iWarpFlags;
    if (!bFlagsSet) {
        iWarpFlags = GetCommandFlags("warp_to_start_area");
        SetCommandFlags("warp_to_start_area", iWarpFlags & ~FCVAR_CHEAT);
    }

    if (GetEntProp(iClient, Prop_Send, "m_isHangingFromLedge"))
        L4D_ReviveSurvivor(iClient);

    FakeClientCommand(iClient, "warp_to_start_area");
    if (!bFlagsSet)
        SetCommandFlags("warp_to_start_area", iWarpFlags);

    TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, NULL_VELOCITY);
    SetEntPropFloat(iClient, Prop_Send, "m_flFallVelocity", 0.0);
}