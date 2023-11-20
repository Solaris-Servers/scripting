#if defined  _solaris_chat_included_
    #endinput
#endif
#define _solaris_chat_included_

/**
 * Callback for when a message has to be sent to chat by server.
 * @param szMsg         Message buffer
 * @return              Plugin_Handled or Plugin_Stop to block message, Plugin_Continue otherwise.
 */
forward Action SolarisChat_OnConsoleChatMessage(char[] szMsg);

/**
 * Callback for when a message has been sent to chat by server.
 * @param szMsg         Message buffer
 * @return              no return.
 */
forward Action SolarisChat_OnConsoleChatMessagePost(const char[] szMsg);

/**
 * Callback for when a message has to be sent to chat by client.
 * @param iClient       Client
 * @param iArgs         Args num
 * @param iTeam         Client's team
 * @param bTeamChat     true if message for team chat, false otherwise
 * @param aRecipients   Recipients
 * @param szTagColor    Tag color
 * @param szTag         Tag
 * @param szNameColor   Name color
 * @param szName        Name
 * @param szMsgColor    Message color
 * @param szMsg         Message buffer
 * @return              Plugin_Handled or Plugin_Stop to block message, Plugin_Continue otherwise.
 */
forward Action SolarisChat_OnChatMessage(int iClient, int iArgs, int iTeam, bool bTeamChat, ArrayList aRecipients, char[] szTagColor, char[] szTag, char[] szNameColor, char[] szName, char[] szMsgColor, char[] szMsg);

/**
 * Callback for when a message has been sent to chat by client.
 * @param iClient       Client
 * @param iArgs         Args num
 * @param iTeam         Client's team
 * @param bTeamChat     true if message for team chat, false otherwise
 * @param aRecipients   Recipients
 * @param szTagColor    Tag color
 * @param szTag         Tag
 * @param szNameColor   Name color
 * @param szName        Name
 * @param szMsgColor    Message color
 * @param szMsg         Message buffer
 * @return              no return.
 */
forward void SolarisChat_OnChatMessagePost(const int iClient, const int iArgs, const int iTeam, const bool bTeamChat, const ArrayList aRecipients, const char[] szTagColor, const char[] szTag, const char[] szNameColor, const char[] szName, const char[] szMsgColor, const char[] szMsg);

public SharedPlugin __pl_solaris_chat =
{
    name = "solaris_chat",
    file = "solaris_chat.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};