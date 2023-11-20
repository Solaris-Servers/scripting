#if defined _skill_detect_prints_included
    #endinput
#endif
#define _skill_detect_prints_included

#undef REQUIRE_PLUGIN
#include <l4d2_jockey_skeet>
#define REQUIRE_PLUGIN

public void HeadShotPrint(int iAttacker, int iVictim) {
    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim))
        return;

    int zClass = GetEntProp(iVictim, Prop_Send, "m_zombieClass");
    if (zClass >= L4D2Infected_Smoker && zClass <= L4D2Infected_Charger) {
        PrintCenterText(iAttacker, "HEADSHOT!");

        if (IsFakeClient(iVictim))
            return;

        PrintCenterText(iVictim, "HEADSHOTED!");
    }
}

public void PopPrint(int iAttacker, int iVictim, int iShover, int iShoveCount, float fTimeAlive) {
    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim))
        return

    if (fTimeAlive > 2.0)
        return;

    if (IsValidSurvivor(iShover)) {
        if (iAttacker == iShover) {
            if (fTimeAlive < 0.1) {
                if (!IsFakeClient(iVictim)) {
                    CPrintToChatAll("{green}★★★ {blue}%N{default} shoved and popped {green}%N{default}'s boomer {blue}in no time", iAttacker, iVictim);
                } else if (g_bIsPvE) {
                    CPrintToChatAll("{green}☆☆☆ {blue}%N{default} shoved and popped a boomer {blue}in no time", iAttacker);
                }
            } else {
                if (!IsFakeClient(iVictim)) {
                    CPrintToChatAll("{green}★ {blue}%N{default} shoved and popped {green}%N{default}'s boomer in {blue}%0.1fs", iAttacker, iVictim, fTimeAlive);
                } else if (g_bIsPvE) {
                    CPrintToChatAll("{green}☆ {blue}%N{default} shoved and popped a boomer in {blue}%0.1fs", iAttacker, fTimeAlive);
                }
            }
        } else {
            if (fTimeAlive < 0.1) {
                if (!IsFakeClient(iVictim)) {
                    CPrintToChatAll("{green}★★★ {blue}%N{default} shoved and {blue}%N{default} popped {green}%N{default}'s boomer {blue}in no time", iShover, iAttacker, iVictim);
                } else if (g_bIsPvE) {
                    CPrintToChatAll("{green}☆☆☆ {blue}%N{default} shoved and {blue}%N{default} popped a boomer {blue}in no time", iShover, iAttacker);
                }
            } else {
                if (!IsFakeClient(iVictim)) {
                    CPrintToChatAll("{green}★ {blue}%N{default} shoved and {blue}%N{default} popped {green}%N{default}'s boomer in {blue}%0.1fs", iShover, iAttacker, iVictim, fTimeAlive);
                } else if (g_bIsPvE) {
                    CPrintToChatAll("{green}☆ {blue}%N{default} shoved and {blue}%N{default} popped a boomer in {blue}%0.1fs", iShover, iAttacker, fTimeAlive);
                }
            }
        }
    } else {
        if (fTimeAlive < 0.1) {
            if (!IsFakeClient(iVictim)) {
                CPrintToChatAll("{green}★★★ {blue}%N{default} shut down {green}%N{default}'s boomer {blue}in no time", iAttacker, iVictim);
            } else if (g_bIsPvE) {
                CPrintToChatAll("{green}☆☆☆ {blue}%N{default} shut down a boomer {blue}in no time", iAttacker);
            }
        } else {
            if (!IsFakeClient(iVictim)) {
                CPrintToChatAll("{green}★ {blue}%N{default} shut down {green}%N{default}'s boomer in {blue}%0.1fs", iAttacker, iVictim, fTimeAlive);
            } else if (g_bIsPvE) {
                CPrintToChatAll("{green}☆ {blue}%N{default} shut down a boomer in {blue}%0.1fs", iAttacker, fTimeAlive);
            }
        }
    }
}

public void PopEarlyPrint(int iAttacker, int iVictim, int iShover) {
    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim) || !IsValidSurvivor(iShover))
        return

    if (iAttacker == iShover) {
        if (!IsFakeClient(iVictim)) {
            CPrintToChatAll("{green}☠ {blue}%N{default} shoved {green}%N{default}'s boomer but popped it too early", iAttacker, iVictim);
        } else if (g_bIsPvE) {
            CPrintToChatAll("{green}☠ {blue}%N{default} shoved a boomer but popped it too early", iAttacker);
        }
    } else {
        if (!IsFakeClient(iVictim)) {
            CPrintToChatAll("{green}☠ {blue}%N{default} shoved {green}%N{default}'s boomer but {blue}%N{default} popped it too early", iShover, iVictim, iAttacker);
        } else if (g_bIsPvE) {
            CPrintToChatAll("{green}☠ {blue}%N{default} shoved a boomer but {blue}%N{default} popped it too early", iShover, iVictim);
        }
    }
}

public void LevelPrint(iAttacker, iVictim) {
    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim))
        return;

    if (!IsFakeClient(iVictim)) {
        CPrintToChatAll("{green}★★★ {blue}%N{default} leveled {green}%N{default}'s charger", iAttacker, iVictim);
    } else if (g_bIsPvE) {
        CPrintToChatAll("{green}☆☆☆ {blue}%N{default} leveled a charger", iAttacker);
    }
}

public void LevelHurtPrint(iAttacker, iVictim, iDmg) {
    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim))
        return;

    if (!IsFakeClient(iVictim)) {
        CPrintToChatAll("{green}★ {blue}%N{default} leveled hurt {green}%N{default}'s charger for {blue}%d{default} damage", iAttacker, iVictim, iDmg);
    } else if (g_bIsPvE) {
        CPrintToChatAll("{green}☆ {blue}%N{default} leveled a hurt charger for {blue}%d{default} damage", iAttacker, iDmg);
    }
}

public void DeadstopPrint(int iAttacker, int iVictim) {
    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim))
        return;

    if (!IsFakeClient(iVictim)) {
        CPrintToChatAll("{green}★ {blue}%N{default} deadstopped {green}%N{default}'s hunter", iAttacker, iVictim);
    } else if (g_bIsPvE) {
        CPrintToChatAll("{green}☆ {blue}%N{default} deadstopped a hunter", iAttacker);
    }
}

public void SkeetSniperPrint(int iAttacker, int iVictim) {
    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim))
        return;

    if (!IsFakeClient(iVictim)) {
        CPrintToChatAll("{green}★★★{default} Sniper {blue}%N{default} headshot-skeeted {green}%N{default}'s hunter", iAttacker, iVictim);
    } else if (g_bIsPvE) {
        CPrintToChatAll("{green}☆☆☆{default} Sniper {blue}%N{default} headshot-skeeted a hunter", iAttacker);
    }
}

public void SkeetMeleePrint(int iAttacker, int iVictim) {
    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim))
        return;

    if (!IsFakeClient(iVictim)) {
        CPrintToChatAll("{green}★★★ {blue}%N{default} melee-skeeted {green}%N{default}'s hunter", iAttacker, iVictim);
    } else if (g_bIsPvE) {
        CPrintToChatAll("{green}☆☆☆ {blue}%N{default} melee-skeeted a hunter", iAttacker);
    }
}

public void SkeetHurtPrint(int iAttacker, int iVictim, int iDmg, int iShots) {
    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim))
        return;

    if (!IsFakeClient(iVictim)) {
        CPrintToChatAll("{green}★ {blue}%N{default} skeeted hurt {green}%N{default}'s hunter for {blue}%d{default} damage in {blue}%d{default} shot%s", iAttacker, iVictim, iDmg, iShots, iShots == 1 ? "" : "s");
    } else if (g_bIsPvE) {
        CPrintToChatAll("{green}☆ {blue}%N{default} skeeted a hurt hunter for {blue}%d{default} damage in {blue}%d{default} shot%s", iAttacker, iDmg, iShots, iShots == 1 ? "" : "s");
    }
}

public void SkeetPrint(int iAttacker, int iVictim, int iShots) {
    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim))
        return;

    if (!IsFakeClient(iVictim)) {
        if (iShots == 1) {
            CPrintToChatAll("{green}★★ {blue}%N{default} skeeted {green}%N{default}'s hunter in {blue}%d{default} shot", iAttacker, iVictim, iShots);
        } else {
            CPrintToChatAll("{green}★ {blue}%N{default} skeeted {green}%N{default}'s hunter in {blue}%d{default} shots", iAttacker, iVictim, iShots);
        }
    } else if (g_bIsPvE) {
        if (iShots == 1) {
            CPrintToChatAll("{green}☆☆ {blue}%N{default} skeeted a hunter in {blue}%d{default} shot", iAttacker, iShots);
        } else {
            CPrintToChatAll("{green}☆ {blue}%N{default} skeeted a hunter in {blue}%d{default} shots", iAttacker, iShots);
        }
    }
}

public void TongueCutPrint(int iAttacker, int iVictim) {
    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim))
        return;

    if (!IsFakeClient(iVictim)) {
        CPrintToChatAll("{green}★★ {blue}%N{default} cut {green}%N{default}'s smoker tongue", iAttacker, iVictim);
    } else if (g_bIsPvE) {
        CPrintToChatAll("{green}☆☆ {blue}%N{default} cut a smoker tongue", iAttacker);
    }
}

public void SmokerSelfClearPrint(int iAttacker, int iVictim, bool bWithShove) {
    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim))
        return;

    if (!IsFakeClient(iVictim)) {
        if (bWithShove) {
            CPrintToChatAll("{green}★★ {blue}%N{default} shoved {green}%N{default}'s smoker while being capped", iAttacker, iVictim);
        } else {
            CPrintToChatAll("{green}★★ {blue}%N{default} killed {green}%N{default}'s smoker while being capped", iAttacker, iVictim);
        }
    } else if (g_bIsPvE) {
        if (bWithShove) {
            CPrintToChatAll("{green}☆☆ {blue}%N{default} shoved a smoker while being capped", iAttacker);
        } else {
            CPrintToChatAll("{green}☆☆ {blue}%N{default} killed a smoker while being capped", iAttacker);
        }
    }
}

public void RockSkeetedPrint(int iAttacker, int iVictim) {
    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim))
        return;

    if (!IsFakeClient(iVictim)) {
        CPrintToChatAll("{green}★★ {blue}%N{default} skeeted {green}%N{default}'s tank rock", iAttacker, iVictim);
    } else if (g_bIsPvE) {
        CPrintToChatAll("{green}☆☆ {blue}%N{default} skeeted a tank rock", iAttacker);
    }
}

public void HunterPouncePrint(int iAttacker, int iVictim, int iActualDmg, float fCalculatedDmg, float fHeight, bool bPlayerIncapped) {
    if (!IsValidInfected(iAttacker) || IsFakeClient(iAttacker) || !IsValidSurvivor(iVictim))
        return;

    if (!IsFakeClient(iVictim)) {
        if (RoundToFloor(fCalculatedDmg) == 25) {
            CPrintToChatAll("{green}★★★ {red}%N{default} high-pounced {green}%N{default} (Damage: {red}%i{default})", iAttacker, iVictim, RoundToFloor(fCalculatedDmg));
        } else if (RoundToFloor(fCalculatedDmg) >= 20) {
            CPrintToChatAll("{green}★★ {red}%N{default} high-pounced {green}%N{default} (Damage: {red}%i{default})", iAttacker, iVictim, RoundToFloor(fCalculatedDmg));
        } else if (RoundToFloor(fCalculatedDmg) >= 15) {
            CPrintToChatAll("{green}★ {red}%N{default} high-pounced {green}%N{default} (Damage: {red}%i{default})", iAttacker, iVictim, RoundToFloor(fCalculatedDmg));
        }
    } else if (g_bIsPvE) {
        if (RoundToFloor(fCalculatedDmg) == 25) {
            CPrintToChatAll("{green}☆☆☆ {red}%N{default} high-pounced {green}%N{default} (Damage: {red}%i{default})", iAttacker, iVictim, RoundToFloor(fCalculatedDmg));
        } else if (RoundToFloor(fCalculatedDmg) >= 20) {
            CPrintToChatAll("{green}☆☆ {red}%N{default} high-pounced {green}%N{default} (Damage: {red}%i{default})", iAttacker, iVictim, RoundToFloor(fCalculatedDmg));
        } else if (RoundToFloor(fCalculatedDmg) >= 15) {
            CPrintToChatAll("{green}☆ {red}%N{default} high-pounced {green}%N{default} (Damage: {red}%i{default})", iAttacker, iVictim, RoundToFloor(fCalculatedDmg));
        }
    }
}

public void DeathChargePrint(int iAttacker, int iVictim, float fHeight, float fDistance, bool bCarried) {
    if (!IsValidInfected(iAttacker) || IsFakeClient(iAttacker) || !IsValidSurvivor(iVictim))
        return;

    if (!IsFakeClient(iVictim)) {
        CPrintToChatAll("{green}★★★ {red}%N{default} death-charged {green}%N{default}%s", iAttacker, iVictim, bCarried ? "" : " by bowling");
    } else if (g_bIsPvE) {
        CPrintToChatAll("{green}☆☆☆ {red}%N{default} death-charged {green}%N{default}%s", iAttacker, iVictim, bCarried ? "" : " by bowling");
    }
}

public void InstaClearPrint(int iAttacker, int iVictim, int iPinVictim, int zClass, float fClearTimeA, float fClearTimeB, bool bWithShove) {
    static const char szInfCls[][] = {
        "none",
        "smoker",
        "boomer",
        "hunter",
        "spitter",
        "jockey",
        "charger",
        "witch",
        "tank"
    }

    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim) || !IsValidSurvivor(iPinVictim))
        return;

    // sanity check:
    if (fClearTimeA < 0 && fClearTimeA != -1.0)
        fClearTimeA = 0.0;

    if (fClearTimeB < 0 && fClearTimeB != -1.0)
        fClearTimeB = 0.0;

    if (iAttacker == iPinVictim)
        return;

    float fClearTime = fClearTimeA;

    if (zClass == L4D2Infected_Smoker || zClass == L4D2Infected_Charger)
        fClearTime = fClearTimeB;

    if (fClearTime == -1.0)
        return;

    if (fClearTime <= 0.01) {
        if (!IsFakeClient(iVictim)) {
            CPrintToChatAll("{green}★★★ {blue}%N{default} saved {blue}%N{default} from {green}%N{default}'s %s {blue}in no time", iAttacker, iPinVictim, iVictim, szInfCls[zClass]);
        } else {
            CPrintToChatAll("{green}☆☆☆ {blue}%N{default} saved {blue}%N{default} from a %s {blue}in no time", iAttacker, iPinVictim, szInfCls[zClass]);
        }
    } else if (fClearTime <= 0.40) {
        if (!IsFakeClient(iVictim)) {
            CPrintToChatAll("{green}★★ {blue}%N{default} insta-cleared {blue}%N{default} from {green}%N{default}'s %s in {blue}%.2fs", iAttacker, iPinVictim, iVictim, szInfCls[zClass], fClearTime);
        } else {
            CPrintToChatAll("{green}☆☆ {blue}%N{default} insta-cleared {blue}%N{default} from a %s in {blue}%.2fs", iAttacker, iPinVictim, szInfCls[zClass], fClearTime);
        }
    } else if (fClearTime <= 0.75) {
        if (!IsFakeClient(iVictim)) {
            CPrintToChatAll("{green}★ {blue}%N{default} insta-cleared {blue}%N{default} from {green}%N{default}'s %s in {blue}%.2fs", iAttacker, iPinVictim, iVictim, szInfCls[zClass], fClearTime);
        } else {
            CPrintToChatAll("{green}☆ {blue}%N{default} insta-cleared {blue}%N{default} from a %s in {blue}%.2fs", iAttacker, iPinVictim, szInfCls[zClass], fClearTime);
        }
    }
}

public void VomitLandedPrint(int iAttacker, int iBoomCount) {
    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker))
        return;

    if (iBoomCount == 4)
        CPrintToChatAll("{green}★★★ {red}%N{default} vomited all {olive}4{default} survivors", iAttacker);
}

public void BHopStreakPrint(int iSurvivor, int iStreak, float fMaxVelocity) {
    if (!IsValidSurvivor(iSurvivor) || IsFakeClient(iSurvivor))
        return;

    if (fMaxVelocity < 250.0)
        return;

    if (iStreak > 8) {
        CPrintToChatAll("{green}★★★ {blue}%N{default} got {blue}%d{default} bunnyhops in a row. Top speed: {blue}%.01f", iSurvivor, iStreak, fMaxVelocity);
    } else if (iStreak > 5) {
        CPrintToChatAll("{green}★★ {blue}%N{default} got {blue}%d{default} bunnyhops in a row. Top speed: {blue}%.01f", iSurvivor, iStreak, fMaxVelocity);
    } else if (iStreak > 2) {
        CPrintToChatAll("{green}★ {blue}%N{default} got {blue}%d{default} bunnyhops in a row. Top speed: {blue}%.01f", iSurvivor, iStreak, fMaxVelocity);
    }
}

public void CarAlarmTriggerPrint(int iSurvivor) {
    if (!IsValidSurvivor(iSurvivor) || IsFakeClient(iSurvivor))
        return;

    CPrintToChatAll("{green}☠ {blue}%N{default} triggered an alarm", iSurvivor);
}

public void OnJockeySkeet(int iAttacker, int iVictim) {
    if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker) || !IsValidInfected(iVictim))
        return;

    if (!IsFakeClient(iVictim)) {
        CPrintToChatAll("{green}★★ {blue}%N{default} skeeted {green}%N{default}'s jockey", iAttacker, iVictim);
    } else if (g_bIsPvE) {
        CPrintToChatAll("{green}☆☆ {blue}%N{default} skeeted a jockey", iAttacker);
    }
}