#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo = {
    name        = "[L4D & 2] Freely Round End",
    author      = "Forgetest",
    description = "Free movement after round ends.",
    version     = "1.0",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

public void OnPluginStart() {
    HookEvent("round_end", Event_RoundEnd);
}

void Event_RoundEnd(Event eEvent, const char[] szName, bool bDontBroadcast) {
    /**
     * typeof (event["reason"]) == "ScenarioRestartReason"
     *
     * Get an incomplete list here:
     * https://github.com/Attano/Left4Downtown2/blob/944994f916617201680c100d372c1074c5f6ae42/l4d2sdk/director.h#L121
     **/
    switch (eEvent.GetInt("reason")) {
        // versus round end
        case 5: RequestFrame(OnFrame_RoundEnd);
    }
}

void OnFrame_RoundEnd() {
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i)) continue;
        SetEntityFlags(i, GetEntityFlags(i) & ~(FL_FROZEN|FL_GODMODE));
    }
}