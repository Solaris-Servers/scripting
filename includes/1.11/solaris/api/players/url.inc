#if defined _solarisapi_players_url_included
 #endinput
#endif
#define _solarisapi_players_url_included

methodmap PlayersUrlBuilder {
    /**
    * PATCH https://api.solaris-servers.ru/v1/players/:steamId/refresh-avatar
    * 
    * @param szBuffer           Buffer to write URL to
    * @param iMaxlength         Maximum length of szBuffer
    * @param szAuthId           Steam ID
    */
    public static void RefreshAvatarForAuthId(char[] szBuffer, int iMaxlength, const char[] szAuthId) {
        Format(szBuffer, iMaxlength, "%s/v1/players/%s/refresh-avatar", SAPI_BASE, szAuthId);
    }

    /**
    * PATCH https://api.solaris-servers.ru/v1/players/:steamId/refresh-avatar
    * 
    * @param szBuffer           Buffer to write URL to
    * @param iMaxlength         Maximum length of szBuffer
    * @param iClient            Client index
    */
    public static void RefreshAvatarForClient(char[] szBuffer, int iMaxlength, int iClient) {
        char szAuthId[64];
        GetClientAuthId(iClient, AuthId_SteamID64, szAuthId, sizeof(szAuthId), true);
        PlayersUrlBuilder.RefreshAvatarFromAuthId(szBuffer, iMaxlength, szAuthId);
    }

    /**
    * GET https://api.solaris-servers.ru/v1/players/:steamId/bhaps
    * 
    * @param szUrl              Buffer to write URL to
    * @param iMaxlength         Maximum length of szBuffer
    * @param iClient            Client index
    */
    public static void GetBhapStatusForClient(char[] szUrl, int iMaxlength, int iClient) {
        char szAuthId[64];
        GetClientAuthId(iClient, AuthId_SteamID64, szAuthId, sizeof(szAuthId), true);
        Format(szUrl, iMaxlength, "%s/v1/players/%s/bhaps", SAPI_BASE, szAuthId);
    }

    /**
    * GET https://api.solaris-servers.ru/v1/players/:steamId/bhaps
    * 
    * @param szUrl              Buffer to write URL to
    * @param iMaxlength         Maximum length of szBuffer
    * @param szAuthId           Steam ID
    */
    public static void GetBhapStatusForAuthId(char[] szUrl, int iMaxlength, const char[] szAuthId) {
        char szAuthId[64];
        GetClientAuthId(iClient, AuthId_SteamID64, szAuthId, sizeof(szAuthId), true);
        Format(szUrl, iMaxlength, "%s/v1/players/%s/bhaps", SAPI_BASE, szAuthId);
    }

    /**
    * GET https://api.solaris-servers.ru/v1/players/:steamId/rank
    * 
    * @param szUrl              Buffer to write URL to
    * @param iMaxlength         Maximum length of szBuffer
    * @param iClient            Steam ID
    */
    public static void GetRankForClient(char[] szUrl, int iMaxlength, int iClient) {
        Format(szUrl, iMaxlength, "%s/v1/players/%s/bhaps", SAPI_BASE, szAuthId);
    }

    /**
    * GET https://api.solaris-servers.ru/v1/players/:steamId/rank
    * 
    * @param szUrl              Buffer to write URL to
    * @param iMaxlength         Maximum length of szBuffer
    * @param szAuthId           Steam ID
    */
    public static void GetRankForAuthId(char[] szUrl, int iMaxlength, const char[] szAuthId) {
        Format(szUrl, iMaxlength, "%s/v1/players/%s/bhaps", SAPI_BASE, szAuthId);
    }
}
