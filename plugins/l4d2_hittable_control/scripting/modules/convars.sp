#if defined __CONVARS__
    #endinput
#endif
#define __CONVARS__

ConVar cvGauntletFinaleMulti;
float  fGauntletFinaleMulti;

ConVar cvLogStandingDamage;
float  fLogStandingDamage;

ConVar cvBHLogStandingDamage;
float  fBHLogStandingDamage;

ConVar cvCarStandingDamage;
float  fCarStandingDamage;

ConVar cvBumperCarStandingDamage;
float  fBumperCarStandingDamage;

ConVar cvHandtruckStandingDamage;
float  fHandtruckStandingDamage;

ConVar cvForkliftStandingDamage;
float  fForkliftStandingDamage;

ConVar cvBrokenForkliftStandingDamage;
float  fBrokenForkliftStandingDamage;

ConVar cvDumpsterStandingDamage;
float  fDumpsterStandingDamage;

ConVar cvHaybaleStandingDamage;
float  fHaybaleStandingDamage;

ConVar cvBaggageStandingDamage;
float  fBaggageStandingDamage;

ConVar cvStandardIncapDamage;
float  fStandardIncapDamage;

ConVar cvGeneratorTrailerStandingDamage;
float  fGeneratorTrailerStandingDamage;

ConVar cvMilitiaRockStandingDamage;
float  fMilitiaRockStandingDamage;

ConVar cvSofaChairStandingDamage;
float  fSofaChairStandingDamage;

ConVar cvAtlasBallDamage;
float  fAtlasBallDamage;

ConVar cvIBeamDamage;
float  fIBeamDamage;

ConVar cvDiescraperBallDamage;
float  fDiescraperBallDamage;

ConVar cvVanDamage;
float  fVanDamage;

ConVar cvOverHitInterval;
float  fOverHitInterval;

ConVar cvTankSelfDamage;
bool   bTankSelfDamage;

ConVar cvUnbreakableForklifts;
bool   bUnbreakableForklifts;

void OnModuleStart_ConVars() {
    cvGauntletFinaleMulti = CreateConVar(
    "hc_gauntlet_finale_multiplier", "0.25", "Multiplier of damage that hittables deal on gauntlet finales.",
    FCVAR_NONE, true, 0.0, true, 4.0);
    fGauntletFinaleMulti = cvGauntletFinaleMulti.FloatValue;
    cvGauntletFinaleMulti.AddChangeHook(CvChg_GauntletFinaleMulti);

    cvLogStandingDamage = CreateConVar(
    "hc_sflog_standing_damage", "48.0", "Damage of hittable swamp fever logs to non-incapped survivors.",
    FCVAR_NONE, true, 0.0, true, 300.0);
    fLogStandingDamage = cvLogStandingDamage.FloatValue;
    cvLogStandingDamage.AddChangeHook(CvChg_LogStandingDamage);

    cvBHLogStandingDamage = CreateConVar(
    "hc_bhlog_standing_damage", "100.0", "Damage of hittable blood harvest logs to non-incapped survivors.",
    FCVAR_NONE, true, 0.0, true, 300.0);
    fBHLogStandingDamage = cvBHLogStandingDamage.FloatValue;
    cvBHLogStandingDamage.AddChangeHook(CvChbHLogStandingDamage);

    cvCarStandingDamage = CreateConVar(
    "hc_car_standing_damage", "100.0", "Damage of hittable cars to non-incapped survivors.",
    FCVAR_NONE, true, 0.0, true, 300.0);
    fCarStandingDamage = cvCarStandingDamage.FloatValue;
    cvCarStandingDamage.AddChangeHook(CvChg_CarStandingDamage);

    cvBumperCarStandingDamage = CreateConVar(
    "hc_bumpercar_standing_damage", "100.0", "Damage of hittable bumper cars to non-incapped survivors.",
    FCVAR_NONE, true, 0.0, true, 300.0);
    fBumperCarStandingDamage = cvBumperCarStandingDamage.FloatValue;
    cvBumperCarStandingDamage.AddChangeHook(CvChbumperCarStandingDamage);

    cvHandtruckStandingDamage = CreateConVar(
    "hc_handtruck_standing_damage", "8.0", "Damage of hittable handtrucks (aka dollies) to non-incapped survivors.",
    FCVAR_NONE, true, 0.0, true, 300.0);
    fHandtruckStandingDamage = cvHandtruckStandingDamage.FloatValue;
    cvHandtruckStandingDamage.AddChangeHook(CvChg_HandtruckStandingDamage);

    cvForkliftStandingDamage = CreateConVar(
    "hc_forklift_standing_damage", "100.0", "Damage of hittable forklifts to non-incapped survivors.",
    FCVAR_NONE, true, 0.0, true, 300.0);
    fForkliftStandingDamage = cvForkliftStandingDamage.FloatValue;
    cvForkliftStandingDamage.AddChangeHook(CvChforkliftStandingDamage);

    cvBrokenForkliftStandingDamage = CreateConVar(
    "hc_broken_forklift_standing_damage", "100.0", "Damage of hittable broken forklifts to non-incapped survivors.",
    FCVAR_NONE, true, 0.0, true, 300.0);
    fBrokenForkliftStandingDamage = cvBrokenForkliftStandingDamage.FloatValue;
    cvBrokenForkliftStandingDamage.AddChangeHook(CvChbrokenForkliftStandingDamage);

    cvDumpsterStandingDamage = CreateConVar(
    "hc_dumpster_standing_damage", "100.0", "Damage of hittable dumpsters to non-incapped survivors.",
    FCVAR_NONE, true, 0.0, true, 300.0);
    fDumpsterStandingDamage = cvDumpsterStandingDamage.FloatValue;
    cvDumpsterStandingDamage.AddChangeHook(CvChg_DumpsterStandingDamage);

    cvHaybaleStandingDamage = CreateConVar(
    "hc_haybale_standing_damage", "48.0", "Damage of hittable haybales to non-incapped survivors.",
    FCVAR_NONE, true, 0.0, true, 300.0);
    fHaybaleStandingDamage = cvHaybaleStandingDamage.FloatValue;
    cvHaybaleStandingDamage.AddChangeHook(CvChg_HaybaleStandingDamage);

    cvBaggageStandingDamage = CreateConVar(
    "hc_baggage_standing_damage", "48.0", "Damage of hittable baggage carts to non-incapped survivors.",
    FCVAR_NONE, true, 0.0, true, 300.0);
    fBaggageStandingDamage = cvBaggageStandingDamage.FloatValue;
    cvBaggageStandingDamage.AddChangeHook(CvChbaggageStandingDamage);

    cvStandardIncapDamage = CreateConVar(
    "hc_incap_standard_damage", "100", "Damage of all hittables to incapped players. -1 will have incap damage default to valve's standard incoherent damages. -2 will have incap damage default to each hittable's corresponding standing damage.",
    FCVAR_NONE, true, -2.0, true, 300.0);
    fStandardIncapDamage = cvStandardIncapDamage.FloatValue;
    cvStandardIncapDamage.AddChangeHook(CvChg_StandardIncapDamage);

    cvGeneratorTrailerStandingDamage = CreateConVar(
    "hc_generator_trailer_standing_damage", "48.0", "Damage of hittable generator trailers to non-incapped survivors.",
    FCVAR_NONE, true, 0.0, true, 300.0);
    fGeneratorTrailerStandingDamage = cvGeneratorTrailerStandingDamage.FloatValue;
    cvGeneratorTrailerStandingDamage.AddChangeHook(CvChg_GeneratorTrailerStandingDamage);

    cvMilitiaRockStandingDamage = CreateConVar(
    "hc_militia_rock_standing_damage", "100.0", "Damage of hittable militia rocks to non-incapped survivors.",
    FCVAR_NONE, true, 0.0, true, 300.0);
    fMilitiaRockStandingDamage = cvMilitiaRockStandingDamage.FloatValue;
    cvMilitiaRockStandingDamage.AddChangeHook(CvChg_MilitiaRockStandingDamage);

    cvSofaChairStandingDamage = CreateConVar(
    "hc_sofa_chair_standing_damage", "100.0", "Damage of hittable sofa chair on Blood Harvest finale to non-incapped survivors. Applies only to sofa chair with a targetname of 'hittable_chair_l4d1' to emulate L4D1 behaviour, the hittable chair from TLS update is parented to a bumper car.",
    FCVAR_NONE, true, 0.0, true, 300.0);
    fSofaChairStandingDamage = cvSofaChairStandingDamage.FloatValue;
    cvSofaChairStandingDamage.AddChangeHook(CvChg_SofaChairStandingDamage);

    cvAtlasBallDamage = CreateConVar(
    "hc_atlas_ball_standing_damage", "100.0", "Damage of hittable atlas balls to non-incapped survivors.",
    FCVAR_NONE, true, 0.0, true, 300.0);
    fAtlasBallDamage = cvAtlasBallDamage.FloatValue;
    cvAtlasBallDamage.AddChangeHook(CvChg_AtlasBallDamage);

    cvIBeamDamage = CreateConVar(
    "hc_ibeam_standing_damage", "48.0", "Damage of ibeams to non-incapped survivors.",
    FCVAR_NONE, true, 0.0, true, 300.0);
    fIBeamDamage = cvIBeamDamage.FloatValue;
    cvIBeamDamage.AddChangeHook(CvChg_IBeamDamage);

    cvDiescraperBallDamage = CreateConVar(
    "hc_diescraper_ball_standing_damage", "100.0", "Damage of hittable ball statue on Diescraper finale to non-incapped survivors.",
    FCVAR_NONE, true, 0.0, true, 300.0);
    fDiescraperBallDamage = cvDiescraperBallDamage.FloatValue;
    cvDiescraperBallDamage.AddChangeHook(CvChg_DiescraperBallDamage);

    cvVanDamage = CreateConVar(
    "hc_van_standing_damage", "100.0", "Damage of hittable van on Detour Ahead map 2 to non-incapped survivors.",
    FCVAR_NONE, true, 0.0, true, 300.0);
    fVanDamage = cvVanDamage.FloatValue;
    cvVanDamage.AddChangeHook(CvChg_VanDamage);

    cvOverHitInterval = CreateConVar(
    "hc_overhit_time", "1.4", "The amount of time to wait before allowing consecutive hits from the same hittable to register. Recommended values: 0.0-0.5: instant kill; 0.5-0.7: sizeable overhit; 0.7-1.0: standard overhit; 1.0-1.2: reduced overhit; 1.2+: no overhit unless the car rolls back on top. Set to tank's punch interval (default 1.5) to fully remove all possibility of overhit.",
    FCVAR_NONE, true, 0.0, false);
    fOverHitInterval = cvOverHitInterval.FloatValue;
    cvOverHitInterval.AddChangeHook(CvChg_OverHitInterval);

    cvTankSelfDamage = CreateConVar(
    "hc_disable_self_damage", "0", "If set, tank will not damage itself with hittables.",
    FCVAR_NONE, true, 0.0, true, 1.0);
    bTankSelfDamage = cvTankSelfDamage.BoolValue;
    cvTankSelfDamage.AddChangeHook(CvChg_TankSelfDamage);

    cvUnbreakableForklifts = CreateConVar(
    "hc_unbreakable_forklifts", "0", "Prevents forklifts breaking into pieces when hit by a tank.",
    FCVAR_NONE, true, 0.0, false);
    bUnbreakableForklifts = cvUnbreakableForklifts.BoolValue;
    cvUnbreakableForklifts.AddChangeHook(CvChg_UnbreakableForklifts);
}

void CvChg_GauntletFinaleMulti(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    fGauntletFinaleMulti = cvGauntletFinaleMulti.FloatValue;
}

void CvChg_LogStandingDamage(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    fLogStandingDamage = cvLogStandingDamage.FloatValue;
}

void CvChbHLogStandingDamage(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    fBHLogStandingDamage = cvBHLogStandingDamage.FloatValue;
}

void CvChg_CarStandingDamage(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    fCarStandingDamage = cvCarStandingDamage.FloatValue;
}

void CvChbumperCarStandingDamage(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    fBumperCarStandingDamage = cvBumperCarStandingDamage.FloatValue;
}

void CvChg_HandtruckStandingDamage(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    fHandtruckStandingDamage = cvHandtruckStandingDamage.FloatValue;
}

void CvChforkliftStandingDamage(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    fForkliftStandingDamage = cvForkliftStandingDamage.FloatValue;
}

void CvChbrokenForkliftStandingDamage(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    fBrokenForkliftStandingDamage = cvBrokenForkliftStandingDamage.FloatValue;
}

void CvChg_DumpsterStandingDamage(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    fDumpsterStandingDamage = cvDumpsterStandingDamage.FloatValue;
}

void CvChg_HaybaleStandingDamage(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    fHaybaleStandingDamage = cvHaybaleStandingDamage.FloatValue;
}

void CvChbaggageStandingDamage(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    fBaggageStandingDamage = cvBaggageStandingDamage.FloatValue;
}

void CvChg_StandardIncapDamage(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    fStandardIncapDamage = cvStandardIncapDamage.FloatValue;
}

void CvChg_GeneratorTrailerStandingDamage(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    fGeneratorTrailerStandingDamage = cvGeneratorTrailerStandingDamage.FloatValue;
}

void CvChg_MilitiaRockStandingDamage(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    fMilitiaRockStandingDamage = cvMilitiaRockStandingDamage.FloatValue;
}

void CvChg_SofaChairStandingDamage(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    fSofaChairStandingDamage = cvSofaChairStandingDamage.FloatValue;
}

void CvChg_AtlasBallDamage(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    fAtlasBallDamage = cvAtlasBallDamage.FloatValue;
}

void CvChg_IBeamDamage(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    fIBeamDamage = cvIBeamDamage.FloatValue;
}

void CvChg_DiescraperBallDamage(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    fDiescraperBallDamage = cvDiescraperBallDamage.FloatValue;
}

void CvChg_VanDamage(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    fVanDamage = cvVanDamage.FloatValue;
}

void CvChg_OverHitInterval(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    fOverHitInterval = cvOverHitInterval.FloatValue;
}

void CvChg_TankSelfDamage(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    bTankSelfDamage = cvTankSelfDamage.BoolValue;
}

void CvChg_UnbreakableForklifts(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    bUnbreakableForklifts = cvUnbreakableForklifts.BoolValue;
    ToggleBreakableForklifts(bUnbreakableForklifts, 1.0);
}