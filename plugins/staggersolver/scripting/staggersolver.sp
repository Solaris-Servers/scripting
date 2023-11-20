#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <left4dhooks>

public Plugin myinfo = {
    name        = "Super Stagger Solver",
    author      = "CanadaRox, A1m (fix), Sir (rework), Forgetest",
    description = "Blocks all button presses and restarts animations during stumbles",
    version     = "2.2",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void L4D_OnShovedBySurvivor_Post(int iClient, int iVictim, const float vDir[3]) {
    if (!L4D_IsPlayerStaggering(iVictim))
        return;

    if (FixSpitter(iVictim))
        return;

    SetEntPropFloat(iVictim, Prop_Send, "m_fServerAnimStartTime", GetGameTime());
    SetEntPropFloat(iVictim, Prop_Send, "m_flCycle", 0.0);
}

public void L4D2_OnEntityShoved_Post(int iClient, int iEnt, int iWeapon, const float vDir[3], bool bIsHighPounce) {
    if (iEnt <= 0)
        return;

    if (iEnt > MaxClients)
        return;

    if (!IsClientInGame(iEnt))
        return;

    if (GetClientTeam(iEnt) != 3)
        return;

    if (!L4D_IsPlayerStaggering(iEnt))
        return;

    if (FixSpitter(iEnt))
        return;

    SetEntPropFloat(iEnt, Prop_Send, "m_fServerAnimStartTime", GetGameTime());
    SetEntPropFloat(iEnt, Prop_Send, "m_flCycle", 0.0);
}

bool FixSpitter(int iClient) {
    if (GetClientTeam(iClient) != 3)
        return false;

    if (GetEntProp(iClient, Prop_Send, "m_zombieClass") != 4)
        return false;

    if (GetEntProp(iClient, Prop_Send, "m_nSequence") != 21)
        return false;

    SetEntPropFloat(iClient, Prop_Send, "m_flCycle", 1.0);
    return true;
}

public Action OnPlayerRunCmd(int iClient, int &iButtons) {
    if (!IsClientInGame(iClient))
        return Plugin_Continue;

    if (!IsPlayerAlive(iClient))
        return Plugin_Continue;

    if (!L4D_IsPlayerStaggering(iClient))
        return Plugin_Continue;

    /**
     * If you shove an SI that's on the ladder, the player won't be able to move at all until killed.
     * This is why we only apply this method when the SI is not on a ladder.
    **/
    if (GetEntityMoveType(iClient) != MOVETYPE_LADDER) {
        iButtons = 0;
        return Plugin_Changed;
    }

    return Plugin_Continue;
}