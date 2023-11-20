#if defined __Precache__
    #endinput
#endif
#define __Precache__

static const char g_szMeleeModel[][] = {
    "models/weapons/melee/v_bat.mdl",
    "models/weapons/melee/v_cricket_bat.mdl",
    "models/weapons/melee/v_crowbar.mdl",
    "models/weapons/melee/v_electric_guitar.mdl",
    "models/weapons/melee/v_fireaxe.mdl",
    "models/weapons/melee/v_frying_pan.mdl",
    "models/weapons/melee/v_golfclub.mdl",
    "models/weapons/melee/v_katana.mdl",
    "models/weapons/melee/v_machete.mdl",
    "models/weapons/melee/v_tonfa.mdl",

    "models/weapons/melee/w_bat.mdl",
    "models/weapons/melee/w_cricket_bat.mdl",
    "models/weapons/melee/w_crowbar.mdl",
    "models/weapons/melee/w_electric_guitar.mdl",
    "models/weapons/melee/w_fireaxe.mdl",
    "models/weapons/melee/w_frying_pan.mdl",
    "models/weapons/melee/w_golfclub.mdl",
    "models/weapons/melee/w_katana.mdl",
    "models/weapons/melee/w_machete.mdl",
    "models/weapons/melee/w_tonfa.mdl"
};

static const char g_szMeleeScripts[][] = {
    "scripts/melee/baseball_bat.txt",
    "scripts/melee/cricket_bat.txt",
    "scripts/melee/crowbar.txt",
    "scripts/melee/electric_guitar.txt",
    "scripts/melee/fireaxe.txt",
    "scripts/melee/frying_pan.txt",
    "scripts/melee/golfclub.txt",
    "scripts/melee/katana.txt",
    "scripts/melee/machete.txt",
    "scripts/melee/tonfa.txt"
};

void Precache_OnMapStart() {
    for (int i = 0; i < sizeof(g_szMeleeModel); i++) {
        PrecacheModel(g_szMeleeModel[i], true);
    }
    for (int i = 0; i < sizeof(g_szMeleeScripts); i++) {
        PrecacheGeneric(g_szMeleeScripts[i], true);
    }
}