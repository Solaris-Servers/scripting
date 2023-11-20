#if defined __solaris_votes_pools_included
    #endinput
#endif
#define __solaris_votes_pools_included

/**
 * Fills passed int array with clients from both teams
 *
 * @param   iPoolToFill_arr Int array of MaxClients size
 * @return  int             Amount of clients stored to array
 */
int CreatePlayersOnlyPool(int[] iPoolToFill_arr) {
    int iTotal = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i) || IsFakeClient(i) || (GetClientTeam(i) < 2) || TM_IsPlayerRespectating(i)) {
            continue;
        }
        iPoolToFill_arr[iTotal++] = i;
    }
    return iTotal;
}

/**
 * Fills passed int array with clients from specified team
 *
 * @param   iPoolToFill_arr Int array of MaxClients size
 * @param   iTeam           Team number
 * @return  int             Amount of clients stored to array
 */
int CreateTeamOnlyPool(int[] iPoolToFill_arr, int iTeam) {
    int iTotal = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i) || IsFakeClient(i) || (GetClientTeam(i) != iTeam) || TM_IsPlayerRespectating(i)) {
            continue;
        }
        iPoolToFill_arr[iTotal++] = i;
    }
    return iTotal;
}