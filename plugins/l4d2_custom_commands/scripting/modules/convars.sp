#if defined __CONVARS__
    #endinput
#endif
#define __CONVARS__

void OnModuleStart_ConVars() {
    g_cvRadius = CreateConVar(
    "l4d2_custom_commands_explosion_radius", "350",
    "Radius for the Create Explosion's command explosion.",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_fRadius = g_cvRadius.FloatValue;
    g_cvRadius.AddChangeHook(ConVarChanged_Radius);

    g_cvPower = CreateConVar(
    "l4d2_custom_commands_explosion_power", "350",
    "Power of the Create Explosion's command explosion.",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_fPower = g_cvPower.FloatValue;
    g_cvPower.AddChangeHook(ConVarChanged_Power);

    g_cvDuration = CreateConVar(
    "l4d2_custom_commands_explosion_duration", "15",
    "Duration of the Create Explosion's command explosion fire trace.",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_fDuration = g_cvDuration.FloatValue;
    g_cvDuration.AddChangeHook(ConVarChanged_Duration);

    g_cvRainDur = CreateConVar(
    "l4d2_custom_commands_rain_duration", "10",
    "Time out for the gnome's rain or l4d1 survivors rain.",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_fRainDur = g_cvRainDur.FloatValue;
    g_cvRainDur.AddChangeHook(ConVarChanged_RainDur);

    g_cvRainRadius = CreateConVar(
    "l4d2_custom_commands_rain_radius", "300",
    "Maximum radius of the gnome rain or l4d1 rain.\nWill also affect the air strike radius.",
    FCVAR_NONE, true, 0.0, false, 0.0);
    g_fRainRadius = g_cvRainRadius.FloatValue;
    g_cvRainRadius.AddChangeHook(ConVarChanged_RainRadius);

    g_cvLog = CreateConVar(
    "l4d2_custom_commands_log", "1",
    "Log admin actions when they use a command?",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bLog = g_cvLog.BoolValue;
    g_cvLog.AddChangeHook(ConVarChanged_Log);

    g_cvMaxIncaps = FindConVar("survivor_max_incapacitated_count");
    g_iMaxIncaps  = g_cvMaxIncaps.IntValue;
    g_cvMaxIncaps.AddChangeHook(ConVarChanged_MaxIncaps);

    g_cvPillsDecay = FindConVar("pain_pills_decay_rate");
    g_fPillsDecay  = g_cvPillsDecay.FloatValue;
    g_cvPillsDecay.AddChangeHook(ConVarChanged_PillsDecay);
}

void ConVarChanged_Radius(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fRadius = cv.FloatValue;
}

void ConVarChanged_Power(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fPower = cv.FloatValue;
}

void ConVarChanged_Duration(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fDuration = cv.FloatValue;
}

void ConVarChanged_RainDur(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fRainDur = cv.FloatValue;
}

void ConVarChanged_RainRadius(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fRainRadius = cv.FloatValue;
}

void ConVarChanged_Log(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bLog = cv.BoolValue;
}

void ConVarChanged_MaxIncaps(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iMaxIncaps = cv.IntValue;
}

void ConVarChanged_PillsDecay(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_fPillsDecay = cv.FloatValue;
}