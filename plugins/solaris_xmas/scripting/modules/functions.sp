#if defined __FUNCTIONS__
    #endinput
#endif
#define __FUNCTIONS__

void MakeSnow() {
    KillSnow();

    if (!IsSnowAllowed())
        return;

    int iSnow = CreateEntityByName("func_precipitation");
    if (iSnow != -1) {
        char szMap[64];
        GetCurrentMap(szMap, sizeof(szMap));
        Format(szMap, sizeof(szMap), "maps/%s.bsp", szMap);
        PrecacheModel(szMap, true);
        DispatchKeyValue(iSnow, "model", szMap);
        DispatchKeyValue(iSnow, "preciptype", "3");

        float vMax[3];
        GetEntPropVector(0, Prop_Data, "m_WorldMaxs", vMax);
        SetEntPropVector(iSnow, Prop_Send, "m_vecMaxs", vMax);

        float vMins[3];
        GetEntPropVector(0, Prop_Data, "m_WorldMins", vMins);
        SetEntPropVector(iSnow, Prop_Send, "m_vecMins", vMins);

        float vBuff[3];
        vBuff[0] = vMins[0] + vMax[0];
        vBuff[1] = vMins[1] + vMax[1];
        vBuff[2] = vMins[2] + vMax[2];
        TeleportEntity(iSnow, vBuff, NULL_VECTOR, NULL_VECTOR);
        DispatchSpawn(iSnow);
        ActivateEntity(iSnow);
    }
}

void KillSnow() {
    int iSnow = -1;
    while ((iSnow = FindEntityByClassname(iSnow , "func_precipitation")) != INVALID_ENT_REFERENCE) {
        AcceptEntityInput(iSnow, "Kill");
    }
}

void TreeSpawnByFile() {
    char szFile[256];
    BuildPath(Path_SM, szFile, sizeof(szFile), "configs/xmas/trees/%s.cfg", g_szMapName);

    File fFile = OpenFile(szFile, "r");
    int iLen;
    if (fFile == null)
        return;

    char szBuffer[256];
    while (ReadFileLine(fFile, szBuffer, sizeof(szBuffer))) {
        iLen = strlen(szBuffer);
        if (szBuffer[iLen - 1] == '\n')
            szBuffer[--iLen] = '\0';

        TrimString(szBuffer);
        if (strcmp(szBuffer, "", false) != 0) {
            if (StrContains(szBuffer, "//", false) < 0) {
                char szBuff[10][32];
                float fVec[3];
                ExplodeString(szBuffer, " ", szBuff, 10, 32);
                fVec[0] = StringToFloat(szBuff[0]);
                fVec[1] = StringToFloat(szBuff[1]);
                fVec[2] = StringToFloat(szBuff[2]);
                TreeSpawn(fVec);
            }
        }

        if (IsEndOfFile(fFile))
            break;
    }

    if (fFile != null)
        delete fFile;
}


void TreeSpawn(float vPos[3]) {
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

    if (IsPvP()){
        int iRandom = GetRandomInt(1, 4);
        switch (iRandom) {
            case 1: {
                vPos[0] += 25.0;
                BoxBonusSpawn(vPos);
            }
            case 2: {
                vPos[0] -= 25.0;
                BoxBonusSpawn(vPos);
            }
            case 3: {
                vPos[1] += 25.0;
                BoxBonusSpawn(vPos);
            }
            case 4: {
                vPos[1] -= 25.0;
                BoxBonusSpawn(vPos);
            }
        }
    }
}

void BoxBonusSpawn(float vPos[3]) {
    float vAng[3] = {0.0, 0.0, 0.0};
    vAng[1] = GetRandomFloat(-360.0, 360.0);

    int iEnt = CreateEntityByName("prop_dynamic");

    char szTargetname[64];
    FormatEx(szTargetname, sizeof(szTargetname), "gift_%i", iEnt);
    DispatchKeyValue(iEnt, "model", "models/items/l4d_gift.mdl");
    DispatchKeyValue(iEnt, "physicsmode", "2");
    DispatchKeyValue(iEnt, "massScale", "1.0");
    DispatchKeyValue(iEnt, "szTargetname", szTargetname);
    DispatchKeyValue(iEnt, "spawnflags", "0");
    SetEntProp(iEnt, Prop_Send, "m_usSolidFlags", 8);
    SetEntProp(iEnt, Prop_Send, "m_CollisionGroup", 1);

    vPos[2] += 5;
    TeleportEntity(iEnt, vPos, vAng, NULL_VECTOR);

    if (g_cvXmasColoredGift.BoolValue) {
        char szColorCvar[64];
        g_cvXmasGiftColor.GetString(szColorCvar, sizeof(szColorCvar));

        char szColorStr[4][32];
        ExplodeString(szColorCvar, " ", szColorStr, 4, 32);

        int iColors[4] = { 255, 255, 255, 255};
        iColors[0] = StringToInt(szColorStr[0]);
        iColors[1] = StringToInt(szColorStr[1]);
        iColors[2] = StringToInt(szColorStr[2]);
        iColors[3] = StringToInt(szColorStr[3]);
        SetEntityRenderMode(iEnt, RENDER_NORMAL);
        SetEntityRenderColor(iEnt, iColors[0], iColors[1], iColors[2], iColors[3]);
    }

    DispatchSpawn(iEnt);
    SetEntGlow(iEnt, GetColor());
    SDKHook(iEnt, SDKHook_StartTouch,  Hook_OnStartTouch);
    SDKHook(iEnt, SDKHook_SetTransmit, Hook_OnTransmit);
}

void Hook_OnStartTouch(int iEnt, int iClient) {
    if (iClient > 0 && iClient <= MaxClients && !IsFakeClient(iClient) && IsSurvivor(iClient)) {
        int iNeedPlayersToCollect = g_cvXmasPlayersNeeded.IntValue;
        if (GetRealCountPlayers() < iNeedPlayersToCollect)
            return;

        AcceptEntityInput(iEnt, "Kill");
        SetEntNoGlow(iEnt);
        Request_AwardPoints(iClient, 1);
    }
}

Action Hook_OnTransmit(int iEnt, int iClient) {
    if (GetClientTeam(iClient) == 2)
        return Plugin_Continue;
    return Plugin_Handled;
}