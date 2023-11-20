#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>

int incap_count[4];
int preheal_temp[4];
int preheal_perm[4];
bool bEnabled;
Handle sdkRevive;
ConVar hEnabled;

public Plugin myinfo =
{
    name        = "Temp Health Medkits",
    description = "A plugin that replaced health gained by medkits with temporary health",
    author      = "CanadaRox",
    version     = "0.3",
    url         = "https://bitbucket.org/CanadaRox/random-sourcemod-stuff/"
};

public void OnPluginStart()
{
    hEnabled = CreateConVar("l4d2_temphealthmedkits_enable", "1", "Enable temp health medkits");
    bEnabled = hEnabled.BoolValue;
    hEnabled.AddChangeHook(Enabled_Change);

    HookEvent("heal_success", HealSuccess_Event);
    HookEvent("heal_end",     HealEnd_Event);

    GameData config = new GameData("left4dhooks.l4d2");

    if (!config)
    {
        SetFailState("Unable to find the gamedata file, check that it is installed correctly!");
    }

    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(config, SDKConf_Signature, "CTerrorPlayer::OnRevived");
    sdkRevive = EndPrepSDKCall();

    if (!sdkRevive)
    {
        SetFailState("Unable to find the \"CTerrorPlayer::OnRevived(void)\" signature, check the file version!");
    }

    delete config;
}

public void Enabled_Change(ConVar convar, char[] newvalue, char[] oldvalue)
{
    bEnabled = hEnabled.BoolValue;
}

public void HealEnd_Event(Event event, char[] name, bool dontBroadcast)
{
    if (!bEnabled)
    {
        return;
    }

    int character;

    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client) && GetClientTeam(client) == 2)
        {
            character               = GetSurvivorCharacter(client);
            preheal_temp[character] = GetSurvivorTempHealth(client);
            preheal_perm[character] = GetSurvivorPermanentHealth(client);
            incap_count[character]  = GetEntProp(client, Prop_Send, "m_currentReviveCount");
        }
    }
}

public void HealSuccess_Event(Event event, char[] name, bool dontBroadcast)
{
    if (!bEnabled)
    {
        return;
    }

    int client        = GetClientOfUserId(event.GetInt("subject"));
    int character     = GetSurvivorCharacter(client);
    int max_health    = GetEntProp(client, Prop_Send, "m_iMaxHealth");
    int preheal_total = preheal_temp[character] + preheal_perm[character];
    int new_temp      = preheal_temp[character] + RoundToCeil(FindConVar("first_aid_heal_percent").FloatValue * max_health - preheal_total);

    if (FindConVar("survivor_max_incapacitated_count").IntValue == incap_count[character])
    {
        SetBlackAndWhite(client, preheal_perm[character], new_temp);
    }
    else
    {
        SetEntProp(client, Prop_Send, "m_currentReviveCount", incap_count[character]);
        SetSurvivorTempHealth(client, new_temp);
        SetEntityHealth(client, preheal_perm[character]);
    }
}

stock int GetSurvivorPermanentHealth(int client)
{
    return GetEntProp(client, Prop_Send, "m_iHealth");
}

stock int GetSurvivorTempHealth(int client)
{
    int temphp = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * FindConVar("pain_pills_decay_rate").FloatValue)) - 1;
    return (temphp > 0 ? temphp : 0);
}

int GetSurvivorCharacter(int client)
{
    return GetEntProp(client, Prop_Send, "m_survivorCharacter");
}

void SetSurvivorTempHealth(int client, int hp)
{
    SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
    float newOverheal = 1.0 * hp;
    SetEntPropFloat(client, Prop_Send, "m_healthBuffer", newOverheal);
}

void SetBlackAndWhite(int target, int health, int temp_health)
{
    if (target > 0 && IsValidEntity(target) && IsClientInGame(target) && IsPlayerAlive(target) && GetClientTeam(target) == 2)
    {
        SetEntProp(target, Prop_Send, "m_currentReviveCount", (FindConVar("survivor_max_incapacitated_count").IntValue - 1));
        SetEntProp(target, Prop_Send, "m_isIncapacitated", 1);
        SDKCall(sdkRevive, target);
        SetEntityHealth(target, health);
        SetSurvivorTempHealth(target, temp_health);
    }
}