#if defined _readyup_native_included
    #endinput
#endif
#define _readyup_native_included

any Native_IsReady(Handle hPlugin, int iNumParams) {
    int iClient = GetNativeCell(1);
    if (iClient <= 0)
        return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);

    if (iClient > MaxClients)
        return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);

    if (!IsClientInGame(iClient))
        return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", iClient);

    return IsPlayerReady(iClient);
}

any Native_IsInReady(Handle hPlugin, int iNumParams) {
    return g_bInReadyUp;
}

any Native_ToggleReadyPanel(Handle hPlugin, int iNumParams) {
    if (g_bInReadyUp) {
        // TODO: Inform the client(s) that panel is supressed?
        bool bHide   = !GetNativeCell(1);
        int  iClient =  GetNativeCell(2);
        if (iClient && IsClientInGame(iClient)) {
            return SetPlayerHiddenPanel(iClient, bHide);
        } else {
            for (int i = 1; i <= MaxClients; i++) {
                if (!IsClientInGame(i))
                    continue;

                if (IsFakeClient(i))
                    continue;

                SetPlayerHiddenPanel(i, bHide);
            }

            return true;
        }
    }

    return false;
}