#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <dhooks>

Handle hCBaseAbility_OnOwnerTakeDamage;

public Plugin myinfo =
{
    name        = "L4D2 Pounce Protect",
    author      = "ProdigySim",
    description = "Prevent damage from blocking a hunter's ability to pounce",
    version     = "1.0",
    url         = "http://www.l4dnation.com/"
}

public void OnPluginStart()
{
    GameData gameConf = new GameData("l4d_pounceprotect");
    int OnOwnerTakeDamageOffset = gameConf.GetOffset("CBaseAbility_OnOwnerTakeDamage");
    delete gameConf;

    hCBaseAbility_OnOwnerTakeDamage = DHookCreate(OnOwnerTakeDamageOffset, HookType_Entity, ReturnType_Void, ThisPointer_Ignore, CBaseAbility_OnOwnerTakeDamage);
    DHookAddParam(hCBaseAbility_OnOwnerTakeDamage, HookParamType_ObjectPtr);

    DHookAddEntityListener(ListenType_Created, OnEntityCreated);
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (StrEqual(classname, "ability_lunge"))
    {
        DHookEntity(hCBaseAbility_OnOwnerTakeDamage, false, entity);
    }
}

// During this function call the game simply validates the owner entity
// and then sets a bool saying you can't pounce again if you're already mid-pounce.
// afaik
public MRESReturn CBaseAbility_OnOwnerTakeDamage(Handle hParams)
{
    // Skip the whole function plox
    return MRES_Supercede;
}