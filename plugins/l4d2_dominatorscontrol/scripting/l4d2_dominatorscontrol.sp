#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>

#define NUM_SI_CLASSES     6
#define DOMINATORS_DEFAULT 53

ConVar  g_cvDominators;
int     g_iDominators = DOMINATORS_DEFAULT;
Address g_pDominatorsAddress = Address_Null;

public Plugin myinfo = {
    name        = "Dominators Control",
    author      = "vintik",
    description = "Changes bIsDominator flag for infected classes. Allows to have native-order quad-caps.",
    version     = "1.1",
    url         = "https://bitbucket.org/vintik/various-plugins"
}

public void OnPluginStart() {
    GameData gmConf = new GameData("l4d2_dominators");
    if (!gmConf) SetFailState("File 'l4d2_dominators' was not found!");
    g_pDominatorsAddress = gmConf.GetAddress("bIsDominator");
    if (g_pDominatorsAddress == Address_Null) SetFailState("Couldn't find 'bIsDominator' signature!");
    delete gmConf;

    g_cvDominators = CreateConVar(
    "l4d2_dominators", "53",
    "Which infected class is considered as dominator (bitmask: 1 - smoker, 2 - boomer, 4 - hunter, 8 - spitter, 16 - jockey, 32 - charger)",
    FCVAR_NONE, true, 0.0, true, 63.0);
    g_iDominators = g_cvDominators.IntValue;
    g_cvDominators.AddChangeHook(ConVarChanged_Dominators);

    SetDominators();
}

public void OnPluginEnd() {
    g_iDominators = DOMINATORS_DEFAULT;
    SetDominators();
}

void ConVarChanged_Dominators(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iDominators = g_cvDominators.IntValue;
    SetDominators();
    
}

void SetDominators() {
    bool bIsDominator;
    for (int i = 0; i < NUM_SI_CLASSES; i++) {
        bIsDominator = (((1 << i) & g_iDominators) != 0);
        StoreToAddress(g_pDominatorsAddress + view_as<Address>(i), view_as<int>(bIsDominator), NumberType_Int8);
    }
}