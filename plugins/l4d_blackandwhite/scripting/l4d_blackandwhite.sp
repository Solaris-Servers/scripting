#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <colors>
#include <l4d2util>

#define NO_GLOW 0
#define STEADY_GLOW 3
#define COLOR_WHITE 16777215

ConVar g_cvNoticeType;
int    g_iNoticeType;

ConVar g_cvPrintType;
int    g_iPrintType;

ConVar g_cvGlowEnable;
bool   g_bGlowEnable;

bool g_bStatus[SurvivorCharacter_Size - 1];

public Plugin myinfo = {
    name        = "L4D Black and White Notifier",
    author      = "DarkNoghri, madcap",
    description = "Notify people when player is black and white.",
    version     = "1.32.1",
    url         = "http://www.sourcemod.net"
};

public void OnPluginStart() {
    g_cvNoticeType = CreateConVar(
    "l4d_bandw_notice", "1",
    "0 turns notifications off, 1 notifies all, 2 notifies survivors, 3 notifies infected.",
    FCVAR_NONE, true, 0.0, true, 3.0);
    g_iNoticeType = g_cvNoticeType.IntValue;
    g_cvNoticeType.AddChangeHook(ConVarChanged_NoticeType);

    g_cvPrintType = CreateConVar(
    "l4d_bandw_type", "1",
    "0 prints to chat, 1 displays hint box, 2 both.",
    FCVAR_NONE, true, 0.0, true, 2.0);
    g_iPrintType = g_cvPrintType.IntValue;
    g_cvPrintType.AddChangeHook(ConVarChanged_PrintType);

    g_cvGlowEnable = CreateConVar(
    "l4d_bandw_glow", "0",
    "0 turns glow off, 1 turns glow on.",
    FCVAR_NONE, true, 0.0, true, 1.0);
    g_bGlowEnable = g_cvGlowEnable.BoolValue;
    g_cvGlowEnable.AddChangeHook(ConVarChanged_GlowEnable);

    HookEvent("revive_success",     Event_ReviveSuccess);
    HookEvent("heal_success",       Event_HealSuccess);
    HookEvent("player_death",       Event_PlayerDeath);
    HookEvent("player_bot_replace", Event_PlayerBotReplace);
    HookEvent("bot_player_replace", Event_BotPlayerReplace);
}

// get cvar changes during game
void ConVarChanged_NoticeType(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iNoticeType = g_cvNoticeType.IntValue;
}

void ConVarChanged_PrintType(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iPrintType = g_cvPrintType.IntValue;
}

void ConVarChanged_GlowEnable(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_bGlowEnable = g_cvGlowEnable.BoolValue;
    ToggleGlows(g_bGlowEnable);
}

void ToggleGlows(bool bEnable) {
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i)) continue;
        int iCharIdx = IdentifySurvivorFast(i);
        if (iCharIdx == SurvivorCharacter_Invalid)
            continue;
        if (!g_bStatus[iCharIdx])
            continue;
        SetEntProp(i, Prop_Send, "m_iGlowType",         bEnable ? STEADY_GLOW : NO_GLOW);
        SetEntProp(i, Prop_Send, "m_glowColorOverride", bEnable ? COLOR_WHITE : NO_GLOW);
    }
}

void Event_ReviveSuccess(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!eEvent.GetBool("lastlife")) return;

    int iTarget = GetClientOfUserId(eEvent.GetInt("subject"));
    if (iTarget <= 0) return;
    if (!IsClientInGame(iTarget)) return;

    int iCharIdx = IdentifySurvivorFast(iTarget);
    if (iCharIdx == SurvivorCharacter_Invalid)
        return;

    g_bStatus[iCharIdx] = true;

    if (g_bGlowEnable) {
        SetEntProp(iTarget, Prop_Send, "m_iGlowType",         STEADY_GLOW);
        SetEntProp(iTarget, Prop_Send, "m_glowColorOverride", COLOR_WHITE);
    }

    switch (g_iNoticeType) {
        case 0: {
            return;
        }
        case 1: {
            char szCharChatName[64];
            FormatEx(szCharChatName, sizeof(szCharChatName), " {olive}({default}%s{olive})", g_sSurvivorDisplayName[iCharIdx]);

            char szCharHintName[32];
            FormatEx(szCharHintName, sizeof(szCharHintName), " (%s)", g_sSurvivorDisplayName[iCharIdx]);

            switch (g_iPrintType) {
                case 0 : CPrintToChatAll("{green}[{default}B&W Notifier{green}]{default} {blue}%N%s{default} is black and white.", iTarget, IsFakeClient(iTarget) ? "" : szCharChatName);
                case 1 : PrintHintTextToAll("%N%s is black and white.", iTarget, IsFakeClient(iTarget) ? "" : szCharHintName);
                case 2 : {
                    CPrintToChatAll("{green}[{default}B&W Notifier{green}]{default} {blue}%N%s{default} is black and white.", iTarget, IsFakeClient(iTarget) ? "" : szCharChatName);
                    PrintHintTextToAll("%N%s is black and white.", iTarget, IsFakeClient(iTarget) ? "" : szCharHintName);
                }
            }
        }
        case 2, 3: {
            char szCharChatName[64];
            FormatEx(szCharChatName, sizeof(szCharChatName), " {green}({default}%s{green})", g_sSurvivorDisplayName[iCharIdx]);

            char szCharHintName[32];
            FormatEx(szCharHintName, sizeof(szCharHintName), " (%s)", g_sSurvivorDisplayName[iCharIdx]);

            for (int i = 1; i <= MaxClients; i++) {
                if (!IsClientInGame(i))                continue;
                if (GetClientTeam(i) != g_iNoticeType) continue;
                if (i == iTarget)                      continue;
                if (IsFakeClient(i))                   continue;
                switch (g_iPrintType) {
                    case 0 : CPrintToChat(i, "{green}[{default}B&W Notifier{green}]{default} {blue}%N%s{default} is black and white.", iTarget, IsFakeClient(iTarget) ? "" : szCharChatName);
                    case 1 : PrintHintText(i, "%N%s is black and white.", iTarget, IsFakeClient(iTarget) ? "" : szCharHintName);
                    case 2 : {
                        CPrintToChat(i, "{green}[{default}B&W Notifier{green}]{default} {blue}%N%s{default} is black and white.", iTarget, IsFakeClient(iTarget) ? "" : szCharChatName);
                        PrintHintText(i, "%N%s is black and white.", iTarget, IsFakeClient(iTarget) ? "" : szCharHintName);
                    }
                }
            }
        }
    }
}

void Event_HealSuccess(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iTarget = GetClientOfUserId(eEvent.GetInt("subject"));
    if (iTarget <= 0) return;
    if (!IsClientInGame(iTarget)) return;

    int iCharIdx = IdentifySurvivorFast(iTarget);
    if (iCharIdx == SurvivorCharacter_Invalid)
        return;

    g_bStatus[iCharIdx] = false;

    if (g_bGlowEnable) {
        SetEntProp(iTarget, Prop_Send, "m_iGlowType",         NO_GLOW);
        SetEntProp(iTarget, Prop_Send, "m_glowColorOverride", NO_GLOW);
    }
}

void Event_PlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (iClient <= 0) return;
    if (!IsClientInGame(iClient)) return;

    int iCharIdx = IdentifySurvivorFast(iClient);
    if (iCharIdx == SurvivorCharacter_Invalid)
        return;

    g_bStatus[iCharIdx] = false;

    if (g_bGlowEnable) {
        SetEntProp(iClient, Prop_Send, "m_iGlowType",         NO_GLOW);
        SetEntProp(iClient, Prop_Send, "m_glowColorOverride", NO_GLOW);
    }
}

void Event_PlayerBotReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!g_bGlowEnable) return;
    DataPack dp = new DataPack();
    dp.WriteCell(eEvent.GetInt("bot"));
    dp.WriteCell(eEvent.GetInt("player"));
    RequestFrame(OnNextFrame_HandlePlayerReplace);
}

void Event_BotPlayerReplace(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!g_bGlowEnable) return;
    DataPack dp = new DataPack();
    dp.WriteCell(eEvent.GetInt("player"));
    dp.WriteCell(eEvent.GetInt("bot"));
    RequestFrame(OnNextFrame_HandlePlayerReplace);
}

void OnNextFrame_HandlePlayerReplace(DataPack dp) {
    dp.Reset();
    int iReplacer = GetClientOfUserId(dp.ReadCell());
    int iReplacee = GetClientOfUserId(dp.ReadCell());
    delete dp;
    HandlePlayerReplace(iReplacer, iReplacee);
}

void HandlePlayerReplace(int iReplacer, int iReplacee) {
    if (iReplacer) {
        SetEntProp(iReplacee, Prop_Send, "m_iGlowType",         NO_GLOW);
        SetEntProp(iReplacee, Prop_Send, "m_glowColorOverride", NO_GLOW);
    }
    if (iReplacee) {
        int iCharIdx = IdentifySurvivorFast(iReplacee);
        if (iCharIdx != SurvivorCharacter_Invalid) {
            if (g_bStatus[iCharIdx]) {
                SetEntProp(iReplacee, Prop_Send, "m_iGlowType",         STEADY_GLOW);
                SetEntProp(iReplacee, Prop_Send, "m_glowColorOverride", COLOR_WHITE);
            }
        }
    }
}