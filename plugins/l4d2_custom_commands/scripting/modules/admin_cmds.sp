#if defined __ADMINCMDS__
    #endinput
#endif
#define __ADMINCMDS__

void OnModuleStart_AdminCmds() {
    RegAdminCmd("sm_vomitplayer",    Cmd_VomitPlayer,    ADMFLAG_UNBAN, "Vomits the desired player");
    RegAdminCmd("sm_incapplayer",    Cmd_IncapPlayer,    ADMFLAG_UNBAN, "Incapacitates a survivor or tank");
    RegAdminCmd("sm_smackillplayer", Cmd_SmackillPlayer, ADMFLAG_UNBAN, "Smacks a player to death, sending their body flying.");
    RegAdminCmd("sm_rock",           Cmd_Rock,           ADMFLAG_UNBAN, "Launch a tank rock.");
    RegAdminCmd("sm_speedplayer",    Cmd_SpeedPlayer,    ADMFLAG_UNBAN, "Set a player's speed");
    RegAdminCmd("sm_sethpplayer",    Cmd_SetHpPlayer,    ADMFLAG_UNBAN, "Set a player's health");
    RegAdminCmd("sm_colorplayer",    Cmd_ColorPlayer,    ADMFLAG_UNBAN, "Set a player's model color");
    RegAdminCmd("sm_setexplosion",   Cmd_SetExplosion,   ADMFLAG_UNBAN, "Creates an explosion on your feet or where you are looking at");
    RegAdminCmd("sm_pipeexplosion",  Cmd_PipeExplosion,  ADMFLAG_UNBAN, "Creates a pipebomb explosion on your feet or where you are looking at");
    RegAdminCmd("sm_dontrush",       Cmd_DontRush,       ADMFLAG_UNBAN, "Forces a player to re-appear in the starting safe zone");
    RegAdminCmd("sm_changehp",       Cmd_ChangeHp,       ADMFLAG_UNBAN, "Will switch a player's health between temporal or permanent");
    RegAdminCmd("sm_airstrike",      Cmd_Airstrike,      ADMFLAG_UNBAN, "Will set an airstrike attack in the player's face");
    RegAdminCmd("sm_godmode",        Cmd_GodMode,        ADMFLAG_UNBAN, "Will activate or deactivate godmode from player");
    RegAdminCmd("sm_l4drain",        Cmd_L4dRain,        ADMFLAG_UNBAN, "Will rain left 4 dead 1 survivors");
    RegAdminCmd("sm_colortarget",    Cmd_ColorTarget,    ADMFLAG_UNBAN, "Will color the aiming target entity");
    RegAdminCmd("sm_shakeplayer",    Cmd_ShakePlayer,    ADMFLAG_UNBAN, "Will shake a player screen during the desired amount of time");
    RegAdminCmd("sm_weaponrain",     Cmd_WeaponRain,     ADMFLAG_UNBAN, "Will rain the specified weapon");
    RegAdminCmd("sm_cmdplayer",      Cmd_ConsolePlayer,  ADMFLAG_UNBAN, "Will control a player's console");
    RegAdminCmd("sm_bleedplayer",    Cmd_BleedPlayer,    ADMFLAG_UNBAN, "Will force a player to bleed");
    RegAdminCmd("sm_hinttext",       Cmd_HintText,       ADMFLAG_UNBAN, "Prints an instructor hint to all players");
    RegAdminCmd("sm_cheat",          Cmd_Cheat,          ADMFLAG_UNBAN, "Bypass any command and executes it. Rule: [command] [argument] EX: z_spawn tank");
    RegAdminCmd("sm_wipeentity",     Cmd_WipeEntity,     ADMFLAG_UNBAN, "Wipe all entities with the given name");
    RegAdminCmd("sm_setmodel",       Cmd_SetModel,       ADMFLAG_UNBAN, "Sets a player's model relavite to the models folder");
    RegAdminCmd("sm_setmodelentity", Cmd_SetModelEntity, ADMFLAG_UNBAN, "Sets all entities model that match the given classname");
    RegAdminCmd("sm_createparticle", Cmd_CreateParticle, ADMFLAG_UNBAN, "Creates a particle with the option to parent it");
    RegAdminCmd("sm_ignite",         Cmd_Ignite,         ADMFLAG_UNBAN, "Ignites a survivor player");
    RegAdminCmd("sm_teleport",       Cmd_Teleport,       ADMFLAG_UNBAN, "Teleports a player to your cursor position");
    RegAdminCmd("sm_teleportent",    Cmd_TeleportEnt,    ADMFLAG_UNBAN, "Teleports all entities with the given classname to your cursor position");
    RegAdminCmd("sm_rcheat",         Cmd_CheatRcon,      ADMFLAG_UNBAN, "Bypass any command and executes it on the server console");
    RegAdminCmd("sm_scanmodel",      Cmd_ScanModel,      ADMFLAG_UNBAN, "Scans the model of an entity, if possible");
    RegAdminCmd("sm_grabentity",     Cmd_GrabEntity,     ADMFLAG_UNBAN, "Grabs any entity, if possible");
    RegAdminCmd("sm_sizeplayer",     Cmd_SizePlayer,     ADMFLAG_UNBAN, "Resize a player's model (Most likely, their pants)");
    RegAdminCmd("sm_sizeclass",      Cmd_SizeClass,      ADMFLAG_UNBAN, "Will size all entities of the defined classname");
    RegAdminCmd("sm_sizetarget",     Cmd_SizeTarget,     ADMFLAG_UNBAN, "Will size the aiming target entity");
    RegAdminCmd("sm_charge",         Cmd_Charge,         ADMFLAG_UNBAN, "Will launch a survivor far away");
    RegAdminCmd("sm_acidspill",      Cmd_AcidSpill,      ADMFLAG_UNBAN, "Spawns a spitter's acid spill on your the desired player");
    RegAdminCmd("sm_adren",          Cmd_Adren,          ADMFLAG_UNBAN, "Gives a player the adrenaline effect");
    RegAdminCmd("sm_gnomerain",      Cmd_GnomeRain,      ADMFLAG_UNBAN, "Will rain gnomes within your position");
    RegAdminCmd("sm_gnomewipe",      Cmd_GnomeWipe,      ADMFLAG_UNBAN, "Will delete all the gnomes in the map");
    RegAdminCmd("sm_temphp",         Cmd_TempHp,         ADMFLAG_UNBAN, "Sets a player temporary health into the desired value");
    RegAdminCmd("sm_revive",         Cmd_Revive,         ADMFLAG_UNBAN, "Revives an incapacitated player");
    RegAdminCmd("sm_oldmovie",       Cmd_OldMovie,       ADMFLAG_UNBAN, "Sets a player into black and white");
    RegAdminCmd("sm_panic",          Cmd_Panic,          ADMFLAG_UNBAN, "Forces a panic event");
    RegAdminCmd("sm_shove",          Cmd_Shove,          ADMFLAG_UNBAN, "Shoves a player");

    // Development
    RegAdminCmd("sm_entityinfo", Cmd_EntityInfo, ADMFLAG_UNBAN, "Returns the aiming entity classname");
    RegAdminCmd("sm_ccrefresh",  Cmd_Refresh,  ADMFLAG_UNBAN, "Refreshes the menu items");
}

Action Cmd_EntityInfo(int iClient, int iArgs) {
    int iEnt = GetClientAimTarget(iClient, false);
    if (!RealValidEntity(iEnt)) {
        ReplyToCommand(iClient, "[SM] Invalid entity!");
        return Plugin_Handled;
    }

    static char szClsName[64];
    GetEntityClassname(iEnt, szClsName, sizeof(szClsName));
    PrintToChat(iClient, "classname: %s", szClsName);
    return Plugin_Handled;
}

Action Cmd_Refresh(int iClient, int iArgs) {
    PrintToChat(iClient, "[SM] Refreshing the admin menu...");
    TopMenu topmenu = GetAdminTopMenu();
    AddMenuItems(topmenu);
    return Plugin_Handled;
}

Action Cmd_VomitPlayer(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs == 0) {
        PrintToChat(iClient, "[SM] Usage: sm_vomitplayer <#userid|name>");
        return Plugin_Handled;
    }

    static char szArg[65];
    GetCmdArg(1, szArg, sizeof(szArg));

    int iTargetList[MAXPLAYERS];
    int iTargetCount = Cmd_GetTargets(iClient, szArg, iTargetList);

    for (int i = 0; i < iTargetCount; i++) {
        LogCommand("'%N' used the 'Vomit Player' command on '%N'", iClient, i);
        VomitPlayer(iTargetList[i], iClient);
    }

    return Plugin_Handled;
}

Action Cmd_IncapPlayer(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs < 1) {
        PrintToChat(iClient, "[SM] Usage: sm_incapplayer <#userid|name>");
        return Plugin_Handled;
    }

    static char szArg[65];
    GetCmdArg(1, szArg, sizeof(szArg));

    int iTargetList[MAXPLAYERS];
    int iTargetCount = Cmd_GetTargets(iClient, szArg, iTargetList);

    for (int i = 0; i < iTargetCount; i++) {
        LogCommand("'%N' used the 'Incap Player' command on '%N'", iClient, i);
        IncapPlayer(iTargetList[i], iClient);
    }

    return Plugin_Handled;
}

Action Cmd_SmackillPlayer(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs < 1) {
        PrintToChat(iClient, "[SM] Usage: sm_smackillplayer <#userid|name>");
        return Plugin_Handled;
    }

    static char szArg[65];
    GetCmdArg(1, szArg, sizeof(szArg));

    int iTargetList[MAXPLAYERS];
    int iTargetCount = Cmd_GetTargets(iClient, szArg, iTargetList);

    for (int i = 0; i < iTargetCount; i++) {
        LogCommand("'%N' used the 'Smackill Player' command on '%N'", iClient, i);
        SmackillPlayer(iTargetList[i], iClient);
    }

    return Plugin_Handled;
}

Action Cmd_Rock(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    static char szArg[65];

    if (iArgs < 1 || iArgs > 1) {
        strcopy(szArg, sizeof(szArg), "position");
    } else {
        GetCmdArg(1, szArg, sizeof(szArg));
    }

    bool bSuccess = false;
    if (StrContains(szArg, "position", false) != -1) {
        float vPos[3];
        GetClientAbsOrigin(iClient, vPos);

        float vAng[3];
        GetClientEyeAngles(iClient, vAng);

        LaunchRock(vPos, vAng);
        bSuccess = true;
    } else if (StrContains(szArg, "cursor", false) != -1) {
        float vPos[3];
        DoClientTrace(iClient, MASK_OPAQUE, true, vPos);

        float vAng[3];
        GetClientEyeAngles(iClient, vAng);

        LaunchRock(vPos, vAng);
        bSuccess = true;
    }

    if (!bSuccess) {
        PrintToChat(iClient, "[SM] Specify the explosion position");
        return Plugin_Handled;
    }

    LogCommand("'%N' used the 'Set Explosion' command", iClient);
    return Plugin_Handled;
}

Action Cmd_SpeedPlayer(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs < 2) {
        PrintToChat(iClient, "[SM] Usage: sm_speedplayer <#userid|name> [value]");
        return Plugin_Handled;
    }

    static char szArg[65];
    GetCmdArg(1, szArg, sizeof(szArg));

    static char szArg2[65];
    GetCmdArg(2, szArg2, sizeof(szArg2));

    static float fSpeed;
    fSpeed = StringToFloat(szArg2);

    int iTargetList[MAXPLAYERS];
    int iTargetCount = Cmd_GetTargets(iClient, szArg, iTargetList);

    for (int i = 0; i < iTargetCount; i++) {
        LogCommand("'%N' used the 'Speed Player' command on '%N' with value <%f>", iClient, i, fSpeed);
        ChangeSpeed(iTargetList[i], iClient, fSpeed);
    }

    return Plugin_Handled;
}

Action Cmd_SetHpPlayer(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs < 2) {
        PrintToChat(iClient, "[SM] Usage: sm_sethpplayer <#userid|name> [amount]");
        return Plugin_Handled;
    }

    static char szArg[65];
    GetCmdArg(1, szArg, sizeof(szArg));

    static char szArg2[65];
    GetCmdArg(2, szArg2, sizeof(szArg2));

    int iHealth = StringToInt(szArg2);

    int iTargetList[MAXPLAYERS];
    int iTargetCount = Cmd_GetTargets(iClient, szArg, iTargetList);

    for (int i = 0; i < iTargetCount; i++) {
        LogCommand("'%N' used the 'Set Health' command on '%N' with value <%i>", iClient, i, iHealth);
        SetHealth(iTargetList[i], iClient, iHealth);
    }

    return Plugin_Handled;
}

Action Cmd_ColorPlayer(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs < 2) {
        PrintToChat(iClient, "[SM] Usage: sm_colorplayer <#userid|name> [R G B A]");
        return Plugin_Handled;
    }

    static char szArg[65];
    GetCmdArg(1, szArg, sizeof(szArg));

    static char szArg2[65];
    GetCmdArg(2, szArg2, sizeof(szArg2));

    int iTargetList[MAXPLAYERS];
    int iTargetCount = Cmd_GetTargets(iClient, szArg, iTargetList);

    for (int i = 0; i < iTargetCount; i++) {
        LogCommand("'%N' used the 'Color Player' command on '%N' with value <%s>", iClient, i, szArg2);
        ChangeColor(iTargetList[i], iClient, szArg2);
    }

    return Plugin_Handled;
}

Action Cmd_ColorTarget(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs < 1) {
        PrintToChat(iClient, "[SM] Usage: sm_colortarget [R G B A]");
        return Plugin_Handled;
    }

    int iTarget = GetClientAimTarget(iClient, false);
    if (!RealValidEntity(iTarget)) {
        PrintToChat(iClient, "[SM] Invalid entity or looking to nothing");
        return Plugin_Handled;
    }

    static char szArg[256];
    GetCmdArg(1, szArg, sizeof(szArg));

    DispatchKeyValue(iTarget, "rendercolor", szArg);
    DispatchKeyValue(iTarget, "color", szArg);

    static char szClsName[64];
    GetEntityClassname(iTarget, szClsName, sizeof(szClsName));

    LogCommand("'%N' used the 'Color Target' command on entity '%i' of classname '%s' with value <%s>", iClient, iTarget, szClsName, szArg);
    return Plugin_Handled;
}

Action Cmd_SizeTarget(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs < 1) {
        PrintToChat(iClient, "[SM] Usage: sm_sizetarget [scale]");
        return Plugin_Handled;
    }

    int iTarget = GetClientAimTarget(iClient, false);
    if (!RealValidEntity(iTarget)) {
        PrintToChat(iClient, "[SM] Invalid entity or looking to nothing");
        return Plugin_Handled;
    }

    static char szArg[24];
    GetCmdArg(1, szArg, sizeof(szArg));

    float fScale = StringToFloat(szArg);
    SetEntPropFloat(iTarget, Prop_Send, "m_flModelScale", fScale);

    static char szClsName[64];
    GetEntityClassname(iTarget, szClsName, sizeof(szClsName));

    LogCommand("'%N' used the 'Size Target' command on entity '%i' of classname '%s' with value <%s>", iClient, iTarget, szClsName, szArg);
    return Plugin_Handled;
}

Action Cmd_SizeClass(int iClient, int iArgs) {
    if (iArgs < 1) {
        PrintToChat(iClient, "[SM] Usage: sm_sizeclass [classname] [scale]");
        return Plugin_Handled;
    }

    static char szArg[65];
    GetCmdArg(1, szArg, sizeof(szArg));

    static char szArg2[65];
    GetCmdArg(2, szArg2, sizeof(szArg2));

    float fScale = StringToFloat(szArg2);
    int i = FindEntityByClassname(-1, szArg);

    if (!RealValidEntity(i))
        return Plugin_Handled;

    for (; i < GetMaxEntities(); i++) {
        if (!RealValidEntity(i))
            continue;

        static char szClsName[64];
        GetEntityClassname(i, szClsName, sizeof(szClsName));

        if (strcmp(szClsName, szArg, false) != 0)
            continue;

        SetEntPropFloat(i, Prop_Send, "m_flModelScale", fScale);
    }

    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    LogCommand("'%N' used the 'Size Class' command on classname '%s' with value <%f>", iClient, szArg, fScale);
    return Plugin_Handled;
}

Action Cmd_SetExplosion(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs < 1 || iArgs > 1) {
        PrintToChat(iClient, "[SM] Usage: sm_setexplosion [position | cursor]");
        return Plugin_Handled;
    }

    static char szArg[65];
    GetCmdArg(1, szArg, sizeof(szArg));

    bool bSuccess = false;
    if (StrContains(szArg, "position", false) != -1) {
        float vPos[3];
        GetClientAbsOrigin(iClient, vPos);
        CreateExplosion(vPos);
        bSuccess = true;
    } else if (StrContains(szArg, "cursor", false) != -1) {
        float vOrigin[3];
        DoClientTrace(iClient, MASK_OPAQUE, true, vOrigin);
        CreateExplosion(vOrigin);
        bSuccess = true;
    }

    if (!bSuccess) {
        PrintToChat(iClient, "[SM] Specify the explosion position");
        return Plugin_Handled;
    }

    LogCommand("'%N' used the 'Set Explosion' command", iClient);
    return Plugin_Handled;
}

Action Cmd_PipeExplosion(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs < 1 || iArgs > 1) {
        PrintToChat(iClient, "[SM] Usage: sm_pipeexplosion [position | cursor]");
        return Plugin_Handled;
    }

    static char szArg[65];
    GetCmdArg(1, szArg, sizeof(szArg));

    bool bSuccess = false;
    if (StrContains(szArg, "position", false) != -1) {
        float pos[3];
        GetClientAbsOrigin(iClient, pos);
        PipeExplosion(iClient, pos);
        bSuccess = true;
    } else if (StrContains(szArg, "cursor", false) != -1) {
        float vOrigin[3];
        DoClientTrace(iClient, MASK_OPAQUE, true, vOrigin);
        PipeExplosion(iClient, vOrigin);
        bSuccess = true;
    }

    if (!bSuccess)
        LogCommand("'%N' used the 'Pipe Explosion' command", iClient);
        return Plugin_Handled;
    }

    PrintToChat(iClient, "[SM] Specify the explosion position");
    return Plugin_Handled;
}

Action Cmd_SizePlayer(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs < 2) {
        PrintToChat(iClient, "[SM] Usage: sm_sizeplayer <#userid|name> [value]");
        return Plugin_Handled;
    }

    static char szArg[65];
    GetCmdArg(1, szArg, sizeof(szArg));

    static char szArg2[65];
    GetCmdArg(2, szArg2, sizeof(szArg2));

    static float fScale;
    fScale = StringToFloat(szArg2);

    int iTargetList[MAXPLAYERS];
    int iTargetCount = Cmd_GetTargets(iClient, szArg, iTargetList);

    for (int i = 0; i < iTargetCount; i++) {
        LogCommand("'%N' used the 'Size Player' command on '%N' with value <%f>", iClient, i, fScale);
        ChangeScale(iTargetList[i], iClient, fScale);
    }

    return Plugin_Handled;
}

Action Cmd_DontRush(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs < 1) {
        PrintToChat(iClient, "[SM] Usage: sm_dontrush <#userid|name>");
        return Plugin_Handled;
    }

    static char szArg[65];
    GetCmdArg(1, szArg, sizeof(szArg));

    int iTargetList[MAXPLAYERS];
    int iTargetCount = Cmd_GetTargets(iClient, szArg, iTargetList);

    for (int i = 0; i < iTargetCount; i++) {
        LogCommand("'%N' used the 'Anti Rush' command on '%N'", iClient, i);
        TeleportBack(iTargetList[i], iClient);
    }

    return Plugin_Handled;
}

Action Cmd_Airstrike(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs < 1) {
        PrintToChat(iClient, "[SM] Usage: sm_airstrike <#userid|name>");
        return Plugin_Handled;
    }

    static char szArg[65];
    GetCmdArg(1, szArg, sizeof(szArg));

    int iTargetList[MAXPLAYERS];
    int iTargetCount = Cmd_GetTargets(iClient, szArg, iTargetList);

    for (int i = 0; i < iTargetCount; i++) {
        LogCommand("'%N' used the 'Airstrike' command on '%N'", iClient, i);
        Airstrike(iTargetList[i]);
    }

    return Plugin_Handled;
}

Action Cmd_OldMovie(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs < 1) {
        PrintToChat(iClient, "[SM] Usage: sm_oldmovie <#userid|name>");
        return Plugin_Handled;
    }

    static char szArg[65];
    GetCmdArg(1, szArg, sizeof(szArg));

    int iTargetList[MAXPLAYERS];
    int iTargetCount = Cmd_GetTargets(iClient, szArg, iTargetList);

    for (int i = 0; i < iTargetCount; i++) {
        float fHealth = GetClientHealth(iClient) + 1.0;
        BlackAndWhite(iTargetList[i], iClient);
        SetEntityHealth(iTargetList[i], 1);
        SetTempHealth(iTargetList[i], fHealth);
    }

    return Plugin_Handled;
}

Action Cmd_ChangeHp(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs < 1) {
        PrintToChat(iClient, "[SM] Usage: sm_changehp <#userid|name> [perm | temp]");
        return Plugin_Handled;
    }

    static char szArg[65];
    GetCmdArg(1, szArg, sizeof(szArg));

    static char szArg2[65];
    GetCmdArg(2, szArg2, sizeof(szArg2));

    int iType = 0;
    if (strncmp(szArg2, "perm", 4, false) == 0) {
        type = 1;
    } else if (strncmp(szArg2, "temp", 4, false) == 0) {
        type = 2;
    }

    if (type <= 0 || type > 2) {
        PrintToChat(iClient, "[SM] Specify the health style you want");
        return Plugin_Handled;
    }

    int iTargetList[MAXPLAYERS];
    int iTargetCount = Cmd_GetTargets(iClient, szArg, iTargetList);

    for (int i = 0; i < iTargetCount; i++) {
        LogCommand("'%N' used the 'Change Health Type' command on '%N' with value <%s>", iClient, i, szArg2);
        SwitchHealth(iTargetList[i], iClient, type);
    }

    return Plugin_Handled;
}

Action Cmd_GnomeRain(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    LogCommand("'%N' used the 'Gnome Rain' command", iClient);
    StartGnomeRain(iClient);
    return Plugin_Handled;
}

Action Cmd_L4dRain(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    LogCommand("'%N' used the 'L4D1 Rain' command", iClient);
    StartL4dRain(iClient);
    return Plugin_Handled;
}

Action Cmd_GnomeWipe(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    int iCount = 0;
    static char szClsName[14];
    for (int i = MaxClients; i <= GetMaxEntities(); i++) {
        if (!RealValidEntity(i))
            continue;

        GetEntityClassname(i, szClsName, sizeof(szClsName));
        if (strcmp(szClsName, "weapon_gnome", false) == 0) {
            AcceptEntityInput(i, "Kill");
            iCount++;
        }
    }

    PrintToChat(iClient, "[SM] Succesfully wiped %i gnomes", iCount);
    iCount = 0;

    LogCommand("'%N' used the 'Gnome Wipe' command", iClient);
    return Plugin_Handled;
}

Action Cmd_GodMode(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs < 1) {
        PrintToChat(iClient, "[SM] Usage: sm_godmode <#userid|name>");
        return Plugin_Handled;
    }

    static char szArg[65];
    GetCmdArg(1, szArg, sizeof(szArg));

    int iTargetList[MAXPLAYERS];
    int iTargetCount = Cmd_GetTargets(iClient, szArg, iTargetList);

    for (int i = 0; i < iTargetCount; i++) {
        LogCommand("'%N' used the 'God Mode' command on '%N'", iClient, i);
        GodMode(iTargetList[i], iClient);
    }

    return Plugin_Handled;
}

Action Cmd_Charge(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs < 1) {
        PrintToChat(iClient, "[SM] Usage: sm_charge <#userid|name>");
        return Plugin_Handled;
    }

    static char szArg[65];
    GetCmdArg(1, szArg, sizeof(szArg));

    int iTargetList[MAXPLAYERS];
    int iTargetCount = Cmd_GetTargets(iClient, szArg, iTargetList);

    for (int i = 0; i < iTargetCount; i++) {
        LogCommand("'%N' used the 'Charge' command on '%N'", iClient, i);
        Charge(iTargetList[i], iClient);
    }

    return Plugin_Handled;
}

Action Cmd_ShakePlayer(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs < 2) {
        PrintToChat(iClient, "[SM] Usage: sm_shake <#userid|name> [duration]");
        return Plugin_Handled;
    }

    static char szArg[65];
    GetCmdArg(1, szArg, sizeof(szArg));

    static char szArg2[65];
    GetCmdArg(2, szArg2, sizeof(szArg2));

    float fDuration = StringToFloat(szArg2);

    int iTargetList[MAXPLAYERS];
    int iTargetCount = Cmd_GetTargets(iClient, szArg, iTargetList);

    for (int i = 0; i < iTargetCount; i++) {
        LogCommand("'%N' used the 'Shake' command on '%N' with value <%f>", iClient, i, fDuration);
        Shake(iTargetList[i], iClient, fDuration);
    }

    return Plugin_Handled;
}

Action Cmd_ConsolePlayer(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs < 2) {
        PrintToChat(iClient, "[SM] Usage: sm_cmdplayer <#userid|name> [command]");
        return Plugin_Handled;
    }

    static char szArg[65];
    GetCmdArg(1, szArg, sizeof(szArg));

    static char szArg2[65];
    GetCmdArg(2, szArg2, sizeof(szArg2));

    int iTargetList[MAXPLAYERS];
    int iTargetCount = Cmd_GetTargets(iClient, szArg, iTargetList, COMMAND_FILTER_CONNECTED);

    for (int i = 0; i < iTargetCount; i++) {
        LogCommand("'%N' used the 'Client Console' command on '%N' with value <%s>", iClient, i, szArg2);
        ClientCommand(iTargetList[i], szArg2);
    }

    return Plugin_Handled;
}

Action Cmd_WeaponRain(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs < 1) {
        PrintToChat(iClient, "[SM] Usage: sm_weaponrain [weapon type] [Example: !weaponrain adrenaline]");
        return Plugin_Handled;
    }

    static char szArg[65];
    GetCmdArgString(szArg, sizeof(szArg));

    if (!IsValidWeapon(szArg)) {
        PrintToChat(iClient, "[SM] Wrong weapon type");
        return Plugin_Handled;
    }

    WeaponRain(szArg, iClient);
    LogCommand("'%N' used the 'Weapon Rain' command with value <%s>", iClient, szArg);
    return Plugin_Handled;
}

Action Cmd_BleedPlayer(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs < 2) {
        PrintToChat(iClient, "[SM] Usage: sm_bleedplayer <#userid|name> [duration]");
        return Plugin_Handled;
    }

    static char szArg[65];
    GetCmdArg(1, szArg, sizeof(szArg));

    static char szArg2[65];
    GetCmdArg(2, szArg2, sizeof(szArg2));

    float fDuration = StringToFloat(szArg2);

    int iTargetList[MAXPLAYERS];
    int iTargetCount = Cmd_GetTargets(iClient, szArg, iTargetList);

    for (int i = 0; i < iTargetCount; i++) {
        LogCommand("'%N' used the 'Bleed' command on '%N' with value <%f>", iClient, i, fDuration);
        Bleed(iTargetList[i], iClient, fDuration);
    }

    return Plugin_Handled;
}

Action Cmd_HintText(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    static char szArg[65];
    GetCmdArgString(szArg, sizeof(szArg));
    InstructorHint(szArg);

    LogCommand("'%N' used the 'Hint Text' command with value <%s>", iClient, szArg);
    return Plugin_Handled;
}

Action Cmd_Cheat(int iClient, int iArgs) {
    if (iArgs < 2) {
        ReplyToCommand(iClient, "[SM] Usage: sm_cheat <command>");
        return Plugin_Handled;
    }

    static char szArg[65];
    GetCmdArg(1, szArg, sizeof(szArg));

    static char szArg2[65];
    GetCmdArg(2, szArg2, sizeof(szArg2));

    if (!Cmd_CheckClient(client, iClient, false, -1, true)) {
        int cmdflags = GetCommandFlags(szArg);
        SetCommandFlags(szArg, cmdflags & ~FCVAR_CHEAT);
        ServerCommand("%s", szArg2);
        SetCommandFlags(szArg, cmdflags);
        LogCommand("Console used the 'Cheat' command with value <%s>", szArg2);
    } else {
        CheatCommand(iClient, szArg, szArg2);
        LogCommand("'%N' used the 'Cheat' command with value <%s>", iClient, szArg2);
    }

    return Plugin_Handled;
}

Action Cmd_WipeEntity(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    static char szArg[128];
    GetCmdArgString(szArg, sizeof(szArg));

    int iCount = 0;
    static char szClsName[64];
    for (int i = MaxClients + 1; i <= GetMaxEntities(); i++) {
        if (!RealValidEntity(i)) continue;
        GetEntityClassname(i, szClsName, sizeof(szClsName));
        if (strcmp(szClsName, szArg, false) == 0) {
            AcceptEntityInput(i, "Kill");
            iCount++;
        }
    }

    PrintToChat(iClient, "[SM] Succesfully deleted %i <%s> entities", iCount, szArg);
    LogCommand("'%N' used the 'Wipe Entity' command on classname <%s>", iClient, szArg);
    return Plugin_Handled;
}

Action Cmd_SetModel(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs < 2) {
        PrintToChat(iClient, "[SM] Usage: sm_setmodel <#userid|name> [model]");
        PrintToChat(iClient, "Example: !setmodel @me models/props_interiors/table_bedside.mdl ");
        return Plugin_Handled;
    }

    static char szArg[256];
    GetCmdArg(1, szArg, sizeof(szArg));

    static char szArg2[256];
    GetCmdArg(2, szArg2, sizeof(szArg2));

    int iTargetList[MAXPLAYERS];
    int iTargetCount = Cmd_GetTargets(iClient, szArg, iTargetList);

    PrecacheModel(szArg2);
    for (int i = 0; i < iTargetCount; i++) {
        LogCommand("'%N' used the 'Set Model' command on '%N' with value <%s>", iClient, i, szArg2);
        SetEntityModel(iTargetList[i], szArg2);
    }

    return Plugin_Handled;
}

Action Cmd_SetModelEntity(int iClient, int iArgs) {
    if (iArgs < 2) {
        PrintToChat(iClient, "[SM] Usage: sm_setmodelentity <classname> [model]");
        PrintToChat(iClient, "Example: !setmodelentity infected models/props_interiors/table_bedside.mdl");
        return Plugin_Handled;
    }

    static char szArg[128];
    GetCmdArg(1, szArg, sizeof(szArg));

    static char szArg2[128];
    GetCmdArg(2, szArg2, sizeof(szArg2));

    PrecacheModel(szArg2);

    int iCount = 0;
    static char szClsName[64];
    for (int i = MaxClients + 1; i <= GetMaxEntities(); i++) {
        if (RealValidEntity(i)) {
            GetEntityClassname(i, szClsName, sizeof(szClsName));
            if (strcmp(szClsName, szArg, false) == 0) {
                SetEntityModel(i, szArg2);
                iCount++;
            }
        }
    }

    PrintToChat(iClient, "[SM] Succesfully set the %s model to %i <%s> entities", szArg2, iCount, szArg);
    LogCommand("'%N' used the 'Set Model Entity' command on classname '%s' with value <%s>", iClient, szArg, szArg2);
    return Plugin_Handled;
}

Action Cmd_CreateParticle(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs < 4) {
        PrintToChat(iClient, "[SM] Usage: sm_createparticle <#userid|name> [particle] [parent: yes|no] [duration]");
        PrintToChat(iClient, "Example: !createparticle @me no 5 (Teleports the particle to my position, but don't parent it and stop the effect in 5 seconds)");
        return Plugin_Handled;
    }

    static char szArg[64];
    GetCmdArg(1, szArg, sizeof(szArg));

    static char szArg2[32];
    GetCmdArg(2, szArg2, sizeof(szArg2));

    static char szArg3[8];
    GetCmdArg(3, szArg3, sizeof(szArg3));

    static char szArg4[8];
    GetCmdArg(4, szArg4, sizeof(szArg4));

    float fDuration = StringToFloat(szArg4);

    bool bParent = false;
    if (strncmp(szArg3, "yes", 3, false) == 0) {
        bParent = false;
    } else if (strncmp(szArg3, "no", 2, false) == 0) {
        bParent = true;
    } else {
        PrintToChat(iClient, "[SM] No parent option given. As default it won't be parented");
    }

    int iTargetList[MAXPLAYERS];
    int iTargetCount = Cmd_GetTargets(iClient, szArg, iTargetList, COMMAND_FILTER_CONNECTED);

    for (int i = 0; i < iTargetCount; i++) {
        LogCommand("'%N' used the 'Create Particle' command on '%N' with value <%s> <%s> <%f>", iClient, i, szArg2, szArg3, fDuration);
        CreateParticle(iTargetList[i], szArg2, bParent, fDuration);
    }

    return Plugin_Handled;
}

Action Cmd_Ignite(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs < 2) {
        PrintToChat(iClient, "[SM] Usage: sm_ignite <#userid|name> [duration]");
        return Plugin_Handled;
    }

    static char szArg[64];
    GetCmdArg(1, szArg, sizeof(szArg));

    static char szArg2[8];
    GetCmdArg(2, szArg2, sizeof(szArg2));

    float fDuration = StringToFloat(szArg2);

    int iTargetList[MAXPLAYERS];
    int iTargetCount = Cmd_GetTargets(iClient, szArg, iTargetList);

    for (int i = 0; i < iTargetCount; i++) {
        LogCommand("'%N' used the 'Ignite Player' command on '%N' with value <%f>", iClient, i, fDuration);
        IgnitePlayer(iTargetList[i], fDuration);
    }

    return Plugin_Handled;
}

Action Cmd_Teleport(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs < 1) {
        PrintToChat(iClient, "[SM] Usage: sm_teleport <#userid|name>");
        return Plugin_Handled;
    }

    static char szArg[64];
    GetCmdArg(1, szArg, sizeof(szArg));

    int iTargetList[MAXPLAYERS];
    int iTargetCount = Cmd_GetTargets(iClient, szArg, iTargetList);

    float vOrigin[3];
    DoClientTrace(iClient, MASK_OPAQUE, true, vOrigin);

    for (int i = 0; i < iTargetCount; i++) {
        LogCommand("'%N' used the 'Teleport' command on '%N'", iClient, i);
        TeleportEntity(iTargetList[i], vOrigin, NULL_VECTOR, NULL_VECTOR);
    }

    return Plugin_Handled;
}

Action Cmd_TeleportEnt(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs < 1) {
        PrintToChat(iClient, "[SM] Usage: sm_teleportent <classname>");
        return Plugin_Handled;
    }

    static char szArg[64];
    GetCmdArg(1, szArg, sizeof(szArg));

    float vOrigin[3];
    DoClientTrace(iClient, MASK_OPAQUE, true, vOrigin);

    int iCount = 0;

    static char szClsName[64];
    for (int i = 1; i < (GetMaxEntities() * 2); i++) {
        if (RealValidEntity(i)) {
            GetEntityClassname(i, szClsName, sizeof(szClsName));
            if (strcmp(szClsName, szArg, false) == 0) {
                TeleportEntity(i, vOrigin, NULL_VECTOR, NULL_VECTOR);
                iCount++;
            }
        }
    }

    PrintToChat(iClient, "[SM] Successfully teleported '%i' entities with <%s> classname", iCount, szArg);
    LogCommand("'%N' used the 'Teleport Entity' command on '%i' entities with classname <%s>", iClient, iCount, szArg);
    return Plugin_Handled;
}

Action Cmd_CheatRcon(int iClient, int iArgs) {
    if (iArgs < 2) {
        ReplyToCommand(iClient, "[SM] Usage: sm_rcheat <command>");
        return Plugin_Handled;
    }

    static char szArg[256];
    GetCmdArg(1, szArg, sizeof(szArg));

    static char szArgStr[256];
    GetCmdArgString(szArgStr, sizeof(szArgStr));

    if (!Cmd_CheckClient(iClient, iClient, false, -1, true)) {
        int iFlags = GetCommandFlags(szArg);
        SetCommandFlags(szArg, iFlags & ~FCVAR_CHEAT);
        ServerCommand("%s", szArgStr);
        SetCommandFlags(szArg, iFlags);
        LogCommand("Console used the 'RCON Cheat' command with value <%s> <%s>", szArg, szArgStr);
    } else {
        int iFlags = GetCommandFlags(szArg);
        SetCommandFlags(szArg, iFlags & ~FCVAR_CHEAT);
        ServerCommand("%s", szArgStr);
        SetCommandFlags(szArg, iFlags);
        LogCommand("'%N' used the 'RCON Cheat' command with value <%s> <%s>", iClient, szArg, szArgStr);
    }

    return Plugin_Handled;
}

Action Cmd_ScanModel(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    int iEnt = GetLookingEntity(iClient);
    if (!RealValidEntity(iEnt)) {
        PrintToChat(iClient, "[SM] Unable to find a valid target!");
        return Plugin_Handled;
    }

    static char szModel[PLATFORM_MAX_PATH];
    GetEntPropString(iEnt, Prop_Data, "m_ModelName", szModel, sizeof(szModel));

    static char szClsName[64];
    GetEntityClassname(iEnt, szClsName, sizeof(szClsName));

    PrintToChat(iClient, "\x04[SM] The model of the entity <%s>(%d) is \"%s\"", szClsName, iEnt, szModel);
    LogCommand("'%N' used the 'Scan Model' command on entity '%i' of classname '%s'", iClient, iEnt, szClsName);
    return Plugin_Handled;
}

Action Cmd_GrabEntity(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (!g_bGrab[iClient]) {
        GrabLookingEntity(iClient);
    } else {
        ReleaseLookingEntity(iClient);
    }

    LogCommand("'%N' used the 'Grab' command", iClient);
    return Plugin_Handled;
}

Action Cmd_AcidSpill(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs < 1) {
        PrintToChat(iClient, "[SM] Usage: sm_acidspill <#userid|name>");
        return Plugin_Handled;
    }

    static char szArg[64];
    GetCmdArg(1, szArg, sizeof(szArg));

    int iTargetList[MAXPLAYERS];
    int iTargetCount = Cmd_GetTargets(iClient, szArg, iTargetList);

    for (int i = 0; i < iTargetCount; i++) {
        CreateAcidSpill(iTargetList[i], iClient);
    }

    return Plugin_Handled;
}

Action Cmd_Adren(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs < 1) {
        PrintToChat(iClient, "[SM] Usage: sm_adren <#userid|name> <seconds|15.0>");
        return Plugin_Handled;
    }

    static char szArg[64];
    GetCmdArg(1, szArg, sizeof(szArg));

    static char szArg2[64];
    GetCmdArg(2, szArg2, sizeof(szArg2));

    int iTargetList[MAXPLAYERS];
    int iTargetCount = Cmd_GetTargets(iClient, szArg, iTargetList);

    for (int i = 0; i < iTargetCount; i++) {
        SetAdrenalineEffect(iTargetList[i], iClient, StringToFloat(szArg2));
    }

    return Plugin_Handled;
}

Action Cmd_TempHp(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs < 2) {
        PrintToChat(iClient, "[SM] Usage: sm_temphp <#userid|name> <amount>");
        return Plugin_Handled;
    }

    static char szArg[64];
    GetCmdArg(1, szArg, sizeof(szArg));

    static char szArg2[12];
    GetCmdArg(2, szArg2, sizeof(szArg2));

    int iTargetList[MAXPLAYERS];
    int iTargetCount = Cmd_GetTargets(iClient, szArg, iTargetList);

    float fAmount = StringToFloat(szArg2);
    if (fAmount > 65000.0) {
        PrintToChat(iClient, "[SM] The amount <%f> is too high (MAX: 65000)", fAmount);
        return Plugin_Handled;
    } else if (fAmount < 0.0) {
        PrintToChat(iClient, "[SM] The amount <%f> is too low (MIN: 0)", fAmount);
        return Plugin_Handled;
    }

    for (int i = 0; i < iTargetCount; i++) {
        SetTempHealth(iTargetList[i], fAmount);
    }

    return Plugin_Handled;
}

Action Cmd_Revive(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs < 1) {
        PrintToChat(iClient, "[SM] Usage: sm_revive <#userid|name>");
        return Plugin_Handled;
    }

    static char szArg[64];
    GetCmdArg(1, szArg, sizeof(szArg));

    int iTargetList[MAXPLAYERS];
    int iTargetCount = Cmd_GetTargets(iClient, szArg, iTargetList);

    for (int i = 0; i < iTargetCount; i++) {
        RevivePlayer_Cmd(iTargetList[i], iClient);
    }

    return Plugin_Handled;
}

Action Cmd_Panic(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, -1, false, -1, false)) {
        PrintToServer("[SM] Creating a panic event..."); }
    else {
        PrintToChat(iClient, "[SM] Creating a panic event...");
    }

    PanicEvent();
    return Plugin_Handled;
}

Action Cmd_Shove(int iClient, int iArgs) {
    if (!Cmd_CheckClient(iClient, iClient, false, -1, true))
        return Plugin_Handled;

    if (iArgs < 1) {
        PrintToChat(iClient, "[SM] Usage: sm_shove <#userid|name>");
        return Plugin_Handled;
    }

    static char szArg[64];
    GetCmdArg(1, szArg, sizeof(szArg));

    int iTargetList[MAXPLAYERS];
    int iTargetCount = Cmd_GetTargets(iClient, szArg, iTargetList);

    for (int i = 0; i < iTargetCount; i++) {
        ShovePlayer_Cmd(iTargetList[i], iClient);
    }

    return Plugin_Handled;
}