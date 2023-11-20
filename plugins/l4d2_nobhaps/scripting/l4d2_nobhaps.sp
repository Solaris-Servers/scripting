#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ripext>
#include <solaris/api/players>

#define GAMEDATA_FILE "left4dhooks.l4d2"

bool   g_bBlockBH [MAXPLAYERS + 1];
float  g_fNextJump[MAXPLAYERS + 1];

ConVar g_cvEnable;
bool   g_bEnabled;

ConVar g_cvBlockSpam;
bool   g_bBlockSpam;

ConVar g_cvSIExcept;
int    g_iSiExcept;

ConVar g_cvTankExcept;
bool   g_bTankExcept;

ConVar g_cvSurvivorExcept;
bool   g_bSurvivorExcept;

Handle g_hGetRunTopSpeed;

public Plugin myinfo = {
    name        = "Anti BH",
    author      = "CanadaRox, ProdigySim, blodia, CircleSquared, robex",
    description = "Stops bunnyhops by restricting speed when a player lands on the ground to their MaxSpeed",
    version     = "0.5",
    url         = "https://bitbucket.org/CanadaRox/random-sourcemod-stuff/"
};

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    CreateNative("IsClientBlockedBH", Native_BlockBH);
    RegPluginLibrary("l4d2_nobhaps");
    return APLRes_Success;
}

any Native_BlockBH(Handle hPlugin, int iNumParams) {
    int iClient = GetNativeCell(1);
    return g_bBlockBH[iClient];
}

public void OnPluginStart() {
    LoadSDK();

    g_cvEnable = CreateConVar(
    "bhop_block_enabled", "1", "Enable or disable the Simple Anti-Bhop plugin",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bEnabled = g_cvEnable.BoolValue;
    g_cvEnable.AddChangeHook(OnCvarChange);

    g_cvBlockSpam = CreateConVar(
    "bhop_block_spam", "0", "Block wheel/macro spam",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bBlockSpam = g_cvBlockSpam.BoolValue;
    g_cvBlockSpam.AddChangeHook(OnCvarChange);

    g_cvSIExcept = CreateConVar(
    "bhop_except_si_flags", "63", "Bitfield for exempting SI in anti-bhop functionality.",
    FCVAR_NONE, true, 0.0, true, 63.0);
    g_iSiExcept = g_cvSIExcept.IntValue;
    g_cvSIExcept.AddChangeHook(OnCvarChange);

    g_cvTankExcept = CreateConVar(
    "bhop_allow_tank", "1", "Allow Tank to bhop while plugin is enabled",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bTankExcept = g_cvTankExcept.BoolValue;
    g_cvTankExcept.AddChangeHook(OnCvarChange);

    g_cvSurvivorExcept = CreateConVar(
    "bhop_allow_survivor", "1", "Allow Survivors to bhop while plugin is enabled",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bSurvivorExcept = g_cvSurvivorExcept.BoolValue;
    g_cvSurvivorExcept.AddChangeHook(OnCvarChange);
}

void LoadSDK() {
    GameData gmConf = new GameData(GAMEDATA_FILE);
    if (gmConf == null)
        SetFailState("Could not load gamedata/%s.txt", GAMEDATA_FILE);
    StartPrepSDKCall(SDKCall_Player);

    if (!PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, "CTerrorPlayer::GetRunTopSpeed"))
        SetFailState("Function 'CTerrorPlayer::GetRunTopSpeed' not found");

    PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
    g_hGetRunTopSpeed = EndPrepSDKCall();
    if (g_hGetRunTopSpeed == null)
        SetFailState("Function 'CTerrorPlayer::GetRunTopSpeed' found, but something went wrong");

    delete gmConf;
}

void OnCvarChange(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bEnabled        = g_cvEnable.BoolValue;
    g_bBlockSpam      = g_cvBlockSpam.BoolValue;
    g_iSiExcept       = g_cvSIExcept.IntValue;
    g_bTankExcept     = g_cvTankExcept.BoolValue;
    g_bSurvivorExcept = g_cvSurvivorExcept.BoolValue;
}

public void OnClientPutInServer(int iClient) {
    g_bBlockBH [iClient] = false;
    g_fNextJump[iClient] = 0.0;
}

public void OnClientPostAdminCheck(int iClient) {
    Request_GetBhapStatus(iClient);
}

public void OnClientDisconnect(int iClient) {
    g_bBlockBH [iClient] = false;
    g_fNextJump[iClient] = 0.0;
}

void Request_GetBhapStatus(int iClient) {
    if (!IsClientInGame(iClient))
        return;

    if (IsFakeClient(iClient))
        return;

    static char szUrl[2000];
    PlayersUrlBuilder.GetBhapStatusForClient(szUrl, sizeof(szUrl), iClient);
    HTTPRequest req = new HTTPRequest(szUrl);
    req.ConnectTimeout = 4;
    req.SetHeader("Authorization", SAPI_AUTHORIZAION_HEADER);
    req.Get(Response_GetBhapStatus, iClient);
}

void Response_GetBhapStatus(HTTPResponse res, any value, const char[] szClientErr) {
    int iClient = view_as<int>(value);
    if (!IsClientInGame(iClient))
        return;

    if (IsFakeClient(iClient))
        return;

    static char szReqUrl[2000];
    PlayersUrlBuilder.GetBhapStatusForClient(szReqUrl, sizeof(szReqUrl), iClient);
    if (strlen(szClientErr)) {
        LogToGame("GET %s: %s\nRetrying...", szReqUrl, szClientErr);
        CreateTimer(1.0, Timer_GetBhapStatusRetry, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
        return;
    }

    if (res.Status != HTTPStatus_OK) {
        static char szResponseErr[2048];
        res.Data.ToString(szResponseErr, sizeof(szResponseErr));
        LogToGame("GET %s: \n%s\nRetrying...", szReqUrl, szResponseErr);
        CreateTimer(1.0, Timer_GetBhapStatusRetry, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
        return;
    }

    if (IsClientInGame(iClient) && !IsFakeClient(iClient)) {
        JSONObject resData = view_as<JSONObject>(res.Data);
        g_bBlockBH[iClient] = resData.GetBool("isBlocked");
        delete resData;
        return;
    }

    g_bBlockBH[iClient] = false;
}

Action Timer_GetBhapStatusRetry(Handle hTimer, int iUserId) {
    int iClient = GetClientOfUserId(iUserId);
    if (iClient <= 0)
        return Plugin_Stop;

    Request_GetBhapStatus(iClient);
    return Plugin_Stop;
}

public void OnPlayerRunCmdPost(int iClient, int iButtons) {
    static float fLeftGroundMaxSpeed[MAXPLAYERS + 1];

    if (!g_bEnabled)
        return;

    if (!IsClientInGame(iClient))
        return;

    if (IsFakeClient(iClient))
        return;

    if (!IsPlayerAlive(iClient))
        return;

    static float fCurTime;
    fCurTime = GetGameTime();

    static int iTeam;
    iTeam = GetClientTeam(iClient);

    static bool bAllowBhop;
    bAllowBhop = false;

    static int iClass;
    switch (iTeam) {
        case 3: {
            iClass = GetEntProp(iClient, Prop_Send, "m_zombieClass");
            switch (iClass) {
                case 8: {
                    bAllowBhop = g_bTankExcept;
                }
                default: {
                    bAllowBhop = ((1 << (iClass - 1)) & g_iSiExcept) > 0;
                }
            }
        }
        case 2: {
            bAllowBhop = g_bSurvivorExcept;
        }
    }

    if ((iButtons & IN_JUMP) && fCurTime >= g_fNextJump[iClient]) g_fNextJump[iClient] = fCurTime + 0.4;

    if (!AllowBhop(iClient, bAllowBhop, fCurTime)) {
        if ((GetEntityFlags(iClient) & FL_ONGROUND)) {
            if (fLeftGroundMaxSpeed[iClient] != -1.0) {
                float vCurVel[3];
                GetEntPropVector(iClient, Prop_Data, "m_vecAbsVelocity", vCurVel);
                if (GetVectorLength(vCurVel) > fLeftGroundMaxSpeed[iClient]) {
                    NormalizeVector(vCurVel, vCurVel);
                    ScaleVector(vCurVel, fLeftGroundMaxSpeed[iClient]);
                    TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, vCurVel);
                }
                fLeftGroundMaxSpeed[iClient] = -1.0;
            }
        } else if (fLeftGroundMaxSpeed[iClient] == -1.0) {
            fLeftGroundMaxSpeed[iClient] = SDKCall(g_hGetRunTopSpeed, iClient);
        }
    }
}

bool AllowBhop(int iClient, bool bAllowBhop, float fCurTime) {
    if (!bAllowBhop)
        return false;

    if (g_bBlockBH[iClient])
        return false;

    if (g_bBlockSpam)
        return fCurTime < g_fNextJump[iClient];

    return true;
}
