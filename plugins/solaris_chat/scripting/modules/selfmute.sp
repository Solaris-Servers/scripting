#if defined __SelfMute__
    #endinput
#endif
#define __SelfMute__

enum struct Targeting {
    char szArg       [MAX_NAME_LENGTH];
    int  iBuffer     [MAXPLAYERS + 1];
    int  iBufferSize;
    char szTargetName[MAX_TARGET_LENGTH];
    bool bTnIsMl;
}

Targeting eTarget;

enum struct IgnoreStatus {
    int Chat;
    int Voice;
}

IgnoreStatus eIgnoreMatrix[MAXPLAYERS + 1][MAXPLAYERS + 1];

void SelfMute_OnModuleStart() {
    RegConsoleCmd("sm_smute",   Command_Ignore,   "Usage: sm_smute <#userid|name>\nSet target's chat and voice to be ignored.");
    RegConsoleCmd("sm_sunmute", Command_UnIgnore, "Usage: sm_sunmute <#userid|name>\nUnmutes target.");
}

/**
 *  Commands
**/
Action Command_Ignore(int iClient, int iArgs) {
    if (iArgs == 0) {
        CPrintToChat(iClient, "Usage: {olive}sm_smute{green} <{blue}#userid{default}|{blue}name{green}>");
        return Plugin_Handled;
    }
    ProcessIgnore(iClient, true, true, 3);
    return Plugin_Handled;
}

Action Command_UnIgnore(int iClient, int iArgs) {
    if (iArgs == 0) {
        CPrintToChat(iClient, "Usage: {olive}sm_sunmute{green} <{blue}#userid{default}|{blue}name{green}>");
        return Plugin_Handled;
    }
    ProcessIgnore(iClient, false, false, 3);
    return Plugin_Handled;
}

void SelfMute_OnClientPutInServer(int iClient) {
    for (int i = 1; i <= MaxClients; i++) {
        eIgnoreMatrix[iClient][i].Chat  = false;
        eIgnoreMatrix[iClient][i].Voice = false;
    }
}

void SelfMute_OnClientDisconnect(int iClient) {
    for (int i = 1; i <= MaxClients; i++) {
        eIgnoreMatrix[iClient][i].Chat  = false;
        eIgnoreMatrix[iClient][i].Voice = false;
    }
}

/**
 *  client is the person ignoring someone
 *  the chat/voice bool says what we want to set their status to
 *  which says whether or not we're actually changing chat 1, voice 2, or both 3
**/
void ProcessIgnore(int iClient, const bool bChat = false, const bool bVoice = false, const int iFlags) {
    GetCmdArg(1, eTarget.szArg, MAX_NAME_LENGTH);
    bool bTargetAll = false;
    if (strcmp(eTarget.szArg, "@all", false) == 0)
        bTargetAll = true;
    eTarget.iBufferSize = ProcessTargetString(eTarget.szArg, iClient, eTarget.iBuffer, MaxClients + 1, COMMAND_FILTER_CONNECTED|COMMAND_FILTER_NO_IMMUNITY, eTarget.szTargetName, MAX_TARGET_LENGTH, eTarget.bTnIsMl);
    if (eTarget.iBufferSize <= 0) {
        ReplyToTargetError(iClient, eTarget.iBufferSize);
        return;
    }
    for (int i = 0; i < eTarget.iBufferSize; i++) {
        ToggleIgnoreStatus(iClient, eTarget.iBuffer[i], bChat, bVoice, iFlags, bTargetAll);
    }
    if (!bTargetAll) return;
    char szBuffer[MAXLENGTH_MESSAGE];
    Format(szBuffer, sizeof(szBuffer), "{green}[{default}SelfMute{green}] {olive}All Players{default} - Chat: %s | Voice: %s", !(iFlags & 1) ? "Unchanged" : bChat  ? "{red}OFF{default}" : "{blue}ON{default}",
                                                                                                                               !(iFlags & 2) ? "Unchanged" : bVoice ? "{red}OFF{default}" : "{blue}ON{default}");
    CPrintToChat(iClient, szBuffer);
}

void ToggleIgnoreStatus(const int iClient, const int iTarget, const bool bChat, const bool bVoice, const int iFlags, const bool bTargetAll) {
    if (iFlags & 1) eIgnoreMatrix[iClient][iTarget].Chat = bChat;
    if (iFlags & 2) {
        eIgnoreMatrix[iClient][iTarget].Voice = bVoice;
        SetListenOverride(iClient, iTarget, eIgnoreMatrix[iClient][iTarget].Voice ? Listen_No : Listen_Default);
    }
    if (bTargetAll) return;
    char szBuffer[MAXLENGTH_MESSAGE];
    Format(szBuffer, sizeof(szBuffer), "{green}[{default}SelfMute{green}] {olive}%N{default} - Chat: %s | Voice: %s", iTarget,
                                                                                                                      eIgnoreMatrix[iClient][iTarget].Chat  ? "{red}OFF{default}" : "{blue}ON{default}",
                                                                                                                      eIgnoreMatrix[iClient][iTarget].Voice ? "{red}OFF{default}" : "{blue}ON");
    CPrintToChat(iClient, szBuffer);
}

void SelfMute_OnChatMessage(int iClient, ArrayList aRecipients) {
    int iRecipient;
    for (int i = 0; i < aRecipients.Length; i++) {
        iRecipient = GetClientOfUserId(aRecipients.Get(i));
        if (iRecipient <= 0)
            continue;

        if (eIgnoreMatrix[iRecipient][iClient].Chat) {
            aRecipients.Erase(i);
        }
    }
}