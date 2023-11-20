#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>

#define MAXLENGTH_FLAG 32
#define MAX_COLORS     12

bool   g_bLateload;
bool   g_bEatMultiSpace;
bool   g_bHideNickChange;

ConVar g_cvEatMultiSpace;
ConVar g_cvHideNickChange;

static const char g_szTags[][] = {
    "{default}",
    "{darkred}",
    "{green}",
    "{lightgreen}",
    "{red}",
    "{blue}",
    "{olive}",
    "{lime}",
    "{lightred}",
    "{purple}",
    "{grey}",
    "{orange}"
};

static const char g_szTagsSwap[][] = {
    "(default)",
    "(darkred)",
    "(green)",
    "(lightgreen)",
    "(red)",
    "(blue)",
    "(olive)",
    "(lime)",
    "(lightred)",
    "(purple)",
    "(grey)",
    "(orange)"
};

public Plugin myinfo = {
    name        = "BeQuiet + Name Normalizer",
    author      = "Sir, Dragokas",
    description = "Please be Quiet!",
    version     = "1.33.7",
    url         = "https://github.com/SirPlease/SirCoding"
}

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    g_bLateload = bLate;
    return APLRes_Success;
}

public void OnPluginStart() {
    g_cvEatMultiSpace  = CreateConVar(
    "l4d2_eat_multi_space", "1", "Eat subsequent space characters? (1 - Yes, 0 - No)",
    FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_bEatMultiSpace = g_cvEatMultiSpace.BoolValue;
    g_cvEatMultiSpace.AddChangeHook(OnCvarChanged);

    g_cvHideNickChange = CreateConVar(
    "l4d2_hide_nick_change", "1",
    "Always hide nickname change notification in chat? (1 - Yes, 0 - No)",
    FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_bHideNickChange = g_cvHideNickChange.BoolValue;
    g_cvHideNickChange.AddChangeHook(OnCvarChanged);

    HookUserMessage(GetUserMessageId("SayText2"), UserMsg_OnSayText2, true);

    // Server ConVar
    HookEvent("server_cvar", Event_ServerConVar, EventHookMode_Pre);

    if (g_bLateload) {
        for (int i = 1; i <= MaxClients; i++) {
            if (!IsClientInGame(i))
                continue;

            OnClientPutInServer(i);
        }
    }
}

public void OnClientPutInServer(int iClient) {
    if (IsFakeClient(iClient))
        return;

    ValidateName(iClient);
}

void OnCvarChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bEatMultiSpace  = g_cvEatMultiSpace.BoolValue;
    g_bHideNickChange = g_cvHideNickChange.BoolValue;
}

Action UserMsg_OnSayText2(UserMsg MsgId, BfRead Msg, const int[] iPlayers, int iPlayersNum, bool bReliable, bool bInit) {
    int iSender = Msg.ReadByte();

    if (iSender <= 0)
        return Plugin_Continue;

    Msg.ReadByte(); // Chat Type

    static char szFlag[MAXLENGTH_FLAG];
    Msg.ReadString(szFlag, sizeof(szFlag));

    if (strcmp(szFlag, "#Cstrike_Name_Change") == 0) {
        RequestFrame(OnNextFrame, GetClientUserId(iSender));
        if (g_bHideNickChange)
            return Plugin_Handled;
    }

    return Plugin_Continue;
}

void OnNextFrame(int iUserId) {
    int iClient = GetClientOfUserId(iUserId);
    if (iClient <= 0)
        return;

    if (!IsClientInGame(iClient))
        return;

    ValidateName(iClient);
}

Action Event_ServerConVar(Event eEvent, const char[] szName, bool bDontBroadcast) {
    return Plugin_Handled;
}

void ValidateName(int iClient) {
    char szName[MAX_NAME_LENGTH];
    char szNew [MAX_NAME_LENGTH];
    int i, j, k, iBytes, iPrev;
    if (!GetClientInfo(iClient, "name", szName, sizeof szName))
        return;

    i = 0;
    while (szName[i]) {
        iBytes = GetCharBytes(szName[i]);
        if (iBytes > 1) {
            for (k = 0; k < iBytes; k++) {
                szNew[j++] = szName[i++];
            }
        } else {
            if (g_bEatMultiSpace) {
                if (szName[i] == 32 && iPrev == 32) {
                    i++;
                    continue;
                }
            }

            if (szName[i] >= 32) {
                szNew[j++] = szName[i++];
            } else {
                i++;
            }
        }

        iPrev = szName[i - 1];
    }

    RemoveTags(szNew, sizeof(szNew));
    if (strcmp(szName, szNew) == 0)
        return;

    SetClientInfo(iClient, "name", szNew);
}

stock void RemoveTags(char[] szName, int iLength) {
    for (int i = 0; i < MAX_COLORS; i++) {
        ReplaceString(szName, iLength, g_szTags[i], g_szTagsSwap[i], false);
    }
    ReplaceString(szName, iLength, "{teamcolor}", "(teamcolor)", false);
}