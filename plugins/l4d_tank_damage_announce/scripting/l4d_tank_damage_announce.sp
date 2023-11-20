/*
* Version 0.6.6
* - Better looking Output.
* - Added Tank Name display when Tank dies, normally it only showed the Tank's name if the Tank survived
*
* Version 0.6.6b
* - Fixed Printing Two Tanks when last map Tank survived.
* Added by; Sir

* Version 0.6.7
* - Added Campaign Difficulty Support.
* Added by; Sir

* Version 2.0
* - Full support for multiple tanks.
* - Merged with `l4d2_tank_facts_announce`
* - DONE: Some style settings. (See Version 2.2)
* @Forgetest

* Version 2.1
* - Added support to print names of AI Tank.
* @Forgetest

* Version 2.2
* - Fixed no print when Tank dies to "world". (Thanks to @Alan)
* - Fixed incorrect remaining health if Tank is full healthy. (Thanks to @nikita1824)
* - Fixed death remaining unchanged if Survivor dies to anything else than Tank.
* - Added another 3 text styles (one is disabling extra prints).
* - Added a few natives written by @nikita1824.
* @Forgetest

* Version 2.3
* - Fixed a case where there's no print if an AI as Tank is kicked. (Reported by @Alan)
* - Added a variant to separate lines printing style. (Requested by @Alan)
* - Added a new field "Index" to Tank info to indicate the number of Tank spawned on current map.
* @Forgetest

* Version 2.4
* - Fixed info remaining for kicked AI Tank
* - Fixed info printed if with plugin Tank Swap passing Tank to others
* @Forgetest

* Version 2.5
* - Added compatibility with Tank Swap
* @Forgetest
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>
#include <left4dhooks>
#include <l4d2util>

/**
 * Entity-Relationship: UserVector(Userid, ...)
 */
methodmap UserVector < ArrayList {
    public UserVector(int iBlockSize = 1) {
        return view_as<UserVector>(new ArrayList(iBlockSize + 1, 0)); // extended by 1 cell for userid field
    }

    public any Get(int iIdx, int iType) {
        return GetArrayCell(this, iIdx, iType + 1);
    }

    public void Set(int iIdx, any val, int iType) {
        SetArrayCell(this, iIdx, val, iType + 1);
    }

    public int User(int iIdx) {
        return GetArrayCell(this, iIdx, 0);
    }

    public int Push(any val) {
        int iBlockSize = this.BlockSize;

        any[] array = new any[iBlockSize];
        array[0] = val;
        for (int i = 1; i < iBlockSize; i++) {
            array[i] = 0;
        }

        return this.PushArray(array);
    }

    public bool UserIndex(int iUserId, int &iIdx, bool bCreate = false) {
        if (this == null)
            return false;

        iIdx = this.FindValue(iUserId, 0);
        if (iIdx == -1) {
            if (!bCreate)
                return false;

            iIdx = this.Push(iUserId);
        }

        return true;
    }

    public bool UserReplace(int iUserId, int replacer) {
        int iIdx;
        if (!this.UserIndex(iUserId, iIdx, false))
            return false;

        SetArrayCell(this, iIdx, replacer, 0);
        return true;
    }

    public bool UserGet(int iUserId, int iType, any &val) {
        int iIdx;
        if (!this.UserIndex(iUserId, iIdx, false))
            return false;

        val = this.Get(iIdx, iType);
        return true;
    }

    public bool UserSet(int iUserId, int iType, any val, bool bCreate = false) {
        int iIdx;
        if (!this.UserIndex(iUserId, iIdx, bCreate))
            return false;

        this.Set(iIdx, val, iType);
        return true;
    }

    public bool UserAdd(int iUserId, int iType, any amount, bool bCreate = false) {
        int iIdx;
        if (!this.UserIndex(iUserId, iIdx, bCreate))
            return false;

        int val = this.Get(iIdx, iType);
        this.Set(iIdx, val + amount, iType);
        return true;
    }
}

enum {
    eDmgDone,           // Damage to Tank
    eTeamIdx,           // Team color
    ePunch,             // Punch hits
    eRock,              // Rock hits
    eHittable,          // Hittable hits
    eDamageReceived,    // Damage from Tank
    eDamagerInfoSize
};

enum {
    eIndex,                 // Serial number of Tanks spawned on this map
    eIncap,                 // Total Survivor incaps
    eDeath,                 // Total Survivor death
    eTotalDamage,           // Total damage done to Survivors
    eAliveSince,            // Initial spawn time
    eTankLastHealth,        // Last HP after hit
    eLastControlUserId,     // Last human control
    eTankMaxHealth,         // Max HP
    eDamagerInfoVector,     // UserVector storing info described above
    eTankInfoSize
};

enum {
    Style_Nothing,
    Style_Combined,
    Style_Separate_Reverse,
    Style_Separate,
    Stype_SeparateDelay
}

int  g_iTankIdx;                            // Used to index every Tank
int  g_iTimerDelay;                         // Workaround for announce multiple tanks
int  g_iPlayerLastHealth[MAXPLAYERS + 1];   // Used for Tank damage record
bool g_bIsTankInPlay;                       // Whether or not the tank is active
bool g_bRoundEnd;

UserVector g_aTankInfo;      // Every Tank has a slot here along with relationships.
StringMap  g_smUserNames;    // Simple map from userid to player names.

GlobalForward g_fwdOnTankSpawn;
GlobalForward g_fwdOnTankDeath;

ConVar g_cvDmgAnnounce;
bool   g_bDmgAnnounce;

ConVar g_cvSpawnSound;
char   g_szSound[PLATFORM_MAX_PATH];

public Plugin myinfo = {
    name        = "[L4D2] Tank Announce and Tank Damage Announce",
    author      = "Visor, Forgetest, xoxo, Griffin and Blade, Sir",
    description = "Announce damage dealt to tanks by survivors",
    version     = "2.5.3",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    CreateNative("TFA_Punches",   Native_Punches);
    CreateNative("TFA_Rocks",     Native_Rocks);
    CreateNative("TFA_Hittables", Native_Hittables);
    CreateNative("TFA_TotalDmg",  Native_TotalDamage);
    CreateNative("TFA_UpTime",    Native_UpTime);

    g_fwdOnTankSpawn = new GlobalForward("OnTankSpawn", ET_Ignore);
    g_fwdOnTankDeath = new GlobalForward("OnTankDeath", ET_Ignore);

    RegPluginLibrary("l4d_tank_damage_announce");
    return APLRes_Success;
}

any Native_Punches(Handle hPlugin, int iNumParams) {
    int iClient = GetNativeCell(1);
    if (iClient <= 0)
        ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);

    if (iClient > MaxClients)
        ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);

    int iUserId = GetClientUserId(iClient);
    UserVector uDamagerVector;
    if (!g_aTankInfo.UserGet(iUserId, eDamagerInfoVector, uDamagerVector))
        return 0;

    int iSum = 0, iSize = uDamagerVector.Length;
    for (int i = 0; i < iSize; i++) {
        iSum += uDamagerVector.Get(i, ePunch);
    }

    return iSum;
}

any Native_Rocks(Handle hPlugin, int iNumParams) {
    int iClient = GetNativeCell(1);
    if (iClient <= 0)
        ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);

    if (iClient > MaxClients)
        ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);

    int iUserId = GetClientUserId(iClient);
    UserVector uDamagerVector;
    if (!g_aTankInfo.UserGet(iUserId, eDamagerInfoVector, uDamagerVector))
        return 0;

    int iSum = 0, iSize = uDamagerVector.Length;
    for (int i = 0; i < iSize; i++) {
        iSum += uDamagerVector.Get(i, eRock);
    }

    return iSum;
}

any Native_Hittables(Handle hPlugin, int iNumParams) {
    int iClient = GetNativeCell(1);
    if (iClient <= 0)
        ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);

    if (iClient > MaxClients)
        ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);

    int iUserId = GetClientUserId(iClient);
    UserVector uDamagerVector;
    if (!g_aTankInfo.UserGet(iUserId, eDamagerInfoVector, uDamagerVector))
        return 0;

    int iSum = 0, iSize = uDamagerVector.Length;
    for (int i = 0; i < iSize; i++) {
        iSum += uDamagerVector.Get(i, eHittable);
    }

    return iSum;
}

any Native_TotalDamage(Handle hPlugin, int iNumParams) {
    int iClient = GetNativeCell(1);
    if (iClient <= 0)
        ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);

    if (iClient > MaxClients)
        ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);

    int iUserId = GetClientUserId(iClient);
    int iValue  = 0;
    g_aTankInfo.UserGet(iUserId, eTotalDamage, iValue);
    return iValue;
}

any Native_UpTime(Handle plugin, int numParams) {
    int iClient = GetNativeCell(1);
    if (iClient <= 0)
        ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);

    if (iClient > MaxClients)
        ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);

    int   iUserId = GetClientUserId(iClient);
    float fValue  = -1.0;
    if (g_aTankInfo.UserGet(iUserId, eAliveSince, fValue))
        fValue = GetGameTime() - fValue;

    return RoundToFloor(fValue);
}

public void OnPluginStart() {
    HookEvent("round_start",          Event_RoundStart);
    HookEvent("round_end",            Event_RoundEnd);
    HookEvent("player_bot_replace",   Event_PlayerBotReplace);
    HookEvent("bot_player_replace",   Event_BotPlayerReplace);
    HookEvent("player_hurt",          Event_PlayerHurt);
    HookEvent("player_incapacitated", Event_PlayerIncap);
    HookEvent("player_death",         Event_PlayerKilled);

    g_aTankInfo   = new UserVector(eTankInfoSize);
    g_smUserNames = new StringMap();

    g_cvDmgAnnounce = CreateConVar(
    "l4d2_tank_damage_announce", "1",
    "Announce damage done to tanks",
    FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_bDmgAnnounce = g_cvDmgAnnounce.BoolValue;
    g_cvDmgAnnounce.AddChangeHook(CvChg_DmgAnnounce);

    g_cvSpawnSound = CreateConVar(
    "l4d2_tank_announce_sound", "ui/pickup_secret01.wav",
    "Sound emitted every tank spawn .",
    FCVAR_SPONLY|FCVAR_NOTIFY, false, 0.0, false, 0.0);
    g_cvSpawnSound.GetString(g_szSound, sizeof(g_szSound));
    g_cvSpawnSound.AddChangeHook(CvChg_SpawnSound);

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        OnClientPutInServer(i);
    }
}

void CvChg_DmgAnnounce(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bDmgAnnounce = g_cvDmgAnnounce.BoolValue;
}

void CvChg_SpawnSound(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_cvSpawnSound.GetString(g_szSound, sizeof(g_szSound));
}

public void OnMapStart() {
    PrecacheSound(g_szSound);
}

public void OnClientPutInServer(int iClient) {
    SDKHook(iClient, SDKHook_OnTakeDamagePost, SDK_OnTakeDamagePost);
}

public void OnClientDisconnect(int iClient) {
    int iUserId = GetClientUserId(iClient);

    char szKey[16];
    IntToString(iUserId, szKey, sizeof(szKey));

    char szName[MAX_NAME_LENGTH];
    GetClientName(iClient, szName, sizeof(szName));
    g_smUserNames.SetString(szKey, szName);

    if (!IsFakeClient(iClient))
        return;

    Timer_CheckTank(null, GetClientUserId(iClient));
}

void SDK_OnTakeDamagePost(int iVictim, int iAttacker, int iInflictor, float fDamage, int iDamageType) {
    if (!g_bIsTankInPlay)
        return;

    if (!IsValidEntity(iVictim))
        return;

    if (!IsValidEntity(iAttacker))
        return;

    if (!IsValidEdict(iInflictor))
        return;

    if (iAttacker <= 0)
        return;

    if (iAttacker > MaxClients)
        return;

    if (GetClientTeam(iVictim) != L4D2Team_Survivor)
        return;

    if (!IsTank(iAttacker))
        return;

    /* Store HP only when the damage is greater than this, so we can turn to IncapStart for Damage record */
    int iPlayerHealth = GetClientHealth(iVictim) + RoundToCeil(L4D_GetTempHealth(iVictim));
    g_iPlayerLastHealth[iVictim] = iPlayerHealth;
}

/**
 * Events
 */
public void L4D_OnSpawnTank_Post(int iClient, const float vPos[3], const float vAng[3]) {
    if (iClient <= 0)
        return;

    int iUserId = GetClientUserId(iClient);
    g_iTankIdx++;

    // Multiple tanks?
    g_iTimerDelay++;
    float fDelay = 0.1 * g_iTimerDelay;

    // New tank, damage has not been announced
    DataPack dp;
    CreateDataTimer(fDelay, Timer_Announce, dp, TIMER_FLAG_NO_MAPCHANGE);
    dp.WriteCell(iUserId);
    dp.WriteCell(g_iTankIdx);

    g_bIsTankInPlay = true;
    g_aTankInfo.UserSet(iUserId, eDamagerInfoVector, new UserVector(eDamagerInfoSize), true);
    g_aTankInfo.UserSet(iUserId, eAliveSince,     GetGameTime());
    g_aTankInfo.UserSet(iUserId, eTankLastHealth, GetEntProp(iClient, Prop_Send, "m_iHealth", 4, 0));
    g_aTankInfo.UserSet(iUserId, eTankMaxHealth,  GetEntProp(iClient, Prop_Send, "m_iHealth", 4, 0));
    g_aTankInfo.UserSet(iUserId, eIndex,          g_iTankIdx);
}

Action Timer_Announce(Handle hTimer, DataPack dp) {
    if (g_iTimerDelay > 0)
        g_iTimerDelay--;

    dp.Reset();
    int iUserId  = dp.ReadCell();
    int iTankIdx = dp.ReadCell();

    int iClient = GetClientOfUserId(iUserId);
    if (iClient <= 0)
        return Plugin_Stop;

    if (!IsClientInGame(iClient))
        return Plugin_Stop;

    char szIdx[8];
    if (g_iTankIdx > 1) {
        if      (iTankIdx == 1) FormatEx(szIdx, sizeof(szIdx), "%dst ", iTankIdx);
        else if (iTankIdx == 2) FormatEx(szIdx, sizeof(szIdx), "%dnd ", iTankIdx);
        else if (iTankIdx == 3) FormatEx(szIdx, sizeof(szIdx), "%drd ", iTankIdx);
        else                    FormatEx(szIdx, sizeof(szIdx), "%dth ", iTankIdx);
    }

    EmitSoundToAll(g_szSound);

    if (IsFakeClient(iClient)) {
        iClient = GetEntProp(L4D_GetResourceEntity(), Prop_Send, "m_pendingTankPlayerIndex");
        if (iClient && IsClientInGame(iClient)) {
            CPrintToChatAll("{green}[{default}!{green}]{default} The {olive}%sTank{default} ({green}%N{default}) is up!", szIdx, iClient);
            Call_StartForward(g_fwdOnTankSpawn);
            Call_Finish();
            return Plugin_Stop;
        }
    }

    CPrintToChatAll("{green}[{default}!{green}]{default} The {olive}%sTank{default} is up!", szIdx);
    Call_StartForward(g_fwdOnTankSpawn);
    Call_Finish();
    return Plugin_Stop;
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    g_bRoundEnd = false;
    g_iTankIdx = 0;
    g_iTimerDelay = 0;
    g_smUserNames.Clear();
    ClearTankInfo();
}

// When survivors wipe or juke tank, announce damage
void Event_RoundEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    // But only if a tank that hasn't been killed exists
    if (!g_bRoundEnd)
        PrintTankInfo();

    g_bRoundEnd = true;
}

void Event_PlayerBotReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    HandlePlayerReplace(eEvent.GetInt("bot"), eEvent.GetInt("player"));
}

void Event_BotPlayerReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    HandlePlayerReplace(eEvent.GetInt("player"), eEvent.GetInt("bot"));
}

// Tank passing between players
public void L4D_OnReplaceTank(int iOldTank, int iNewTank) {
    if (iOldTank <= 0)
        return;

    if (iNewTank <= 0)
        return;

    if (iOldTank == iNewTank)
        return;

    // A pre-hook here so make sure the replace actually happens via a delayed check.
    DataPack dp = new DataPack();
    dp.WriteCell(GetClientUserId(iOldTank));
    dp.WriteCell(GetClientUserId(iNewTank));
    RequestFrame(OnFrame_HandlePlayerReplace, dp);
}

void OnFrame_HandlePlayerReplace(DataPack dp) {
    int iOldTank, iNewTank;

    dp.Reset();
    iOldTank = dp.ReadCell();
    iNewTank = dp.ReadCell();
    delete dp;

    HandlePlayerReplace(iNewTank, iOldTank);
}

void HandlePlayerReplace(int iReplacer, int iReplacee) {
    int iClient = GetClientOfUserId(iReplacer);
    if (iClient <= 0)
        return;

    if (!IsClientInGame(iClient))
        return;

    if (!IsTank(iClient))
        return;

    g_aTankInfo.UserReplace(iReplacee, iReplacer);
    iClient = GetClientOfUserId(iReplacee);
    if (iClient <= 0 || !IsClientInGame(iClient) || !IsFakeClient(iClient))
        g_aTankInfo.UserSet(iReplacer, eLastControlUserId, iReplacee);
}

void Event_PlayerHurt(Event eEvent, const char[] szName, bool bDontBroadcast) {
    // No tank in play; no damage to record
    if (!g_bIsTankInPlay)
        return;

    int iVictimId = eEvent.GetInt("userid");
    int iVictim   = GetClientOfUserId(iVictimId);
    if (iVictim <= 0)
        return;

    if (!IsClientInGame(iVictim))
        return;

    // Victim isn't tank; no damage to record
    if (IsTank(iVictim)) {
        // Something buggy happens when tank is dying with regards to damage
        if (IsIncapacitated(iVictim))
            return;

        int iAttackerId = eEvent.GetInt("attacker");
        int iAttacker   = GetClientOfUserId(iAttackerId);

        // We only care about damage dealt by survivors and world, though it can be funny to see
        // claw/self inflicted hittable damage, so maybe in the future we'll do that
        if (iAttacker == 0)
            iAttackerId = 0;

        int iTeam = L4D2Team_None;
        if (iAttacker > 0 && IsClientInGame(iAttacker))
            iTeam = GetClientTeam(iAttacker);

        g_aTankInfo.UserSet(iVictimId, eTankLastHealth, eEvent.GetInt("health"));
        UserVector uDamagerVector;
        g_aTankInfo.UserGet(iVictimId, eDamagerInfoVector, uDamagerVector);
        uDamagerVector.UserAdd(iAttackerId, eDmgDone, eEvent.GetInt("dmg_health"), true);
        uDamagerVector.UserSet(iAttackerId, eTeamIdx, iTeam, true);
    } else if (GetClientTeam(iVictim) == L4D2Team_Survivor) {
        if (IsIncapacitated(iVictim))
            return;

        int iAttackerId = eEvent.GetInt("attacker");
        int iAttacker   = GetClientOfUserId(iAttackerId);
        // We only care about damage dealt by survivors, though it can be funny to see
        // claw/self inflicted hittable damage, so maybe in the future we'll do that
        if (iAttacker <= 0)
            return;

        if (!IsClientInGame(iAttacker))
            return;

        if (!IsTank(iAttacker))
            return;

        char szWeapon[64];
        eEvent.GetString("weapon", szWeapon, sizeof(szWeapon));

        UserVector uDamagerVector;
        g_aTankInfo.UserGet(iAttackerId, eDamagerInfoVector, uDamagerVector);

        int iDmg = eEvent.GetInt("dmg_health");
        if (iDmg > 0) {
            if      (strcmp(szWeapon, "tank_claw") == 0) uDamagerVector.UserAdd(iVictimId, ePunch,    1, true);
            else if (strcmp(szWeapon, "tank_rock") == 0) uDamagerVector.UserAdd(iVictimId, eRock,     1, true);
            else                                         uDamagerVector.UserAdd(iVictimId, eHittable, 1, true);
            uDamagerVector.UserAdd(iVictimId, eDamageReceived, iDmg);
            g_aTankInfo.UserAdd(iAttackerId, eTotalDamage, iDmg);
        }
    }
}

void Event_PlayerIncap(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!g_bIsTankInPlay)
        return;

    int iVictimId = eEvent.GetInt("userid");
    int iVictim = GetClientOfUserId(iVictimId);
    if (iVictim <= 0)
        return;

    if (!IsClientInGame(iVictim))
        return;

    if (GetClientTeam(iVictim) == L4D2Team_Survivor) {
        int iAttackerId = eEvent.GetInt("attacker");
        int iAttacker = GetClientOfUserId(iAttackerId);
        if (iAttacker <= 0)
            return;

        if (!IsClientInGame(iAttacker))
            return;

        if (!IsTank(iAttacker))
            return;

        UserVector uDamagerVector;
        g_aTankInfo.UserGet(iAttackerId, eDamagerInfoVector, uDamagerVector);

        char szWeapon[64];
        eEvent.GetString("weapon", szWeapon, sizeof(szWeapon));

        if      (strcmp(szWeapon, "tank_claw") == 0) uDamagerVector.UserAdd(iVictimId, ePunch,    1, true);
        else if (strcmp(szWeapon, "tank_rock") == 0) uDamagerVector.UserAdd(iVictimId, eRock,     1, true);
        else                                         uDamagerVector.UserAdd(iVictimId, eHittable, 1, true);

        uDamagerVector.UserAdd(iVictimId, eDamageReceived, g_iPlayerLastHealth[iVictim]);
        g_aTankInfo.UserAdd(iAttackerId, eIncap, 1);
        g_aTankInfo.UserAdd(iAttackerId, eTotalDamage, g_iPlayerLastHealth[iVictim]);
    }
}

void Event_PlayerKilled(Event eEvent, const char[] szName, bool bDontBroadcast) {
    // No tank in play; no damage to record
    if (!g_bIsTankInPlay)
        return;

    // A Tank replace is happening
    if (eEvent.GetBool("abort"))
        return;

    int iVictimId = eEvent.GetInt("userid");
    int iVictim   = GetClientOfUserId(iVictimId);
    if (iVictim <= 0)
        return;

    if (!IsClientInGame(iVictim))
        return;

    int iAttackerId = eEvent.GetInt("attacker");
    // Victim isn't tank; no damage to record
    if (IsTank(iVictim)) {
        // Damage announce could probably happen right here...
        // Use a delayed timer due to bugs where the tank passes to another player
        CreateTimer(0.1, Timer_CheckTank, iVictimId, TIMER_FLAG_NO_MAPCHANGE);
        // Award the killing blow's damage to the attacker; we don't award
        // damage from player_hurt after the tank has died/is dying
        // If we don't do it this way, we get wonky/inaccurate damage values
        int iAttacker = GetClientOfUserId(iAttackerId);
        if (iAttacker <= 0)
            return;

        if (!IsClientInGame(iAttacker))
            return;

        if (GetClientTeam(iAttacker) == L4D2Team_Survivor) {
            int iTankLastHealth;
            g_aTankInfo.UserGet(iVictimId, eTankLastHealth, iTankLastHealth);

            UserVector uDamagerVector;
            g_aTankInfo.UserGet(iVictimId, eDamagerInfoVector, uDamagerVector);
            uDamagerVector.UserAdd(iAttackerId, eDmgDone, iTankLastHealth, true);
        }
    } else if (GetClientTeam(iVictim) == L4D2Team_Survivor) {
        g_aTankInfo.UserAdd(iAttackerId, eDeath, 1);
    }
}

Action Timer_CheckTank(Handle hTimer, int iUserId) {
    int iTmp;
    // straight searching for the index, if success it indicates no replace has happened
    // so the user is the final control of the Tank
    if (g_aTankInfo.UserIndex(iUserId, iTmp, false)) {
        PrintTankInfo(iUserId);
        ClearTankInfo(iUserId);
        Call_StartForward(g_fwdOnTankDeath);
        Call_Finish();
    }

    return Plugin_Stop;
}

bool FindTankControlName(int iUserId, char[] szName, int iMaxLen) {
    int iClient = GetClientOfUserId(iUserId);
    if (!IsFakeClient(iClient))
        return GetClientName(iClient, szName, iMaxLen);

    int iLastControlUserid;
    if (g_aTankInfo.UserGet(iUserId, eLastControlUserId, iLastControlUserid) && iLastControlUserid)
        return GetClientNameFromUserId(iLastControlUserid, szName, iMaxLen);

    GetClientName(iClient, szName, iMaxLen);
    return false;
}

void PrintTankInfo(int iParamUserId = 0) {
    if (!g_bDmgAnnounce)
        return;

    static const char szTeamColor[][] = {
        "{olive}",
        "{olive}",
        "{blue}",
        "{red}",
        "{blue}"
    };

    int iLength = g_aTankInfo.Length;
    if (!iLength)
        return;

    int iIdx = 0;
    if (iParamUserId > 0 && !g_aTankInfo.UserIndex(iParamUserId, iIdx, false))
        return;

    for (; iIdx < iLength; iIdx++) {
        int iUserId = g_aTankInfo.User(iIdx);
        int iClient = GetClientOfUserId(iUserId);

        if (iClient <= 0)
            continue;

        char szTankName[MAX_NAME_LENGTH];
        bool bHumanControlled = FindTankControlName(iUserId, szTankName, sizeof(szTankName));
        int  iLastHealth      = g_aTankInfo.Get(iIdx, eTankLastHealth);
        int  iMaxHealth       = g_aTankInfo.Get(iIdx, eTankMaxHealth);
        int  iTankIdx         = g_aTankInfo.Get(iIdx, eIndex);

        UserVector uDamagerVector = g_aTankInfo.Get(iIdx, eDamagerInfoVector);
        uDamagerVector.SortCustom(SortAdtDamageDesc);

        int iDmgTtl = 0, iPctTtl = 0, iSize = uDamagerVector.Length;
        for (int i = 0; i < iSize; i++) {
            iDmgTtl += uDamagerVector.Get(i, eDmgDone);
            iPctTtl += GetDamageAsPercent(iIdx, uDamagerVector.Get(i, eDmgDone));
        }

        PrintTitle(iUserId, szTankName, iLastHealth, IsFakeClient(iClient), IsPlayerAlive(iClient), bHumanControlled, iTankIdx);

        char szName[MAX_NAME_LENGTH];
        int  iDmg, iPct, iTeamIdx;

        int iPctAdjustment;
        if ((iPctTtl < 100 && float(iDmgTtl) > (iMaxHealth - (iMaxHealth / 200))))
            iPctAdjustment = 100 - iPctTtl;

        int iLastPct = 100;
        int iAdjustedPctDmg;
        for (int i = 0; i < iSize; i++) {
            // generally needed
            GetClientNameFromUserId(uDamagerVector.User(i), szName, sizeof(szName));

            // basic tank damage announce
            iTeamIdx = uDamagerVector.Get(i, eTeamIdx);
            iDmg     = uDamagerVector.Get(i, eDmgDone);
            iPct     = GetDamageAsPercent(iIdx, iDmg);

            if (iPctAdjustment != 0 && iDmg > 0 && !IsExactPercent(iIdx, iDmg)) {
                iAdjustedPctDmg = iPct + iPctAdjustment;

                if (iAdjustedPctDmg <= iLastPct) {
                    iPct = iAdjustedPctDmg;
                    iPctAdjustment = 0;
                }
            }

            // ignore cases printing zeros only
            if (iDmg > 0) {
                char szDmgSpace[16];
                FormatEx(szDmgSpace, sizeof(szDmgSpace), "%s",
                iDmg < 10 ? "      " : iDmg < 100 ? "    " : iDmg < 1000 ? "  " : "");

                char szPrcntSpace[16];
                FormatEx(szPrcntSpace, sizeof(szPrcntSpace), "%s",
                iPct < 10 ? "  " : iPct < 100 ? " " : "");

                CPrintToChatAll("{olive}%s%d {green}|%s{default}%d%%{green}%s|{default}: %s%s", szDmgSpace, iDmg, szPrcntSpace, iPct, szPrcntSpace, szTeamColor[iTeamIdx], szName);
            }
        }

        if (iParamUserId > 0)
            break;
    }
}

void PrintTitle(int iUserId, const char[] szName, int iLastHealth, bool bAI, bool bAlive, bool bHumanControlled, int iIdx) {
    char szIdx[8];
    if (g_iTankIdx > 1) {
        if      (iIdx == 1) FormatEx(szIdx, sizeof(szIdx), "%dst ", iIdx);
        else if (iIdx == 2) FormatEx(szIdx, sizeof(szIdx), "%dnd ", iIdx);
        else if (iIdx == 3) FormatEx(szIdx, sizeof(szIdx), "%drd ", iIdx);
        else                FormatEx(szIdx, sizeof(szIdx), "%dth ", iIdx);
    }

    if (bAlive) {
        if (bAI) {
            if (bHumanControlled) CPrintToChatAll("{green}[{default}!{green}]{default} The {olive}%sTank{default} ({green}AI [%s]{default}) had {olive}%d{default} health remaining.", szIdx, szName, iLastHealth);
            else                  CPrintToChatAll("{green}[{default}!{green}]{default} The {olive}%sTank{default} ({green}AI{default}) had {olive}%d{default} health remaining.", szIdx, iLastHealth);
        } else {
            CPrintToChatAll("{green}[{default}!{green}]{default} The {olive}%sTank{default} ({green}%s{default}) had {olive}%d{default} health remaining.", szIdx, szName, iLastHealth);
        }
    } else {
        if (bAI) {
            if (bHumanControlled) CPrintToChatAll("{green}[{default}!{green}]{default} The {olive}%sTank{default} ({green}AI [%s]{default}) is dead!", szIdx, szName);
            else                  CPrintToChatAll("{green}[{default}!{green}]{default} The {olive}%sTank{default} ({green}AI{default}) is dead!", szIdx);
        } else {
            CPrintToChatAll("{green}[{default}!{green}]{default} The {olive}%sTank{default} ({green}%s{default}) is dead!", szIdx, szName);
        }
    }

    UserVector uDamagerVector;
    if (!g_aTankInfo.UserGet(iUserId, eDamagerInfoVector, uDamagerVector))
        return;

    int iDmgTtl = 0, iSize = uDamagerVector.Length;
    for (int i = 0; i < iSize; i++) {
        iDmgTtl += uDamagerVector.Get(i, eDmgDone);
    }

    if (iDmgTtl > 0) CPrintToChatAll("{green}[{default}!{green}] {olive}Damage{default} dealt to the {olive}Tank{default}:");
}

void ClearTankInfo(int iUserId = 0) {
    int iIdx = 0;
    if (iUserId > 0 && !g_aTankInfo.UserIndex(iUserId, iIdx, false))
        return;

    while (g_aTankInfo.Length) {
        UserVector uDamagerVector = g_aTankInfo.Get(iIdx, eDamagerInfoVector);
        delete uDamagerVector;
        g_aTankInfo.Erase(iIdx);
        if (iUserId > 0)
            break;
    }

    // TODO: Move this to somewhere else? not quite satisfying
    g_bIsTankInPlay = g_aTankInfo.Length > 0;
}

// utilize our map g_smUserNames
bool GetClientNameFromUserId(int iUserId, char[] szName, int iMaxLen) {
    if (iUserId == 0) {
        FormatEx(szName, iMaxLen, "World");
        return true;
    }

    int iClient = GetClientOfUserId(iUserId);
    if (iClient && IsClientInGame(iClient))
        return GetClientName(iClient, szName, iMaxLen);

    char szKey[16];
    IntToString(iUserId, szKey, sizeof(szKey));
    return g_smUserNames.GetString(szKey, szName, iMaxLen);
}

int SortAdtDamageDesc(int iIdx1, int iIdx2, Handle hArray, Handle hHndl) {
    UserVector uDamagerVector = view_as<UserVector>(hArray);
    int iDmg1 = uDamagerVector.Get(iIdx1, eDmgDone);
    int iDmg2 = uDamagerVector.Get(iIdx2, eDmgDone);
    if      (iDmg1 > iDmg2) return -1;
    else if (iDmg1 < iDmg2) return  1;
    return 0;
}

int GetDamageAsPercent(int iIdx, int iDmg) {
    int iMaxHealth = g_aTankInfo.Get(iIdx, eTankMaxHealth);
    return RoundToFloor(((float(iDmg) / iMaxHealth) * 100.0));
}

bool IsExactPercent(int iIdx, int iDmg) {
    int iMaxHealth = g_aTankInfo.Get(iIdx, eTankMaxHealth);
    return (FloatAbs(float(GetDamageAsPercent(iIdx, iDmg)) - ((float(iDmg) / iMaxHealth) * 100.0)) < 0.001) ? true : false;
}