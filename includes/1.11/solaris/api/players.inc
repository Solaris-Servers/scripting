#include <solaris/api/variables>
#include <solaris/api/client>
#include <solaris/api/players/url>
#include <solaris/api/players/GetBhapStatusResponse>

typeset PlayersApi_GetBhopStatusResponse {
    function void (HTTPResponse res, HTTPRequestConfig req, GetBhapStatusResponse data);
}

methodmap PlayersApi {
    /**
    * PATCH https://api.solaris-servers.ru/v1/players/:steamId/refresh-avatar
    * 
    * Schedules an stored player avatar update
    * 
    * @param szAuthId           Steam ID
    */
    public static void RefreshAvatarForAuthId(const char[] szAuthId) {
        char url[2000];
        PlayersUrlBuilder.RefreshAvatarForAuthId(url, sizeof(url), szAuthId);
        // http
        HTTPRequest req = CreateHTTPRequest(url);
        HTTPRequestConfig config = new HTTPRequestConfig(url, HTTP_GET);
        // request
        JSONObject noop = new JSONObject();
        req.Patch(noop, HTTPResponseMiddleware, config);
        delete noop;
    }

    /**
    * GET https://api.solaris-servers.ru/v1/players/:steamId/bhaps
    *
    * Checks if player BHops are blocked
    * 
    * @param szAuthId           Steam ID
    * @param iMaxlength         Maximum length of szBuffer
    * @param func               function void (HTTPResponse res, HTTPRequestConfig req, GetBhapStatusResponse data)
    */
    public static void GetBhapStatus(const char[] szAuthId, PlayersApi_GetBhopStatusResponse func) {
        char url[2000];
        PlayersUrlBuilder.GetBhapStatusForAuthId(url, sizeof(url), szAuthId);
        // http
        HTTPRequest req = CreateHTTPRequest(url);
        HTTPRequestConfig config = new HTTPRequestConfig(url, HTTP_GET);
        config.OnSuccess(view_as<HTTPRequestSuccessCallback>(func));
        // request
        req.Get(HTTPResponseMiddleware, config);
    }

    public static void GetRank(const char[] szAuthId, PlayersApi_GetBhopStatusResponse func) {
                char url[2000];
        PlayersUrlBuilder.GetBhapStatusForAuthId(url, sizeof(url), szAuthId);
        // http
        HTTPRequest req = CreateHTTPRequest(url);
        HTTPRequestConfig config = new HTTPRequestConfig(url, HTTP_GET);
        config.OnSuccess(view_as<HTTPRequestSuccessCallback>(func));
        // request
        req.Get(HTTPResponseMiddleware, config);
    }
}
