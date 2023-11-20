#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <colors>
#include <l4d2util>

#define MAX_ENTITY_NAME 64
#define DMG_BURN (1 << 3) /**< heat burned */ /*sdkhooks*/

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

    public int Ent(int iIdx) {
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

    public bool EntIndex(int iEnt, int &iIdx, bool bCreate = false) {
        if (this == null)
            return false;

        iIdx = this.FindValue(iEnt, 0);
        if (iIdx == -1) {
            if (!bCreate)
                return false;

            iIdx = this.Push(iEnt);
        }

        return true;
    }

    public bool EntGet(int iEnt, int iType, any &val) {
        int iIdx;
        if (!this.EntIndex(iEnt, iIdx, false))
            return false;

        val = this.Get(iIdx, iType);
        return true;
    }

    public bool EntSet(int iEnt, int iType, any val, bool bCreate = false) {
        int iIdx;
        if (!this.EntIndex(iEnt, iIdx, bCreate))
            return false;

        this.Set(iIdx, val, iType);
        return true;
    }

    public bool EntAdd(int iUserId, int iType, any amount, bool bCreate = false) {
        int iIdx;
        if (!this.EntIndex(iUserId, iIdx, bCreate))
            return false;

        int val = this.Get(iIdx, iType);
        this.Set(iIdx, val + amount, iType);
        return true;
    }
}

enum {
    eDmgDone,        // Damage to Witch
    eTeamIdx,        // Team color
    eHarrasser,      // Is harrasser
    eArsonist,       // Is arsonist
    eDamagerInfoSize // Size
};

enum {
    eWitchLastHealth,    // Last HP after hit
    eWitchMaxHealth,     // Max HP
    eWitchHarrasser,     // Witch Harrasser
    eWitchArsonist,      // Witch Arsonist
    eDamagerInfoVector,  // UserVector storing info described above
    eWitchInfoSize       // Size
};

UserVector g_aWitchInfo;     // Every Witch has a slot here along with relationships.
StringMap  g_smUserNames;    // Simple map from userid to player names.

ConVar g_cvWitchHealth;
int    g_iWitchHealth;

public Plugin myinfo = {
    name        = "Witch Announce++",
    author      = "CanadaRox",
    description = "Prints damage done to witches!",
    version     = "1.0",
    url         = "https://github.com/Attano/L4D2-Competitive-Framework"
};

public void OnPluginStart() {
    HookEvent("round_start",                Event_RoundStart);
    HookEvent("round_end",                  Event_RoundEnd);
    HookEvent("witch_spawn",                Event_WitchSpawn);
    HookEvent("witch_harasser_set",         Event_WitchHarasserSet);
    HookEvent("infected_hurt",              Event_InfectedHurt);
    HookEvent("witch_killed",               Event_WitchKilled);
    HookEvent("player_hurt",                Event_PlayerHurt);
    HookEvent("player_incapacitated_start", Event_PlayerIncap);

    g_cvWitchHealth = FindConVar("z_witch_health");
    g_iWitchHealth = g_cvWitchHealth.IntValue;
    g_cvWitchHealth.AddChangeHook(ConVarChanged);

    g_aWitchInfo  = new UserVector(eWitchInfoSize);
    g_smUserNames = new StringMap();

    int iEntityMaxCount = GetEntityCount();
    for (int i = MaxClients + 1; i <= iEntityMaxCount; i++) {
        if (!IsWitch(i))
            continue;

        g_aWitchInfo.EntSet(i, eDamagerInfoVector, new UserVector(eDamagerInfoSize), true);
        g_aWitchInfo.EntSet(i, eWitchLastHealth, g_iWitchHealth);
        g_aWitchInfo.EntSet(i, eWitchMaxHealth, g_iWitchHealth);
        g_aWitchInfo.EntSet(i, eWitchHarrasser, -1);
        g_aWitchInfo.EntSet(i, eWitchArsonist, -1);
    }
}

public void OnClientDisconnect(int iClient) {
    int iUserId = GetClientUserId(iClient);

    char szKey[16];
    IntToString(iUserId, szKey, sizeof(szKey));

    char szName[MAX_NAME_LENGTH];
    GetClientName(iClient, szName, sizeof(szName));
    g_smUserNames.SetString(szKey, szName);
}

void ConVarChanged(ConVar cv, const char[] szOldValie, const char[] szNewValue) {
    g_iWitchHealth = g_cvWitchHealth.IntValue;
}

void Event_RoundStart(Event eEvent, const char[] szName, bool bDontBroadcast) {
    ClearWitchInfo();
    g_smUserNames.Clear();
}

void Event_RoundEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    ClearWitchInfo();
    g_smUserNames.Clear();
}

void Event_WitchSpawn(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iWitch = eEvent.GetInt("witchid");
    g_aWitchInfo.EntSet(iWitch, eDamagerInfoVector, new UserVector(eDamagerInfoSize), true);
    g_aWitchInfo.EntSet(iWitch, eWitchLastHealth, g_iWitchHealth);
    g_aWitchInfo.EntSet(iWitch, eWitchMaxHealth, g_iWitchHealth);
    g_aWitchInfo.EntSet(iWitch, eWitchHarrasser, -1);
    g_aWitchInfo.EntSet(iWitch, eWitchArsonist, -1);
}

void Event_WitchHarasserSet(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iWitch = eEvent.GetInt("witchid");
    int iAttackerId = eEvent.GetInt("userid");
    int iAttacker = GetClientOfUserId(iAttackerId);

    if (!IsValidSurvivor(iAttacker))
        return;

    g_aWitchInfo.EntSet(iWitch, eWitchHarrasser, iAttackerId);

    UserVector uDamagerVector;
    g_aWitchInfo.EntGet(iWitch, eDamagerInfoVector, uDamagerVector);
    uDamagerVector.EntSet(iAttackerId, eHarrasser, true, true);
    uDamagerVector.EntSet(iAttackerId, eTeamIdx, L4D2Team_Survivor, true);
}

void Event_InfectedHurt(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iWitch = eEvent.GetInt("entityid");
    if (!IsWitch(iWitch))
        return;

    int iAttackerId = eEvent.GetInt("attacker");
    int iAttacker   = GetClientOfUserId(iAttackerId);

    if (iAttacker == 0) {
        iAttackerId = 0;
        iAttacker   = 0;
    }

    int iWitchArsonistId;
    g_aWitchInfo.EntGet(iWitch, eWitchArsonist, iWitchArsonistId);

    int iWitchHarrasserId;
    g_aWitchInfo.EntGet(iWitch, eWitchHarrasser, iWitchHarrasserId);

    int iType = eEvent.GetInt("type");
    if (iType == DMG_BURN) {
        if (iWitchArsonistId == -1) {
            g_aWitchInfo.EntSet(iWitch, eWitchArsonist, iAttackerId);

            UserVector uDamagerVector;
            g_aWitchInfo.EntGet(iWitch, eDamagerInfoVector, uDamagerVector);
            uDamagerVector.EntSet(iAttackerId, eArsonist, true, true);

            iWitchArsonistId = iAttackerId;
        }
    }

    if (iAttacker == 0) {
        int iWitchArsonist  = GetClientOfUserId(iWitchArsonistId);
        int iWitchHarrasser = GetClientOfUserId(iWitchHarrasserId);

        if (IsValidSurvivor(iWitchArsonist)) {
            iAttackerId = iWitchArsonistId;
            iAttacker   = iWitchArsonist;
        } else if (IsValidSurvivor(iWitchHarrasser)) {
            iAttackerId = iWitchHarrasserId;
            iAttacker   = iWitchHarrasser;
        }
    }

    int iTeam = L4D2Team_None;
    if (iAttacker > 0 && IsClientInGame(iAttacker))
        iTeam = GetClientTeam(iAttacker);

    int iLastHealth;
    g_aWitchInfo.EntGet(iWitch, eWitchLastHealth, iLastHealth);

    int iDmg = eEvent.GetInt("amount");
    if (iDmg >= iLastHealth)
        iDmg = iLastHealth;

    g_aWitchInfo.EntSet(iWitch, eWitchLastHealth, iLastHealth - iDmg);

    UserVector uDamagerVector;
    g_aWitchInfo.EntGet(iWitch, eDamagerInfoVector, uDamagerVector);
    uDamagerVector.EntAdd(iAttackerId, eDmgDone, iDmg, true);
    uDamagerVector.EntSet(iAttackerId, eTeamIdx, iTeam, true);
}

void Event_WitchKilled(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iWitch = eEvent.GetInt("witchid");
    int iAttackerId = eEvent.GetInt("userid");

    int iAttacker = GetClientOfUserId(iAttackerId);
    if (iAttacker == 0) {
        int iWitchArsonistId;
        g_aWitchInfo.EntGet(iWitch, eWitchArsonist, iWitchArsonistId);

        int iWitchHarrasserId;
        g_aWitchInfo.EntGet(iWitch, eWitchHarrasser, iWitchHarrasserId);

        int iWitchArsonist  = GetClientOfUserId(iWitchArsonistId);
        int iWitchHarrasser = GetClientOfUserId(iWitchHarrasserId);

        if (IsValidSurvivor(iWitchArsonist)) {
            iAttackerId = iWitchArsonistId;
            iAttacker   = iWitchArsonist;
        } else if (IsValidSurvivor(iWitchHarrasser)) {
            iAttackerId = iWitchHarrasserId;
            iAttacker   = iWitchHarrasser;
        } else {
            iAttackerId = 0;
            iAttacker   = 0;
        }
    }

    int iLastHealth;
    g_aWitchInfo.EntGet(iWitch, eWitchLastHealth, iLastHealth);
    g_aWitchInfo.EntSet(iWitch, eWitchLastHealth, 0);

    UserVector uDamagerVector;
    g_aWitchInfo.EntGet(iWitch, eDamagerInfoVector, uDamagerVector);
    uDamagerVector.EntAdd(iAttackerId, eDmgDone, iLastHealth, true);

    PrintWitchInfo(iWitch);
    ClearWitchInfo(iWitch);
}

void Event_PlayerHurt(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iVictim = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iVictim <= 0 || !IsSurvivor(iVictim))
        return;

    int iWitch = eEvent.GetInt("attackerentid");
    if (!IsWitch(iWitch))
        return;

    int iDmg = eEvent.GetInt("dmg_health");
    if (iDmg == 0)
        return;

    PrintWitchInfo(iWitch);
    ClearWitchInfo(iWitch);
}

void Event_PlayerIncap(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iVictim = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iVictim <= 0 || !IsSurvivor(iVictim))
        return;

    int iWitch = eEvent.GetInt("attackerentid");
    if (!IsWitch(iWitch))
        return;

    PrintWitchInfo(iWitch);
    ClearWitchInfo(iWitch);
}

public void OnEntityDestroyed(int iEnt) {
    if (!IsWitch(iEnt))
        return;

    ClearWitchInfo(iEnt);
}

void PrintTitle(int iUserId, int iLastHealth) {
    if (iLastHealth == 0)
        CPrintToChatAll("{green}[{default}!{green}]{default} The {olive}Witch{default} is dead!");
    else
        CPrintToChatAll("{green}[{default}!{green}]{default} The {olive}Witch{default} had {olive}%d{default} health remaining.", iLastHealth);

    UserVector uDamagerVector;
    if (!g_aWitchInfo.EntGet(iUserId, eDamagerInfoVector, uDamagerVector))
        return;

    int iDmg = 0, iSize = uDamagerVector.Length;
    for (int i = 0; i < iSize; i++) {
        iDmg += uDamagerVector.Get(i, eDmgDone);
    }

    if (iDmg > 0)
        CPrintToChatAll("{green}[{default}!{green}] {olive}Damage{default} dealt to the {olive}Witch{default}:");
}

void PrintWitchInfo(int iParamUserId = 0) {
    static const char szTeamColor[][] = {
        "{olive}",
        "{olive}",
        "{blue}",
        "{red}",
        "{blue}"
    };

    int iLength = g_aWitchInfo.Length;
    if (!iLength)
        return;

    int iIdx = 0;
    if (iParamUserId > 0 && !g_aWitchInfo.EntIndex(iParamUserId, iIdx, false))
        return;

    for (; iIdx < iLength; iIdx++) {
        int iWitch = g_aWitchInfo.Ent(iIdx);

        int iLastHealth = g_aWitchInfo.Get(iIdx, eWitchLastHealth);
        int iMaxHealth  = g_aWitchInfo.Get(iIdx, eWitchMaxHealth);

        UserVector uDamagerVector = g_aWitchInfo.Get(iIdx, eDamagerInfoVector);
        uDamagerVector.SortCustom(SortAdtDamageDesc);

        int iDmgTtl = 0, iPctTtl = 0, iSize = uDamagerVector.Length;
        for (int i = 0; i < iSize; i++) {
            iDmgTtl += uDamagerVector.Get(i, eDmgDone);
            iPctTtl += GetDamageAsPercent(uDamagerVector.Get(i, eDmgDone));
        }

        PrintTitle(iWitch, iLastHealth);

        char szName[MAX_NAME_LENGTH];
        int  iDmg, iPct, iTeamIdx;

        int iPctAdjustment;
        if ((iPctTtl < 100 && float(iDmgTtl) > (iMaxHealth - (iMaxHealth / 200))))
            iPctAdjustment = 100 - iPctTtl;

        int iLastPct = 100;
        int iAdjustedPctDmg;
        for (int i = 0; i < iSize; i++) {
            // generally needed
            GetClientNameFromUserId(uDamagerVector.Ent(i), szName, sizeof(szName));

            // basic witch damage announce
            iTeamIdx = uDamagerVector.Get(i, eTeamIdx);

            iDmg = uDamagerVector.Get(i, eDmgDone);

            iPct = GetDamageAsPercent(iDmg);
            if (iPctAdjustment != 0 && iDmg > 0 && !IsExactPercent(iDmg)) {
                iAdjustedPctDmg = iPct + iPctAdjustment;

                if (iAdjustedPctDmg <= iLastPct) {
                    iPct = iAdjustedPctDmg;
                    iPctAdjustment = 0;
                }
            }

            // ignore cases printing zeros only except harrasser and arsonist
            bool bArsonist  = uDamagerVector.Get(i, eArsonist);
            bool bHarrasser = uDamagerVector.Get(i, eHarrasser);
            if (iDmg > 0 || bHarrasser || bArsonist) {
                char szDmgSpace[16];
                FormatEx(szDmgSpace, sizeof(szDmgSpace), "%s",
                iDmg < 10 ? "      " : iDmg < 100 ? "    " : iDmg < 1000 ? "  " : "");

                char szPrcntSpace[16];
                FormatEx(szPrcntSpace, sizeof(szPrcntSpace), "%s",
                iPct < 10 ? "  " : iPct < 100 ? " " : "");

                CPrintToChatAll("{olive}%s%d {green}|%s{default}%d%%{green}%s|{default}: {green}%s%s%s{green}%s", szDmgSpace, iDmg, szPrcntSpace, iPct, szPrcntSpace, bHarrasser ? "»" : "", szTeamColor[iTeamIdx], szName, bHarrasser ? "«" : "");
            }
        }

        if (iParamUserId > 0)
            break;
    }
}

void ClearWitchInfo(int iUserId = 0) {
    int iIdx = 0;
    if (iUserId > 0 && !g_aWitchInfo.EntIndex(iUserId, iIdx, false))
        return;

    while (g_aWitchInfo.Length) {
        UserVector uDamagerVector = g_aWitchInfo.Get(iIdx, eDamagerInfoVector);
        delete uDamagerVector;

        g_aWitchInfo.Erase(iIdx);

        if (iUserId > 0)
            break;
    }
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

int GetDamageAsPercent(int iDmg) {
    return RoundToFloor(((float(iDmg) / g_iWitchHealth) * 100.0));
}

bool IsExactPercent(int iDmg) {
    return (FloatAbs(float(GetDamageAsPercent(iDmg)) - ((float(iDmg) / g_iWitchHealth) * 100.0)) < 0.001) ? true : false;
}

bool IsWitch(int iEnt) {
    if (iEnt <= MaxClients || !IsValidEdict(iEnt) || !IsValidEntity(iEnt))
        return false;

    char szClsName[MAX_ENTITY_NAME];
    GetEdictClassname(iEnt, szClsName, sizeof(szClsName));

    // witch and witch_bride
    return (strncmp(szClsName, "witch", 5) == 0);
}