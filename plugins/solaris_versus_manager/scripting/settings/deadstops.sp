#if defined __DEADSTOPS__
    #endinput
#endif
#define __DEADSTOPS__

/*======================================================================================
    Plugin Info:

*   Name    :   L4D2 No Hunter M2
*   Author  :   Visor, A1m
*   Link    :   https://github.com/SirPlease/L4D2-Competitive-Rework

========================================================================================*/

static const int iDeadstopSeq[] = {64, 67, 11, 8};

public Action L4D_OnShovedBySurvivor(int iShover, int iShovee, const float vDir[3]) {
    return Shove_Handler(iShover, iShovee);
}

public Action L4D2_OnEntityShoved(int iShover, int iShovee, int weapon, float vDir[3], bool bIsHunterDeadstop) {
    return Shove_Handler(iShover, iShovee);
}

Action Shove_Handler(int iShover, int iShovee) {
    if (!DeadstopsBlocked())
        return Plugin_Continue;

    if (!IsValidSurvivor(iShover))
        return Plugin_Continue;

    if (!IsHunter(iShovee))
        return Plugin_Continue;

    if (HasTarget(iShovee))
        return Plugin_Continue;

    if (IsPlayingDeadstopAnimation(iShovee))
        return Plugin_Handled;

    return Plugin_Continue;
}

bool IsHunter(int iClient) {
    if (!IsValidInfected(iClient))
        return false;

    if (!IsPlayerAlive(iClient))
        return false;

    if (GetInfectedClass(iClient) != L4D2Infected_Hunter)
        return false;

    return true;
}

bool IsPlayingDeadstopAnimation(int iClient) {
    int iSeq = GetEntProp(iClient, Prop_Send, "m_nSequence");
    for (int i = 0; i < sizeof(iDeadstopSeq); i++) {
        if (iDeadstopSeq[i] == iSeq)
            return true;
    }
    return false;
}

bool HasTarget(int iClient) {
    int iTarget = GetEntPropEnt(iClient, Prop_Send, "m_pounceVictim");
    return (IsValidSurvivor(iTarget) && IsPlayerAlive(iTarget));
}

bool DeadstopsBlocked(bool bSet = false, bool bVal = false) {
    static bool bBlocked;

    if (bSet)
        bBlocked = bVal;

    return bBlocked;
}