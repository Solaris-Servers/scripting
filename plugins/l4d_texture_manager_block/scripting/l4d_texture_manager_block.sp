#pragma newdecls required
#pragma semicolon 1
#include <sourcemod>

public Plugin myinfo = {
    name        = "Mathack Block",
    author      = "Sir, Visor",
    description = "Kicks out clients who are potentially attempting to enable mathack",
    version     = "1.0",
    url         = ""
};

public void OnPluginStart() {
    CreateTimer(GetRandomFloat(2.5, 3.5), CheckClients, _, TIMER_REPEAT);
}

public Action CheckClients(Handle hTimer) {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i)) {
            // Only query clients on survivor or infected team, ignore spectators.
            if (GetClientTeam(i) > 1) QueryClientConVar(i, "mat_texture_list", ClientQueryCallback);
        }
    }
    return Plugin_Continue;
}

public void ClientQueryCallback(QueryCookie qCookie, int iClient, ConVarQueryResult cqResult, const char[] szCvarName, const char[] szCvarValue) {
    switch (cqResult) {
        case view_as<ConVarQueryResult>(0): {
            int mathax = StringToInt(szCvarValue);
            if (mathax > 0) KickClient(iClient, "Kicked for using 'mat_texture_list'");
        }
        case view_as<ConVarQueryResult>(1): {
            KickClient(iClient, "ConVarQuery_NotFound");
        }
        case view_as<ConVarQueryResult>(2): {
            KickClient(iClient, "ConVarQuery_NotValid");
        }
        case view_as<ConVarQueryResult>(3): {
            KickClient(iClient, "ConVarQuery_Protected");
        }
    }
}