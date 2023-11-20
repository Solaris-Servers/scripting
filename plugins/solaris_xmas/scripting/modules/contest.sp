#if defined __CONTEST__
    #endinput
#endif
#define __CONTEST__

#define CONTEST_ID "xmas"

void Contest_OnModuleStart() {
    ContestsApi.SetRewardAmount(CONTEST_ID, g_cvXmasVipCount.IntValue);
}

/**
 * POST https://api.solaris-servers.ru/v1/contests/:contestId/award-points
 * Logs points to a player contestant and rewards them, total amount of points is sufficient
 *
 * @param iClient             Client
 * @param iPoints             Amount of points to award player with
 */
void Request_AwardPoints(int iClient, int iPoints) {
    char szSteamID[64];
    GetClientAuthId(iClient, AuthId_SteamID64, szSteamID, sizeof(szSteamID));
    AwardPointsPayload payload = new AwardPointsPayload();
    payload.SetSteamId(szSteamID);
    payload.SetEventType("gift_pickup");
    payload.SetMap(g_szMapName);
    payload.Client = iClient;
    payload.Points = iPoints;
    payload.ServerPort = FindConVar("hostport").IntValue;
    ContestsApi.AwardPoints(CONTEST_ID, payload, Response_AwardPoints);
    delete payload;
}

void Response_AwardPoints(HTTPResponse res, HTTPRequestConfig req, AwardPointsResponse data) {
    AwardPointsPayload reqData = view_as<AwardPointsPayload>(req.Data);
    int iClient = reqData.Client;
    if (IsClientInGame(iClient)) {
        if (data.WasRewarded) {
            EmitSoundToClient(iClient, "npc/moustachio/strengthlvl5_sostrong.wav", SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
            if (data.WasVipBeforeReward) {
                if (data.IsTempVip) {
                    CPrintToChat(iClient, "{blue} ");
                    CPrintToChat(iClient, "{green}★★★ {olive}Congratulations! {blue}You{default}'ve just collected all gifts.\nAn extra {olive}1 month{default} of {green}VIP status {default}was added to your account!");
                    CPrintToChat(iClient, "{blue} ");
                } else {
                    CPrintToChat(iClient, "{blue} ");
                    CPrintToChat(iClient, "{green}★★★ {olive}Congratulations! {blue}Ti{default} itak uje vechniy VIP, a vso begaew, podbiraew s pola vsyakoe!");
                    CPrintToChat(iClient, "{blue} ");
                }
            } else {
                    CPrintToChat(iClient, "{blue} ");
                    CPrintToChat(iClient, "{green}★★★ {olive}Congratulations! {blue}You{default}'ve just collected all gifts.\nNow you have {green}VIP status {default}for {olive}1 month{default}!");
                    CPrintToChat(iClient, "{blue} ");
            }
        } else {
            EmitSoundToClient(iClient, "UI/LittleReward.wav", SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
            int iPoints = data.Points;
            int iPointsToNextReward = data.PointsToNextReward;
            if (iPoints == 1) {
                CPrintToChat(iClient, "{green}★ {blue}You{default}'ve picked up a gift, {blue}%d{default} more to go!", iPointsToNextReward);
            } else {
                int iRandom = GetRandomInt(1, 7);
                switch (iRandom) {
                    case 1: CPrintToChat(iClient, "{green}★{default} Keep it up, {blue}%d{default} more to go!", iPointsToNextReward);
                    case 2: CPrintToChat(iClient, "{green}★{default} That's amazing, {blue}%d{default} more to go!", iPointsToNextReward);
                    case 3: CPrintToChat(iClient, "{green}★{default} Go on, {blue}%d{default} more to go!", iPointsToNextReward);
                    case 4: CPrintToChat(iClient, "{green}★{default} Keep calm and carry on, {blue}%d{default} more to go!", iPointsToNextReward);
                    case 5: CPrintToChat(iClient, "{green}★{default} Nice, {blue}%d{default} more to go!", iPointsToNextReward);
                    case 6: CPrintToChat(iClient, "{green}★{default} Wonderful, {blue}%d{default} more to go!", iPointsToNextReward);
                    case 7: CPrintToChat(iClient, "{green}★{default} Good going, {blue}%d{default} more to go!", iPointsToNextReward);
                }
            }
        }
    }
    delete data;
}