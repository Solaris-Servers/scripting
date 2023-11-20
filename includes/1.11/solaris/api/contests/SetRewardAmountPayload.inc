#if defined _solarisapi_contests_SetRewardAmountPayload_included
 #endinput
#endif
#define _solarisapi_contests_SetRewardAmountPayload_included

#include <ripext/json>

/**
 * {
 *   points_to_reward: number
 * }
 */
methodmap SetRewardAmountPayload < JSONObject {
    /**
     * "points_to_reward": number
     */
    property int PointsToReward {
        public get() { return this.GetInt("points_to_reward"); }
        public set(int iAmount) { this.SetInt("points_to_reward", iAmount); }
    }

    public SetRewardAmountPayload() { return view_as<SetRewardAmountPayload>(new JSONObject()); }
}