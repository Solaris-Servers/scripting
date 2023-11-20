#if defined __AI_JOCKEY__
    #endinput
#endif
#define __AI_JOCKEY__

bool  bDoNormalJump [MAXPLAYERS + 1];
float fLeapAgainTime[MAXPLAYERS + 1];

void Jockey_RoundEnd() {
    for (int i = 1; i <= MaxClients; i++) {
        fLeapAgainTime[i] = 0.0;
    }
}

void Jockey_PlayerSpawn(int iClient) {
    fLeapAgainTime[iClient] = 0.0;
}

void Jockey_RideStart(int iVictim, int iAttacker) {
    if (g_fJockeyStumbleRadius <= 0.0 || !L4D2_IsGenericCooperativeMode())
        return;

    if (iVictim <= 0 || !IsClientInGame(iVictim))
        return;

    if (iAttacker <= 0 || !IsClientInGame(iAttacker))
        return;

    StumbleByStanders(iVictim, iAttacker);
}

void StumbleByStanders(int iTarget, int iPinner) {
    float vPos[3];
    GetClientAbsOrigin(iTarget, vPos);

    float vTarget[3];
    for (int i = 1; i <= MaxClients; i++) {
        if (i == iTarget || i == iPinner || !IsClientInGame(i) || GetClientTeam(i) != L4D2Team_Survivor || !IsPlayerAlive(i) || IsPinned(i, false))
            continue;
        GetClientAbsOrigin(i, vTarget);
        if (GetVectorDistance(vPos, vTarget) <= g_fJockeyStumbleRadius)
            L4D_StaggerPlayer(i, i, vPos);
    }
}

Action Jockey_OnPlayerRunCmd(int iClient, int &iButtons) {
    if (!GetEntProp(iClient, Prop_Send, "m_hasVisibleThreats"))
        return Plugin_Continue;

    static float fDistance;
    fDistance = NearestSurvivorDistance(iClient);
    if (fDistance > g_fHopActivationProximity)
        return Plugin_Continue;

    if (!IsGrounded(iClient)) {
        iButtons &= ~IN_JUMP;
        iButtons &= ~IN_ATTACK;
    }

    if (bDoNormalJump[iClient]) {
        bDoNormalJump[iClient] = false;
        if (iButtons & IN_FORWARD && WithinViewAngle(iClient, -1, 60.0)) {
            switch (Math_GetRandomInt(0, 1)) {
                case 0: iButtons |= IN_MOVELEFT;
                case 1: iButtons |= IN_MOVERIGHT;
            }
        }
        iButtons |= IN_JUMP;
        switch (Math_GetRandomInt(0, 2)) {
            case 0: iButtons |= IN_DUCK;
            case 1: iButtons |= IN_ATTACK2;
        }
    } else {
        static float fTime;
        fTime = GetGameTime();
        if (fLeapAgainTime[iClient] < fTime) {
            if (fDistance < g_fJockeyLeapRange )
                iButtons |= IN_ATTACK;
            bDoNormalJump[iClient] = true;
            fLeapAgainTime[iClient] = fTime + g_fJockeyLeapAgain;
        }
    }

    return Plugin_Changed;
}