#if defined __SPIT_FIX__
    #endinput
#endif
#define __SPIT_FIX__

void OnModuleStart_SpitFix() {
    HookEvent("player_hurt", Event_PlayerHurt);
}

void Event_PlayerHurt(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iEnt = eEvent.GetInt("attackerentid", 0);

    static char szClsName[14];
    GetEntityClassname(iEnt, szClsName, sizeof(szClsName));
    if (szClsName[0] != 'i' || strcmp(szClsName, "insect_swarm", false) != 0)
        return;

    int iClient = GetClientOfUserId(eEvent.GetInt("userid", 0));
    if (!IsValidClient(iClient))
        return;
    
    int iTeam = GetClientTeam(iClient);
    if (iTeam != 2 && iTeam != 4)
        return;

    static char szSliceSnd[34];
    Format(szSliceSnd, sizeof(szSliceSnd), "player/PZ/hit/zombie_slice_%i.wav", GetRandomInt(1, 6));
    EmitSoundToAll(szSliceSnd, iClient, SNDCHAN_AUTO, 85, SND_NOFLAGS, 0.7, GetRandomInt(95, 105));

    int iDuration = 360;
    int iHoldTime = 0;
    int iFlags    = 1;
    int iColor[4] = { 255, 0, 0, 32 };

    int iClients[2];
    iClients[0] = iClient;

    static UserMsg g_FadeUserMsgId = INVALID_MESSAGE_ID;
    if (g_FadeUserMsgId == INVALID_MESSAGE_ID)
        g_FadeUserMsgId = GetUserMessageId("Fade");

    Handle hMsg = StartMessageEx(g_FadeUserMsgId, iClients, 1);
    if (GetUserMessageType() == UM_Protobuf) {
        Protobuf pb = UserMessageToProtobuf(hMsg);
        pb.SetInt("duration",  iDuration);
        pb.SetInt("hold_time", iHoldTime);
        pb.SetInt("flags",     iFlags);
        pb.SetColor("clr",     iColor);
    } else {
        BfWriteShort(hMsg, iDuration);
        BfWriteShort(hMsg, iHoldTime);
        BfWriteShort(hMsg, iFlags);
        BfWriteByte(hMsg, iColor[0]);
        BfWriteByte(hMsg, iColor[1]);
        BfWriteByte(hMsg, iColor[2]);
        BfWriteByte(hMsg, iColor[3]);
    }

    EndMessage();
}