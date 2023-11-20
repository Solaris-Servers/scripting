#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sourcescramble>

#define POUNCE_INTERRUPT   (1 << 0)
#define CONVERT_LEAP       (1 << 1)
#define CROUCH_POUNCE      (1 << 2)
#define BONUS_DAMAGE       (1 << 3)
#define DEBUFF_CHARGING_AI (1 << 4)

MemoryPatch g_mPatch_PounceInterrupt;
MemoryPatch g_mPatch_ConvertLeap;
MemoryPatch g_mPatch_CrouchPounce;
MemoryPatch g_mPatch_BonusDamage;
MemoryPatch g_mPatch_DebuffCharging;

ConVar g_cvFlags;
int    g_iFlags;

public Plugin myinfo = {
    name        = "Bot SI skeet/level damage fix",
    author      = "Tabun, dcx2, fdxx, umlka",
    description = "Makes AI SI take (and do) damage like human SI.",
    version     = "3.0.0",
    url         = "https://github.com/Tabbernaut/L4D2-Plugins/tree/master/ai_damagefix"
}

void InitGameData() {
    GameData gmConf = new GameData("l4d2_ai_damagefix");
    if (gmConf == null) SetFailState("Failed to load \"l4d2_ai_damagefix.txt\" gamedata.");

    g_mPatch_PounceInterrupt = MemoryPatch.CreateFromConf(gmConf, "pounce_interrupt");
    if (!g_mPatch_PounceInterrupt.Validate()) SetFailState("Verify patch: pounce_interrupt failed.");

    g_mPatch_ConvertLeap = MemoryPatch.CreateFromConf(gmConf, "convert_leap");
    if (!g_mPatch_ConvertLeap.Validate()) SetFailState("Verify patch: convert_leap failed.");

    g_mPatch_CrouchPounce = MemoryPatch.CreateFromConf(gmConf, "crouch_pounce");
    if (!g_mPatch_CrouchPounce.Validate()) SetFailState("Verify patch: crouch_pounce failed.");

    g_mPatch_BonusDamage = MemoryPatch.CreateFromConf(gmConf, "bonus_damage");
    if (!g_mPatch_BonusDamage.Validate()) SetFailState("Verify patch: bonus_damage failed.");

    g_mPatch_DebuffCharging = MemoryPatch.CreateFromConf(gmConf, "debuff_charging_ai");
    if (!g_mPatch_DebuffCharging.Validate()) SetFailState("Verify patch: debuff_charging_ai failed.");

    delete gmConf;
}

public void OnPluginStart() {
    InitGameData();

    g_cvFlags = CreateConVar(
    "sm_aidmgfix_enable", "31",
    "Bit flag: Enables plugin features (add together): 1 = Skeet pouncing AI, 2 = Convert leap to pounce, 4 = Need press crouch button to pounce, 8 = Bonus pounce damage, 16 = Debuff charging AI, 0 = off",
    FCVAR_NONE, true, 0.0, true, 31.0);
    g_iFlags = g_cvFlags.IntValue;
    g_cvFlags.AddChangeHook(ConVarChanged_Flags);

    if (g_iFlags & POUNCE_INTERRUPT)   g_mPatch_PounceInterrupt.Enable();
    if (g_iFlags & CONVERT_LEAP)       g_mPatch_ConvertLeap.Enable();
    if (g_iFlags & CROUCH_POUNCE)      g_mPatch_CrouchPounce.Enable();
    if (g_iFlags & BONUS_DAMAGE)       g_mPatch_BonusDamage.Enable();
    if (g_iFlags & DEBUFF_CHARGING_AI) g_mPatch_DebuffCharging.Enable();

    HookEvent("lunge_pounce", Event_LungePounce);
}

void ConVarChanged_Flags(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iFlags = g_cvFlags.IntValue;

    g_mPatch_PounceInterrupt.Disable();
    g_mPatch_ConvertLeap.Disable();
    g_mPatch_CrouchPounce.Disable();
    g_mPatch_BonusDamage.Disable();
    g_mPatch_DebuffCharging.Disable();

    if (g_iFlags & POUNCE_INTERRUPT)   g_mPatch_PounceInterrupt.Enable();
    if (g_iFlags & CONVERT_LEAP)       g_mPatch_ConvertLeap.Enable();
    if (g_iFlags & CROUCH_POUNCE)      g_mPatch_CrouchPounce.Enable();
    if (g_iFlags & BONUS_DAMAGE)       g_mPatch_BonusDamage.Enable();
    if (g_iFlags & DEBUFF_CHARGING_AI) g_mPatch_DebuffCharging.Enable();
}

void Event_LungePounce(Event eEvent, const char[] szName, bool bDontBroadcast) {
    // Fixed crash in CTerrorPlayer::OnPouncedOnSurvivor function when the server is empty.
    // HookEvent so that the function always returns a valid event pointer when CreateEvent.
    // If there are other plugins already hooked 'lunge_pounce' event, it can also prevent crashes.
    /*
    IGameEvent *event = gameeventmanager->CreateEvent( "lunge_pounce" );
    if ( event )
    {
        ...
    }
    if ( CTerrorGameRules::HasPlayerControlledZombies() )
    {
        ...
        event->SetInt("damage", dmg ); // NULL pointer crash
    }
    */
}