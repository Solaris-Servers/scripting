#if defined __LOCATION__
    #endinput
#endif
#define __LOCATION__

#include <geoip>

#define DATA_FILE "addons/sourcemod/data/solaris_info.txt"
#define KEY_VALUE "Connect_Announce"

void GetPlayerCountry(int iClient, char[] szBuffer, int iLen) {
    static char szSteamId[32];
    GetClientAuthId(iClient, AuthId_Steam2, szSteamId, sizeof(szSteamId));

    static char szIP[32];
    GetClientIP(iClient, szIP, sizeof(szIP), true);

    static char szCountry[3];
    if (GeoipCode2(szIP, szCountry))
        FormatEx(szBuffer, iLen, "%s", szCountry);
    GetPlayerFakeLoc(szSteamId, "country", szBuffer, iLen);
}

void GetPlayerCity(int iClient, char[] szBuffer, int iLen) {
    static char szSteamId[32];
    GetClientAuthId(iClient, AuthId_Steam2, szSteamId, sizeof(szSteamId));

    static char szIP[32];
    GetClientIP(iClient, szIP, sizeof(szIP), true);

    static char szCity[45];
    if (GeoipCity(szIP, szCity, sizeof(szCity)))
        FormatEx(szBuffer, iLen, "%s", szCity);
    GetPlayerFakeLoc(szSteamId, "city", szBuffer, iLen);
}

bool GetPlayerFakeLoc(const char[] szSteamId, const char[] szType, char[] szBuffer, int iLen) {
    static bool bFound;
    bFound = false;

    KeyValues kv = new KeyValues(KEY_VALUE);
    if (kv.ImportFromFile(DATA_FILE)) {
        if (kv.JumpToKey(szSteamId, false)) {
            kv.GetString(szType, szBuffer, iLen);
            bFound = true;
        }
    }
    delete kv;

    return bFound;
}