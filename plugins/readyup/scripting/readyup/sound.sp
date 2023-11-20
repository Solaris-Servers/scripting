#if defined _readyup_sound_included
    #endinput
#endif
#define _readyup_sound_included

#define SECRET_SOUND            "level/gnomeftw.wav"
#define DEFAULT_NOTIFY_SOUND    "buttons/button14.wav"
#define DEFAULT_COUNTDOWN_SOUND "weapons/hegrenade/beep.wav"
#define DEFAULT_LIVE_SOUND      "ui/survival_medal.wav"

#define MAX_CHUCKLE_SOUNDS 5

static const char szChuckleSound[MAX_CHUCKLE_SOUNDS][] = {
    "/npc/moustachio/strengthattract01.wav",
    "/npc/moustachio/strengthattract02.wav",
    "/npc/moustachio/strengthattract05.wav",
    "/npc/moustachio/strengthattract06.wav",
    "/npc/moustachio/strengthattract09.wav"
};

static char szNotifySound[PLATFORM_MAX_PATH];
static char szCountdownSound[PLATFORM_MAX_PATH];
static char szLiveSound[PLATFORM_MAX_PATH];

void PrecacheSounds() {
    char szPath[PLATFORM_MAX_PATH];

    g_cvReadyNotifySound.GetString(szNotifySound, sizeof(szNotifySound));
    g_cvReadyCountdownSound.GetString(szCountdownSound, sizeof(szCountdownSound));
    g_cvReadyLiveSound.GetString(szLiveSound, sizeof(szLiveSound));

    FormatEx(szPath, sizeof(szPath), "sound/%s", szNotifySound);
    if (!FileExists(szPath, true)) strcopy(szNotifySound, sizeof(szNotifySound), DEFAULT_NOTIFY_SOUND);
    FormatEx(szPath, sizeof(szPath), "sound/%s", szCountdownSound);
    if (!FileExists(szPath, true)) strcopy(szCountdownSound, sizeof(szCountdownSound), DEFAULT_COUNTDOWN_SOUND);
    FormatEx(szPath, sizeof(szPath), "sound/%s", szLiveSound);
    if (!FileExists(szPath, true)) strcopy(szLiveSound, sizeof(szLiveSound), DEFAULT_LIVE_SOUND);
    
    PrecacheSound(SECRET_SOUND);
    PrecacheSound(szNotifySound);
    PrecacheSound(szCountdownSound);
    PrecacheSound(szLiveSound);
    
    for (int i = 0; i < MAX_CHUCKLE_SOUNDS; i++) {
        PrecacheSound(szChuckleSound[i]);
    }
}

void PlayLiveSound() {
    if (g_cvReadyEnableSound.BoolValue) {
        if (g_cvReadyChuckle.BoolValue) {
            EmitSoundToAll(szChuckleSound[GetRandomInt(0, MAX_CHUCKLE_SOUNDS - 1)], .volume = 0.5);
        } else {
            EmitSoundToAll(szLiveSound, .volume = 0.5);
        }
    }
}

void PlayCountdownSound() {
    if (!g_cvReadyEnableSound.BoolValue)
        return;
    
    EmitSoundToAll(szCountdownSound, .volume = 0.5);
}

void PlayNotifySound(int iClient) {
    if (!g_cvReadyEnableSound.BoolValue)
        return;
    
    EmitSoundToClient(iClient, szNotifySound);
}

// ========================
// BoneSaw
// ========================
static Handle hBlockSecretSpam[MAXPLAYERS + 1];

void DoSecrets(int iClient) {
    if (GetClientTeam(iClient) == L4D2Team_Survivor && !hBlockSecretSpam[iClient]) {
        int iParticle = CreateEntityByName("info_particle_system");
        if (iParticle == -1)
            return;
        
        float vPos[3];
        GetClientAbsOrigin(iClient, vPos);
        vPos[2] += 80;
        TeleportEntity(iParticle, vPos, NULL_VECTOR, NULL_VECTOR);
        DispatchKeyValue(iParticle, "effect_name", "achieved");
        DispatchKeyValue(iParticle, "targetname", "particle");
        DispatchSpawn(iParticle);
        ActivateEntity(iParticle);
        AcceptEntityInput(iParticle, "start");
        CreateTimer(5.0, Timer_KillParticle, EntIndexToEntRef(iParticle), TIMER_FLAG_NO_MAPCHANGE);
        EmitSoundToAll(SECRET_SOUND, iClient, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
        CreateTimer(2.5, Timer_KillSound);
        hBlockSecretSpam[iClient] = CreateTimer(5.0, Timer_SecretSpamDelay, iClient);
    }
    
    PrintCenterTextAll("\x42\x4f\x4e\x45\x53\x41\x57\x20\x49\x53\x20\x52\x45\x41\x44\x59\x21");
}

Action Timer_SecretSpamDelay(Handle hTimer, int iClient) {
    hBlockSecretSpam[iClient] = null;
    return Plugin_Stop;
}

Action Timer_KillParticle(Handle hTimer, int iEntRef) {
    int iEntity = EntRefToEntIndex(iEntRef);
    if (iEntity <= 0)
        return Plugin_Stop;
    
    if (!IsValidEdict(iEntity))
        return Plugin_Stop;
    
    RemoveEntity(iEntity);
    return Plugin_Stop;
}

Action Timer_KillSound(Handle hTimer) {
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;
        
        if (IsFakeClient(i))
            continue;
        
        StopSound(i, SNDCHAN_AUTO, SECRET_SOUND);
    }
    
    return Plugin_Stop;
}