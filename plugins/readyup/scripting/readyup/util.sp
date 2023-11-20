#if defined _readyup_util_included
    #endinput
#endif
#define _readyup_util_included

#include "player.sp"

void UTIL_WrapperForward(GlobalForward fwd) {
    if (fwd.FunctionCount) {
        Call_StartForward(fwd);
        Call_Finish();
    }
}

bool IsEmptyString(const char[] szStr, int iMaxLen) {
    int iLen = strlen(szStr);
    if (iLen == 0)
        return true;
    
    if (iLen > iMaxLen)
        iLen = iMaxLen;
    
    for (int i = 0; i < iLen; i++) {
        if (IsCharSpace(szStr[i]))
            continue;
        
        if (szStr[i] == '\r')
            continue;
        
        if (szStr[i] == '\n')
            continue;
        
        return false;
    }
    
    return true;
}

int GetSeriousClientCount(bool bInGame = false) {
    int iClients = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (bInGame) {
            if (IsClientInGame(i) && !IsFakeClient(i))
                iClients++;
        } else {
            if (IsClientConnected(i) && !IsFakeClient(i))
                iClients++;
        }
    }
    
    return iClients;
}

void ReturnTeamToSaferoom(int iTeam) {
    int iWarpFlags = GetCommandFlags("warp_to_start_area");
    SetCommandFlags("warp_to_start_area", iWarpFlags & ~FCVAR_CHEAT);
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;
        
        if (GetClientTeam(i) != iTeam)
            continue;
        
        if (TM_IsPlayerRespectating(i))
            continue;
        
        ReturnPlayerToSaferoom(i, true);
    }
    
    SetCommandFlags("warp_to_start_area", iWarpFlags);
}

void SetTeamFrozen(int iTeam, bool bFreezeStatus) {
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;
        
        if (GetClientTeam(i) != iTeam)
            continue;
        
        if (TM_IsPlayerRespectating(i))
            continue;
        
        SetClientFrozen(i, bFreezeStatus);
    }
}

int GetTeamHumanCount(int iTeam) {
    int iHumans = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;
        
        if (IsFakeClient(i))
            continue;
        
        if (iTeam == L4D2Team_Spectator) {
            if (GetClientTeam(i) == iTeam || TM_IsPlayerRespectating(i))
                iHumans++;
        } else {
            if (GetClientTeam(i) == iTeam && !TM_IsPlayerRespectating(i))
                iHumans++;
        }
    }
    
    return iHumans;
}

int GetTeamMaxHumans(int iTeam) {
    if (iTeam == L4D2Team_Survivor) {
        return g_cvSurvivorLimit.IntValue;
    } else if (iTeam == L4D2Team_Infected) {
        return g_cvInfectedLimit.IntValue;
    }
    return MaxClients;
}

bool IsStaticTank() {
    if (!g_bIsWitchAndTankifierAvailable)
        return false;
    return IsStaticTankMap();
}

bool IsStaticWitch() {
    if (!g_bIsWitchAndTankifierAvailable)
        return false;
    return IsStaticWitchMap();
}