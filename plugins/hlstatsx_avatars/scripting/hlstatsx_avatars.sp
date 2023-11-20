#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <ripext>
#include <solaris/api/players>

public Plugin myinfo = {
    name        = "[Solaris] HLStatsX Avatars",
    author      = "0x0c",
    description = "",
    version     = "1.0.0",
    url         = "https://solaris-servers.ru/"
};

public void OnPluginStart() {
    RegAdminCmd("sm_hlx_avatar", Cmd_SmHlxAvatar, ADMFLAG_ROOT, "Test avatar refresh for player. Usage sm_hlx_avatar <steam_id>");
}

public Action Cmd_SmHlxAvatar(int iClient, int iArgs) {
    if (iClient == 0 && iArgs == 0) {
        ReplyToCommand(iClient, "[AvatarsForHLX] Usage: sm_hlx_avatar <steam_id>");
        return Plugin_Handled;
    }
    char szAuthId[64];
    if (iArgs > 0) {
        GetCmdArg(1, szAuthId, sizeof(szAuthId));
    } else {
        GetClientAuthId(iClient, AuthId_SteamID64, szAuthId, sizeof(szAuthId), true);
    }
    Request_RefreshAvatar(szAuthId);
    return Plugin_Handled;
}

public void OnClientConnected(int iClient) {
    CreateTimer(20.0, UpdateAvatars, iClient);
}

public Action UpdateAvatars(Handle timer, int iClient) {
    if (iClient < 1 || !IsClientInGame(iClient) || IsFakeClient(iClient))
        return Plugin_Stop;
    char szAuthId[64];
    GetClientAuthId(iClient, AuthId_SteamID64, szAuthId, sizeof(szAuthId), true);
    Request_RefreshAvatar(szAuthId);
    PlayersApi.RefreshAvatarForAuthId(szAuthId);
    return Plugin_Stop;
}

public void Request_RefreshAvatar(const char[] szAuthId) {
    char szUrl[2000];
    PlayersUrlBuilder.RefreshAvatarForAuthId(szUrl, sizeof(szUrl), szAuthId);
    JSONObject dto = new JSONObject();
    HTTPRequest req = new HTTPRequest(szUrl);
    req.SetHeader("Authorization", SAPI_AUTHORIZAION_HEADER);
    req.Patch(dto, Response_RefreshAvatar);
    delete dto;
}

public void Response_RefreshAvatar(HTTPResponse res, any value) {
    // char szResponse[2000];
    // res.Data.ToString(szResponse, sizeof(szResponse));
    // PrintToServer(szResponse);
}
