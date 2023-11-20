#if defined __Functions__
    #endinput
#endif
#define __Functions__

void SpawnCustomList(float vPos[3], float vAng[3]) {
    char szScriptName[32];

    if (g_cvWeaponMelee[eBaseballBat].IntValue > 0) {
        for (int i = 0; i < g_cvWeaponMelee[eBaseballBat].IntValue; i++) {
            GetScriptName("baseball_bat", szScriptName);
            SpawnMelee(szScriptName, vPos, vAng);
        }
    }

    // Spawn Cricket Bats
    if (g_cvWeaponMelee[eCricketBat].IntValue > 0) {
        for (int i = 0; i < g_cvWeaponMelee[eCricketBat].IntValue; i++) {
            GetScriptName("cricket_bat", szScriptName);
            SpawnMelee(szScriptName, vPos, vAng);
        }
    }

    // Spawn Crowbars
    if (g_cvWeaponMelee[eCrowbar].IntValue > 0) {
        for (int i = 0; i < g_cvWeaponMelee[eCrowbar].IntValue; i++) {
            GetScriptName("crowbar", szScriptName);
            SpawnMelee(szScriptName, vPos, vAng);
        }
    }

    // Spawn Electric Guitars
    if (g_cvWeaponMelee[eElecGuitar].IntValue > 0) {
        for (int i = 0; i < g_cvWeaponMelee[eElecGuitar].IntValue; i++) {
            GetScriptName("electric_guitar", szScriptName);
            SpawnMelee(szScriptName, vPos, vAng);
        }
    }

    // Spawn Fireaxes
    if (g_cvWeaponMelee[eFireAxe].IntValue > 0) {
        for (int i = 0; i < g_cvWeaponMelee[eFireAxe].IntValue; i++) {
            GetScriptName("fireaxe", szScriptName);
            SpawnMelee(szScriptName, vPos, vAng);
        }
    }

    // Spawn Frying Pans
    if (g_cvWeaponMelee[eFryingPan].IntValue > 0) {
        for (int i = 0; i < g_cvWeaponMelee[eFryingPan].IntValue; i++) {
            GetScriptName("frying_pan", szScriptName);
            SpawnMelee(szScriptName, vPos, vAng);
        }
    }

    // Spawn Golfclubs
    if (g_cvWeaponMelee[eGolfClub].IntValue > 0) {
        for (int i = 0; i < g_cvWeaponMelee[eGolfClub].IntValue; i++) {
            GetScriptName("golfclub", szScriptName);
            SpawnMelee(szScriptName, vPos, vAng);
        }
    }

    // Spawn Knifes
    if (g_cvWeaponMelee[eKnife].IntValue > 0) {
        for (int i = 0; i < g_cvWeaponMelee[eKnife].IntValue; i++) {
            GetScriptName("hunting_knife", szScriptName);
            SpawnMelee(szScriptName, vPos, vAng);
        }
    }

    // Spawn Katanas
    if (g_cvWeaponMelee[eKatana].IntValue > 0) {
        for (int i = 0; i < g_cvWeaponMelee[eKatana].IntValue; i++) {
            GetScriptName("katana", szScriptName);
            SpawnMelee(szScriptName, vPos, vAng);
        }
    }

    // Spawn Machetes
    if (g_cvWeaponMelee[eMachete].IntValue > 0) {
        for (int i = 0; i < g_cvWeaponMelee[eMachete].IntValue; i++) {
            GetScriptName("machete", szScriptName);
            SpawnMelee(szScriptName, vPos, vAng);
        }
    }

    // Spawn Tonfas
    if (g_cvWeaponMelee[eTonfa].IntValue > 0) {
        for (int i = 0; i < g_cvWeaponMelee[eTonfa].IntValue; i++) {
            GetScriptName("tonfa", szScriptName);
            SpawnMelee(szScriptName, vPos, vAng);
        }
    }
}

void SpawnMelee(const char szCls[32], float vPos[3], float vAng[3]) {
    float vSpawnPos[3];
    float vSpawnAng[3];

    vSpawnPos = vPos;
    vSpawnAng = vAng;

    vSpawnPos[0] += (-10 + GetRandomInt(0, 20));
    vSpawnPos[1] += (-10 + GetRandomInt(0, 20));
    vSpawnPos[2] += GetRandomInt(0, 10);

    vSpawnAng[1] = GetRandomFloat(0.0, 360.0);

    int iMeleeSpawn = CreateEntityByName("weapon_melee");
    DispatchKeyValue(iMeleeSpawn, "melee_script_name", szCls);
    DispatchSpawn(iMeleeSpawn);
    TeleportEntity(iMeleeSpawn, vSpawnPos, vSpawnAng, NULL_VECTOR);
}

void GetMeleeClasses() {
    int iMeleeStringTable = FindStringTable("MeleeWeapons");
    for (int i = 0; i < eWeaponMeleeSize; i++) {
        ReadStringTable(iMeleeStringTable, i, g_szMeleeClass[i], sizeof(g_szMeleeClass[]));
    }
}

void GetScriptName(const char szCls[32], char szScriptName[32]) {
    for (int i = 0; i < eWeaponMeleeSize; i++) {
        if (StrContains(g_szMeleeClass[i], szCls, false) == 0) {
            Format(szScriptName, sizeof(szScriptName), "%s", g_szMeleeClass[i]);
            return;
        }
    }
    Format(szScriptName, sizeof(szScriptName), "%s", g_szMeleeClass[0]);
}