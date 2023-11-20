#if defined __VOTES__
    #endinput
#endif
#define __VOTES__

#include <solaris/votes>
#include <l4d2_changelevel>

#define MAPRESTARTTIME 3.0

SolarisVote
    voteSettings;

void OnModuleStart_Vote() {
    voteSettings = (new SolarisVote()).RestrictToGamemodes(GM_VERSUS)
                                      .SetRequiredVotes(RV_MORETHANHALF)
                                      .RestrictToBeforeRoundStart()
                                      .RestrictToFirstHalf()
                                      .SetSuccessMessage("Applying custom settings...")
                                      .SetPrint("applying custom settings.")
                                      .SetTitle("Apply custom settings?")
                                      .OnSuccess(VoteCallback_ApplySettings);
}

void VoteCallback_ApplySettings() {
    if (SettingsToApply(false, ePunchRockBlock) != -1) {
        BlockPunchRock(true, view_as<bool>(SettingsToApply(false, ePunchRockBlock)));
    }

    if (SettingsToApply(false, eJumpRockBlock) != -1) {
        BlockJumpRock(true, view_as<bool>(SettingsToApply(false, eJumpRockBlock)));
    }

    if (SettingsToApply(false, eNoTankRush) != -1) {
        FreezePointsEnabled(true, view_as<bool>(SettingsToApply(false, eNoTankRush)));
    }

    if (SettingsToApply(false, eDeadstopsBlock) != -1) {
        DeadstopsBlocked(true, view_as<bool>(SettingsToApply(false, eDeadstopsBlock)));
    }

    if (SettingsToApply(false, eLaserSights) != -1) {
        UIM_SetItemLimit(MAP_LIMIT, LASERSIGHTS, SettingsToApply(false, eLaserSights));
    }

    if (SettingsToApply(false, ePills) != -1) {
        UIM_SetItemLimit(MAP_LIMIT, PILLS, SettingsToApply(false, ePills));
    }

    if (SettingsToApply(false, eAdrenaline) != -1) {
        UIM_SetItemLimit(MAP_LIMIT, ADRENALINE, SettingsToApply(false, eAdrenaline));
    }

    if (SettingsToApply(false, eVomitjar) != -1) {
        UIM_SetItemLimit(MAP_LIMIT, VOMITJAR, SettingsToApply(false, eVomitjar));
    }

    if (SettingsToApply(false, ePipeBomb) != -1) {
        UIM_SetItemLimit(MAP_LIMIT, PIPEBOMB, SettingsToApply(false, ePipeBomb));
    }

    CreateTimer(MAPRESTARTTIME, MapRestartTimer, _, TIMER_FLAG_NO_MAPCHANGE);
    CPrintToChatAll("{blue}[{default}Settings{blue}]{default} Applying custom settings...");
    CPrintToChatAll("{blue}[{default}Settings{blue}]{default} Restarting the map!");
}

Action MapRestartTimer(Handle hTimer) {
    static char szBuffer[64];
    GetCurrentMap(szBuffer, sizeof(szBuffer));
    L4D2_ChangeLevel(szBuffer, false); // We don't need to clear transition info! We save our scores
    return Plugin_Stop;
}

bool StartVote(int iClient) {
    return voteSettings.Start(iClient);
}