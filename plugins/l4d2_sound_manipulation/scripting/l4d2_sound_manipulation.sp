#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define HEART_BEAT     (1 << 0)
#define HEAVY_HITTABLE (1 << 1)
#define INCAP_SCREAMS  (1 << 2)
#define FIREWORKS      (1 << 3)

ConVar g_cvSoundFlags;
int    g_iSoundFlags;

public Plugin myinfo = {
    name        = "Sound Manipulation: REWORK",
    author      = "Sir",
    description = "Allows control over certain sounds",
    version     = "1.1",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
}

public void OnPluginStart() {
    g_cvSoundFlags = CreateConVar(
    "sound_flags", "0",
    "Prevent Sounds from playing - Bitmask: 0=Nothing | 1=Heartbeat | 2=Heavy Hittable Sounds | 4=Incapacitated Injury | 8=Fireworks",
    FCVAR_NONE, true, 0.0, true, 15.0);
    g_iSoundFlags = g_cvSoundFlags.IntValue;
    g_cvSoundFlags.AddChangeHook(ConVarChanged_SoundFlags);

    // Sound Hook
    AddNormalSoundHook(view_as<NormalSHook>(SoundHook));
    AddAmbientSoundHook(view_as<AmbientSHook>(AmbientHook));
}

void ConVarChanged_SoundFlags(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iSoundFlags = g_cvSoundFlags.IntValue;
}

Action SoundHook(int iClients[MAXPLAYERS], int &iNumClients, char szSample[PLATFORM_MAX_PATH], int &iEntity, int &iChannel, float &fVolume, int &iLevel, int &iPitch, int &iFlags, char szEntry[PLATFORM_MAX_PATH], int &iSeed) {
    // Are we even blocking sounds?
    if (!g_iSoundFlags)
        return Plugin_Continue;

    // Are we blocking Heartbeat sounds?
    if (g_iSoundFlags & HEART_BEAT && strcmp(szSample, "player/heartbeatloop.wav", false) == 0)
        return Plugin_Stop;

    // Are we blocking Heavy Impact sounds on Hittables?
    if (g_iSoundFlags & HEAVY_HITTABLE && StrContains(szSample, "vehicle_impact_heavy") != -1)
        return Plugin_Stop;

    // Are we blocking Incapacitated Injury noises?
    if (g_iSoundFlags & INCAP_SCREAMS && StrContains(szSample, "incapacitatedinjury", false) != -1)
        return Plugin_Stop;

    if (g_iSoundFlags & FIREWORKS && StrContains(szSample, "firewerks", true) != -1)
        return Plugin_Stop;

    // That'll be all.
    return Plugin_Continue;
}

Action AmbientHook(char szSample[PLATFORM_MAX_PATH], int &iEntity, float &fVolume, int &iLevel, int &iPitch, float vPos[3], int &iFlags, float &fDelay) {
    return (g_iSoundFlags & FIREWORKS && StrContains(szSample, "firewerks", true) > -1) ? Plugin_Stop : Plugin_Continue;
}