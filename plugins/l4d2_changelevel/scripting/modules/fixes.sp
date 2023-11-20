#if defined __FIXES__
    #endinput
#endif
#define __FIXES__

void Fixes_OnMapStart() {
    RequestFrame(OnNextFrame);
}

void Fixes_OnMapEnd() {
    if (Clear())
        SDK_ClearTransitionInfo();
    Clear(true, false);
}

void OnNextFrame() {
    if (!SDK_HasPlayerInfected())
        return;

    bool bTeamsFlipped = SDK_AreTeamsFlipped();
    if (SDK_IsVersus()) {
        if (L4D2Direct_GetVSCampaignScore(1) > L4D2Direct_GetVSCampaignScore(0)) {
            if (!bTeamsFlipped)
                SDK_SwapTeams();
        } else {
            if (bTeamsFlipped)
                SDK_SwapTeams();
        }

        return;
    }

    if (bTeamsFlipped)
        SDK_SwapTeams();
}