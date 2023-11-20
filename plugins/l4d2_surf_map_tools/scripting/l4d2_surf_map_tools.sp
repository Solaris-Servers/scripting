#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>

#define NULL_VELOCITY view_as<float>({0.0, 0.0, 0.0})

#define DAS_VER        "3.29.71"
#define VERTIGO_VER    "2.27.58"
#define DEAD_HOTEL_VER "2.3b"

#define DAS_TOP        "addons/sourcemod/data/surf/das_top.txt"
#define VERTIGO_TOP    "addons/sourcemod/data/surf/vertigo_top.txt"
#define DEAD_HOTEL_TOP "addons/sourcemod/data/surf/dead_hotel_top.txt"

#define DAS_URL        "https://steamcommunity.com/sharedfiles/filedetails/?id=526792721"
#define VERTIGO_URL    "https://steamcommunity.com/sharedfiles/filedetails/?id=733998434"
#define DEAD_HOTEL_URL "https://steamcommunity.com/sharedfiles/filedetails/?id=1898421157"

#define FLOOD_DELAY 4.0

bool  g_bPrintTip       [MAXPLAYERS + 1];
bool  g_bPrintWelcome   [MAXPLAYERS + 1];
bool  g_bIsPlayerStarted[MAXPLAYERS + 1];
bool  g_bIsFair         [MAXPLAYERS + 1];
float g_fTime           [MAXPLAYERS + 1];
float g_fAntiFloodTime  [MAXPLAYERS + 1];

float g_vPlayerPos[MAXPLAYERS + 1][3];
float g_vPlayerAng[MAXPLAYERS + 1][3];

float g_vSpawnPos[3];
float g_vSpawnAng[3];

char g_szInfoPath[PLATFORM_MAX_PATH];
int  g_iGameType;
enum /* g_iGameType */ {
    eDeadAirSurf,
    eVertigo,
    eDeadHotel
};

public Plugin myinfo = {
    name        = "Surf Maps Tools",
    author      = "elias",
    description = "SourceMod tools for Surf maps.",
    version     = "1.0.0",
    url         = "https://solaris-servers.ru/"
}

public void OnPluginStart() {
    RegConsoleCmd("sm_save",    Cmd_Save);
    RegConsoleCmd("sm_tp",      Cmd_Teleport);
    RegConsoleCmd("sm_reset",   Cmd_Reset);
    RegConsoleCmd("sm_top",     Cmd_Leaderboard);
    RegConsoleCmd("sm_current", Cmd_Current);
    RegConsoleCmd("sm_help",    Cmd_Help);

    HookEvent("player_bot_replace", OnGameEvent);
    HookEvent("bot_player_replace", OnGameEvent);
    HookEvent("player_spawn",       OnGameEvent);
    HookEvent("player_disconnect",  OnGameEvent);

    HookEntityOutput("trigger_multiple", "OnStartTouch", OnEntityOutput);
    HookEntityOutput("trigger_teleport", "OnStartTouch", OnEntityOutput);
}

//========================================================================================================================
// Hooks
//========================================================================================================================

public void OnMapStart() {
    static char szMap[64];
    GetCurrentMap(szMap, sizeof(szMap));

    PrecacheSounds();

    if (strcmp(szMap, "c11m5_runway") == 0) {
        RunVScript("vs_das.nut");

        g_iGameType = eDeadAirSurf;
        strcopy(g_szInfoPath, sizeof(g_szInfoPath), DAS_TOP);

        g_vSpawnPos[0] = -14550.0;
        g_vSpawnPos[1] = -16050.0;
        g_vSpawnPos[2] =  8000.0;

        g_vSpawnAng[0] = 0.0;
        g_vSpawnAng[1] = 0.0;
        g_vSpawnAng[2] = 0.0;
    }

    if (strcmp(szMap, "c8m5_rooftop") == 0) {
        RunVScript("vs_vertigo.nut");

        g_iGameType = eVertigo;
        strcopy(g_szInfoPath, sizeof(g_szInfoPath), VERTIGO_TOP);

        g_vSpawnPos[0] = 9100.0;
        g_vSpawnPos[1] = 8551.0;
        g_vSpawnPos[2] = 197.0;

        g_vSpawnAng[0] = 0.0;
        g_vSpawnAng[1] = 180.0;
        g_vSpawnAng[2] = 0.0;
    }

    if (strcmp(szMap, "c1m1_hotel") == 0) {
        RunVScript("vs_dead_hotel.nut");
        CreateTimer(30.0, Timer_OneMoreFix, _, TIMER_FLAG_NO_MAPCHANGE);

        g_iGameType = eDeadHotel;
        strcopy(g_szInfoPath, sizeof(g_szInfoPath), DEAD_HOTEL_TOP);

        g_vSpawnPos[0] = 1761.374;
        g_vSpawnPos[1] = 4608.337;
        g_vSpawnPos[2] = 1184.031;

        g_vSpawnAng[0] = 0.0;
        g_vSpawnAng[1] = 180.0;
        g_vSpawnAng[2] = 0.0;
    }
}

void PrecacheSounds() {
    PrecacheSound("buttons/blip1.wav");
    PrecacheSound("buttons/button11.wav");
    PrecacheSound("npc/moustachio/strengthlvl1_littlepeanut.wav");
    PrecacheSound("npc/moustachio/strengthlvl2_babypeanut.wav");
    PrecacheSound("npc/moustachio/strengthlvl3_oldpeanut.wav");
    PrecacheSound("npc/moustachio/strengthlvl4_notbad.wav");
    PrecacheSound("npc/moustachio/strengthlvl5_sostrong.wav");
}

Action Timer_OneMoreFix(Handle hTimer) {
    RunVScript("skipintro.nut");
    return Plugin_Handled;
}

public void OnClientPutInServer(int iClient) {
    g_bPrintTip       [iClient] = true;
    g_bPrintWelcome   [iClient] = true;
    g_bIsPlayerStarted[iClient] = false;
}

void OnGameEvent(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (strcmp(szName, "player_bot_replace") == 0) {
        int iBot = GetClientOfUserId(eEvent.GetInt("bot"));
        TeleportEntity(iBot, g_vSpawnPos, g_vSpawnAng, NULL_VELOCITY);
    }

    if (strcmp(szName, "bot_player_replace") == 0) {
        int iClient = GetClientOfUserId(eEvent.GetInt("player"));
        TeleportEntity(iClient, g_vSpawnPos, g_vSpawnAng, NULL_VELOCITY);
        g_bIsFair[iClient] = false;
    }

    if (strcmp(szName, "player_spawn") == 0) {
        int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
        if (iClient <= 0)
            return;

        if (!IsClientInGame(iClient))
            return;

        if (!IsFakeClient(iClient))
            CreateTimer(5.0, Timer_Welcome, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);

        if (GetClientTeam(iClient) == 2)
            AcceptEntityInput(iClient, "DisableLedgeHang");

        TeleportEntity(iClient, g_vSpawnPos, g_vSpawnAng, NULL_VELOCITY);
    }

    if (strcmp(szName, "player_disconnect") == 0) {
        int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
        g_bPrintTip       [iClient] = true;
        g_bPrintWelcome   [iClient] = true;
        g_bIsPlayerStarted[iClient] = false;
    }
}

Action Timer_Welcome(Handle hTimer, any aUserId) {
    Print_WelcomeMessage(aUserId);
    return Plugin_Handled;
}

void Print_WelcomeMessage(int iUserId) {
    int iClient = GetClientOfUserId(iUserId);
    if (iClient <= 0)
        return;

    if (!IsClientInGame(iClient))
        return;

    if (!g_bPrintWelcome[iClient])
        return;

    switch (g_iGameType) {
        case eDeadAirSurf: {
            CPrintToChat(iClient, "Dead Air Surf {blue}v%s.", DAS_VER);
            CPrintToChat(iClient, "This map is made out of props and included into {blue}c11m5_runway{default} for fun races.");
            CPrintToChat(iClient, "{blue}!tp{default} — Teleport to start. {blue}!js{default} — Join survivors team. {blue}!top{default} — Show the Leaderboard.");
            CPrintToChat(iClient, "{olive}Link: {blue}%s", DAS_URL);
        }
        case eVertigo: {
            CPrintToChat(iClient, "Vertigo {blue}v%s.", VERTIGO_VER);
            CPrintToChat(iClient, "This map is made out of props and included into {blue}c8m5_rooftop{default}.");
            CPrintToChat(iClient, "{blue}!save{default} — Save your position. {blue}!tp{default} — Teleport to saved position. {blue}!js{default} — Join survivors team.");
            CPrintToChat(iClient, "{blue}!reset{default} — Teleport to start. {blue}!top{default} — Show the Leaderboard. {blue}!current{default} — Show current info.");
            CPrintToChat(iClient, "{olive}Link: {blue}%s", VERTIGO_URL);
        }
        case eDeadHotel: {
            CPrintToChat(iClient, "Dead Hotel {blue}v%s.", DEAD_HOTEL_VER);
            CPrintToChat(iClient, "This map is made out of props and included into {blue}c1m1_hotel{default}.");
            CPrintToChat(iClient, "{blue}!save{default} — Save your position. {blue}!tp{default} — Teleport to saved position. {blue}!js{default} — Join survivors team.");
            CPrintToChat(iClient, "{blue}!reset{default} — Teleport to start. {blue}!top{default} — Show the Leaderboard. {blue}!current{default} — Show current info.");
            CPrintToChat(iClient, "{olive}Link: {blue}%s", DEAD_HOTEL_URL);
        }
    }

    g_bPrintWelcome[iClient] = false;
}

void OnEntityOutput(const char[] szOutput, int iEntity, int iClient, float fDelay) {
    if (iClient <= 0)
        return;

    if (iClient > MaxClients)
        return;

    if (IsFakeClient(iClient))
        return;

    char szEntName[64];
    GetEntPropString(iEntity, Prop_Data, "m_iName", szEntName, sizeof(szEntName));

    switch (g_iGameType) {
        case eDeadAirSurf: {
            if (strcmp(szEntName, "trigger_start") == 0) {
                if (g_bPrintTip[iClient]) {
                    PrintHintText(iClient, "Hold space to jump.");
                    CPrintToChat(iClient, " {green}»{default} Type in chat {olive}!tp{default} to teleport to start.");
                    CPrintToChat(iClient, " {green}»{default} Type in chat {blue}!top{default} to show the Leaderboard.");
                    g_bPrintTip[iClient] = false;
                }

                EmitSoundToClient(iClient, "buttons/blip1.wav");
                g_bIsPlayerStarted[iClient] = true;
                g_bIsFair         [iClient] = true;
                g_fTime           [iClient] = GetGameTime();
            } else if (strcmp(szEntName, "trigger_teleport1") == 0 || strcmp(szEntName, "trigger_teleport2") == 0) {
                TeleportEntity(iClient, g_vSpawnPos, g_vSpawnAng, NULL_VELOCITY);
                EmitSoundToClient(iClient, "buttons/button11.wav");
            } else if (strcmp(szEntName, "trigger_cp1") == 0 || strcmp(szEntName, "trigger_cp2") == 0 || strcmp(szEntName, "trigger_cp3") == 0) {
                if (!g_bIsPlayerStarted[iClient])
                    return;

                float fTime = GetGameTime() - g_fTime[iClient];
                PrintHintText(iClient, "%.03fs", fTime);
                EmitSoundToClient(iClient, "buttons/blip1.wav");
            } else if (strcmp(szEntName, "trigger_finish") == 0) {
                if (!g_bIsPlayerStarted[iClient])
                    return;

                g_bIsPlayerStarted[iClient] = false;
                float fTime = GetGameTime() - g_fTime[iClient];
                TeleportEntity(iClient, g_vSpawnPos, g_vSpawnAng, NULL_VELOCITY);

                if (!g_bIsFair[iClient]) {
                    CPrintToChat(iClient, "{olive}You{default} are suspected in {red}cheating{default}, results are not saved!");
                } else {
                    Func_SaveToFile(iClient, fTime);
                    Func_Leaderboard(iClient);
                    PrintHintText(iClient, "Finished in %.03fs.", fTime);
                    if (fTime < 80.0) {
                        CPrintToChatAll("{green}★★★ {blue}%N{default} finished the map in {blue}%.03f{default} seconds", iClient, fTime);
                        EmitSoundToClient(iClient, "npc/moustachio/strengthlvl5_sostrong.wav");
                    } else if (fTime < 90.0) {
                        CPrintToChatAll("{green}★★☆ {blue}%N{default} finished the map in {blue}%.03f{default} seconds", iClient, fTime);
                        EmitSoundToClient(iClient, "npc/moustachio/strengthlvl4_notbad.wav");
                    } else if (fTime < 100.0) {
                        CPrintToChatAll("{green}★★ {blue}%N{default} finished the map in {blue}%.03f{default} seconds", iClient, fTime);
                        EmitSoundToClient(iClient, "npc/moustachio/strengthlvl3_oldpeanut.wav");
                    } else if (fTime < 110.0) {
                        CPrintToChatAll("{green}★☆ {blue}%N{default} finished in the map {blue}%.03f{default} seconds", iClient, fTime);
                        EmitSoundToClient(iClient, "npc/moustachio/strengthlvl2_babypeanut.wav");
                    } else {
                        CPrintToChatAll("{green}★ {blue}%N{default} finished the map in {blue}%.03f{default} seconds", iClient, fTime);
                        EmitSoundToClient(iClient, "npc/moustachio/strengthlvl1_littlepeanut.wav");
                    }
                }
            }
        }
        case eVertigo: {
            if (strcmp(szEntName, "trigger_start") == 0) {
                if (g_bPrintTip[iClient]) {
                    PrintHintText(iClient, "Hold space to jump.");
                    CPrintToChat(iClient, " {green}»{default} Type in chat {olive}!save{default} to save your position and {blue}!tp{default} to teleport.");
                    CPrintToChat(iClient, " {green}»{default} Type in chat {blue}!top{default} to show the Leaderboard.");
                    g_bPrintTip[iClient] = false;
                }

                GetClientAbsOrigin(iClient, g_vPlayerPos[iClient]);
                GetClientEyeAngles(iClient, g_vPlayerAng[iClient]);
                EmitSoundToClient(iClient, "buttons/blip1.wav");

                g_bIsPlayerStarted[iClient] = true;
                g_fTime           [iClient] = GetGameTime();
                g_bIsFair         [iClient] = true;
            } else if (strcmp(szEntName, "trigger_teleport1") == 0) {
                g_bIsPlayerStarted[iClient] = false;
            } else if (strcmp(szEntName, "trigger_teleport2") == 0 || strcmp(szEntName, "trigger_teleport3") == 0 || strcmp(szEntName, "trigger_teleport4") == 0 || strcmp(szEntName, "trigger_teleport5") == 0) {
                if (!g_bIsPlayerStarted[iClient])
                    return;

                float fTime = GetGameTime() - g_fTime[iClient];
                PrintHintText(iClient, "%.03fs\nRun status: %s", fTime, g_bIsFair[iClient] ? "Fair" : "Not Fair");
                EmitSoundToClient(iClient, "buttons/blip1.wav");
            } else if (strcmp(szEntName, "trigger_finish") == 0) {
                if (!g_bIsPlayerStarted[iClient])
                    return;

                g_bIsPlayerStarted[iClient] = false;
                float fTime = GetGameTime() - g_fTime[iClient];
                TeleportEntity(iClient, g_vSpawnPos, g_vSpawnAng, NULL_VELOCITY);

                if (!g_bIsFair[iClient]) {
                    CPrintToChat(iClient, "{olive}You{default} are suspected in {red}cheating{default}, results are not saved.");
                } else {
                    Func_SaveToFile(iClient, fTime);
                    Func_Leaderboard(iClient);
                    PrintHintText(iClient, "Finished in %.03fs.", fTime);
                    CPrintToChatAll(" {green}»{default} {blue}%N{default} finished the map in {blue}%.03f{default} seconds!", iClient, fTime);
                    EmitSoundToClient(iClient, "npc/moustachio/strengthlvl5_sostrong.wav");
                }
            }
        }
        case eDeadHotel: {
            if (strcmp(szEntName, "trigger_teleport1") == 0) {
                g_bIsPlayerStarted[iClient] = false;
            } else if (strcmp(szEntName, "trigger_elevator") == 0) {
                if (iClient <= 0)
                    return;

                if (!g_bIsPlayerStarted[iClient])
                    return;

                float fTime = GetGameTime() - g_fTime[iClient];
                PrintHintText(iClient, "%.03fs\nRun status: %s", fTime, g_bIsFair[iClient] ? "Fair" : "Not Fair");
                EmitSoundToClient(iClient, "buttons/blip1.wav");

                float vPlayerPos[3] = {2653.326, 5217.459, 3297.093};
                float vPlayerAng[3] = {0.0, 90.0, 0.0};
                TeleportEntity(iClient, vPlayerPos, vPlayerAng, NULL_VELOCITY);
            } else if (strcmp(szEntName, "trigger_start") == 0) {
                if (g_bPrintTip[iClient]) {
                    PrintHintText(iClient, "Hold space to jump.");
                    CPrintToChat(iClient, " {green}»{default} Type in chat {olive}!save{default} to save your position and {blue}!tp{default} to teleport.");
                    CPrintToChat(iClient, " {green}»{default} Type in chat {blue}!top{default} to show the Leaderboard.");
                    g_bPrintTip[iClient] = false;
                }

                GetClientAbsOrigin(iClient, g_vPlayerPos[iClient]);
                GetClientEyeAngles(iClient, g_vPlayerAng[iClient]);
                EmitSoundToClient(iClient, "buttons/blip1.wav");

                g_bIsPlayerStarted[iClient] = true;
                g_fTime           [iClient] = GetGameTime();
                g_bIsFair         [iClient] = true;
            } else if (strcmp(szEntName, "trigger_finish") == 0) {
                if (!g_bIsPlayerStarted[iClient])
                    return;

                g_bIsPlayerStarted[iClient] = false;
                float fTime = GetGameTime() - g_fTime[iClient];
                TeleportEntity(iClient, g_vSpawnPos, g_vSpawnAng, NULL_VELOCITY);

                if (!g_bIsFair[iClient]) {
                    CPrintToChat(iClient, "{olive}You{default} are suspected in {red}cheating{default}, results are not saved.");
                } else {
                    Func_SaveToFile(iClient, fTime);
                    Func_Leaderboard(iClient);
                    PrintHintText(iClient, "Finished in %.03fs.", fTime);
                    CPrintToChatAll(" {green}»{default} {blue}%N{default} finished the map in {blue}%.03f{default} seconds!", iClient, fTime);
                    EmitSoundToClient(iClient, "npc/moustachio/strengthlvl5_sostrong.wav");
                }
            }
        }
    }
}

//========================================================================================================================
// Funcs
//========================================================================================================================

void Func_SaveToFile(int iClient, float fTime) {
    char szName[512];
    GetClientName(iClient, szName, sizeof(szName));

    if (HasUnescapedFormat(szName, sizeof(szName)))
        EscapeFormatInString(szName, sizeof(szName));

    char szSteamId[512];
    GetClientAuthId(iClient, AuthId_SteamID64, szSteamId, sizeof(szSteamId));

    char szDate[512];
    FormatTime(szDate, sizeof(szDate), "%d/%m/%Y", GetTime());

    KeyValues kv = new KeyValues("Run_Top");
    if (kv.ImportFromFile(g_szInfoPath)) {
        if (kv.JumpToKey(szSteamId, true)) {
            char szText[512];
            kv.GetString("time", szText, sizeof(szText));
            if (strcmp(szText, "") == 0) {
                kv.SetString("name", szName);
                kv.SetFloat("time",  fTime);
                kv.SetString("date", szDate);
                kv.Rewind();
                kv.ExportToFile(g_szInfoPath);
                delete kv;
            } else if ((kv.GetFloat("time")) > fTime) {
                kv.SetString("name", szName);
                kv.SetFloat("time",  fTime);
                kv.SetString("date", szDate);
                kv.Rewind();
                kv.ExportToFile(g_szInfoPath);
                delete kv;
            }
        }
    } else {
        kv.JumpToKey(szSteamId, true);
        kv.SetString("name",   szName);
        kv.SetFloat("time",    fTime);
        kv.SetString("date",   szDate);
        kv.Rewind();
        kv.ExportToFile(g_szInfoPath);
        delete kv;
    }
}

void Func_Leaderboard(int iClient) {
    int   iPrintStep    = 10;
    float fCurrentTimer = 0.1;

    Panel mPanel = new Panel();
    mPanel.SetTitle("LEADERBOARD:");
    mPanel.DrawText(" ");

    ArrayList arrPanel   = new ArrayList(ByteCountToCells(1024));
    ArrayList arrConsole = new ArrayList(ByteCountToCells(1024));

    KeyValues kv = new KeyValues("Run_Top");
    if (kv.ImportFromFile(g_szInfoPath)) {
        if (kv.GotoFirstSubKey()) {
            do {
                char szSteam[512];
                kv.GetSectionName(szSteam, sizeof(szSteam));

                char szTime[512];
                kv.GetString("time", szTime, sizeof(szTime));

                char szName[512];
                kv.GetString("Name", szName, sizeof(szName));

                char szDate[512];
                kv.GetString("date", szDate, sizeof(szDate));

                char szInfoPanel[512];
                FormatEx(szInfoPanel, sizeof(szInfoPanel), "%.03fs %s %s", StringToFloat(szTime), szName, szDate);
                arrPanel.PushString(szInfoPanel);

                char szInfoConsole[512];
                FormatEx(szInfoConsole, sizeof(szInfoConsole), "%.03fs %s https://steamcommunity.com/profiles/%s %s", StringToFloat(szTime), szName, szSteam, szDate);
                arrConsole.PushString(szInfoConsole);
            } while (kv.GotoNextKey());
        }

        arrPanel.SortCustom(SortFunc);
        arrConsole.SortCustom(SortFunc);
    }

    int iPanelSize   = arrPanel.Length;
    int iConsoleSize = arrConsole.Length;

    PrintToConsole(iClient, "\n================================ Leaderboard ================================\n");

    if (iPanelSize   == 0) mPanel.DrawText("There is no data in file...");
    if (iConsoleSize == 0) PrintToConsole(iClient, "There is no data in file...");

    for (int i = 0; 10 > i < iPanelSize; i++) {
        char szBuffer [512];
        arrPanel.GetString(i, szBuffer, sizeof(szBuffer));

        char szToPanel[512];
        FormatEx(szToPanel, sizeof(szToPanel), "%d place. %s", i + 1, szBuffer);

        mPanel.DrawText(szToPanel);
    }

    for (int i = 0; 100 > i < iConsoleSize; i++) {
        char szToConsole[512];

        if (i == iPrintStep) {
            FormatEx(szToConsole, sizeof(szToConsole), "");
            DataPack dp = new DataPack();
            dp.WriteString(szToConsole);
            dp.WriteCell(GetClientUserId(iClient));
            CreateTimer(fCurrentTimer, Timer_PrintToConsole, dp);
            iPrintStep += 10;
            fCurrentTimer += 0.1;
        }

        char szBuffer[512];
        arrConsole.GetString(i, szBuffer, sizeof(szBuffer));

        FormatEx(szToConsole, sizeof(szToConsole), "%d place. %s", i + 1, szBuffer);
        DataPack dp = new DataPack();
        dp.WriteString(szToConsole);
        dp.WriteCell(GetClientUserId(iClient));
        CreateTimer(fCurrentTimer, Timer_PrintToConsole, dp);
        fCurrentTimer += 0.1;
    }

    DataPack dp = new DataPack();
    dp.WriteString("\n=============================================================================\n");
    dp.WriteCell(GetClientUserId(iClient));
    CreateTimer(fCurrentTimer, Timer_PrintToConsole, dp);

    mPanel.DrawText(" ");
    mPanel.SetKeys(10);
    mPanel.DrawItem("Exit", ITEMDRAW_CONTROL);

    if (IsClientInGame(iClient) && !IsFakeClient(iClient))
        mPanel.Send(iClient, DummyHandler, 60);

    delete arrPanel;
    delete arrConsole;
}

Action Timer_PrintToConsole(Handle hTimer, DataPack dp) {
    dp.Reset(false);

    char szToConsole[512];
    dp.ReadString(szToConsole, sizeof(szToConsole));

    int iClient = GetClientOfUserId(dp.ReadCell());
    if (iClient > 0 && IsClientInGame(iClient))
        PrintToConsole(iClient, "%s", szToConsole);

    delete dp;
    return Plugin_Stop;
}

int DummyHandler(Menu mMenu, MenuAction maAction, int iParam1, int iParam2) {
    /*Doesn't matter. It's just for Menu Panel*/
    return 0;
}

//========================================================================================================================
// Cmds
//========================================================================================================================

Action Cmd_Save(int iClient, int iArgs) {
    if (g_iGameType == eDeadAirSurf)
        return Plugin_Handled;

    if (iClient <= 0)
        return Plugin_Handled;

    if (!g_bIsPlayerStarted[iClient])
        return Plugin_Handled;

    GetClientAbsOrigin(iClient, g_vPlayerPos[iClient]);
    GetClientEyeAngles(iClient, g_vPlayerAng[iClient]);

    return Plugin_Handled;
}

Action Cmd_Teleport(int iClient, int iArgs) {
    if (iClient <= 0)
        return Plugin_Handled;

    if (g_iGameType == eDeadAirSurf) {
        Cmd_Reset(iClient, 0);
        return Plugin_Handled;
    }

    if (!g_bIsPlayerStarted[iClient])
        return Plugin_Handled;

    TeleportEntity(iClient, g_vPlayerPos[iClient], g_vPlayerAng[iClient], NULL_VELOCITY);
    return Plugin_Handled;
}

Action Cmd_Reset(int iClient, int iArgs) {
    if (iClient <= 0)
        return Plugin_Handled;

    TeleportEntity(iClient, g_vSpawnPos, g_vSpawnAng, NULL_VELOCITY);
    GetClientAbsOrigin(iClient, g_vPlayerPos[iClient]);
    GetClientEyeAngles(iClient, g_vPlayerAng[iClient]);
    g_bIsPlayerStarted[iClient] = false;

    return Plugin_Handled;
}

Action Cmd_Current(int iClient, int iArgs) {
    if (iClient <= 0)
        return Plugin_Handled;

    if (!g_bIsPlayerStarted[iClient])
        return Plugin_Handled;

    float fTime = GetGameTime() - g_fTime[iClient];
    PrintHintText(iClient, "%.03fs\nRun status: %s", fTime, g_bIsFair[iClient] ? "Fair" : "Not Fair");

    return Plugin_Handled;
}

Action Cmd_Help(int iClient, int iArgs) {
    if (iClient <= 0)
        return Plugin_Handled;

    switch (g_iGameType) {
        case eDeadAirSurf: {
            CPrintToChat(iClient, "Dead Air Surf v{blue}%s", DAS_VER);
            CPrintToChat(iClient, "This map is made out of props and included into {blue}c11m5_runway{default} for fun races.");
            CPrintToChat(iClient, "{blue}!tp{default} — Teleport to start. {blue}!js{default} — Join survivors team. {blue}!top{default} — Show the Leaderboard.");
            CPrintToChat(iClient, "{olive}Link: {blue}%s", DAS_URL);
        }
        case eVertigo: {
            CPrintToChat(iClient, "Vertigo v{blue}%s.", VERTIGO_VER);
            CPrintToChat(iClient, "This map is made out of props and included into {blue}c8m5_rooftop{default}.");
            CPrintToChat(iClient, "{blue}!save{default} — Save your position. {blue}!tp{default} — Teleport to saved position. {blue}!js{default} — Join survivors team.");
            CPrintToChat(iClient, "{blue}!reset{default} — Teleport to start. {blue}!top{default} — Show the Leaderboard. {blue}!current{default} — Show current info.");
            CPrintToChat(iClient, "{olive}Link: {blue}%s", VERTIGO_URL);
        }
        case eDeadHotel: {
            CPrintToChat(iClient, "Dead Hotel v{olive}%s", DEAD_HOTEL_VER);
            CPrintToChat(iClient, "This map is made out of props and included into {olive}c1m1_hotel{default}.");
            CPrintToChat(iClient, "{olive}!save{default} — Save your position. {olive}!tp{default} — Teleport to saved position. {olive}!js{default} — Join survivors team.");
            CPrintToChat(iClient, "{olive}!reset{default} — Teleport to start. {olive}!top{default} — Show the Leaderboard. {olive}!current{default} — Show current info.");
            CPrintToChat(iClient, "{olive}Link: {blue}%s", DEAD_HOTEL_URL);
        }
    }

    return Plugin_Handled;
}

Action Cmd_Leaderboard(int iClient, int iArgs) {
    if (iClient <= 0)
        return Plugin_Handled;

    if ((GetGameTime() - g_fAntiFloodTime[iClient]) > FLOOD_DELAY) {
        g_fAntiFloodTime[iClient] = GetGameTime();
        Func_Leaderboard(iClient);
    }

    return Plugin_Handled;
}

//========================================================================================================================
//  Stocks
//========================================================================================================================

stock void RunVScript(const char[] szName) {
    int iEnt = CreateEntityByName("logic_script");
    if (iEnt == -1)
        return;

    DispatchKeyValue(iEnt, "vscripts", szName);
    DispatchSpawn(iEnt);
    SetVariantString("OnUser1 !self:RunScriptCode::0:-1");
    AcceptEntityInput(iEnt, "AddOutput", -1, -1, 0);
    SetVariantString("OnUser1 !self:Kill::1:-1");
    AcceptEntityInput(iEnt, "AddOutput", -1, -1, 0);
    AcceptEntityInput(iEnt, "FireUser1", -1, -1, 0);
}

stock bool HasUnescapedFormat(const char[] szName, int iLength) {
    bool bLastCharQuote;
    for (int i = 0; i < iLength; i++) {
        if (szName[i] == '"')
            bLastCharQuote = true;

        if (bLastCharQuote && szName[i] != '"')
            return true;

        if (szName[i] == '\0' || (i + 1) >= iLength)
            return bLastCharQuote;
    }

    return bLastCharQuote;
}

stock void EscapeFormatInString(char[] szName, int iLength) {
    int  iParts = 1;
    char szTemp[256];
    char szSubstrArr[32][256];
    ExplodeString(szName, "\"", szSubstrArr, sizeof(szSubstrArr), 256, false);
    for (int i = 1, iLen = 0; i < sizeof(szSubstrArr); i++) {
        iLen = strlen(szSubstrArr[i]);
        iParts = iLen > 1 ? iParts + 1 : iParts;

        if (iLen > 1 && szSubstrArr[i][0] != '"') {
            strcopy(szTemp, sizeof(szTemp), szSubstrArr[i]);
            szSubstrArr[i] = "\"";
            StrCat(szSubstrArr[i], sizeof(szTemp), szTemp);
        }
    }

    ImplodeStrings(szSubstrArr, iParts, "\"", szName, iLength);
}

stock int SortFunc(int iIdx1, int iIdx2, Handle hArray, Handle hHndl) {
    char szItem1[512];
    view_as<ArrayList>(hArray).GetString(iIdx1, szItem1, sizeof(szItem1));

    char szItem2[512];
    view_as<ArrayList>(hArray).GetString(iIdx2, szItem2, sizeof(szItem2));

    if (StringToFloat(szItem1) < StringToFloat(szItem2)) {
        return -1;
    } else if (StringToFloat(szItem1) > StringToFloat(szItem2)) {
        return 1;
    } else {
        return 0;
    }
}