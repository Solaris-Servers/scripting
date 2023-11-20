#if defined __ADMINCMDS__
    #endinput
#endif
#define __ADMINCMDS__

void AdminCmds_OnModulesStart() {
    RegAdminCmd("sm_changelevel",   Cmd_ChangeLevel,   ADMFLAG_ROOT, "Changes level (map) using CDirector.");
    RegAdminCmd("sm_changemission", Cmd_ChangeMission, ADMFLAG_ROOT, "Changes map to the first level of a given mission (campaign).");
}

Action Cmd_ChangeLevel(int iClient, int iArgs) {
    if (iArgs == 0) {
        ReplyToCommand(iClient, "Usage: sm_changelevel <Map> <Clear info>.");
        ReplyToCommand(iClient, " 1st arg: <Map> --- Map name e.g. \"c2m1_highway\".");
        ReplyToCommand(iClient, " 2nd arg: <Clear info> --- 0 = don't clear transition info, 1 = clear transition info");
        return Plugin_Handled;
    }

    char szMap[PLATFORM_MAX_PATH];
    GetCmdArg(1, szMap, sizeof(szMap));

    char szTmp[2];
    if (szMap[0] == '\0' || FindMap(szMap, szTmp, sizeof(szTmp)) == FindMap_NotFound) {
        ReplyToCommand(iClient, "sm_changelevel Unable to find map \"%s\"", szMap);
        return Plugin_Handled;
    }

    Clear(true, true);
    if (iArgs >= 2) {
        GetCmdArg(2, szTmp, sizeof(szTmp));
        Clear(true, view_as<bool>(StringToInt(szTmp)));
    }

    SDK_ChangeLevel(szMap, false);
    return Plugin_Handled;
}

Action Cmd_ChangeMission(int iClient, int iArgs) {
    if (iArgs == 0) {
        ReplyToCommand(iClient, "Usage: sm_changemission <Campaign>.");
        ReplyToCommand(iClient, " 1st arg: <Campaign> --- Campaign code name e.g. \"L4D2C2\".");
        return Plugin_Handled;
    }

    char szMission[PLATFORM_MAX_PATH];
    GetCmdArg(1, szMission, sizeof(szMission));

    SDK_ChangeMission(szMission);
    return Plugin_Handled;
}