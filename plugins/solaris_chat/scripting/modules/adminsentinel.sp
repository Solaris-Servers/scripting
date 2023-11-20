#if defined __AdminSentinel__
    #endinput
#endif
#define __AdminSentinel__

#define SPEAK_NORMAL        0   /**< Allow the client to listen and speak normally. */
#define SPEAK_MUTED         1   /**< Mutes the client from speaking to everyone. */
#define SPEAK_ALL           2   /**< Allow the client to speak to everyone. */
#define SPEAK_LISTENALL     4   /**< Allow the client to listen to everyone. */
#define SPEAK_TALKLISTENALL 6
#define SPEAK_TEAM          8   /**< Allow the client to always speak to team, even when dead. */
#define SPEAK_LISTENTEAM    16  /**< Allow the client to always hear teammates, including dead ones. */

bool bEnemyVoice[MAXPLAYERS + 1];
bool bEnemyChat [MAXPLAYERS + 1];

ConVar cvAllTalk;

void AdminSentinel_OnModuleStart() {
    RegAdminCmd("sm_enemyvoice", Cmd_EnemyVoice, ADMFLAG_ROOT, "sm_enemyvoice - toggles on/off enemy voice comm per admin");
    RegAdminCmd("sm_enemychat",  Cmd_EnemyChat,  ADMFLAG_ROOT, "sm_enemychat - toggles on/off enemy chat per admin");

    cvAllTalk = FindConVar("sv_alltalk");
    cvAllTalk.AddChangeHook(AlltalkChanged);
}

void AdminSentinel_OnClientPutInServer(int iClient) {
    SetClientListeningFlags(iClient, SPEAK_NORMAL);
    bEnemyVoice[iClient] = false;
    bEnemyChat [iClient] = false;
}

void AdminSentinel_OnClientDisconnect(int iClient) {
    bEnemyVoice[iClient] = false;
    bEnemyChat [iClient] = false;
}

Action Cmd_EnemyVoice(int iClient, int iArgs) {
    if (iClient <= 0)
        return Plugin_Handled;

    if (!IsClientInGame(iClient))
        return Plugin_Handled;

    bEnemyVoice[iClient] = !bEnemyVoice[iClient];
    SetClientListeningFlags(iClient, bEnemyVoice[iClient] ? SPEAK_LISTENALL : SPEAK_NORMAL);
    CPrintToChat(iClient,"{green}[{default}Admin Sentinel{green}]{default} Listening to enemy voice %s!", bEnemyVoice[iClient] ? "{blue}enabled{default}" : "{red}disabled{default}");
    return Plugin_Handled;
}

Action Cmd_EnemyChat(int iClient, int iArgs) {
    if (iClient <= 0)
        return Plugin_Handled;

    if (!IsClientInGame(iClient))
        return Plugin_Handled;

    bEnemyChat[iClient] = !bEnemyChat[iClient];
    CPrintToChat(iClient,"{green}[{default}Admin Sentinel{green}]{default} Listening to enemy chat %s!", bEnemyChat[iClient] ? "{blue}enabled{default}" : "{red}disabled{default}");
    return Plugin_Handled;
}

void AlltalkChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    if (cv.BoolValue)
        return;

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        if (!bEnemyVoice[i])
            continue;

        SetClientListeningFlags(i, SPEAK_LISTENALL);
        CPrintToChat(i,"{green}[{default}AdminSentinel{green}]{default} Listening to enemy voice {blue}re-enabled{default}!");
    }
}

void AdminSentinel_OnChatMessage(ArrayList aRecipients) {
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        if (bEnemyChat[i] && aRecipients.FindValue(GetClientUserId(i)) == -1) {
            aRecipients.Push(GetClientUserId(i));
        }
    }
}