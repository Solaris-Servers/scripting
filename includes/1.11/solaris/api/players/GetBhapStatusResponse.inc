#if defined _solarisapi_players_GetBhapStatusResponse_included
 #endinput
#endif
#define _solarisapi_players_GetBhapStatusResponse_included

#include <ripext/json>

/**
 * {
 *   isBlocked: boolean
 * }
 */
methodmap GetBhapStatusResponse < JSONObject {
    /**
     * "isBlocked": number
     */
    property bool IsBlocked {
        public get() { return this.GetBool("isBlocked"); }
    }

    public GetBhapStatusResponse() { return view_as<GetBhapStatusResponse>(new JSONObject()); }
}
