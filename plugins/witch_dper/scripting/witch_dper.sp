#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <colors>
#include <l4d2_skill_detect>

ConVar g_cvMinDmg;
ConVar g_cvMultiWitch;

public Plugin myinfo = {
    name        = "Witch DPer",
    author      = "CanadaRox",
    description = "Spawns witches for high damage pounces!",
    version     = "1.0",
    url         = ""
};

public void OnPluginStart() {
    g_cvMinDmg = CreateConVar(
    "wdp_minimum_damage", "25.0", "Amount of damage required to spawn an extra witch",
    FCVAR_NONE, true, 1.0, false, 0.0);
    g_cvMultiWitch = CreateConVar(
    "wdp_multiwitch", "9999", "Maximun number of witches to spawn for a single pounce.",
    FCVAR_NONE, true, 1.0, false, 0.0);
}

public void OnHunterHighPounce(int iAttacker, int iVictim, int iActualDamage, float fCalculatedDamage, float fHeight, bool bReportedHigh) {
    if (RoundFloat(fCalculatedDamage) >= g_cvMinDmg.IntValue) {
        int iFlags = GetCommandFlags("z_spawn_old");
        SetCommandFlags("z_spawn_old", iFlags & ~FCVAR_CHEAT);
        int   iCount  = 0;
        float fTmpDmg = fCalculatedDamage;
        for (int i = g_cvMultiWitch.IntValue; i > 0 && fTmpDmg > g_cvMinDmg.IntValue; i--, fTmpDmg -= g_cvMinDmg.IntValue, iCount++) {
            FakeClientCommand(iAttacker, "z_spawn_old witch auto");
        }
        SetCommandFlags("z_spawn_old", iFlags);
        CPrintToChatAll("{green}[{default}!{green}] {red}%N{default} pounced {green}%N{default} for {red}%d{default} damage, spawning {red}%d{default} witch%s!", iAttacker, iVictim, RoundFloat(fCalculatedDamage), iCount, iCount > 1 ? "es" : "");
    }
}