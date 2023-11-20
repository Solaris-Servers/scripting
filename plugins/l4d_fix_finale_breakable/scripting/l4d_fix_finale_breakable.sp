#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sourcescramble>

public Plugin myinfo = {
    name        = "[L4D & 2] Fix Finale Breakable",
    author      = "Forgetest",
    description = "Fix SI being unable to break props/walls within finale area before finale starts.",
    version     = "1.1",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

public void OnPluginStart() {
    GameData gdConf = new GameData("l4d_fix_finale_breakable");
    if (gdConf == null)
        SetFailState("Missing gamedata \"l4d_fix_finale_breakable\"");
    if (!MemoryPatch.CreateFromConf(gdConf, "CBreakableProp::OnTakeDamage__IsFinale_force_jump").Enable())
        SetFailState("Failed to patch \"CBreakableProp::OnTakeDamage__IsFinale_force_jump\"");
    if (!MemoryPatch.CreateFromConf(gdConf, "CBreakable::OnTakeDamage__IsFinale_force_jump").Enable())
        SetFailState("Failed to patch \"CBreakable::OnTakeDamage__IsFinale_force_jump\"");
    delete gdConf;
}