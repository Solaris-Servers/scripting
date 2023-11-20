#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define KV_MAPCVAR      "/mapcvars.txt"
#define MAX_CONFIG_LEN  128
#define MAX_VARLENGTH   64
#define MAX_VALUELENGTH 128
#define MAX_SETVARS     64

KeyValues g_hKvOrig;
ConVar g_hUseConfigDir;
char g_sUseConfigDir[MAX_CONFIG_LEN];

public Plugin myinfo =
{
    name        = "L4D(2) map-based convar loader.",
    author      = "Tabun",
    version     = "0.1b",
    description = "Loads convars on map-load, based on currently active map and confogl config."
};

public void OnPluginStart()
{
    g_hUseConfigDir = CreateConVar("l4d_mapcvars_configdir", "", "Which cfgogl config are we using?");
    g_hUseConfigDir.GetString(g_sUseConfigDir, MAX_CONFIG_LEN);
    g_hUseConfigDir.AddChangeHook(CvarConfigChange);

    // prepare KV for saving old states
    g_hKvOrig = new KeyValues("MapCvars_Orig"); // store original values
}

public void OnPluginEnd()
{
    ResetMapPrefs();

    if (g_hKvOrig != null)
    {
        delete g_hKvOrig;
    }
}

public void CvarConfigChange(ConVar cvar, const char[] oldValue, const char[] newValue)
{
    strcopy(g_sUseConfigDir, MAX_CONFIG_LEN, newValue);
    ResetMapPrefs();    // reset old
    GetThisMapPrefs();  // apply new
}

public void OnMapStart()
{
    GetThisMapPrefs();
}

public void OnMapEnd()
{
    ResetMapPrefs();
}

public int GetThisMapPrefs()
{
    int iNumChanged = 0; // how many cvars were changed for this map

    // reopen original keyvalues for clean slate:
    if (g_hKvOrig != null)
    {
        delete g_hKvOrig;
    }

    g_hKvOrig = new KeyValues("MapCvars_Orig"); // store original values for this map

    // build path to current config's keyvalues file
    char usePath[PLATFORM_MAX_PATH];

    if (strlen(g_sUseConfigDir) > 0)
    {
        usePath = "../../cfg/cfgogl/";
        StrCat(usePath, PLATFORM_MAX_PATH, g_sUseConfigDir);
        StrCat(usePath, PLATFORM_MAX_PATH, KV_MAPCVAR);
    }
    else
    {
        usePath = "../../cfg";
        StrCat(usePath, PLATFORM_MAX_PATH, KV_MAPCVAR);
    }

    BuildPath(Path_SM, usePath, sizeof(usePath), usePath);

    if (!FileExists(usePath))
    {
        return 0;
    }

    KeyValues hKv = new KeyValues("MapCvars");
    hKv.ImportFromFile(usePath);

    if (hKv == null)
    {
        delete hKv;
        return 0;
    }

    // read keyvalues for current map
    char sMapName[64];
    GetCurrentMap(sMapName, sizeof(sMapName));

    if (!hKv.JumpToKey(sMapName))
    {
        // no special settings for this map
        delete hKv;
        return 0;
    }

    // find all cvar keys and save the original values
    // then execute the change
    char tmpKey[MAX_VARLENGTH];
    char tmpValueNew[MAX_VALUELENGTH];
    char tmpValueOld[MAX_VALUELENGTH];
    ConVar hConVar;

    if (hKv.GotoFirstSubKey(false)) // false to get values
    {
        do
        {
            // read key stuff
            hKv.GetSectionName(tmpKey, sizeof(tmpKey)); // the subkey is a key-value pair, so get this to get the 'convar'

            // is it a convar?
            hConVar = FindConVar(tmpKey);

            if (hConVar != null)
            {
                hKv.GetString(NULL_STRING, tmpValueNew, sizeof(tmpValueNew), "[:none:]");

                // read, save and set value
                if (!StrEqual(tmpValueNew,"[:none:]"))
                {
                    hConVar.GetString(tmpValueOld, sizeof(tmpValueOld));
                    PrintToServer("[mcv] cvar value changed: [%s] => [%s] (saved old: [%s]))", tmpKey, tmpValueNew, tmpValueOld);

                    if (!StrEqual(tmpValueNew,tmpValueOld))
                    {
                        // different, save the old
                        iNumChanged++;
                        g_hKvOrig.SetString(tmpKey, tmpValueOld);

                        // apply the new
                        hConVar.SetString(tmpValueNew);
                    }
                }
            }
        }
        while (hKv.GotoNextKey(false));
    }

    g_hKvOrig.SetString("__EOF__", "1"); // a test-safeguard
    delete hKv;
    delete hConVar;
    return iNumChanged;
}

public void ResetMapPrefs()
{
    g_hKvOrig.Rewind();

    // find all cvar keys and reset to original values
    char tmpKey[64];
    char tmpValueOld[512];
    ConVar hConVar;

    if (g_hKvOrig.GotoFirstSubKey(false)) // false to get values
    {
        do
        {
            // read key stuff
            g_hKvOrig.GetSectionName(tmpKey, sizeof(tmpKey)); // the subkey is a key-value pair, so get this to get the 'convar'

            if (StrEqual(tmpKey, "__EOF__"))
            {
                break;
            }
            else
            {
                // is it a convar?
                hConVar = FindConVar(tmpKey);

                if (hConVar != null)
                {
                    g_hKvOrig.GetString(NULL_STRING, tmpValueOld, sizeof(tmpValueOld), "[:none:]");

                    // read, save and set value
                    if (!StrEqual(tmpValueOld,"[:none:]"))
                    {
                        // reset the old
                        hConVar.SetString(tmpValueOld);
                        PrintToServer("[mcv] cvar value reset to original: [%s] => [%s])", tmpKey, tmpValueOld);
                    }
                }
            }
        }
        while (g_hKvOrig.GotoNextKey(false));
    }

    delete hConVar;
}