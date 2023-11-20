#if defined _solarisapi_contests_AwardPointsPayload_included
 #endinput
#endif
#define _solarisapi_contests_AwardPointsPayload_included

#include <ripext/json>

/**
 * {
 *   points: number,
 *   steam_id: string,
 *   event_type: string,
 *   map?: string,
 *   server_port?: number
 * }
 */
methodmap AwardPointsPayload < JSONObject {
    /*
     * Virtual
     */
    property int Client {
        public get() { return this.GetInt("client_index"); }
        public set(int iClient) { this.SetInt("client_index", iClient); }
    }
    /**
     * "points": number
     */
    property int Points {
        public get() { return this.GetInt("points"); }
        public set(int iAmount) { this.SetInt("points", iAmount); }
    }
    /**
     * "server_port": number
     */
    property int ServerPort {
        public get() { return this.GetInt("server_port"); }
        public set(int iPort) { this.SetInt("server_port", iPort); }
    }

    /**
     * "steam_id": string
     *
     * @param szSteamId             SteamID
     */
    public AwardPointsPayload SetSteamId(const char[] szSteamId) {
        this.SetString("steam_id", szSteamId);
    }

    /**
     * "steam_id": string
     *
     * @param szBuffer             Buffer to write value to
     * @param iMaxlength           Buffer size
     */
    public void GetSteamId(char[] szBuffer, int iMaxlength) {
        this.GetString("steam_id", szBuffer, iMaxlength);
    }

    /**
     * "event_type": string
     *
     * @param szEventType             Event Type
     */
    public AwardPointsPayload SetEventType(const char[] szEventType) {
        this.SetString("event_type", szEventType);
    }

    /**
     * "event_type": string
     *
     * @param szBuffer             Buffer to write value to
     * @param iMaxlength           Buffer size
     */
    public void GetEventType(char[] szBuffer, int iMaxlength) {
        this.GetString("event_type", szBuffer, iMaxlength);
    }

    /**
     * "map": string
     *
     * @param szMap             Current map
     */
    public AwardPointsPayload SetMap(const char[] szMap) {
        this.SetString("map", szMap);
    }

    /**
     * "map": string
     *
     * @param szBuffer             Buffer to write value to
     * @param iMaxlength           Buffer size
     */
    public void GetMap(char[] szBuffer, int iMaxlength) {
        this.GetString("map", szBuffer, iMaxlength);
    }

    public AwardPointsPayload() { return view_as<AwardPointsPayload>(new JSONObject()); }
}