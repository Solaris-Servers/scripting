#if defined __AI_SPITTER__
    #endinput
#endif
#define __AI_SPITTER__

Action Spitter_OnPlayerRunCmd(int iClient, int &iButtons) {
    if (!g_bSpitterBhop)
        return Plugin_Continue;

    if (IsGrounded(iClient) && GetEntityMoveType(iClient) != MOVETYPE_LADDER && GetEntProp(iClient, Prop_Data, "m_nWaterLevel") < 2 && GetEntProp(iClient, Prop_Send, "m_hasVisibleThreats")) {
        static float vVel[3];
        GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", vVel);
        vVel[2] = 0.0;

        if (!CheckPlayerMove(iClient, GetVectorLength(vVel)))
            return Plugin_Continue;

        if (150.0 < NearestSurvivorDistance(iClient) < 1500.0) {
            static float vAng[3];
            GetClientEyeAngles(iClient, vAng);
            return BunnyHop(iClient, iButtons, vAng);
        }
    }

    return Plugin_Continue;
}