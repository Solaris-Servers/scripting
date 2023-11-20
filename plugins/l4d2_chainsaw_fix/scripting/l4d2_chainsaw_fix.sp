#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>

#define GAMEDATA "l4d2_chainsaw_fix"

bool g_bSoundBlock;

public Plugin myinfo = {
	name        = "[L4D2] Chainsaw Crash Fixer",
	author      = "SilverShot",
	description = ".",
	version     = "0.1",
	url         = ""
}

public void OnPluginStart() {
	// ====================================================================================================
	// Detour
	// ====================================================================================================
	GameData gmData = new GameData(GAMEDATA);
	if (gmData == null) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);
	Handle hDetourPitch      = DHookCreateFromConf(gmData, "CSoundPatch::ChangePitch");
	Handle hDetourAttack     = DHookCreateFromConf(gmData, "CChainsaw::PrimaryAttack");
	Handle hDetourStopAttack = DHookCreateFromConf(gmData, "CChainsaw::StopAttack");
	delete gmData;
	if (!hDetourPitch)      SetFailState("Failed to find \"CSoundPatch::ChangePitch\" signature.");
	if (!hDetourAttack)     SetFailState("Failed to find \"CChainsaw::PrimaryAttack\" signature.");
	if (!hDetourStopAttack) SetFailState("Failed to find \"CChainsaw::StopAttack\" signature.");
	if (!DHookEnableDetour(hDetourPitch, false, CSoundPatch_ChangePitch))
		SetFailState("Failed to detour \"CSoundPatch::ChangePitch\".");
	if (!DHookEnableDetour(hDetourAttack, false, CChainsaw_PrimaryAttack))
		SetFailState("Failed to detour \"CChainsaw::PrimaryAttack\".");
	if (!DHookEnableDetour(hDetourStopAttack, false, CChainsaw_StopAttack))
		SetFailState("Failed to detour post \"CChainsaw::StopAttack\".");
}

// ====================================================================================================
// Detour
// ====================================================================================================
public MRESReturn CSoundPatch_ChangePitch(Handle hReturn, Handle hParams) {
	if (g_bSoundBlock) {
		DHookSetReturn(hReturn, 0);
		return MRES_Supercede;
	}	
	return MRES_Ignored;
}

public MRESReturn CChainsaw_PrimaryAttack(Handle hReturn, Handle hParams) {
	g_bSoundBlock = true;
	return MRES_Ignored;
}

public MRESReturn CChainsaw_StopAttack(Handle hReturn, Handle hParams) {
	g_bSoundBlock = false;
	return MRES_Ignored;
}