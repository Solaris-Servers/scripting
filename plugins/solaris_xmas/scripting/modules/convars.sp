#if defined __CONVARS__
    #endinput
#endif
#define __CONVARS__

ConVar g_cvXmasVipCount;
ConVar g_cvXmasPlayersNeeded;
ConVar g_cvXmasColoredGift;
ConVar g_cvXmasGiftColor;
ConVar g_cvXmasGiftGlow;
ConVar g_cvGameMode;

void ConVars_OnModuleStart() {
    g_cvXmasVipCount = CreateConVar(
    "xmas_vip_count", "40",
    "The amount needed for VIP",
    FCVAR_NONE, true, 0.0, false, 0.0);

    g_cvXmasPlayersNeeded = CreateConVar(
    "xmas_need_players", "4",
    "Players needed to spawn gifts",
    FCVAR_NONE, true, 0.0, false, 0.0);

    g_cvXmasColoredGift = CreateConVar(
    "xmas_colored_gift", "1",
    "Create aura for gifts",
    FCVAR_NONE, true, 0.0, true, 1.0);

    g_cvXmasGiftColor = CreateConVar(
    "xmas_color_gift", "255 255 255 255",
    "Gift color (R G B A)",
    FCVAR_NONE, false, 0.0, false, 0.0);

    g_cvXmasGiftGlow = CreateConVar(
    "xmas_color_glow", "255 0 0",
    "Gift glow color",
    FCVAR_NONE, false, 0.0, false, 0.0);

    g_cvGameMode = FindConVar("mp_gamemode");
    g_cvGameMode.AddChangeHook(ConVarChanged_GameMode);
}

void ConVars_OnConfigsExecuted() {
    IsPvP(true, SDK_HasPlayerInfected());
}

void ConVarChanged_GameMode(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    IsPvP(true, SDK_HasPlayerInfected());
}