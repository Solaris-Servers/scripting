#if defined _solarisapi_contests_AwardPointsResponse_included
 #endinput
#endif
#define _solarisapi_contests_AwardPointsResponse_included

#include <ripext/json>

/**
 * {
 *   points: number,
 *   pointsToNextReward: number
 *   isTempVip: boolean,
 *   wasRewarded: boolean,
 *   wasVipBeforeReward: boolean,
 * }
 */
methodmap AwardPointsResponse < JSONObject {
    /**
     * "points": number
     */
    property int Points {
        public get() { return this.GetInt("points"); }
    }
    /**
     * "pointsToNextReward": number
     */
    property int PointsToNextReward {
        public get() { return this.GetInt("pointsToNextReward"); }
    }
    /**
     * "isTempVip": number
     */
    property bool IsTempVip {
        public get() { return this.GetBool("isTempVip"); }
    }
    /**
     * "wasRewarded": number
     */
    property bool WasRewarded {
        public get() { return this.GetBool("wasRewarded"); }
    }
    /**
     * "wasVipBeforeReward": number
     */
    property bool WasVipBeforeReward {
        public get() { return this.GetBool("wasVipBeforeReward"); }
    }

    public AwardPointsResponse() { return view_as<AwardPointsResponse>(new JSONObject()); }
}