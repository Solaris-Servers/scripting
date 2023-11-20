#pragma newdecls required
#pragma semicolon 1
#include <sourcemod>

public void OnMapStart()
{
    Precache();
}

void Precache()
{
    // weapons
    if (!IsModelPrecached("models/survivors/survivor_biker.mdl")) // 'by iHX
    {
        PrecacheModel("models/survivors/survivor_biker.mdl", false);
    }

    if (!IsModelPrecached("models/survivors/survivor_manager.mdl"))
    {
        PrecacheModel("models/survivors/survivor_manager.mdl", false);
    }

    if (!IsModelPrecached("models/survivors/survivor_teenangst.mdl"))
    {
        PrecacheModel("models/survivors/survivor_teenangst.mdl", false);
    }

    if (!IsModelPrecached("models/survivors/survivor_coach.mdl"))
    {
        PrecacheModel("models/survivors/survivor_coach.mdl", false);
    }

    if (!IsModelPrecached("models/survivors/survivor_gambler.mdl"))
    {
        PrecacheModel("models/survivors/survivor_gambler.mdl", false);
    }

    if (!IsModelPrecached("models/survivors/survivor_namvet.mdl"))
    {
        PrecacheModel("models/survivors/survivor_namvet.mdl", false);
    }

    if (!IsModelPrecached("models/survivors/survivor_mechanic.mdl"))
    {
        PrecacheModel("models/survivors/survivor_mechanic.mdl", false);
    }

    if (!IsModelPrecached("models/survivors/survivor_producer.mdl"))
    {
        PrecacheModel("models/survivors/survivor_producer.mdl", false);
    }

    if (!IsModelPrecached("models/infected/witch.mdl"))
    {
        PrecacheModel("models/infected/witch.mdl", false);
    }

    if (!IsModelPrecached("models/infected/witch_bride.mdl"))
    {
        PrecacheModel("models/infected/witch_bride.mdl", false);
    }

    if (!IsModelPrecached("models/v_models/v_rif_sg552.mdl"))
    {
        PrecacheModel("models/v_models/v_rif_sg552.mdl", false);
    }

    if (!IsModelPrecached("models/v_models/v_smg_mp5.mdl"))
    {
        PrecacheModel("models/v_models/v_smg_mp5.mdl", false);
    }

    if (!IsModelPrecached("models/v_models/v_snip_awp.mdl"))
    {
        PrecacheModel("models/v_models/v_snip_awp.mdl", false);
    }

    if (!IsModelPrecached("models/v_models/v_snip_scout.mdl"))
    {
        PrecacheModel("models/v_models/v_snip_scout.mdl", false);
    }

    if (!IsModelPrecached("models/w_models/weapons/50cal.mdl"))
    {
        PrecacheModel("models/w_models/weapons/50cal.mdl", false);
    }

    if (!IsModelPrecached("models/w_models/weapons/w_knife_t.mdl"))
    {
        PrecacheModel("models/w_models/weapons/w_knife_t.mdl", false);
    }

    if (!IsModelPrecached("models/w_models/weapons/w_rifle_sg552.mdl"))
    {
        PrecacheModel("models/w_models/weapons/w_rifle_sg552.mdl", false);
    }

    if (!IsModelPrecached("models/w_models/weapons/w_smg_mp5.mdl"))
    {
        PrecacheModel("models/w_models/weapons/w_smg_mp5.mdl", false);
    }

    if (!IsModelPrecached("models/w_models/weapons/w_sniper_awp.mdl"))
    {
        PrecacheModel("models/w_models/weapons/w_sniper_awp.mdl", false);
    }

    if (!IsModelPrecached("models/w_models/weapons/w_sniper_scout.mdl"))
    {
        PrecacheModel("models/w_models/weapons/w_sniper_scout.mdl", false);
    }

    if (!IsModelPrecached("models/weapons/melee/v_fireaxe.mdl"))
    {
        PrecacheModel("models/weapons/melee/v_fireaxe.mdl", false);
    }

    if (!IsModelPrecached("models/weapons/melee/v_frying_pan.mdl"))
    {
        PrecacheModel("models/weapons/melee/v_frying_pan.mdl", false);
    }

    if (!IsModelPrecached("models/weapons/melee/v_golfclub.mdl"))
    {
        PrecacheModel("models/weapons/melee/v_golfclub.mdl", false);
    }

    if (!IsModelPrecached("models/weapons/melee/v_machete.mdl"))
    {
        PrecacheModel("models/weapons/melee/v_machete.mdl", false);
    }

    if (!IsModelPrecached("models/weapons/melee/w_cricket_bat.mdl"))
    {
        PrecacheModel("models/weapons/melee/w_cricket_bat.mdl", false);
    }

    if (!IsModelPrecached("models/weapons/melee/w_crowbar.mdl"))
    {
        PrecacheModel("models/weapons/melee/w_crowbar.mdl", false);
    }

    if (!IsModelPrecached("models/weapons/melee/w_electric_guitar.mdl"))
    {
        PrecacheModel("models/weapons/melee/w_electric_guitar.mdl", false);
    }

    if (!IsModelPrecached("models/weapons/melee/w_frying_pan.mdl"))
    {
        PrecacheModel("models/weapons/melee/w_frying_pan.mdl", false);
    }

    if (!IsModelPrecached("models/weapons/melee/w_golfclub.mdl"))
    {
        PrecacheModel("models/weapons/melee/w_golfclub.mdl", false);
    }

    if (!IsModelPrecached("models/weapons/melee/w_katana.mdl"))
    {
        PrecacheModel("models/weapons/melee/w_katana.mdl", false);
    }

    if (!IsModelPrecached("models/weapons/melee/w_machete.mdl"))
    {
        PrecacheModel("models/weapons/melee/w_machete.mdl", false);
    }

    if (!IsModelPrecached("models/weapons/melee/w_tonfa.mdl"))
    {
        PrecacheModel("models/weapons/melee/w_tonfa.mdl", false);
    }

    if (!IsModelPrecached("models/weapons/melee/w_shovel.mdl"))
    {
        PrecacheModel("models/weapons/melee/w_shovel.mdl", false);
    }

    if (!IsModelPrecached("models/weapons/melee/w_pitchfork.mdl"))
    {
        PrecacheModel("models/weapons/melee/w_pitchfork.mdl", false);
    }

    if (!IsModelPrecached("models/v_models/weapons/v_claw_smoker_l4d1.mdl"))
    {
        PrecacheModel("models/v_models/weapons/v_claw_smoker_l4d1.mdl", false);
    }

    // crash
    PrecacheModel("models/props_unique/zombiebreakwallhospitalexterior01_main.m");
    PrecacheModel("models/props_unique/zombiebreakwallexteriorhospitalframe01_dm.m");
    PrecacheModel("models/props_unique/zombiebreakwallexteriorhospitalpart01_dm.m");
    PrecacheModel("models/props_unique/zombiebreakwallexteriorhospitalpart02_dm.m");
    PrecacheModel("models/props_unique/zombiebreakwallexteriorhospitalpart03_dm.m");
    PrecacheModel("models/props_unique/zombiebreakwallexteriorhospitalpart04_dm.m");
    PrecacheModel("models/props_unique/zombiebreakwallexteriorhospitalpart05_dm.m");
    PrecacheModel("models/props_unique/zombiebreakwallexteriorhospitalpart06_dm.m");
    PrecacheModel("models/props_unique/zombiebreakwallexteriorhospitalpart07_dm.m");
    PrecacheModel("models/props_unique/zombiebreakwallexteriorhospitalpart08_dm.m");
    PrecacheModel("models/props_unique/zombiebreakwallexteriorhospitalpart09_dm.m");
    PrecacheModel("models/v_models/weapons/v_claw_hunter_l4d1.mdl");
}