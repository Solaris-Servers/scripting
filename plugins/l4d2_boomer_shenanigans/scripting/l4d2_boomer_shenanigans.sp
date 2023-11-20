#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <left4dhooks>

public Plugin myinfo = {
    name        = "L4D2 Boomer Shenanigans",
    author      = "Sir",
    description = "Make sure Boomers are unable to bile Survivors during a stumble (basically reinforce shoves)",
    version     = "1.0",
    url         = "None."
};

public void L4D_OnShovedBySurvivor_Post(int iClient, int iVictim, const float vDir[3]) {
    if (!IsValidClient(iVictim)) return;
    if (!IsValidClient(iClient)) return;

    if (GetEntProp(iVictim, Prop_Send, "m_zombieClass") != 2)
        return;

    int iAbility = GetEntPropEnt(iVictim, Prop_Send, "m_customAbility");
    if (!IsValidEntity(iAbility)) return;

    float fTimeStamp = GetEntPropFloat(iAbility, Prop_Send, "m_timestamp");
    float fGameTime  = GetGameTime();

    bool bUsed = view_as<bool>(GetEntProp(iAbility, Prop_Send, "m_hasBeenUsed"));
    if (!bUsed || fGameTime >= fTimeStamp) SetEntPropFloat(iAbility, Prop_Send, "m_timestamp", fGameTime + 1.0);
}

stock bool IsValidClient(int iClient) {
    if (iClient <= 0)         return false;
    if (iClient > MaxClients) return false;
    return IsClientInGame(iClient);
}