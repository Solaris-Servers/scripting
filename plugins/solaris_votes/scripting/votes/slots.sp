#if defined __solaris_votes_slots_included
    #endinput
#endif
#define __solaris_votes_slots_included

#define MAXSLOTS 30

ConVar cvMaxPlayers;
ConVar cvVisibleMaxPlayers;

ConVar cvCurrentMaxSlots;
int    iCurrentMaxSlots;

ConVar cvDefaultMaxSlots;
int    iDefaultMaxSlots;

int iDesiredSlots;

SolarisVote voteSlots;
SolarisVote voteKickSpec;
SolarisVote voteNoSpec;

void Slots_OnPluginStart() {
    voteSlots    = (new SolarisVote()).OnSuccess(VoteCallback_Slots_Set);

    voteKickSpec = (new SolarisVote()).OnSuccess(VoteCallback_Slots_KickSpec);

    voteNoSpec   = (new SolarisVote()).SetPrint("kicking spectators.")
                                      .SetTitle("Kick spectators?")
                                      .SetSuccessMessage("All spectators were kicked")
                                      .OnSuccess(VoteCallback_NoSpec);

    cvMaxPlayers        = FindConVar("sv_maxplayers");
    cvVisibleMaxPlayers = FindConVar("sv_visiblemaxplayers");

    cvCurrentMaxSlots = CreateConVar("sv_maxslots", "18", "Maximum server slots.");
    cvDefaultMaxSlots = CreateConVar("sv_defslots", "18", "Maximum server slots.");

    cvMaxPlayers.SetInt(cvDefaultMaxSlots.IntValue);
    cvVisibleMaxPlayers.SetInt(cvDefaultMaxSlots.IntValue);
    cvCurrentMaxSlots.SetInt(cvDefaultMaxSlots.IntValue);

    iCurrentMaxSlots = cvCurrentMaxSlots.IntValue;
    iDefaultMaxSlots = cvDefaultMaxSlots.IntValue;

    cvMaxPlayers.AddChangeHook(SlotSettings_Changed);
    cvVisibleMaxPlayers.AddChangeHook(SlotSettings_Changed);
    cvCurrentMaxSlots.AddChangeHook(SlotSettings_Changed);
    cvDefaultMaxSlots.AddChangeHook(SlotSettings_Changed);

    RegConsoleCmd("sm_slots",     Cmd_SlotVote);
    RegConsoleCmd("sm_kickspecs", Cmd_KickSpecs);
    RegConsoleCmd("sm_kickspec",  Cmd_KickSpec);
    RegConsoleCmd("sm_nospec",    Cmd_NoSpec);
}

void SlotSettings_Changed(ConVar szCvar, const char[] szOldVal, const char[] szNewVal) {
    iCurrentMaxSlots = cvCurrentMaxSlots.IntValue;
    iDefaultMaxSlots = cvDefaultMaxSlots.IntValue;

    if (iCurrentMaxSlots < GetSlotVoteMin()) {
        cvCurrentMaxSlots.SetInt(GetSlotVoteMin());
        iCurrentMaxSlots = GetSlotVoteMin();
    }

    cvMaxPlayers.SetInt(iCurrentMaxSlots);
    cvVisibleMaxPlayers.SetInt(iCurrentMaxSlots);
}

Action Cmd_SlotVote(int iClient, int iArgs) {
    if (iClient <= 0)
        return Plugin_Handled;

    if (!IsClientInGame(iClient))
        return Plugin_Handled;

    if (iArgs == 0) {
        CreateSlotMenu(iClient);
        return Plugin_Handled;
    }

    char szArg[4];
    GetCmdArg(1, szArg, sizeof(szArg));

    int iSlots = StringToInt(szArg);

    if (iSlots == iCurrentMaxSlots) {
        CPrintToChat(iClient, "{blue}[{default}Vote{blue}]{default} Server already has %i slot%s set!", iSlots, iSlots > 1 ? "s" : "");
        return Plugin_Handled;
    }

    if (iSlots >= GetSlotVoteMin() && iSlots <= MAXSLOTS) {
        // prepare vote title
        char szVotePrint[64];
        FormatEx(szVotePrint, sizeof(szVotePrint), "setting slots to {olive}%d{default}.", iSlots);

        char szVoteTitle[64];
        FormatEx(szVoteTitle, sizeof(szVoteTitle), "Set slots to %d?", iSlots);

        char szVotePassed[64];
        FormatEx(szVotePassed, sizeof(szVotePassed), "Slots were limited to %d", iSlots);

        // start vote
        bool bVoteStarted = voteSlots.SetPrint(szVotePrint)
                                     .SetTitle(szVoteTitle)
                                     .SetSuccessMessage(szVotePassed)
                                     .Start(iClient);

        if (bVoteStarted)
            iDesiredSlots = iSlots;

        return Plugin_Handled;
    }

    CPrintToChat(iClient, "{blue}[{default}Vote{blue}]{default} Usage: {olive}!slots{default} {green}<{default}Number of slots between {olive}%i{default} and {olive}%i{green}>.", GetSlotVoteMin(), MAXSLOTS);
    return Plugin_Handled;
}

Action Cmd_NoSpec(int iClient, int iArgs) {
    if (iClient <= 0)
        return Plugin_Handled;

    if (!IsClientInGame(iClient))
        return Plugin_Handled;

    // prepare vote title
    char szVotePrint[64];
    FormatEx(szVotePrint, sizeof(szVotePrint), "%s", iCurrentMaxSlots > GetSlotVoteMin() ? "kicking spectators and limiting slots." : "allowing spectators.");

    char szVoteTitle[64];
    FormatEx(szVoteTitle,  sizeof(szVoteTitle), "%s", iCurrentMaxSlots > GetSlotVoteMin() ? "Kick spectators and limit slots?" : "Allow spectators?");

    char szVotePassed[64];
    FormatEx(szVotePassed, sizeof(szVotePassed), "%s", iCurrentMaxSlots > GetSlotVoteMin() ? "Kicked spectators and limited slots" : "Spectators are allowed");

    // start vote
    voteNoSpec.SetPrint(szVotePrint)
              .SetTitle(szVoteTitle)
              .SetSuccessMessage(szVotePassed)
              .Start(iClient);

    return Plugin_Handled;
}

Action Cmd_KickSpecs(int iClient, int iArgs) {
    if (iClient <= 0)
        return Plugin_Handled;

    if (!IsClientInGame(iClient))
        return Plugin_Handled;

    bool bFound = false;
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        if (GetClientTeam(i) == TEAM_SPECTATE || TM_IsPlayerRespectating(i)) {
            bFound = true;
            break;
        }
    }

    if (bFound) {
        // start vote
        voteKickSpec.Start(iClient);
        return Plugin_Handled;
    }

    CPrintToChat(iClient, "{blue}[{default}Vote{blue}]{default} There are no spectators!");
    return Plugin_Handled;
}

void CreateSlotMenu(int iClient) {
    Menu mSlotMenu = new Menu(MenuHandler_SlotMenu);

    char szBuffer[256];
    FormatEx(szBuffer, sizeof(szBuffer), "Current slots: %i\n‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒‒\nChoose new value:", iCurrentMaxSlots);

    mSlotMenu.SetTitle(szBuffer);

    char szCycle[4];
    for (int i = GetSlotVoteMin(); i <= MAXSLOTS; i++) {
        FormatEx(szCycle,  sizeof(szCycle),  "%i", i);
        FormatEx(szBuffer, sizeof(szBuffer), "%i slot%s%s", i, i > 1 ? "s" : "", i != iCurrentMaxSlots ? "" : " [Current]");
        mSlotMenu.AddItem(szCycle, szBuffer, i != iCurrentMaxSlots ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    }

    mSlotMenu.Display(iClient, MENU_TIME_FOREVER);
}

int MenuHandler_SlotMenu(Menu mSlotMenu, MenuAction maAction, int iClient, int iParam2) {
    if (maAction == MenuAction_Select) {
        char szInfo[4];
        mSlotMenu.GetItem(iParam2, szInfo, sizeof(szInfo));

        int iSlots = StringToInt(szInfo);
        if (iSlots == iCurrentMaxSlots) {
            CPrintToChat(iClient, "{blue}[{default}Vote{blue}]{default} Server already has {olive}%i{default} slot%s set!", iSlots, iSlots > 1 ? "s" : "");
            return 0;
        }

        // prepare vote title
        char szVotePrint[64];
        FormatEx(szVotePrint, sizeof(szVotePrint), "setting slots to {olive}%d{default}.", iSlots);

        char szVoteTitle[64];
        FormatEx(szVoteTitle, sizeof(szVoteTitle), "Set slots to %d?", iSlots);

        char szVotePassed[64];
        FormatEx(szVotePassed, sizeof(szVotePassed), "Slots were limited to %d", iSlots);

        // start vote
        bool bVoteStarted = voteSlots.SetPrint(szVotePrint)
                                     .SetTitle(szVoteTitle)
                                     .SetSuccessMessage(szVotePassed)
                                     .Start(iClient);

        if (bVoteStarted)
            iDesiredSlots = iSlots;
    }

    if (maAction == MenuAction_End)
        delete mSlotMenu;

    return 0;
}

void VoteCallback_Slots_Set() {
    cvCurrentMaxSlots.SetInt(iDesiredSlots);
}

void VoteCallback_NoSpec() {
    if (iCurrentMaxSlots > GetSlotVoteMin()) {
        KickAllSpectators();
        cvCurrentMaxSlots.SetInt(GetSlotVoteMin());
        return;
    }

    cvCurrentMaxSlots.SetInt(iDefaultMaxSlots);
}

void VoteCallback_Slots_KickSpec() {
    KickAllSpectators();
}

void KickAllSpectators() {
    char szAuthId[128];

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        if (ST_IsAntiKickClient(i))
            continue;

        if (GetClientTeam(i) == TEAM_SPECTATE || TM_IsPlayerRespectating(i)) {
            GetClientAuthId(i, AuthId_Steam2, szAuthId, sizeof(szAuthId), false);
            ST_KickClient(i, "You have been voted off.");
            BanIdentity(szAuthId, 1, BANFLAG_AUTHID, "You have been voted off.");
            g_smPlayersTemporarilyBanned.SetValue(szAuthId, GetTime() + 300, true);
        }
    }
}

Action Cmd_KickSpec(int iClient, int iArgs) {
    if (iClient <= 0)
        return Plugin_Handled;

    if (!IsClientInGame(iClient))
        return Plugin_Handled;

    if (GetClientTeam(iClient) == 1)
        return Plugin_Handled;

    if (TM_IsPlayerRespectating(iClient))
        return Plugin_Handled;

    CreateKickSpecVoteMenu(iClient);
    return Plugin_Handled;
}

void CreateKickSpecVoteMenu(int iClient) {
    Menu mMenu = new Menu(Menu_KickSpec);
    char szName[MAX_NAME_LENGTH];
    char szUID[32];

    mMenu.SetTitle("Select spectator to kick:");

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        if (i == iClient)
            continue;

        if (GetClientTeam(i) == TEAM_SPECTATE || TM_IsPlayerRespectating(iClient)) {
            FormatEx(szUID, sizeof(szUID), "%i", GetClientUserId(i));
            GetClientName(i, szName, sizeof(szName));
            mMenu.AddItem(szUID, szName);
        }
    }

    char szNospec[64];
    FormatEx(szNospec, sizeof(szNospec), "%s", iCurrentMaxSlots > GetSlotVoteMin() ? "Kick all spectators and limit slots (!nospec)" : "Allow spectators (!nospec)");
    mMenu.AddItem("sm_kickspecs", "Kick all spectators (!kickspecs)");
    mMenu.AddItem("sm_nospec", szNospec);
    mMenu.Display(iClient, MENU_TIME_FOREVER);
}

int Menu_KickSpec(Menu mMenu, MenuAction maAction, int iClient, int iItem) {
    if (maAction == MenuAction_Select) {
        char szInfo[64];
        mMenu.GetItem(iItem, szInfo, sizeof(szInfo));
        if (strcmp(szInfo, "sm_kickspecs") == 0 || strcmp(szInfo, "sm_nospec") == 0) {
            FakeClientCommand(iClient, szInfo);
        } else {
            FakeClientCommand(iClient, "callvote Kick %s", szInfo);
        }
    } else if (maAction == MenuAction_End)
        delete mMenu;
    return 0;
}

stock int GetSlotVoteMin() {
    if (SDK_HasPlayerInfected())
        return g_cvSurvivorLimit.IntValue + g_cvInfectedLimit.IntValue;
    return g_cvSurvivorLimit.IntValue;
}