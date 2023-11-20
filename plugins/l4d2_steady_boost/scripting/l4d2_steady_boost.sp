#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>

#define GAMEDATA_FILE "l4d2_steady_boost"

int g_iFlags;

public Plugin myinfo = {
    name        = "[L4D2] Steady Boost",
    author      = "Forgetest",
    description = "Prevent forced sliding when landing at head of enemies.",
    version     = "1.3",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

void AssertFail(bool bTest, const char[] szError) {
    if (!bTest) SetFailState("%s", szError);
}

public void OnPluginStart() {
    GameData gmConf = new GameData(GAMEDATA_FILE);
    AssertFail(gmConf != null, "Missing gamedata \""...GAMEDATA_FILE..."\"");
    DynamicDetour dDetour = DynamicDetour.FromConf(gmConf, "CBaseEntity::SetGroundEntity");
    AssertFail(dDetour != null && dDetour.Enable(Hook_Pre, DTR_OnSetGroundEntity), "Failed to detour \""..."CBaseEntity::SetGroundEntity"..."\"");
    delete dDetour;
    delete gmConf;

    ConVar cv = CreateConVar(
    "l4d2_steady_boost_flags", "3",
    "Set which teams can perform steady boost. 1 = Survivors, 2 = Infected, 3 = All, 0 = Disabled",
    FCVAR_SPONLY, true, 0.0, true, 3.0);
    OnConVarChanged(cv, "", "");
    cv.AddChangeHook(OnConVarChanged);
}

void OnConVarChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iFlags = cv.IntValue;
}

// TODO: Client prediction fix
MRESReturn DTR_OnSetGroundEntity(int iEntity, DHookParam hParams) {
    if (!g_iFlags)
        return MRES_Ignored;
    
    if (iEntity <= 0)
        return MRES_Ignored;
    
    if (iEntity > MaxClients)
        return MRES_Ignored;
    
    if (!IsClientInGame(iEntity))
        return MRES_Ignored;

    int iTeam = GetClientTeam(iEntity);
    if ((iTeam - 1) & ~g_iFlags)
        return MRES_Ignored;

    int iGround = -1;
    if (!hParams.IsNull(1))
        iGround = hParams.Get(1);

    if (iGround <= 0)
        return MRES_Ignored;
    
    if (iGround > MaxClients)
        return MRES_Ignored;
    
    if (IsPouncing(GetEntPropEnt(iEntity, Prop_Send, "m_customAbility")))
        return MRES_Ignored;
    
    SetEntPropEnt(iEntity, Prop_Send, "m_hGroundEntity", 0);
    return MRES_Supercede;
}

bool IsPouncing(int iAbility) {
    if (!IsValidEdict(iAbility))
        return false;
    
    static char szCls[64];
    if (!GetEdictClassname(iAbility, szCls, sizeof(szCls)))
        return false;
    
    if (szCls[8] != 'l') // match "leap" "lunge"
        return false;
        
    if (szCls[9] == 'e')
        return GetEntPropFloat(iAbility, Prop_Send, "m_nextActivationTimer", 1) <= GetGameTime();
    
    if (szCls[9] == 'u')
        return view_as<bool>(GetEntProp(iAbility, Prop_Send, "m_isLunging", 1));
    
    return false;
}