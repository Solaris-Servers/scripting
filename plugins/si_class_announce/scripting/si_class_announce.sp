#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <l4d2util>
#include <colors>
#include <readyup>

#define MAXSPAWNS 8

public Plugin myinfo = {
    name        = "Special Infected Class Announce",
    author      = "Tabun, Forgetest",
    description = "Report what SI classes are up when the round starts.",
    version     = "1.0.4",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework"
}

public void OnRoundIsLive() {
    AnnounceSIClasses();
}

void AnnounceSIClasses() {
    // Get currently active SI classes
    int iSpawns;
    int iSpawnCls[MAXSPAWNS];
    for (int i = 1; i <= MaxClients && iSpawns < MAXSPAWNS; i++) {
        if (!IsClientInGame(i))
            continue;

        if (GetClientTeam(i) != L4D2Team_Infected)
            continue;

        if (!IsPlayerAlive(i))
            continue;

        iSpawnCls[iSpawns] = GetInfectedClass(i);
        iSpawns++;
    }

    if (!iSpawns)
        return;

    // print classes, according to amount of spawns found
    char szPrint[256];
    for (int i = 0; i < iSpawns; i++) {
        Format(szPrint, sizeof(szPrint), "%s%s{red}%s{default}", szPrint, i > 0 ? ", " : "", L4D2_InfectedNames[iSpawnCls[i]]);
    }
    PrintToSurvivors("{olive}Special Infected: %s.", szPrint);
}

void PrintToSurvivors(const char[] szMessage, any ... ) {
    char szPrint[256];
    VFormat(szPrint, sizeof(szPrint), szMessage, 2);

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            continue;

        if (GetClientTeam(i) != L4D2Team_Survivor)
            continue;

        CPrintToChat(i, "%s", szPrint);
    }
}