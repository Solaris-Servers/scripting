#if defined __DEADSTOPS__
    #endinput
#endif
#define __DEADSTOPS__

void OnModuleStart_DeadStops() {
    RegConsoleCmd("sm_deadstops", Cmd_ToggleDeadstops, "Toggle hunters deadstops");
}

Action Cmd_ToggleDeadstops(int iClient, int iArgs) {
    if (IsRoundLive()) {
        CPrintToChat(iClient, "{green}[{default}Gauntlet{green}]{default} This command can only be used before the round start");
        return Plugin_Handled;
    }

    if (!IsSurvivor(iClient)) {
        CPrintToChat(iClient, "{green}[{default}Gauntlet{green}]{default} You do not have access to this command");
        return Plugin_Handled;
    }

    DeadstopsAllowed(true, !DeadstopsAllowed());
    CPrintToChatAll("{green}[{default}Gauntlet{green}]{default} Hunter deadstops has been %s", DeadstopsAllowed() ? "{olive}enabled" : "{green}disabled");

    return Plugin_Handled;
}

public Action L4D_OnShovedBySurvivor(int iShover, int iShovee, const float vDir[3]) {
    return Shove_Handler(iShover, iShovee);
}

public Action L4D2_OnEntityShoved(int iShover, int iShovee, int weapon, float vDir[3], bool bIsHunterDeadstop) {
    return Shove_Handler(iShover, iShovee);
}

Action Shove_Handler(int iShover, int iShovee) {
    if (DeadstopsAllowed())
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
    static const int iDeadstopSeq[] = {64, 67, 11, 8};
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

bool DeadstopsAllowed(bool bSet = false, bool bVal = false) {
    static bool bAllow = true;

    if (bSet)
        bAllow = bVal;

    return bAllow;
}