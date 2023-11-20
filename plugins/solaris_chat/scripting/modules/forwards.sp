#if defined __Forwards__
    #endinput
#endif
#define __Forwards__

GlobalForward fwdOnConsoleChatMessage;
GlobalForward fwdOnConsoleChatMessagePost;
GlobalForward fwdOnChatMessage;
GlobalForward fwdOnChatMessagePost;

void Forwards_AskPluginLoad2() {
    // Global Forwards
    fwdOnConsoleChatMessage = new GlobalForward(
    "SolarisChat_OnConsoleChatMessage",
    ET_Hook, Param_String);

    fwdOnConsoleChatMessagePost = new GlobalForward(
    "SolarisChat_OnConsoleChatMessagePost",
    ET_Ignore, Param_String);

    fwdOnChatMessage = new GlobalForward(
    "SolarisChat_OnChatMessage",
    ET_Hook, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String, Param_String, Param_String, Param_String, Param_String, Param_String);

    fwdOnChatMessagePost = new GlobalForward(
    "SolarisChat_OnChatMessagePost",
    ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String, Param_String, Param_String, Param_String, Param_String, Param_String);
}

Action Forwards_OnConsoleChatMessage(char[] szMsg) {
    Action aResult = Plugin_Continue;
    Call_StartForward(fwdOnConsoleChatMessage);
    Call_PushString(szMsg);
    Call_Finish(aResult);
    return aResult;
}

void Forwards_OnConsoleChatMessagePost(const char[] szMsg) {
    Call_StartForward(fwdOnConsoleChatMessagePost);
    Call_PushString(szMsg);
    Call_Finish();
}

Action Forwards_OnChatMessage(int iClient, int iArgs, int iTeam, bool bTeamChat, ArrayList aRecipients, char[] szTagColor, char[] szTag, char[] szNameColor, char[] szName, char[] szMsgColor, char[] szMsg) {
    Action aResult = Plugin_Continue;
    Call_StartForward(fwdOnChatMessage);
    Call_PushCell(iClient);
    Call_PushCell(iArgs);
    Call_PushCell(iTeam);
    Call_PushCell(bTeamChat);
    Call_PushCell(aRecipients);
    Call_PushString(szTagColor);
    Call_PushString(szTag);
    Call_PushString(szNameColor);
    Call_PushString(szName);
    Call_PushString(szMsgColor);
    Call_PushString(szMsg);
    Call_Finish(aResult);
    return aResult;
}

void Forwards_OnChatMessagePost(const int iClient, const int iArgs, const int iTeam, const bool bTeamChat, const ArrayList aRecipients, const char[] szTagColor, const char[] szTag, const char[] szNameColor, const char[] szName, const char[] szMsgColor, const char[] szMsg) {
    Call_StartForward(fwdOnChatMessagePost);
    Call_PushCell(iClient);
    Call_PushCell(iArgs);
    Call_PushCell(iTeam);
    Call_PushCell(bTeamChat);
    Call_PushCell(aRecipients);
    Call_PushString(szTagColor);
    Call_PushString(szTag);
    Call_PushString(szNameColor);
    Call_PushString(szName);
    Call_PushString(szMsgColor);
    Call_PushString(szMsg);
    Call_Finish();
}