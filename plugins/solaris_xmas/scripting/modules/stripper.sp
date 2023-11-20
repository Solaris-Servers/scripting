#if defined __STRIPPER__
    #endinput
#endif
#define __STRIPPER__

#include <regex>

/*
public Plugin myinfo = {
    name        = "Stripper:Source (SP edition)",
    version     = "1.3.0",
    description = "Stripper:Source functionality in a Sourcemod plugin",
    author      = "tilgep, Stripper:Source by BAILOPAN",
    url         = "https://forums.alliedmods.net/showthread.php?t=339448"
}
*/

enum Mode {
    Mode_None,
    Mode_Filter,
    Mode_Add,
    Mode_Modify,
}

enum SubMode {
    SubMode_None,
    SubMode_Match,
    SubMode_Replace,
    SubMode_Delete,
    SubMode_Insert,
}

enum struct Property {
    char szKey[PLATFORM_MAX_PATH];
    char szVal[PLATFORM_MAX_PATH];
    bool bRegex;
}

/* Stripper block struct */
enum struct Block {
    Mode eMode;
    SubMode eSubMode;
    ArrayList arrMatch;    // Filter/Modify
    ArrayList arrReplace;  // Modify
    ArrayList arrDel;      // Modify
    ArrayList arrInsert;   // Add/Modify
    bool bHasClsName;      // Ensures that an add block has a classname set

    void Init() {
        this.eMode = Mode_None;
        this.eSubMode = SubMode_None;
        this.arrMatch = new ArrayList(sizeof(Property));
        this.arrReplace = new ArrayList(sizeof(Property));
        this.arrDel = new ArrayList(sizeof(Property));
        this.arrInsert = new ArrayList(sizeof(Property));
    }

    void Clear() {
        this.bHasClsName = false;
        this.eMode = Mode_None;
        this.eSubMode = SubMode_None;
        this.arrMatch.Clear();
        this.arrReplace.Clear();
        this.arrDel.Clear();
        this.arrInsert.Clear();
    }
}

int   g_iSection;
char  g_szFile[PLATFORM_MAX_PATH];
Block g_eProp; // Global current stripper block

void Stripper_OnModuleStart() {
    g_eProp.Init();
}

public void OnMapInit(const char[] szMapName) {
    BuildPath(Path_SM, g_szFile, sizeof(g_szFile), "configs/xmas/global_filters.cfg"); // Parse global filters
    ParseFile();
    strcopy(g_szFile, sizeof(g_szFile), szMapName); // Now parse map config
    BuildPath(Path_SM, g_szFile, sizeof(g_szFile), "configs/xmas/lights/%s.cfg", g_szFile);
    ParseFile();
}

/**
 * Parses a stripper config file
 *
 * @param path      Path to parse from
 */
public void ParseFile() {
    int iLine, iColumn;
    g_iSection = 0;

    g_eProp.Clear();

    SMCParser parser = SMC_CreateParser();
    SMC_SetReaders(parser, Config_NewSection, Config_KeyValue, Config_EndSection);

    SMCError result = SMC_ParseFile(parser, g_szFile, iLine, iColumn);
    delete parser;

    if (result != SMCError_Okay && result != SMCError_StreamOpen) {
        if (result == SMCError_StreamOpen) {
            LogMessage("Failed to open stripper config \"%s\"", g_szFile);
        } else {
            char szError[128];
            SMC_GetErrorString(result, szError, sizeof(szError));
            LogError("%s on line %d, col %d of %s", szError, iLine, iColumn, g_szFile);
        }
    }
}

public SMCResult Config_NewSection(SMCParser smc, const char[] name, bool opt_quotes) {
    g_iSection++;
    if (strcmp(name, "filter:", false) == 0 || strcmp(name, "remove:", false) == 0) {
        if (g_eProp.eMode != Mode_None)
            LogError("Found 'filter' block while inside another block at section %d in file '%s'", g_iSection, g_szFile);
        g_eProp.Clear();
        g_eProp.eMode = Mode_Filter;
    } else if (strcmp(name, "add:", false) == 0) {
        if (g_eProp.eMode != Mode_None)
            LogError("Found 'add' block while inside another block at section %d in file '%s'", g_iSection, g_szFile);
        g_eProp.Clear();
        g_eProp.eMode = Mode_Add;
    } else if (strcmp(name, "modify:", false) == 0) {
        if (g_eProp.eMode != Mode_None)
            LogError("Found 'modify' block while inside another block at section %d in file '%s'", g_iSection, g_szFile);
        g_eProp.Clear();
        g_eProp.eMode = Mode_Modify;
    } else if (g_eProp.eMode == Mode_Modify) {
        if      (strcmp(name, "match:",   false) == 0) g_eProp.eSubMode = SubMode_Match;
        else if (strcmp(name, "replace:", false) == 0) g_eProp.eSubMode = SubMode_Replace;
        else if (strcmp(name, "delete:",  false) == 0) g_eProp.eSubMode = SubMode_Delete;
        else if (strcmp(name, "insert:",  false) == 0) g_eProp.eSubMode = SubMode_Insert;
    }
    return SMCParse_Continue;
}

public SMCResult Config_KeyValue(SMCParser smc, const char[] szKey, const char[] szVal, bool key_quotes, bool value_quotes) {
    Property kv;
    strcopy(kv.szKey, PLATFORM_MAX_PATH, szKey);
    strcopy(kv.szVal, PLATFORM_MAX_PATH, szVal);
    kv.bRegex = FormatRegex(kv.szVal, strlen(szVal));

    switch (g_eProp.eMode) {
        case Mode_None:   return SMCParse_Continue;
        case Mode_Filter: g_eProp.arrMatch.PushArray(kv);
        case Mode_Add: {
            // Adding an entity without a classname will crash the server (shortest classname is "gib")
            if (strcmp(szKey, "classname", false) == 0 && strlen(szVal) > 2)
                g_eProp.bHasClsName = true;
            g_eProp.arrInsert.PushArray(kv);
        }
        case Mode_Modify: {
            switch (g_eProp.eSubMode) {
                case SubMode_Match   : g_eProp.arrMatch.PushArray(kv);
                case SubMode_Replace : g_eProp.arrReplace.PushArray(kv);
                case SubMode_Delete  : g_eProp.arrDel.PushArray(kv);
                case SubMode_Insert  : g_eProp.arrInsert.PushArray(kv);
            }
        }
    }
    return SMCParse_Continue;
}

public SMCResult Config_EndSection(SMCParser smc) {
    switch (g_eProp.eMode) {
        case Mode_Filter: {
            if (g_eProp.arrMatch.Length > 0)
                RunRemoveFilter();
            g_eProp.eMode = Mode_None;
        }
        case Mode_Add: {
            if (g_eProp.arrInsert.Length > 0) {
                if (g_eProp.bHasClsName) {
                    RunAddFilter();
                } else {
                    LogError("Add block with no classname found at section %d in file '%s'", g_iSection, g_szFile);
                }
            }
            g_eProp.eMode = Mode_None;
        }
        case Mode_Modify: {
            // Exiting a modify sub-block
            if (g_eProp.eSubMode != SubMode_None) {
                g_eProp.eSubMode = SubMode_None;
                return SMCParse_Continue;
            }
            // Must have something to match for modify blocks
            if (g_eProp.arrMatch.Length > 0)
                RunModifyFilter();
            g_eProp.eMode = Mode_None;
        }
    }
    return SMCParse_Continue;
}

public void RunRemoveFilter() {
    /**
     * g_eProp.arrMatch holds what we want
     * we know it has at least 1 entry here
     **/

    char szVal[PLATFORM_MAX_PATH];
    Property kv;
    EntityLumpEntry entry;
    for (int i, matches, j, index; i < EntityLump.Length(); i++) {
        matches = 0;
        entry = EntityLump.Get(i);
        for (j = 0; j < g_eProp.arrMatch.Length; j++) {
            g_eProp.arrMatch.GetArray(j, kv, sizeof(kv));
            index = entry.GetNextKey(kv.szKey, szVal, sizeof(szVal));
            while (index != -1) {
                if (EntPropsMatch(kv.szVal, szVal, kv.bRegex)) {
                    matches++;
                    break;
                }
                index = entry.GetNextKey(kv.szKey, szVal, sizeof(szVal), index);
            }
        }
        if (matches == g_eProp.arrMatch.Length) {
            EntityLump.Erase(i);
            i--;
        }
        delete entry;
    }
}

public void RunAddFilter() {
    /**
     * g_eProp.arrInsert holds what we want
     * we know it has at least 1 entry here
     **/

    int iIdx = EntityLump.Append();
    EntityLumpEntry entry = EntityLump.Get(iIdx);
    Property kv;
    for (int i; i < g_eProp.arrInsert.Length; i++) {
        g_eProp.arrInsert.GetArray(i, kv, sizeof(kv));
        entry.Append(kv.szKey, kv.szVal);
    }
    delete entry;
}

void RunModifyFilter() {
    /**
     * g_eProp.arrMatch holds at least 1 entry here
     * others may not have anything
     **/

    // Nothing to do if these are all empty
    if (g_eProp.arrReplace.Length == 0 && g_eProp.arrDel.Length == 0 && g_eProp.arrInsert.Length == 0)
        return;

    char szVal[PLATFORM_MAX_PATH];

    Property kv;
    EntityLumpEntry entry;
    for (int i, matches, j, index; i < EntityLump.Length(); i++) {
        matches = 0;
        entry = EntityLump.Get(i);
        /* Check matches */
        for (j = 0; j < g_eProp.arrMatch.Length; j++) {
            g_eProp.arrMatch.GetArray(j, kv, sizeof(kv));
            index = entry.GetNextKey(kv.szKey, szVal, sizeof(szVal));
            while (index != -1) {
                if (EntPropsMatch(kv.szVal, szVal, kv.bRegex)) {
                    matches++;
                    break;
                }
                index = entry.GetNextKey(kv.szKey, szVal, sizeof(szVal), index);
            }
        }
        if (matches < g_eProp.arrMatch.Length) {
            delete entry;
            continue;
        }

        /* This entry matches, perform any changes */

        /* First do deletions */
        if (g_eProp.arrDel.Length > 0) {
            for (j = 0; j < g_eProp.arrDel.Length; j++) {
                g_eProp.arrDel.GetArray(j, kv, sizeof(kv));
                index = entry.GetNextKey(kv.szKey, szVal, sizeof(szVal));
                while (index != -1) {
                    if (EntPropsMatch(kv.szVal, szVal, kv.bRegex)) {
                        entry.Erase(index);
                        index--;
                    }
                    index = entry.GetNextKey(kv.szKey, szVal, sizeof(szVal), index);
                }
            }
        }

        /* do replacements */
        if (g_eProp.arrReplace.Length > 0) {
            for (j = 0; j < g_eProp.arrReplace.Length; j++) {
                g_eProp.arrReplace.GetArray(j, kv, sizeof(kv));
                index = entry.GetNextKey(kv.szKey, szVal, sizeof(szVal));
                while (index != -1) {
                    entry.Update(index, NULL_STRING, kv.szVal);
                    index = entry.GetNextKey(kv.szKey, szVal, sizeof(szVal), index);
                }
            }
        }

        /* do insertions */
        if (g_eProp.arrInsert.Length > 0) {
            for (j = 0; j < g_eProp.arrInsert.Length; j++) {
                g_eProp.arrInsert.GetArray(j, kv, sizeof(kv));
                entry.Append(kv.szKey, kv.szVal);
            }
        }
        delete entry;
    }
}