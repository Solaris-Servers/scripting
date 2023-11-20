#if defined __Variables__
    #endinput
#endif
#define __Variables__

ConVar g_cvEnabled;
ConVar g_cvWeaponRandom;
ConVar g_cvWeaponRandomAmount;

enum /* Weapon_Melee */ {
    eBaseballBat,
    eCricketBat,
    eCrowbar,
    eElecGuitar,
    eFireAxe,
    eFryingPan,
    eGolfClub,
    eKnife,
    eKatana,
    eMachete,
    eTonfa,
    eWeaponMeleeSize
};

public const char g_szMeleeWeapon[][][] = {
    {"BaseballBat", "baseball bats"   },
    {"CricketBat",  "cricket bat"     },
    {"Crowbar",     "crowbars"        },
    {"ElecGuitar",  "electric guitars"},
    {"FireAxe",     "fireaxes"        },
    {"FryingPan",   "frying pans"     },
    {"GolfClub",    "golf clubs"      },
    {"Knife",       "knifes"          },
    {"Katana",      "katanas"         },
    {"Machete",     "machetes"        },
    {"Tonfa",       "tonfas"          }
};

ConVar g_cvWeaponMelee[eWeaponMeleeSize];

char g_szMeleeClass[eWeaponMeleeSize][32];
int  g_iMeleeRandomSpawn[eWeaponMeleeSize];