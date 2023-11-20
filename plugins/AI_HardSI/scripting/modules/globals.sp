#if defined __GLOBALS__
    #endinput
#endif
#define __GLOBALS__

#define BOOST           90.0
#define PLAYER_HEIGHT   72.0
#define OBSTACLE_HEIGHT 18.0
#define SIZE_OF_INT     2147483647

int   g_iCurTarget   [MAXPLAYERS + 1];
bool  g_bShouldCharge[MAXPLAYERS + 1];
float g_fRunTopSpeed [MAXPLAYERS + 1];

/** Boomer ConVars **/
ConVar g_cvBoomerBhop;
bool   g_bBoomerBhop;

ConVar g_cvVomitRange;
float  g_fVomitRange;

/** Hunter ConVars **/
ConVar g_cvFastPounceProximity;
float  g_fFastPounceProximity;

ConVar g_cvPounceVerticalAngle;
float  g_fPounceVerticalAngle;

ConVar g_cvPounceAngleMean;
float  g_fPounceAngleMean;

ConVar g_cvPounceAngleStd;
float  g_fPounceAngleStd;

ConVar g_cvStraightPounceProximity;
float  g_fStraightPounceProximity;

ConVar g_cvAimOffsetSensitivityHunter;
float  g_fAimOffsetSensitivityHunter;

ConVar g_cvWallDetectionDistance;
float  g_fWallDetectionDistance;

ConVar g_cvLungeInterval;
float  g_fLungeInterval;

/** Spitter ConVars **/
ConVar g_cvSpitterBhop;
bool   g_bSpitterBhop;

/** Jockey ConVars **/
ConVar g_cvJockeyStumbleRadius;
float  g_fJockeyStumbleRadius;

ConVar g_cvHopActivationProximity;
float  g_fHopActivationProximity;

ConVar g_cvJockeyLeapRange;
float  g_fJockeyLeapRange;

ConVar g_cvJockeyLeapAgain;
float  g_fJockeyLeapAgain;

/** Charger ConVars **/
ConVar g_cvChargerBhop;
bool   g_bChargerBhop;

ConVar g_cvChargeProximity;
float  g_fChargeProximity;

ConVar g_cvHealthThreshold;
int    g_iHealthThreshold;

ConVar g_cvAimOffsetSensitivityCharger;
float  g_fAimOffsetSensitivityCharger;

ConVar g_cvChargeMaxSpeed;
float  g_fChargeMaxSpeed;

ConVar g_cvChargeStartSpeed;
float  g_fChargeStartSpeed;

/** Tank ConVars **/
ConVar g_cvTankBhop;
bool   g_bTankBhop;

ConVar g_cvTankAttackRange;
float  g_fTankAttackRange;



void Globals_OnModuleStart() {
    /** Boomer ConVars **/
    g_cvBoomerBhop = CreateConVar(
    "ai_boomer_bhop", "0",
    "Flag to enable bhop facsimile on AI boomers",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bBoomerBhop = g_cvBoomerBhop.BoolValue;
    g_cvBoomerBhop.AddChangeHook(ConVarChanged_BoomerBhop);

    g_cvVomitRange = FindConVar("z_vomit_range");
    g_fVomitRange  = g_cvVomitRange.FloatValue;
    g_cvVomitRange.AddChangeHook(ConVarChanged_VomitRange);

    /** Hunter ConVars **/
    g_cvFastPounceProximity = CreateConVar(
    "ai_fast_pounce_proximity", "1000.0",
    "At what distance to start pouncing fast",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_fFastPounceProximity = g_cvFastPounceProximity.FloatValue;
    g_cvFastPounceProximity.AddChangeHook(ConVarChanged_FastPounceProximity);

    g_cvPounceVerticalAngle = CreateConVar(
    "ai_pounce_vertical_angle", "7.0",
    "Vertical angle to which AI hunter pounces will be restricted",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_fPounceVerticalAngle = g_cvPounceVerticalAngle.FloatValue;
    g_cvPounceVerticalAngle.AddChangeHook(ConVarChanged_PounceVerticalAngle);

    g_cvPounceAngleMean = CreateConVar(
    "ai_pounce_angle_mean", "10.0",
    "Mean angle produced by Gaussian RNG",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_fPounceAngleMean = g_cvPounceAngleMean.FloatValue;
    g_cvPounceAngleMean.AddChangeHook(ConVarChanged_PounceAngleMean);

    g_cvPounceAngleStd = CreateConVar(
    "ai_pounce_angle_std", "20.0",
    "One standard deviation from mean as produced by Gaussian RNG",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_fPounceAngleStd = g_cvPounceAngleStd.FloatValue;
    g_cvPounceAngleStd.AddChangeHook(ConVarChanged_PounceAngleStd);

    g_cvStraightPounceProximity = CreateConVar(
    "ai_straight_pounce_proximity", "200.0",
    "Distance to nearest survivor at which hunter will consider pouncing straight",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_fStraightPounceProximity = g_cvStraightPounceProximity.FloatValue;
    g_cvStraightPounceProximity.AddChangeHook(ConVarChanged_StraightPounceProximity);

    g_cvAimOffsetSensitivityHunter = CreateConVar(
    "ai_aim_offset_sensitivity_hunter", "180.0",
    "If the hunter has a target, it will not straight pounce if the target's aim on the horizontal axis is within this radius",
    FCVAR_NONE, true, 0.0, true, 180.0);
    g_fAimOffsetSensitivityHunter = g_cvAimOffsetSensitivityHunter.FloatValue;
    g_cvAimOffsetSensitivityHunter.AddChangeHook(ConVarChanged_AimOffsetSensitivityHunter);

    g_cvWallDetectionDistance = CreateConVar(
    "ai_wall_detection_distance", "-1.0",
    "How far in front of himself infected bot will check for a wall. Use '-1' to disable feature",
    FCVAR_NONE, true, -1.0, false, 0.0);
    g_fWallDetectionDistance = g_cvWallDetectionDistance.FloatValue;
    g_cvWallDetectionDistance.AddChangeHook(ConVarChanged_WallDetectionDistance);

    g_cvLungeInterval = FindConVar("z_lunge_interval");
    g_fLungeInterval  = g_cvLungeInterval.FloatValue;
    g_cvLungeInterval.AddChangeHook(ConVarChanged_LungeInterval);

    /** Spitter ConVars **/
    g_cvSpitterBhop = CreateConVar(
    "ai_spitter_bhop", "0",
    "Flag to enable bhop facsimile on AI spitters",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bSpitterBhop = g_cvSpitterBhop.BoolValue;
    g_cvSpitterBhop.AddChangeHook(ConVarChanged_SpitterBhop);

    /** Jockey ConVars **/
    g_cvJockeyStumbleRadius = CreateConVar(
    "ai_jockey_stumble_radius", "50.0",
    "Stumble radius of a client landing a ride",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_fJockeyStumbleRadius = g_cvJockeyStumbleRadius.FloatValue;
    g_cvJockeyStumbleRadius.AddChangeHook(ConVarChanged_JockeyStumbleRadius);

    g_cvHopActivationProximity = CreateConVar(
    "ai_hop_activation_proximity", "800.0",
    "How close a client will approach before it starts hopping",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_fHopActivationProximity = g_cvHopActivationProximity.FloatValue;
    g_cvHopActivationProximity.AddChangeHook(ConVarChanged_HopActivationProximity);

    g_cvJockeyLeapRange = FindConVar("z_jockey_leap_range");
    g_fJockeyLeapRange  = g_cvJockeyLeapRange.FloatValue;
    g_cvJockeyLeapRange.AddChangeHook(ConVarChanged_JockeyLeapRange);

    g_cvJockeyLeapAgain = FindConVar("z_jockey_leap_again_timer");
    g_fJockeyLeapAgain  = g_cvJockeyLeapAgain.FloatValue;
    g_cvJockeyLeapAgain.AddChangeHook(ConVarChanged_JockeyLeapAgain);

    /** Charger ConVars **/
    g_cvChargerBhop = CreateConVar(
    "ai_charger_bhop", "0",
    "Flag to enable bhop facsimile on AI chargers",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bChargerBhop = g_cvChargerBhop.BoolValue;
    g_cvChargerBhop.AddChangeHook(ConVarChanged_ChargerBhop);

    g_cvChargeProximity = CreateConVar(
    "ai_charge_proximity", "200.0",
    "How close a client will approach before charging",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_fChargeProximity = g_cvChargeProximity.FloatValue;
    g_cvChargeProximity.AddChangeHook(ConVarChanged_ChargeProximity);

    g_cvHealthThreshold = CreateConVar(
    "ai_health_threshold_charger", "300",
    "Charger will charge if its health drops to this level",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_iHealthThreshold = g_cvHealthThreshold.IntValue;
    g_cvHealthThreshold.AddChangeHook(ConVarChanged_HealthThreshold);

    g_cvAimOffsetSensitivityCharger = CreateConVar(
    "ai_aim_offset_sensitivity_charger", "22.5",
    "If the charger has a target, it will not straight charge if the target's aim on the horizontal axis is within this radius",
    FCVAR_NONE, true, 0.0, true, 180.0);
    g_fAimOffsetSensitivityCharger = g_cvAimOffsetSensitivityCharger.FloatValue;
    g_cvAimOffsetSensitivityCharger.AddChangeHook(ConVarChanged_AimOffsetSensitivityCharger);

    g_cvChargeMaxSpeed = FindConVar("z_charge_max_speed");
    g_fChargeMaxSpeed  = g_cvChargeMaxSpeed.FloatValue;
    g_cvChargeMaxSpeed.AddChangeHook(ConVarChanged_ChargeMaxSpeed);

    g_cvChargeStartSpeed = FindConVar("z_charge_start_speed");
    g_fChargeStartSpeed  = g_cvChargeStartSpeed.FloatValue;
    g_cvChargeStartSpeed.AddChangeHook(ConVarChanged_ChargeStartSpeed);

    /** Tank ConVars **/
    g_cvTankBhop = CreateConVar(
    "ai_tank_bhop", "0",
    "Flag to enable bhop facsimile on AI tanks",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bTankBhop = g_cvTankBhop.BoolValue;
    g_cvTankBhop.AddChangeHook(ConVarChanged_TankBhop);

    g_cvTankAttackRange = FindConVar("tank_attack_range");
    g_fTankAttackRange  = g_cvTankAttackRange.FloatValue;
    g_cvTankAttackRange.AddChangeHook(ConVarChanged_TankAttackRange);
}



/** Boomer ConVars **/
void ConVarChanged_BoomerBhop(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bBoomerBhop = g_cvBoomerBhop.BoolValue;
}

void ConVarChanged_VomitRange(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fVomitRange = g_cvVomitRange.FloatValue;
}

/** Hunter ConVars **/
void ConVarChanged_FastPounceProximity(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fFastPounceProximity = g_cvFastPounceProximity.FloatValue;
}

void ConVarChanged_PounceVerticalAngle(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fPounceVerticalAngle = g_cvPounceVerticalAngle.FloatValue;
}

void ConVarChanged_PounceAngleMean(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fPounceAngleMean = g_cvPounceAngleMean.FloatValue;
}

void ConVarChanged_PounceAngleStd(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fPounceAngleStd = g_cvPounceAngleStd.FloatValue;
}

void ConVarChanged_StraightPounceProximity(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fStraightPounceProximity = g_cvStraightPounceProximity.FloatValue;
}

void ConVarChanged_AimOffsetSensitivityHunter(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fAimOffsetSensitivityHunter = g_cvAimOffsetSensitivityHunter.FloatValue;
}

void ConVarChanged_WallDetectionDistance(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fWallDetectionDistance = g_cvWallDetectionDistance.FloatValue;
}

void ConVarChanged_LungeInterval(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fLungeInterval = g_cvLungeInterval.FloatValue;
}

/** Spitter ConVars **/
void ConVarChanged_SpitterBhop(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bSpitterBhop = g_cvSpitterBhop.BoolValue;
}

/** Jockey ConVars **/
void ConVarChanged_JockeyStumbleRadius(ConVar convar, const char[] oldValue, const char[] newValue) {
    g_fJockeyStumbleRadius = g_cvJockeyStumbleRadius.FloatValue;
}

void ConVarChanged_HopActivationProximity(ConVar convar, const char[] oldValue, const char[] newValue) {
    g_fHopActivationProximity = g_cvHopActivationProximity.FloatValue;
}

void ConVarChanged_JockeyLeapRange(ConVar convar, const char[] oldValue, const char[] newValue) {
    g_fJockeyLeapRange = g_cvJockeyLeapRange.FloatValue;
}

void ConVarChanged_JockeyLeapAgain(ConVar convar, const char[] oldValue, const char[] newValue) {
    g_fJockeyLeapAgain = g_cvJockeyLeapAgain.FloatValue;
}

/** Charger ConVars **/
void ConVarChanged_ChargerBhop(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bChargerBhop = g_cvChargerBhop.BoolValue;
}

void ConVarChanged_ChargeProximity(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fChargeProximity = g_cvChargeProximity.FloatValue;
}

void ConVarChanged_HealthThreshold(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iHealthThreshold = g_cvHealthThreshold.IntValue;
}

void ConVarChanged_AimOffsetSensitivityCharger(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fAimOffsetSensitivityCharger = g_cvAimOffsetSensitivityCharger.FloatValue;
}

void ConVarChanged_ChargeMaxSpeed(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fChargeMaxSpeed = g_cvChargeMaxSpeed.FloatValue;
}

void ConVarChanged_ChargeStartSpeed(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fChargeStartSpeed = g_cvChargeStartSpeed.FloatValue;
}

void Charger_PlayerSpawn(int iClient) {
    g_bShouldCharge[iClient] = false;
}

/** Tank ConVars **/
void ConVarChanged_TankBhop(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bTankBhop = g_cvTankBhop.BoolValue;
}

void ConVarChanged_TankAttackRange(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fTankAttackRange = g_cvTankAttackRange.FloatValue;
}