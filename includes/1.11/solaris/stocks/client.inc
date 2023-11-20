#if defined __stocks_client_included
    #endinput
#endif
#define __stocks_client_included

// check if client has KICK admin flag
stock bool ST_IsAdminClient(int iClient) {
    AdminId adminId = GetUserAdmin(iClient);
    if (adminId == INVALID_ADMIN_ID) return false;
    return adminId.HasFlag(Admin_Kick);
}

// check if client has ANTI-KICK flag
stock bool ST_IsAntiKickClient(int iClient) {
    AdminId adminId = GetUserAdmin(iClient);
    if (adminId == INVALID_ADMIN_ID) return false;
    return adminId.HasFlag(Admin_Custom1);
}

// check if client is spec (include loading)
stock bool ST_IsSpecClient(int iClient) { return GetClientTeam(iClient) <= 1; }

// kick any client, except admin
stock void ST_KickClient(int iClient, const char[] szReason) {
    if (iClient <= 0 || iClient > MaxClients || !IsClientConnected(iClient) || IsClientInKickQueue(iClient)) return;
    if (ST_IsAntiKickClient(iClient)) return;

    KickClient(iClient, szReason);
}
