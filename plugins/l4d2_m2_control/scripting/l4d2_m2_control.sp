#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <l4d2util>
#include <left4dhooks>
#include <solaris/stocks>

ConVar g_cvPenaltyIncreaseHunter;
int    g_iPenaltyIncreaseHunter;
ConVar g_cvPenaltyIncreaseJockey;
int    g_iPenaltyIncreaseJockey;
ConVar g_cvPenaltyIncreaseSmoker;
int    g_iPenaltyIncreaseSmoker;

ConVar g_cvMinShovePenaltyPvE;
int    g_iMinShovePenaltyPvE;
ConVar g_cvMaxShovePenaltyPvE;
int    g_iMaxShovePenaltyPvE;
ConVar g_cvMinShovePenaltyPvP;
int    g_iMinShovePenaltyPvP;
ConVar g_cvMaxShovePenaltyPvP;
int    g_iMaxShovePenaltyPvP;

ConVar g_cvShoveInterval;
float  g_fShoveInterval;
ConVar g_cvShovePenaltyAmt;
float  g_fShovePenaltyAmt;
ConVar g_cvPounceCrouchDelay;
float  g_fPounceCrouchDelay;
ConVar g_cvLeapInterval;
float  g_fLeapInterval;

ConVar g_cvGameMode;
bool   g_bIsPvP;

public Plugin myinfo = {
    name        = "L4D2 M2 Control",
    author      = "Jahze, Visor, A1m`, Forgetest",
    version     = "1.16",
    description = "Blocks instant repounces and gives m2 penalty after a shove/deadstop",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
}

public void OnPluginStart() {
    g_cvPenaltyIncreaseHunter = CreateConVar(
    "l4d2_m2_hunter_penalty", "0",
    "How much penalty gets added when you shove a Hunter",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_iPenaltyIncreaseHunter = g_cvPenaltyIncreaseHunter.IntValue;
    g_cvPenaltyIncreaseHunter.AddChangeHook(CvChg_PenaltyIncrease);

    g_cvPenaltyIncreaseJockey = CreateConVar(
    "l4d2_m2_jockey_penalty", "0",
    "How much penalty gets added when you shove a Jockey",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_iPenaltyIncreaseJockey = g_cvPenaltyIncreaseJockey.IntValue;
    g_cvPenaltyIncreaseJockey.AddChangeHook(CvChg_PenaltyIncrease);

    g_cvPenaltyIncreaseSmoker = CreateConVar(
    "l4d2_m2_smoker_penalty", "0",
    "How much penalty gets added when you shove a Smoker",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_iPenaltyIncreaseSmoker = g_cvPenaltyIncreaseSmoker.IntValue;
    g_cvPenaltyIncreaseSmoker.AddChangeHook(CvChg_PenaltyIncrease);

    g_cvShoveInterval = FindConVar("z_gun_swing_interval");
    g_fShoveInterval  = g_cvShoveInterval.FloatValue;
    g_cvShoveInterval.AddChangeHook(CvChg_ShoveInterval);

    g_cvShovePenaltyAmt = FindConVar("z_gun_swing_vs_amt_penalty");
    g_fShovePenaltyAmt  = g_cvShovePenaltyAmt.FloatValue;
    g_cvShovePenaltyAmt.AddChangeHook(CvChg_ShovePenaltyAmt);

    g_cvPounceCrouchDelay = FindConVar("z_pounce_crouch_delay");
    g_fPounceCrouchDelay  = g_cvPounceCrouchDelay.FloatValue;
    g_cvPounceCrouchDelay.AddChangeHook(CvChg_PounceCrouchDelay);

    g_cvLeapInterval = FindConVar("z_leap_interval");
    g_fLeapInterval  = g_cvLeapInterval.FloatValue;
    g_cvLeapInterval.AddChangeHook(CvChg_LeapInterval);

    g_cvMinShovePenaltyPvE = FindConVar("z_gun_swing_coop_min_penalty");
    g_iMinShovePenaltyPvE  = g_cvMinShovePenaltyPvE.IntValue;
    g_cvMinShovePenaltyPvE.AddChangeHook(CvChg_ShovePenaltyPvE);

    g_cvMaxShovePenaltyPvE = FindConVar("z_gun_swing_coop_max_penalty");
    g_iMaxShovePenaltyPvE  = g_cvMaxShovePenaltyPvE.IntValue;
    g_cvMaxShovePenaltyPvE.AddChangeHook(CvChg_ShovePenaltyPvE);

    g_cvMinShovePenaltyPvP = FindConVar("z_gun_swing_vs_min_penalty");
    g_iMinShovePenaltyPvP  = g_cvMinShovePenaltyPvP.IntValue;
    g_cvMinShovePenaltyPvP.AddChangeHook(CvChg_ShovePenaltyPvP);

    g_cvMaxShovePenaltyPvP = FindConVar("z_gun_swing_vs_max_penalty");
    g_iMaxShovePenaltyPvP  = g_cvMaxShovePenaltyPvP.IntValue;
    g_cvMaxShovePenaltyPvP.AddChangeHook(CvChg_ShovePenaltyPvP);

    g_cvGameMode = FindConVar("mp_gamemode");
    g_cvGameMode.AddChangeHook(CvChg_GameMode);

    HookEvent("player_shoved", Event_PlayerShoved);
}

public void OnConfigsExecuted() {
    g_bIsPvP = SDK_HasPlayerInfected();
}

void CvChg_PenaltyIncrease(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iPenaltyIncreaseHunter = g_cvPenaltyIncreaseHunter.IntValue;
    g_iPenaltyIncreaseJockey = g_cvPenaltyIncreaseJockey.IntValue;
    g_iPenaltyIncreaseSmoker = g_cvPenaltyIncreaseSmoker.IntValue;
}

void CvChg_ShoveInterval(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fShoveInterval = g_cvShoveInterval.FloatValue;
}

void CvChg_ShovePenaltyAmt(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fShovePenaltyAmt = g_cvShovePenaltyAmt.FloatValue;
}

void CvChg_PounceCrouchDelay(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fPounceCrouchDelay = g_cvPounceCrouchDelay.FloatValue;
}

void CvChg_LeapInterval(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fLeapInterval = g_cvLeapInterval.FloatValue;
}

void CvChg_ShovePenaltyPvE(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iMinShovePenaltyPvE = g_cvMinShovePenaltyPvE.IntValue;
    g_iMaxShovePenaltyPvE = g_cvMaxShovePenaltyPvE.IntValue;
}

void CvChg_ShovePenaltyPvP(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iMinShovePenaltyPvP = g_cvMinShovePenaltyPvP.IntValue;
    g_iMaxShovePenaltyPvP = g_cvMaxShovePenaltyPvP.IntValue;
}

void CvChg_GameMode(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bIsPvP = SDK_HasPlayerInfected();
}

void Event_PlayerShoved(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iShover = GetClientOfUserId(eEvent.GetInt("attacker"));
    if (!IsSurvivor(iShover))
        return;

    int iShover_Weapon = GetEntPropEnt(iShover, Prop_Send, "m_hActiveWeapon");
    if (iShover_Weapon == -1)
        return;

    int iShovee = GetClientOfUserId(eEvent.GetInt("userid"));
    if (!IsInfected(iShovee))
        return;

    int iPenaltyIncrease;
    switch (GetInfectedClass(iShovee)) {
        case L4D2Infected_Hunter: {
            iPenaltyIncrease = g_iPenaltyIncreaseHunter;
        }
        case L4D2Infected_Jockey: {
            iPenaltyIncrease = g_iPenaltyIncreaseJockey;
        }
        case L4D2Infected_Smoker: {
            iPenaltyIncrease = g_iPenaltyIncreaseSmoker;
        }
        default: return;
    }

    int iMinPenalty = g_bIsPvP ? g_iMinShovePenaltyPvP : g_iMinShovePenaltyPvE;
    int iMaxPenalty = g_bIsPvP ? g_iMaxShovePenaltyPvP : g_iMaxShovePenaltyPvE;
    int iPenalty    = GetEntProp(iShover, Prop_Send, "m_iShovePenalty");

    iPenalty += iPenaltyIncrease;
    if (iPenalty > iMaxPenalty)
        iPenalty = iMaxPenalty;

    float fAttackStartTime = GetEntPropFloat(iShover_Weapon, Prop_Send, "m_attackTimer", 1) - GetEntPropFloat(iShover_Weapon, Prop_Send, "m_attackTimer", 0);
    float fEps = GetGameTime() - fAttackStartTime;

    SetEntProp(iShover, Prop_Send, "m_iShovePenalty", iPenalty);
    SetEntPropFloat(iShover, Prop_Send, "m_flNextShoveTime", CalcNextShoveTime(iPenalty, iMinPenalty, iMaxPenalty) - fEps);
}

public void L4D_OnCancelStagger_Post(int iClient) {
    if (IsInfected(iClient) && IsPlayerAlive(iClient) && !L4D_IsPlayerGhost(iClient)) {
        float fRecharge  = -1.0;
        bool  bAttacking = false;
        switch (GetInfectedClass(iClient)) {
            case L4D2Infected_Hunter: {
                fRecharge  = g_fPounceCrouchDelay;
                bAttacking = GetEntPropEnt(iClient, Prop_Send, "m_pounceVictim") != -1;
            }
            case L4D2Infected_Jockey: {
                fRecharge  = g_fLeapInterval;
                bAttacking = GetEntPropEnt(iClient, Prop_Send, "m_jockeyVictim") != -1;
            }
            default: {
                return;
            }
        }

        if (fRecharge != -1.0 && !bAttacking) {
            int iAbility = GetInfectedAbilityEntity(iClient);
            if (iAbility != -1) {
                float fNext      = GetGameTime() + fRecharge;
                float fTimeStamp = GetEntPropFloat(iAbility, Prop_Send, "m_nextActivationTimer", 1);
                if (fNext > fTimeStamp) {
                    SetEntPropFloat(iAbility, Prop_Send, "m_nextActivationTimer", fRecharge, 0);
                    SetEntPropFloat(iAbility, Prop_Send, "m_nextActivationTimer", fNext, 1);
                }
            }
        }
    }
}

float CalcNextShoveTime(int iCurrentPenalty, int iMinPenalty, int iMaxPenalty) {
    float fRatio = 0.0;
    if (iCurrentPenalty >= iMinPenalty) fRatio = L4D2Util_ClampFloat(float(iCurrentPenalty - iMinPenalty) / float(iMaxPenalty - iMinPenalty), 0.0, 1.0);
    float fDuration = fRatio * g_fShovePenaltyAmt;
    float fReturn = GetGameTime() + fDuration + g_fShoveInterval;
    return fReturn;
}