#if defined __ADMIN_CMDS__
    #endinput
#endif
#define __ADMIN_CMDS__

void AdminCmds_OnModuleStgart() {
    RegAdminCmd("sm_xmas_add",   Cmd_SpawnAdd, ADMFLAG_ROOT);
    RegAdminCmd("sm_xmas_spawn", Cmd_Spawn,    ADMFLAG_ROOT);
}

Action Cmd_SpawnAdd(int iClient, int iArgs) {
    float vPos[3];
    GetClientEyePosition(iClient, vPos);
    vPos[2] = vPos[2] + 10;

    float vAng[3];
    GetClientEyeAngles(iClient, vAng);

    Handle hTrace = TR_TraceRayFilterEx(vPos, vAng, MASK_SOLID, RayType_Infinite, GetLookPosFilter, iClient);
    if (TR_DidHit(hTrace)) {
        TR_GetEndPosition(vPos, hTrace);
        PrintToChat(iClient, "Added xmas tree. Origin = %.2f %.2f %.2f", vPos[0], vPos[1], vPos[2]);

        char szFile[256];
        BuildPath(Path_SM, szFile, sizeof(szFile), "configs/xmas/trees/%s.cfg", g_szMapName);
        File fFile = OpenFile(szFile, "a");
        fFile.WriteLine("// XMAS TREE");
        fFile.WriteLine("%.2f %.2f %.2f", vPos[0], vPos[1], vPos[2]);
        fFile.WriteLine("// ==========");
        delete fFile;
    }

    return Plugin_Handled;
}

Action Cmd_Spawn(int iClient, int iArgs) {
    float vPos[3];
    GetClientEyePosition(iClient, vPos);
    vPos[2] = vPos[2] + 10;

    float vAng[3];
    GetClientEyeAngles(iClient, vAng);

    Handle hTrace = TR_TraceRayFilterEx(vPos, vAng, MASK_SOLID, RayType_Infinite, GetLookPosFilter, iClient);
    if (TR_DidHit(hTrace)) {
        TR_GetEndPosition(vPos, hTrace);
        int iEnt = CreateEntityByName("prop_dynamic");
        char szTargetname[64];
        FormatEx(szTargetname, sizeof(szTargetname), "gift_%i", iEnt);
        DispatchKeyValue(iEnt, "model", "models/models_kit_go/xmas/xmastree_mini.mdl");
        DispatchKeyValue(iEnt, "spawnflags", "3");
        AcceptEntityInput(iEnt, "DisableMotion");

        TeleportEntity(iEnt, vPos, NULL_VECTOR, NULL_VECTOR);
        SetEntProp(iEnt, Prop_Data, "m_nSolidType", 0);
        SetEntProp(iEnt, Prop_Data, "m_CollisionGroup", 0);
        SetEntProp(iEnt, Prop_Data, "m_takedamage", 0);
        SetEntProp(iEnt, Prop_Data, "m_iHealth", 100);
        SetEntityMoveType(iEnt, MOVETYPE_NONE);
        DispatchSpawn(iEnt);

        int iChanceGiftOne;

        vPos[0] += 25.0;
        iChanceGiftOne = GetRandomInt(0, 1);
        if (iChanceGiftOne)
            BoxBonusSpawn(vPos);

        vPos[0] -= 50.0;
        iChanceGiftOne = GetRandomInt(0, 1);
        if (iChanceGiftOne)
            BoxBonusSpawn(vPos);

        vPos[0] += 25.0;
        vPos[1] += 25.0;
        iChanceGiftOne = GetRandomInt(0, 1);
        if (iChanceGiftOne)
            BoxBonusSpawn(vPos);

        vPos[1] -= 50.0;
        iChanceGiftOne = GetRandomInt(0, 1);
        if (iChanceGiftOne)
            BoxBonusSpawn(vPos);
        vPos[1] += 25.0;
    }

    return Plugin_Handled;
}