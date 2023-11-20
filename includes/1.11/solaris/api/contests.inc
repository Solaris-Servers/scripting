#if defined _solarisapi_contests_included
 #endinput
#endif
#define _solarisapi_contests_included

#include <solaris/api/variables>
#include <solaris/api/client>
#include <solaris/api/contests/url>
#include <solaris/api/contests/AwardPointsPayload>
#include <solaris/api/contests/AwardPointsResponse>
#include <solaris/api/contests/SetRewardAmountPayload>

typeset ContestsApi_AwardPoints {
    function void (HTTPResponse res, HTTPRequestConfig req, AwardPointsResponse data);
}

methodmap ContestsApi {
    /**
     * POST https://api.solaris-servers.ru/v1/contests/:contestId/award-points
     * 
     * Awards points to a player contestant and rewards them with an item for a given conetest (if contest conditions are met)
     *
     * @param contestId                 Existing Contest ID
     * @param payload                   AwardPointsPayload instance
     * @param func                      function void (HTTPResponse res, HTTPRequestConfig req, AwardPointsResponse data)
     */
    public static void AwardPoints(const char[] contestId, AwardPointsPayload payload, ContestsApi_AwardPoints func) {
        char url[2000];
        ContestUrlBuilder.AwardPoints(url, sizeof(url), contestId);
        // http
        HTTPRequest req = CreateHTTPRequest(url);
        HTTPRequestConfig config = new HTTPRequestConfig(url, HTTP_POST, HTTPStatus_Created);
        config.Data = payload;
        config.OnSuccess(view_as<HTTPRequestSuccessCallback>(func));
        // request
        req.Post(payload, HTTPResponseMiddleware, config);
    }

    /**
     * PATCH https://api.solaris-servers.ru/v1/contests/:contestId/set-reward-amount
     * 
     * Updates amount of points required for players to receive contest's reward (contest must exist on the servers)
     * NOTE: changes to this value does not award players retroactively
     *
     * @param contestId                 Existing Contest ID
     * @param amount                    Amount of points required to receive contest's reward
     */
    public static void SetRewardAmount(const char[] contestId, int amount) {
        char url[2000];
        ContestUrlBuilder.SetRewardAmount(url, sizeof(url), contestId);
        // payload
        SetRewardAmountPayload payload = new SetRewardAmountPayload();
        payload.PointsToReward = amount;
        // http
        HTTPRequest req = CreateHTTPRequest(url);
        HTTPRequestConfig config = new HTTPRequestConfig(url, HTTP_PATCH);
        // request
        req.Patch(payload, HTTPResponseMiddleware, config);
        delete payload;
    }
}