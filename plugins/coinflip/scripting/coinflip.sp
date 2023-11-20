#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>

#define MAX_NUMBERS 20

ConVar g_cvDelayTime;
int    g_iDelayTime;

public Plugin myinfo = {
    name        = "Coinflip/Teamflip/8Ball/",
    author      = "purpletreefactory, epilimic, spoon",
    description = "Coinflip/Teamflip/8Ball",
    version     = "1.0.0",
    url         = "http://www.sourcemod.net/"
}

public void OnPluginStart() {
    g_cvDelayTime = CreateConVar(
    "coinflip_delay", "-1",
    "Time delay in seconds between allowed coinflips. Set at -1 if no delay at all is desired.",
    FCVAR_NONE, true, -1.0, false, 0.0);
    g_iDelayTime = g_cvDelayTime.IntValue;
    g_cvDelayTime.AddChangeHook(ConVarChanged_DelayTime);

    RegConsoleCmd("sm_coinflip",   Cmd_CoinFlip);
    RegConsoleCmd("sm_cf",         Cmd_CoinFlip);
    RegConsoleCmd("sm_flip",       Cmd_CoinFlip);

    RegConsoleCmd("sm_roll",       Cmd_PickNumber);
    RegConsoleCmd("sm_picknumber", Cmd_PickNumber);

    RegConsoleCmd("sm_teamflip",   Cmd_TeamFlip);
    RegConsoleCmd("sm_tf",         Cmd_TeamFlip);

    RegConsoleCmd("sm_8ball",      Cmd_8Ball);
}

void ConVarChanged_DelayTime(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iDelayTime = g_cvDelayTime.IntValue;
}

Action Cmd_CoinFlip(int iClient, int iArgs) {
    static int iPrevCmdTime = 0;
    static int iCurrCmdTime = 0;
    iCurrCmdTime = GetTime();

    // Only perform a numberpick if enough time has passed since the last one.
    if ((iCurrCmdTime - iPrevCmdTime) < g_iDelayTime)
        return Plugin_Handled;

    SetRandomSeed(iCurrCmdTime);
    int iResult = GetRandomInt(0, 1); // Generates a random number
    CPrintToChatAllEx(iClient, "{green}[{default}Coin flip{green}] {teamcolor}%N{default} flipped a coin!\nIt's {teamcolor}%s{default}!", iClient, iResult ? "Tails" : "Heads");
    iPrevCmdTime = iCurrCmdTime; // Update the previous time
    return Plugin_Handled;
}

Action Cmd_PickNumber(int iClient, int iArgs) {
    static int iPrevCmdTime = 0;
    static int iCurrCmdTime = 0;
    iCurrCmdTime = GetTime();

    // Only perform a numberpick if enough time has passed since the last one.
    if ((iCurrCmdTime - iPrevCmdTime) < g_iDelayTime)
        return Plugin_Handled;

    int iMaxNumber = MAX_NUMBERS;

    if (iArgs > 0) {
        char szArg[32];
        GetCmdArg(1, szArg, sizeof(szArg));
        iMaxNumber = StringToInt(szArg);
        if (iMaxNumber > 100) iMaxNumber = 100;
    }

    SetRandomSeed(iCurrCmdTime);
    int iResult = GetRandomInt(1, iMaxNumber); // Generates a random number
    CPrintToChatAllEx(iClient, "{green}[{default}Coin flip{green}] {teamcolor}%N{default} rolled a {olive}%d{default} sided die!\nIt's {teamcolor}%d{default}!", iClient, iMaxNumber, iResult);
    iPrevCmdTime = iCurrCmdTime; // Update the previous time
    return Plugin_Handled;
}

Action Cmd_TeamFlip(int iClient, int iArgs) {
    static int iPrevCmdTime = 0;
    static int iCurrCmdTime = 0;
    iCurrCmdTime = GetTime();

    // Only perform a numberpick if enough time has passed since the last one.
    if ((iCurrCmdTime - iPrevCmdTime) < g_iDelayTime)
        return Plugin_Handled;

    SetRandomSeed(iCurrCmdTime);
    int iResult = GetRandomInt(0, 1); // Generates a random number
    CPrintToChatAllEx(iClient, "{green}[{default}Team Flip{green}] {teamcolor}%N{default} flipped a team and is on the %s team!", iClient, iResult ? "{green}Infected{default}" : "{olive}Survivor{default}");
    iPrevCmdTime = iCurrCmdTime; // Update the previous time
    return Plugin_Handled;
}

Action Cmd_8Ball(int iClient, int iArgs) {
    static int iPrevCmdTime = 0;
    static int iCurrCmdTime = 0;
    iCurrCmdTime = GetTime();

    // Only perform a numberpick if enough time has passed since the last one.
    if ((iCurrCmdTime - iPrevCmdTime) < g_iDelayTime)
        return Plugin_Handled;

    if (iArgs == 0) {
        CPrintToChat(iClient, "{green}[{default}8 Ball{green}]{default} Usage: !8ball <question>");
        return Plugin_Handled;
    }

    char szQuestion[192];
    GetCmdArgString(szQuestion, sizeof(szQuestion));
    StripQuotes(szQuestion);

    SetRandomSeed(iCurrCmdTime);
    int iResult = GetRandomInt(1, 6); // Generates a random number

    CPrintToChatAllEx(iClient, "{green}[{default}8Ball{green}] {teamcolor}%N{default} asked: {olive}%s", iClient, szQuestion);
    switch (iResult) {
        case 1: CPrintToChatAllEx(iClient, "{green}[{default}8 Ball{green}]{default} I'm going with {teamcolor}Yes{default}!");
        case 2: CPrintToChatAllEx(iClient, "{green}[{default}8 Ball{green}]{default} I'm going with a {teamcolor}No{default}!");
        case 3: CPrintToChatAllEx(iClient, "{green}[{default}8 Ball{green}]{default} Yikes. {teamcolor}No{default}!");
        case 4: CPrintToChatAllEx(iClient, "{green}[{default}8 Ball{green}]{default} Uhhhhh... {teamcolor}Sure{default}?");
        case 5: CPrintToChatAllEx(iClient, "{green}[{default}8 Ball{green}]{default} LOL {teamcolor}Absolutely Not{default}!");
        case 6: CPrintToChatAllEx(iClient, "{green}[{default}8 Ball{green}]{default} You know what? {teamcolor}Yeah{default}!");
    }

    return Plugin_Handled;
}