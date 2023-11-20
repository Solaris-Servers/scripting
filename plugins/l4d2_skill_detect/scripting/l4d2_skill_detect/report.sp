#if defined _skill_detect_report_included
    #endinput
#endif
#define _skill_detect_report_included

// headshot
void HandleHeadShot(int iAttacker, int iVictim) {
    HeadShotPrint(iAttacker, iVictim);

    Call_StartForward(g_fwdHeadShot);
    Call_PushCell(iAttacker);
    Call_PushCell(iVictim);
    Call_Finish();
}

// boomer pop
void HandlePop(int iAttacker, int iVictim, int iShover, int iShoveCount, float fTimeAlive) {
    PopPrint(iAttacker, iVictim, iShover, iShoveCount, fTimeAlive);

    Call_StartForward(g_fwdBoomerPop);
    Call_PushCell(iAttacker);
    Call_PushCell(iVictim);
    Call_PushCell(iShover);
    Call_PushCell(iShoveCount);
    Call_PushFloat(fTimeAlive);
    Call_Finish();
}

void HandlePopEarly(int iAttacker, int iVictim, int iShover) {
    PopEarlyPrint(iAttacker, iVictim, iShover);

    Call_StartForward(g_fwdBoomerPopEarly);
    Call_PushCell(iAttacker);
    Call_PushCell(iVictim);
    Call_PushCell(iShover);
    Call_Finish();
}

// charger level
void HandleLevel(int iAttacker, int iVictim) {
    LevelPrint(iAttacker, iVictim);

    Call_StartForward(g_fwdLevel);
    Call_PushCell(iAttacker);
    Call_PushCell(iVictim);
    Call_Finish();
}

// charger level hurt
void HandleLevelHurt(int iAttacker, int iVictim, int iDmg) {
    LevelHurtPrint(iAttacker, iVictim, iDmg);

    Call_StartForward(g_fwdLevelHurt);
    Call_PushCell(iAttacker);
    Call_PushCell(iVictim);
    Call_PushCell(iDmg);
    Call_Finish();
}

// deadstops
void HandleDeadstop(int iAttacker, int iVictim) {
    DeadstopPrint(iAttacker, iVictim);

    Call_StartForward(g_fwdHunterDeadstop);
    Call_PushCell(iAttacker);
    Call_PushCell(iVictim);
    Call_Finish();
}

// real skeet
void HandleSkeet(int iAttacker, int iVictim, int iDmg = 0, int iShots = 0, bool bHurt = false, bool bMelee = false, bool bSniper = false) {
    if (bSniper) {
        SkeetSniperPrint(iAttacker, iVictim);

        Call_StartForward(g_fwdSkeetSniper);
        Call_PushCell(iAttacker);
        Call_PushCell(iVictim);
        Call_Finish();
    } else if (bMelee) {
        SkeetMeleePrint(iAttacker, iVictim);

        Call_StartForward(g_fwdSkeetMelee);
        Call_PushCell(iAttacker);
        Call_PushCell(iVictim);
        Call_Finish();
    } else if (bHurt) {
        SkeetHurtPrint(iAttacker, iVictim, iDmg, iShots);

        Call_StartForward(g_fwdSkeetHurt);
        Call_PushCell(iAttacker);
        Call_PushCell(iVictim);
        Call_PushCell(iDmg);
        Call_PushCell(iShots);
        Call_Finish();
    } else {
        SkeetPrint(iAttacker, iVictim, iShots);

        Call_StartForward(g_fwdSkeet);
        Call_PushCell(iAttacker);
        Call_PushCell(iVictim);
        Call_PushCell(iShots);
        Call_Finish();
    }
}

// smoker clears
void HandleTongueCut(int iAttacker, int iVictim) {
    TongueCutPrint(iAttacker, iVictim);

    Call_StartForward(g_fwdTongueCut);
    Call_PushCell(iAttacker);
    Call_PushCell(iVictim);
    Call_Finish();
}

void HandleSmokerSelfClear(int iAttacker, int iVictim, bool bWithShove = false) {
    SmokerSelfClearPrint(iAttacker, iVictim, bWithShove);

    Call_StartForward(g_fwdSmokerSelfClear);
    Call_PushCell(iAttacker);
    Call_PushCell(iVictim);
    Call_PushCell(bWithShove);
    Call_Finish();
}

void HandleRockSkeeted(int iAttacker, int iVictim) {
    RockSkeetedPrint(iAttacker, iVictim);

    Call_StartForward(g_fwdRockSkeeted);
    Call_PushCell(iAttacker);
    Call_PushCell(iVictim);
    Call_Finish();
}

// highpounces
void HandleHunterDP(int iAttacker, int iVictim, int iActualDmg, float fCalculatedDmg, float fHeight, bool bPlayerIncapped = false) {
    HunterPouncePrint(iAttacker, iVictim, iActualDmg, fCalculatedDmg, fHeight, bPlayerIncapped);

    Call_StartForward(g_fwdHunterDP);
    Call_PushCell(iAttacker);
    Call_PushCell(iVictim);
    Call_PushCell(iActualDmg);
    Call_PushFloat(fCalculatedDmg);
    Call_PushFloat(fHeight);
    Call_PushCell((fHeight >= g_cvHunterDPThresh.FloatValue) ? 1 : 0);
    Call_PushCell((bPlayerIncapped) ? 1 : 0);
    Call_Finish();
}

// deathcharges
void HandleDeathCharge(int iAttacker, int iVictim, float fHeight, float fDistance, bool bCarried = true) {
    DeathChargePrint(iAttacker, iVictim, fHeight, fDistance, bCarried);

    Call_StartForward(g_fwdDeathCharge);
    Call_PushCell(iAttacker);
    Call_PushCell(iVictim);
    Call_PushFloat(fHeight);
    Call_PushFloat(fDistance);
    Call_PushCell((bCarried) ? 1 : 0);
    Call_Finish();
}

// SI clears (cleartimeA = pummel/pounce/ride/choke, cleartimeB = tongue drag, charger carry)
void HandleClear(int iAttacker, int iVictim, int iPinVictim, int zClass, float fClearTimeA, float fClearTimeB, bool bWithShove = false) {
    InstaClearPrint(iAttacker, iVictim, iPinVictim, zClass, fClearTimeA, fClearTimeB, bWithShove);

    Call_StartForward(g_fwdClear);
    Call_PushCell(iAttacker);
    Call_PushCell(iVictim);
    Call_PushCell(iPinVictim);
    Call_PushCell(zClass);
    Call_PushFloat(fClearTimeA);
    Call_PushFloat(fClearTimeB);
    Call_PushCell((bWithShove) ? 1 : 0);
    Call_Finish();
}

// booms
void HandleVomitLanded(int iAttacker, int iBoomCount) {
    VomitLandedPrint(iAttacker, iBoomCount);

    Call_StartForward(g_fwdVomitLanded);
    Call_PushCell(iAttacker);
    Call_PushCell(iBoomCount);
    Call_Finish();
}

// bhaps
void HandleBHopStreak(int iSurvivor, int iStreak, float fMaxVelocity) {
    BHopStreakPrint(iSurvivor, iStreak, fMaxVelocity);

    Call_StartForward(g_fwdBHopStreak);
    Call_PushCell(iSurvivor);
    Call_PushCell(iStreak);
    Call_PushFloat(fMaxVelocity);
    Call_Finish();
}

// car alarms
void HandleCarAlarmTriggered(int iSurvivor) {
    CarAlarmTriggerPrint(iSurvivor);

    Call_StartForward(g_fwdAlarmTriggered);
    Call_PushCell(iSurvivor);
    Call_Finish();
}