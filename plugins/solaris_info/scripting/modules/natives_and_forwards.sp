#if defined __NATIVES_AND_FORWARDS__
    #endinput
#endif
#define __NATIVES_AND_FORWARDS__

GlobalForward fwdLerpChanged;

void CreateNativesAndForwards() {
    CreateNative("Solaris_GetRank",        Native_GetRank);
    CreateNative("Solaris_GetLerp",        Native_GetLerp);
    CreateNative("Solaris_GetHours",       Native_GetHours);
    CreateNative("Solaris_GetCountry",     Native_GetCountry);
    CreateNative("Solaris_GetCity",        Native_GetCity);
    CreateNative("Solaris_GetLoadingTime", Native_GetLoadingTime);

    fwdLerpChanged = new GlobalForward("OnPlayerLerpChanged", ET_Ignore, Param_Cell, Param_Float, Param_Float);

    RegPluginLibrary("solaris_info");
}

any Native_GetRank(Handle hPlugin, int iNumParams) {
    int iClient = GetNativeCell(1);
    return PlayerRank(iClient);
}

any Native_GetLerp(Handle hPlugin, int iNumParams) {
    int iClient = GetNativeCell(1);
    return GetPlayerLerp(iClient);
}

any Native_GetHours(Handle hPlugin, int iNumParams) {
    int iClient = GetNativeCell(1);
    return GetPlayerHours(iClient);
}

any Native_GetCountry(Handle hPlugin, int iNumParams) {
    int iClient = GetNativeCell(1);
    int iLen    = GetNativeCell(3);

    char[] szCountry = new char[iLen + 1];
    GetPlayerCountry(iClient, szCountry, iLen);

    SetNativeString(2, szCountry, iLen);
    return 0;
}

any Native_GetCity(Handle hPlugin, int iNumParams) {
    int iClient = GetNativeCell(1);
    int iLen    = GetNativeCell(3);

    char[] szCity = new char[iLen + 1];
    GetPlayerCity(iClient, szCity, iLen);

    SetNativeString(2, szCity, iLen);
    return 0;
}

any Native_GetLoadingTime(Handle hPlugin, int iNumParams) {
    int iClient = GetNativeCell(1);
    return GetPlayerLoadingTime(iClient);
}

void PlayerLerpChanged(const int iClient, const float fNewLerp, const float fLastLerp) {
    Call_StartForward(fwdLerpChanged);
    Call_PushCell(iClient);
    Call_PushFloat(fNewLerp);
    Call_PushFloat(fLastLerp);
    Call_Finish();
}