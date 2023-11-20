#if defined __ConVars__
    #endinput
#endif
#define __ConVars__

void InitConVars() {
    g_cvEnabled = CreateConVar(
    "l4d2_MITSR_Enabled", "1",
    "Should the plugin be enabled",
    FCVAR_NONE, true, 0.0, true, 1.0);

    g_cvWeaponRandom = CreateConVar(
    "l4d2_MITSR_Random", "1",
    "Spawn Random Weapons (1) or custom list (0)",
    FCVAR_NONE, true, 0.0, true, 1.0);

    g_cvWeaponRandomAmount = CreateConVar(
    "l4d2_MITSR_Amount", "4",
    "Number of weapons to spawn if l4d2_MITSR_Random is 1",
    FCVAR_NONE, true, 0.0, true, 10.0);

    for (int i = 0; i < eWeaponMeleeSize; i++) {
        static char szConVar[32];
        FormatEx(szConVar, sizeof(szConVar), "l4d2_MITSR_%s", g_szMeleeWeapon[i][0]);

        static char szDescription[256];
        FormatEx(szDescription, sizeof(szDescription), "Number of %s to spawn (l4d2_MITSR_Random must be 0)", g_szMeleeWeapon[i][1]);

        g_cvWeaponMelee[i] = CreateConVar(
        szConVar, "1", szDescription,
        FCVAR_NONE, true, 0.0, true, 10.0);
    }
}