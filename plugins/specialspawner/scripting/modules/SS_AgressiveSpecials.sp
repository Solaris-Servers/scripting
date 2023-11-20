#if defined _Agressive_Specials_Included
    #endinput
#endif
#define _Agressive_Specials_Included

#define SHOULD_ASSAULT_CONDITION_BOOMER  (1 << 0)
#define SHOULD_ASSAULT_CONDITION_SMOKER  (1 << 1)
#define SHOULD_ASSAULT_CONDITION_HUNTER  (1 << 2)
#define SHOULD_ASSAULT_CONDITION_SPITTER (1 << 3)
#define SHOULD_ASSAULT_CONDITION_JOCKEY  (1 << 4)
#define SHOULD_ASSAULT_CONDITION_CHARGER (1 << 5)
#define SHOULD_ADVANCE_ON_SURVIVORS      (1 << 6)

MemoryPatch mPatch_ShouldAssaultCondition_Boomer;
MemoryPatch mPatch_ShouldAssaultCondition_Smoker;
MemoryPatch mPatch_ShouldAssaultCondition_Hunter;
MemoryPatch mPatch_ShouldAssaultCondition_Spitter;
MemoryPatch mPatch_ShouldAssaultCondition_Jockey;
MemoryPatch mPatch_ShouldAssaultCondition_Charger;
MemoryPatch mPatch_ShouldAdvanceOnSurvivors;

ConVar cvFlags;
int    iFlags;

void InitGameData() {
    GameData gmData = new GameData("specialspawner");
    if (gmData == null) SetFailState("Failed to load \"specialspawner.txt\" gamedata.");

    mPatch_ShouldAssaultCondition_Boomer = MemoryPatch.CreateFromConf(gmData, "should_assault_condition_boomer");
    if (!mPatch_ShouldAssaultCondition_Boomer.Validate()) SetFailState("Verify patch: should_assault_condition_boomer failed.");

    mPatch_ShouldAssaultCondition_Smoker = MemoryPatch.CreateFromConf(gmData, "should_assault_condition_smoker");
    if (!mPatch_ShouldAssaultCondition_Smoker.Validate()) SetFailState("Verify patch: should_assault_condition_smoker failed.");

    mPatch_ShouldAssaultCondition_Hunter = MemoryPatch.CreateFromConf(gmData, "should_assault_condition_hunter");
    if (!mPatch_ShouldAssaultCondition_Hunter.Validate()) SetFailState("Verify patch: should_assault_condition_hunter failed.");

    mPatch_ShouldAssaultCondition_Spitter = MemoryPatch.CreateFromConf(gmData, "should_assault_condition_spitter");
    if (!mPatch_ShouldAssaultCondition_Spitter.Validate()) SetFailState("Verify patch: should_assault_condition_spitter failed.");

    mPatch_ShouldAssaultCondition_Jockey = MemoryPatch.CreateFromConf(gmData, "should_assault_condition_jockey");
    if (!mPatch_ShouldAssaultCondition_Jockey.Validate()) SetFailState("Verify patch: should_assault_condition_jockey failed.");

    mPatch_ShouldAssaultCondition_Charger = MemoryPatch.CreateFromConf(gmData, "should_assault_condition_charger");
    if (!mPatch_ShouldAssaultCondition_Charger.Validate()) SetFailState("Verify patch: should_assault_condition_charger failed.");

    mPatch_ShouldAdvanceOnSurvivors = MemoryPatch.CreateFromConf(gmData, "should_advance_on_survivors");
    if (!mPatch_ShouldAdvanceOnSurvivors.Validate()) SetFailState("Verify patch: should_advance_on_survivors failed.");

    delete gmData;
}

void AggressiveSpecials_OnModuleStart() {
    InitGameData();
    cvFlags = CreateConVar(
    "sm_aggressive_specials_enable", "127",
    "Bit flag: Apply patch for: 0 = Disable, 1 = Boomer, 2 = Smoker, 4 = Hunter, 8 = Spitter, 16 = Jockey, 32 = Charger, 64 = Should advance on survivors",
    FCVAR_NONE, true, 0.0, true, 127.0);
    iFlags = cvFlags.IntValue;

    if (iFlags & SHOULD_ASSAULT_CONDITION_BOOMER)  mPatch_ShouldAssaultCondition_Boomer.Enable();
    if (iFlags & SHOULD_ASSAULT_CONDITION_SMOKER)  mPatch_ShouldAssaultCondition_Smoker.Enable();
    if (iFlags & SHOULD_ASSAULT_CONDITION_HUNTER)  mPatch_ShouldAssaultCondition_Hunter.Enable();
    if (iFlags & SHOULD_ASSAULT_CONDITION_SPITTER) mPatch_ShouldAssaultCondition_Spitter.Enable();
    if (iFlags & SHOULD_ASSAULT_CONDITION_JOCKEY)  mPatch_ShouldAssaultCondition_Jockey.Enable();
    if (iFlags & SHOULD_ASSAULT_CONDITION_CHARGER) mPatch_ShouldAssaultCondition_Charger.Enable();
    if (iFlags & SHOULD_ADVANCE_ON_SURVIVORS)      mPatch_ShouldAdvanceOnSurvivors.Enable();

    cvFlags.AddChangeHook(ConVarChanged_Flags);
}

void ConVarChanged_Flags(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    iFlags = cvFlags.IntValue;

    mPatch_ShouldAssaultCondition_Boomer.Disable();
    mPatch_ShouldAssaultCondition_Smoker.Disable();
    mPatch_ShouldAssaultCondition_Hunter.Disable();
    mPatch_ShouldAssaultCondition_Spitter.Disable();
    mPatch_ShouldAssaultCondition_Jockey.Disable();
    mPatch_ShouldAssaultCondition_Charger.Disable();
    mPatch_ShouldAdvanceOnSurvivors.Disable();

    if (iFlags & SHOULD_ASSAULT_CONDITION_BOOMER)  mPatch_ShouldAssaultCondition_Boomer.Enable();
    if (iFlags & SHOULD_ASSAULT_CONDITION_SMOKER)  mPatch_ShouldAssaultCondition_Smoker.Enable();
    if (iFlags & SHOULD_ASSAULT_CONDITION_HUNTER)  mPatch_ShouldAssaultCondition_Hunter.Enable();
    if (iFlags & SHOULD_ASSAULT_CONDITION_SPITTER) mPatch_ShouldAssaultCondition_Spitter.Enable();
    if (iFlags & SHOULD_ASSAULT_CONDITION_JOCKEY)  mPatch_ShouldAssaultCondition_Jockey.Enable();
    if (iFlags & SHOULD_ASSAULT_CONDITION_CHARGER) mPatch_ShouldAssaultCondition_Charger.Enable();
    if (iFlags & SHOULD_ADVANCE_ON_SURVIVORS)      mPatch_ShouldAdvanceOnSurvivors.Enable();
}