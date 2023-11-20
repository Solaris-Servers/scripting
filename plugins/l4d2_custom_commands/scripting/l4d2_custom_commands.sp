#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <adminmenu>

// Definitions needed for plugin functionality
#define ARRAY_SIZE 5000

// Colors
#define RED             "189 9   13  255"
#define BLUE            "34  22  173 255"
#define GREEN           "34  120 24  255"
#define YELLOW          "231 220 24  255"
#define BLACK           "0   0   0   255"
#define WHITE           "255 255 255 255"
#define TRANSPARENT     "255 255 255 0"
#define HALFTRANSPARENT "255 255 255 180"

// Sounds
#define EXPLOSION_SOUND  "ambient/explosions/explode_1.wav"
#define EXPLOSION_SOUND2 "ambient/explosions/explode_2.wav"
#define EXPLOSION_SOUND3 "ambient/explosions/explode_3.wav"
#define EXPLOSION_DEBRIS "animation/plantation_exlposion.wav"

// Particles
#define FIRE_PARTICLE        "gas_explosion_ground_fire"
#define EXPLOSION_PARTICLE   "FluidExplosion_fps"
#define EXPLOSION_PARTICLE2  "weapon_grenade_explosion"
#define EXPLOSION_PARTICLE3  "explosion_huge_b"
#define BURN_IGNITE_PARTICLE "fire_small_01"
#define BLEED_PARTICLE       "blood_chainsaw_constant_tp"

// Models
#define ZOEY_MODEL    "models/survivors/survivor_teenangst.mdl"
#define FRANCIS_MODEL "models/survivors/survivor_biker.mdl"
#define LOUIS_MODEL   "models/survivors/survivor_manager.mdl"
#define MUZZLE_MODEL  "sprites/muzzleflash4.vmt"

//Integers
/* Refers to the last selected userid by the admin client index. Doesn't matter if the admins leaves and another using the same index gets in
 * because if this admin uses the same menu item, the last userid will be reset.
 */
int g_iCurrentUserId[MAXPLAYERS+1] = {0};
int g_iLastGrabbedEntity[ARRAY_SIZE+1] = {-1};

// Bools
bool g_bStrike;
bool g_bGnomeRain;
bool g_bGrab[MAXPLAYERS + 1];
bool g_bGrabbed[ARRAY_SIZE + 1];

// CVARS
ConVar g_cvRadius;
float  g_fRadius;

ConVar g_cvPower;
float  g_fPower;

ConVar g_cvDuration;
float  g_fDuration;

ConVar g_cvRainDur;
float  g_fRainDur;

ConVar g_cvRainRadius;
float  g_fRainRadius;

ConVar g_cvLog;
bool   g_bLog;

ConVar g_cvMaxIncaps;
int    g_iMaxIncaps;

ConVar g_cvPillsDecay;
float  g_fPillsDecay;

// Plugin Info
public Plugin myinfo = {
    name        = "[L4D2] Custom admin commands",
    author      = "honorcode23, Shadowysn (improvements)",
    description = "Allow admins to use new administrative or fun commands",
    version     = "1.3.9e",
    url         = "https://forums.alliedmods.net/showpost.php?p=2704580&postcount=483"
}

public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax) {
    EngineVersion ev = GetEngineVersion();
    if (ev != Engine_Left4Dead2) {
        strcopy(szError, iErrMax, "Plugin only supports Left 4 Dead 2.");
        return APLRes_SilentFailure;
    }
    return APLRes_Success;
}

public void OnPluginStart() {
    OnModuleStart_ConVars();
    OnModuleStart_AdminCmds();
    OnModuleStart_SpitFix();
    OnModuleStart_AdminMenu();

    // Translations
    LoadTranslations("common.phrases");
}

public void OnMapStart() {
    PrecacheSound(EXPLOSION_SOUND);
    PrecacheSound(EXPLOSION_SOUND2);
    PrecacheSound(EXPLOSION_SOUND3);

    static char szSliceSnd[34];
    for (int i = 1; i <= 6; i++) {
        Format(szSliceSnd, sizeof(szSliceSnd), "player/PZ/hit/zombie_slice_%i.wav", i);
        PrecacheSound(szSliceSnd);
    }

    PrecacheModel(ZOEY_MODEL);
    PrecacheModel(LOUIS_MODEL);
    PrecacheModel(FRANCIS_MODEL);
    PrecacheModel(MUZZLE_MODEL);

    PrefetchSound(EXPLOSION_SOUND);
    PrefetchSound(EXPLOSION_SOUND2);
    PrefetchSound(EXPLOSION_SOUND3);

    PrecacheParticle(FIRE_PARTICLE);
    PrecacheParticle(EXPLOSION_PARTICLE);
    PrecacheParticle(EXPLOSION_PARTICLE2);
    PrecacheParticle(EXPLOSION_PARTICLE3);
    PrecacheParticle(BURN_IGNITE_PARTICLE);
}

public void OnMapEnd() {
    for (int i = 1; i <= MaxClients; i++) {
        g_bGrab[i] = false;
    }

    for (int i = MaxClients + 1; i < ARRAY_SIZE; i++) {
        g_iLastGrabbedEntity[i] = -1;
        g_bGrabbed[i] = false;
    }
}

public void OnEntityCreated(int iEnt, const char[] szEntCls) {
    if (szEntCls[0] == 'i' && strcmp(szEntCls, "insect_swarm", false) == 0)
        SDKHook(iEnt, SDKHook_SpawnPost, SDK_SpawnPost);
}

void SDK_SpawnPost(int iEnt) {
    if (!RealValidEntity(iEnt))
        return;

    int iOwner = GetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity");
    if (!RealValidEntity(iOwner))
        SetEntProp(iEnt, Prop_Send, "m_iTeamNum", 3);
}

// FUNCTIONS //
void VomitPlayer(int iClient, int iSender) {
    if (!IsValidClient(iClient)) {
        PrintToChat(iSender, "[SM] Client is invalid");
        return;
    }

    if (!IsSurvivor(iClient) && !IsInfected(iClient)) {
        PrintToChat(iSender, "[SM] Spectators cannot be vomited!");
        return;
    }

    Logic_RunScript("GetPlayerFromUserID(%d).HitWithVomit()", GetClientUserId(iClient));
}

void DoDamage(int iClient, int iSender, int iDmg, int iDmgType = 0) {
    float vPos[3];
    if (IsValidClient(iSender))
        GetClientAbsOrigin(iSender, vPos);

    int iDmgEnt = CreateEntityByName("point_hurt");
    if (IsValidClient(iSender) && iClient != iSender)
        TeleportEntity(iDmgEnt, vPos, NULL_VECTOR, NULL_VECTOR);

    DispatchKeyValue(iDmgEnt, "DamageTarget", "!activator");

    static char szBuffer[32];
    IntToString(iDmg, szBuffer, sizeof(szBuffer));
    DispatchKeyValue(iDmgEnt, "Damage", szBuffer);
    IntToString(iDmgType, szBuffer, sizeof(szBuffer));
    DispatchKeyValue(iDmgEnt, "DamageType", szBuffer);

    DispatchSpawn(iDmgEnt);
    ActivateEntity(iDmgEnt);
    AcceptEntityInput(iDmgEnt, "Hurt", iClient);
    AcceptEntityInput(iDmgEnt, "Kill");
}

void IncapPlayer(int iClient, int iSender) {
    if (!Cmd_CheckClient(iClient, iSender, true, -1, true))
        return;

    if (IsInfected(iClient) && GetEntProp(iClient, Prop_Send, "m_zombieClass") != 8) {
        PrintToChat(iSender, "[SM] Only survivors and tanks can be incapacitated!");
        return;
    } else if ((IsSurvivor(iClient) || IsInfected(iClient)) && GetEntProp(iClient, Prop_Send, "m_isIncapacitated")) {
        PrintToChat(iSender, "[SM] Cannot incap already incapacitated players!");
        return;
    }

    SetEntityHealth(iClient, 1);
    DoDamage(iClient, iSender, 100);
}

void SmackillPlayer(int iClient, int iSender) {
    if (!Cmd_CheckClient(iClient, iSender, true, -1, true))
        return;

    if (IsSurvivor(iClient)) {
        AcceptEntityInput(iClient, "ClearContext");
        AcceptEntityInput(iClient, "CancelCurrentScene");

        SetVariantString("PainLevel:Incapacitated:0.1");
        AcceptEntityInput(iClient, "AddContext");

        SetVariantString("Pain");
        AcceptEntityInput(iClient, "SpeakResponseConcept");
    }

    if (IsSurvivor(iClient))
        BlackAndWhite(iClient, iSender);

    SetEntityHealth(iClient, 1);
    SetTempHealth(iClient, 0.0);
    DoDamage(iClient, iSender, 1000000, 32);

    if (!IsPlayerAlive(iClient) && IsSurvivor(iClient)) {
        float vPos[3];
        GetClientAbsOrigin(iClient, vPos);

        CreateRagdoll(iClient);
        int iBody = FindEntityByClassname(-1, "survivor_death_model");
        if (RealValidEntity(iBody)) {
            for (int i = MaxClients; i < GetMaxEntities(); i++) {
                if (!RealValidEntity(i))
                    continue;

                static char szClsName[22];
                GetEntityClassname(i, szClsName, sizeof(szClsName));
                if (strcmp(szClsName, "survivor_death_model", false) != 0)
                    continue;

                float vBodyPos[3];
                GetEntPropVector(i, Prop_Data, "m_vecOrigin", vBodyPos);

                if (vBodyPos[0] == vPos[0] && vBodyPos[1] == vPos[1] && vBodyPos[2] == vPos[2])
                    SetEntityRenderMode(i, RENDER_NONE);
            }
        }
    }
}

void LaunchRock(const float vPos[3], const float vAng[3]) {
    int iLauncher = CreateEntityByName("env_rock_launcher");
    if (!RealValidEntity(iLauncher))
        return;

    DispatchKeyValueVector(iLauncher, "origin", vPos);
    DispatchKeyValueVector(iLauncher, "angles", vAng);

    DispatchSpawn(iLauncher);
    ActivateEntity(iLauncher);

    AcceptEntityInput(iLauncher, "LaunchRock");
    AcceptEntityInput(iLauncher, "Kill");
}

void CreateRagdoll(int iClient) {
    if (!IsValidClient(iClient) || (!IsSurvivor(iClient) && !IsInfected(iClient)))
        return;

    int iPrevRagdoll = GetEntPropEnt(iClient, Prop_Send, "m_hRagdoll");
    if (RealValidEntity(iPrevRagdoll))
        return;

    int iRagdoll = CreateEntityByName("cs_ragdoll");

    float vPos[3];
    GetClientAbsOrigin(iClient, vPos);

    float vAng[3];
    GetClientAbsAngles(iClient, vAng);

    TeleportEntity(iRagdoll, vPos, vAng, NULL_VECTOR);

    SetEntPropVector(iRagdoll, Prop_Send, "m_vecRagdollOrigin", vPos);
    SetEntProp(iRagdoll, Prop_Send, "m_nModelIndex", GetEntProp(iClient, Prop_Send, "m_nModelIndex"));
    SetEntProp(iRagdoll, Prop_Send, "m_iTeamNum", GetClientTeam(iClient));
    SetEntPropEnt(iRagdoll, Prop_Send, "m_hPlayer", iClient);
    SetEntProp(iRagdoll, Prop_Send, "m_iDeathPose", GetEntProp(iClient, Prop_Send, "m_nSequence"));
    SetEntProp(iRagdoll, Prop_Send, "m_iDeathFrame", GetEntProp(iClient, Prop_Send, "m_flAnimTime"));
    SetEntProp(iRagdoll, Prop_Send, "m_nForceBone", GetEntProp(iClient, Prop_Send, "m_nForceBone"));
    
    float vVel[3];
    vVel[0] = GetEntPropFloat(iClient, Prop_Send, "m_vecVelocity[0]") * 30;
    vVel[1] = GetEntPropFloat(iClient, Prop_Send, "m_vecVelocity[1]") * 30;
    vVel[2] = GetEntPropFloat(iClient, Prop_Send, "m_vecVelocity[2]") * 30;
    SetEntPropVector(iRagdoll, Prop_Send, "m_vecForce", vVel);

    if (IsSurvivor(iClient)) {
        SetEntProp(iRagdoll, Prop_Send, "m_ragdollType", 1);
        SetEntProp(iRagdoll, Prop_Send, "m_survivorCharacter", GetEntProp(iClient, Prop_Send, "m_survivorCharacter", 1), 1);
    } else if (IsInfected(iClient)) {
        int iInfCls = GetEntProp(iClient, Prop_Send, "m_zombieClass", 1);
        if (iInfCls == 8) {
            SetEntProp(iRagdoll, Prop_Send, "m_ragdollType", 3);
        } else {
            SetEntProp(iRagdoll, Prop_Send, "m_ragdollType", 2);
        }
    
        SetEntProp(iRagdoll, Prop_Send, "m_zombieClass", iInfCls, 1);

        int iEffect = GetEntPropEnt(iClient, Prop_Send, "m_hEffectEntity");
        if (RealValidEntity(iEffect)) {
            static char szEffectCls[13];
            GetEntityClassname(iEffect, szEffectCls, sizeof(szEffectCls));
            if (strcmp(szEffectCls, "entityflame", false) == 0)
                SetEntProp(iRagdoll, Prop_Send, "m_bOnFire", 1, 1);
        }
    } else {
        SetEntProp(iRagdoll, Prop_Send, "m_ragdollType", 1);
    }

    SetEntPropEnt(iClient, Prop_Send, "m_hRagdoll", iRagdoll);
    DispatchSpawn(iRagdoll);
    ActivateEntity(iRagdoll);
}

void ChangeSpeed(int client, int sender, float newspeed) {
    if (!Cmd_CheckClient(client, sender, false, -1, true))
        return;
    SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", newspeed);
}

void SetHealth(int client, int sender, int amount) {
    if (!Cmd_CheckClient(client, sender, true, -1, true))
        return;
    SetEntityHealth(client, amount);
}

void ChangeColor(int client, int sender, const char[] color) {
    if (!Cmd_CheckClient(client, sender, false, -1, true))
        return;
    DispatchKeyValue(client, "rendercolor", color);
}

void CreateExplosion(float carPos[3]) {
    static char sRadius[64];
    static char sPower[64];
    float flMxDistance = g_fRadius;
    float power = g_fPower;
    IntToString(RoundToNearest(flMxDistance), sRadius, sizeof(sRadius));
    IntToString(RoundToNearest(power), sPower, sizeof(sPower));
    int exParticle2 = CreateEntityByName("info_particle_system");
    int exParticle3 = CreateEntityByName("info_particle_system");
    int exTrace = CreateEntityByName("info_particle_system");
    int exPhys = CreateEntityByName("env_physexplosion");
    int exHurt = CreateEntityByName("point_hurt");
    int exParticle = CreateEntityByName("info_particle_system");
    int exEntity = CreateEntityByName("env_explosion");

    //Set up the particle explosion
    DispatchKeyValue(exParticle, "effect_name", EXPLOSION_PARTICLE);
    DispatchSpawn(exParticle);
    ActivateEntity(exParticle);
    TeleportEntity(exParticle, carPos, NULL_VECTOR, NULL_VECTOR);

    DispatchKeyValue(exParticle2, "effect_name", EXPLOSION_PARTICLE2);
    DispatchSpawn(exParticle2);
    ActivateEntity(exParticle2);
    TeleportEntity(exParticle2, carPos, NULL_VECTOR, NULL_VECTOR);

    DispatchKeyValue(exParticle3, "effect_name", EXPLOSION_PARTICLE3);
    DispatchSpawn(exParticle3);
    ActivateEntity(exParticle3);
    TeleportEntity(exParticle3, carPos, NULL_VECTOR, NULL_VECTOR);

    DispatchKeyValue(exTrace, "effect_name", FIRE_PARTICLE);
    DispatchSpawn(exTrace);
    ActivateEntity(exTrace);
    TeleportEntity(exTrace, carPos, NULL_VECTOR, NULL_VECTOR);


    // Set up explosion entity
    DispatchKeyValue(exEntity, "fireballsprite", "sprites/muzzleflash4.vmt");
    DispatchKeyValue(exEntity, "iMagnitude", sPower);
    DispatchKeyValue(exEntity, "iRadiusOverride", sRadius);
    DispatchKeyValue(exEntity, "spawnflags", "828");
    DispatchSpawn(exEntity);
    TeleportEntity(exEntity, carPos, NULL_VECTOR, NULL_VECTOR);

    // Set up physics movement explosion
    DispatchKeyValue(exPhys, "radius", sRadius);
    DispatchKeyValue(exPhys, "magnitude", sPower);
    DispatchSpawn(exPhys);
    TeleportEntity(exPhys, carPos, NULL_VECTOR, NULL_VECTOR);


    // Set up hurt point
    DispatchKeyValue(exHurt, "DamageRadius", sRadius);
    DispatchKeyValue(exHurt, "DamageDelay", "0.5");
    DispatchKeyValue(exHurt, "Damage", "5");
    DispatchKeyValue(exHurt, "DamageType", "8");
    DispatchSpawn(exHurt);
    TeleportEntity(exHurt, carPos, NULL_VECTOR, NULL_VECTOR);

    switch (GetRandomInt(1,3))
    {
        case 1:
        {
            PrecacheSound(EXPLOSION_SOUND);
            EmitAmbientGenericSound(carPos, EXPLOSION_SOUND);
        }
        case 2:
        {
            PrecacheSound(EXPLOSION_SOUND2);
            EmitAmbientGenericSound(carPos, EXPLOSION_SOUND2);
        }
        case 3:
        {
            PrecacheSound(EXPLOSION_SOUND3);
            EmitAmbientGenericSound(carPos, EXPLOSION_SOUND3);
        }
    }

    PrecacheSound(EXPLOSION_DEBRIS);
    EmitAmbientGenericSound(carPos, EXPLOSION_DEBRIS);

    //BOOM!
    AcceptEntityInput(exParticle, "Start");
    AcceptEntityInput(exParticle2, "Start");
    AcceptEntityInput(exParticle3, "Start");
    AcceptEntityInput(exTrace, "Start");
    AcceptEntityInput(exEntity, "Explode");
    AcceptEntityInput(exPhys, "Explode");
    AcceptEntityInput(exHurt, "TurnOn");

    static char temp_str[64];
    Format(temp_str, sizeof(temp_str), "OnUser1 !self:Kill::%f:1", g_fDuration+1.5);

    SetVariantString(temp_str);
    AcceptEntityInput(exParticle, "AddOutput");
    AcceptEntityInput(exParticle, "FireUser1");
    SetVariantString(temp_str);
    AcceptEntityInput(exParticle2, "AddOutput");
    AcceptEntityInput(exParticle2, "FireUser1");
    SetVariantString(temp_str);
    AcceptEntityInput(exParticle3, "AddOutput");
    AcceptEntityInput(exParticle3, "FireUser1");
    SetVariantString(temp_str);
    AcceptEntityInput(exEntity, "AddOutput");
    AcceptEntityInput(exEntity, "FireUser1");
    SetVariantString(temp_str);
    AcceptEntityInput(exPhys, "AddOutput");
    AcceptEntityInput(exPhys, "FireUser1");
    SetVariantString(temp_str);
    AcceptEntityInput(exTrace, "AddOutput");
    SetVariantString(temp_str);
    AcceptEntityInput(exHurt, "AddOutput");

    Format(temp_str, sizeof(temp_str), "OnUser1 !self:Stop::%f:1", g_fDuration);
    SetVariantString(temp_str);
    AcceptEntityInput(exTrace, "AddOutput");
    AcceptEntityInput(exTrace, "FireUser1");

    Format(temp_str, sizeof(temp_str), "OnUser1 !self:TurnOff::%f:1", g_fDuration);
    SetVariantString(temp_str);
    AcceptEntityInput(exHurt, "AddOutput");
    AcceptEntityInput(exHurt, "FireUser1");

    float survivorPos[3], traceVec[3], resultingFling[3], currentVelVec[3];
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || !IsPlayerAlive(i) || !IsSurvivor(i))
        {
            continue;
        }

        GetEntPropVector(i, Prop_Data, "m_vecOrigin", survivorPos);

        //Vector and radius distance calcs by AtomicStryker!
        if (GetVectorDistance(carPos, survivorPos) <= flMxDistance)
        {
            MakeVectorFromPoints(carPos, survivorPos, traceVec);                // draw a line from car to Survivor
            GetVectorAngles(traceVec, resultingFling);                          // get the angles of that line

            resultingFling[0] = Cosine(DegToRad(resultingFling[1])) * power;    // use trigonometric magic
            resultingFling[1] = Sine(DegToRad(resultingFling[1])) * power;
            resultingFling[2] = power;

            GetEntPropVector(i, Prop_Data, "m_vecVelocity", currentVelVec);     // add whatever the Survivor had before
            resultingFling[0] += currentVelVec[0];
            resultingFling[1] += currentVelVec[1];
            resultingFling[2] += currentVelVec[2];

            L4D2_CTerrorPlayer_Fling(i, i, resultingFling);
        }
    }
}

void PipeExplosion(int client, float carPos[3])
{
    int explosion = CreateEntityByName("prop_physics");
    if (!RealValidEntity(explosion)) return;

    DispatchKeyValue(explosion, "physdamagescale", "0.0");
    DispatchKeyValue(explosion, "model", "models/props_junk/propanecanister001a.mdl");
    DispatchSpawn(explosion);
    ActivateEntity(explosion);
    SetEntityRenderMode(explosion, RENDER_NONE);
    TeleportEntity(explosion, carPos, NULL_VECTOR, NULL_VECTOR);
    SetEntityMoveType(explosion, MOVETYPE_VPHYSICS);

    SetEntPropEnt(explosion, Prop_Send, "m_hOwnerEntity", client);

    AcceptEntityInput(explosion, "Break");
}

void Charge(int client, int sender)
{
    float tpos[3], spos[3];
    float distance[3], ratio[3], addVel[3], tvec[3];
    GetClientAbsOrigin(client, tpos);
    GetClientAbsOrigin(sender, spos);
    distance[0] = (spos[0] - tpos[0]);
    distance[1] = (spos[1] - tpos[1]);
    distance[2] = (spos[2] - tpos[2]);
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", tvec);
    ratio[0] = distance[0] / SquareRoot(distance[1]*distance[1] + distance[0]*distance[0]);//Ratio x/hypo
    ratio[1] = distance[1] / SquareRoot(distance[1]*distance[1] + distance[0]*distance[0]);//Ratio y/hypo

    addVel[0] = ratio[0]*-1 * 500.0;
    addVel[1] = ratio[1]*-1 * 500.0;
    addVel[2] = 500.0;
    L4D2_CTerrorPlayer_Fling(client, sender, addVel);
}

void Bleed(int client, int sender, float duration)
{
    if (!Cmd_CheckClient(client, sender, true, -1, true)) return;

    //Userid for targetting
    int userid = GetClientUserId(client);
    float pos[3]; char sName[64], sTargetName[64];
    int Particle = CreateEntityByName("info_particle_system");

    GetClientAbsOrigin(client, pos);
    TeleportEntity(Particle, pos, NULL_VECTOR, NULL_VECTOR);

    Format(sName, sizeof(sName), "%d", userid+25);
    DispatchKeyValue(client, "targetname", sName);
    GetEntPropString(client, Prop_Data, "m_iName", sName, sizeof(sName));

    Format(sTargetName, sizeof(sTargetName), "%d", userid+1000);

    DispatchKeyValue(Particle, "targetname", sTargetName);
    DispatchKeyValue(Particle, "parentname", sName);
    DispatchKeyValue(Particle, "effect_name", BLEED_PARTICLE);

    DispatchSpawn(Particle);

    DispatchSpawn(Particle);

    //Parent:
    SetVariantString(sName);
    AcceptEntityInput(Particle, "SetParent", Particle, Particle);
    ActivateEntity(Particle);
    AcceptEntityInput(Particle, "start");

    static char temp_str[64];
    Format(temp_str, sizeof(temp_str), "OnUser1 !self:Kill::%f:1", duration);

    SetVariantString(temp_str);
    AcceptEntityInput(Particle, "AddOutput");
    AcceptEntityInput(Particle, "FireUser1");
}

void ChangeScale(int client, int sender, float scale)
{
    if (!Cmd_CheckClient(client, sender, true, -1, true)) return;

    SetEntPropFloat(client, Prop_Send, "m_flModelScale", scale);
}

void TeleportBack(int client, int sender)
{
    static char map[32]; float pos[3];
    GetCurrentMap(map, sizeof(map));
    if (!Cmd_CheckClient(client, sender, true, -1, true)) return;

    if (strcmp(map, "c1m1_hotel", false) == 0)
    {
        pos[0] = 568.0;
        pos[1] = 5707.0;
        pos[2] = 2848.0;
    }
    else if (strcmp(map, "c1m2_streets", false) == 0)
    {
        pos[0] = 2049.0;
        pos[1] = 4460.0;
        pos[2] = 1235.0;
    }
    else if (strcmp(map, "c1m3_mall", false) == 0)
    {
        pos[0] = 6697.0;
        pos[1] = -1424.0;
        pos[2] = 86.0;
    }
    else if (strcmp(map, "c1m4_atrium", false) == 0)
    {
        pos[0] = -2046.0;
        pos[1] = -4641.0;
        pos[2] = 598.0;
    }
    else if (strcmp(map, "c2m1_highway", false) == 0)
    {
        pos[0] = 10855.0;
        pos[1] = 7864.0;
        pos[2] = -488.0;
    }
    else if (strcmp(map, "c2m2_fairgrounds", false) == 0)
    {
        pos[0] = 1653.0;
        pos[1] = 2796.0;
        pos[2] = 32.0;
    }
    else if (strcmp(map, "c2m3_coaster", false) == 0)
    {
        pos[0] = 4336.0;
        pos[1] = 2048.0;
        pos[2] = -1.0;
    }
    else if (strcmp(map, "c2m4_barns", false) == 0)
    {
        pos[0] = 3057.0;
        pos[1] = 3632.0;
        pos[2] = -152.0;
    }
    else if (strcmp(map, "c2m5_concert", false) == 0)
    {
        pos[0] = -938.0;
        pos[1] = 2194.0;
        pos[2] = -193.0;
    }
    else if (strcmp(map, "c3m1_plankcountry", false) == 0)
    {
        pos[0] = -12549.0;
        pos[1] = 10488.0;
        pos[2] = 270.0;
    }
    else if (strcmp(map, "c3m2_swamp", false) == 0)
    {
        pos[0] = -8158.0;
        pos[1] = 7531.0;
        pos[2] = 32.0;
    }
    else if (strcmp(map, "c3m3_shantytown", false) == 0)
    {
        pos[0] = -5718.0;
        pos[1] = 2137.0;
        pos[2] = 170.0;
    }
    else if (strcmp(map, "c3m4_plantation", false) == 0)
    {
        pos[0] = -5027.0;
        pos[1] = -1662.0;
        pos[2] = -34.0;
    }
    else if (strcmp(map, "c4m1_milltown_a", false) == 0)
    {
        pos[0] = -7097.0;
        pos[1] = 7706.0;
        pos[2] = 175.0;
    }
    else if (strcmp(map, "c4m2_sugarmill_a", false) == 0)
    {
        pos[0] = 3617.0;
        pos[1] = -1659.0;
        pos[2] = 270.0;
    }
    else if (strcmp(map, "c4m3_sugarmill_b", false) == 0)
    {
        pos[0] = -1788.0;
        pos[1] = -13701.0;
        pos[2] = 170.0;
    }
    else if (strcmp(map, "c4m4_milltown_b", false) == 0)
    {
        pos[0] = 3883.0;
        pos[1] = -1484.0;
        pos[2] = 270.0;
    }
    else if (strcmp(map, "c4m5_milltown_escape", false) == 0)
    {
        pos[0] = -3146.0;
        pos[1] = 7818.0;
        pos[2] = 182.0;
    }
    else if (strcmp(map, "c5m1_waterfront", false) == 0)
    {
        pos[0] = 790.0;
        pos[1] = 686.0;
        pos[2] = -419.0;
    }
    else if (strcmp(map, "c5m2_park", false) == 0)
    {
        pos[0] = -4119.0;
        pos[1] = -1263.0;
        pos[2] = -281.0;
    }
    else if (strcmp(map, "c5m3_cemetery", false) == 0)
    {
        pos[0] = 6361.0;
        pos[1] = 8372.0;
        pos[2] = 62.0;
    }
    else if (strcmp(map, "c5m4_quarter", false) == 0)
    {
        pos[0] = -3235.0;
        pos[1] = 4849.0;
        pos[2] = 130.0;
    }
    else if (strcmp(map, "c5m5_bridge", false) == 0)
    {
        pos[0] = -12062.0;
        pos[1] = 5913.0;
        pos[2] = 574.0;
    }
    else if (strcmp(map, "c6m1_riverbank", false) == 0)
    {
        pos[0] = 913.0;
        pos[1] = 3750.0;
        pos[2] = 156.0;
    }
    else if (strcmp(map, "c6m2_bedlam", false) == 0)
    {
        pos[0] = 3014.0;
        pos[1] = -1216.0;
        pos[2] = -233.0;
    }
    else if (strcmp(map, "c6m3_port", false) == 0)
    {
        pos[0] = -2364.0;
        pos[1] = -471.0;
        pos[2] = -193.0;
    }
    else
    {
        PrintToChat(sender, "[SM] This commands doesn't support the current map!");
    }
    TeleportEntity(client, pos, NULL_VECTOR, NULL_VECTOR);
    PrintHintText(client, "You were teleported to the beginning of the map for rushing!");
}

void EndGame()
{
    for (int i=1; i<=MaxClients; i++)
    {
        if (IsValidClient(i) && IsPlayerAlive(i) && !IsClientObserver(i) && GetClientTeam(i) == 2) // Dont need to as team 4 doesn't count to living survivors
        {
            ForcePlayerSuicide(i);
        }
    }
}

void Airstrike(int client)
{
    g_bStrike = true;
    CreateTimer(6.0, timerStrikeTimeout, _, TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(1.0, timerStrike, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

Action timerStrikeTimeout(Handle timer)
{
    g_bStrike = false;
    return Plugin_Continue;
}

Action timerStrike(Handle timer, int client)
{
    client = GetClientOfUserId(client);
    if (!g_bStrike)
    {
        return Plugin_Stop;
    }
    float pos[3];
    GetClientAbsOrigin(client, pos);
    float radius = g_fRainRadius;
    pos[0] += GetRandomFloat(radius*-1, radius);
    pos[1] += GetRandomFloat(radius*-1, radius);
    CreateExplosion(pos);
    return Plugin_Continue;
}

void BlackAndWhite(int client, int sender)
{
    if (!Cmd_CheckClient(client, sender, true, -1, true)) return;

    if (GetEntProp(client, Prop_Send, "m_isIncapacitated")) RevivePlayer(client);
    Logic_RunScript("GetPlayerFromUserID(%d).SetReviveCount(%i)", GetClientUserId(client), g_iMaxIncaps);
}

void SwitchHealth(int client, int sender, int type)
{
    if (!Cmd_CheckClient(client, sender, true, -1, true)) return;

    if (type == 1)
    {
        int iTempHealth = GetClientTempHealth(client);
        int iPermHealth = GetClientHealth(client);
        RemoveTempHealth(client);
        SetEntityHealth(client, iTempHealth+iPermHealth);
    }
    else if (type == 2)
    {
        int iTempHealth = GetClientTempHealth(client);
        int iPermHealth = GetClientHealth(client);
        int iTotal = iTempHealth+iPermHealth;
        SetEntityHealth(client, 1);
        RemoveTempHealth(client);
        SetTempHealth(client, iTotal+0.0);
    }
}

void WeaponRain(const char[] weapon, int sender)
{
    static char item[64];
    Format(item, sizeof(item), "weapon_%s", weapon);

    g_bGnomeRain = true;

    CreateTimer(g_fRainDur, timerRainTimeout, TIMER_FLAG_NO_MAPCHANGE);
    DataPack dpack = CreateDataPack();
    WritePackCell(dpack, GetClientUserId(sender));
    WritePackString(dpack, item);
    CreateTimer(0.1, timerSpawnWeapon, dpack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

Action timerSpawnWeapon(Handle timer, Handle dpack)
{
    static char item[96];
    ResetPack(dpack);
    int client = GetClientOfUserId(ReadPackCell(dpack));
    ReadPackString(dpack, item, sizeof(item));

    int weap = CreateEntityByName(item);
    DispatchSpawn(weap);

    if (!g_bGnomeRain)
    { return Plugin_Stop; }

    float pos[3];
    GetClientAbsOrigin(client, pos);
    pos[2] += 350.0;
    float radius = g_fRainRadius;
    pos[0] += GetRandomFloat(radius*-1, radius);
    pos[1] += GetRandomFloat(radius*-1, radius);
    TeleportEntity(weap, pos, NULL_VECTOR, NULL_VECTOR);
    return Plugin_Continue;
}

void StartGnomeRain(int client)
{
    g_bGnomeRain = true;
    CreateTimer(g_fRainDur, timerRainTimeout, _, TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(0.1, timerSpawnGnome, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

void StartL4dRain(int client)
{
    g_bGnomeRain = true;
    CreateTimer(g_fRainDur, timerRainTimeout, _, TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(0.7, timerSpawnL4d, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

void GodMode(int client, int sender)
{
    if (!Cmd_CheckClient(client, sender, false, -1, true)) return;

    if (GetEntProp(client, Prop_Data, "m_takedamage") <= 0)
    {
        SetEntProp(client, Prop_Data, "m_takedamage", 2);
        PrintToChat(sender, "[SM] The selected player now has god mode [Deactivated]");
    }
    else
    {
        SetEntProp(client, Prop_Data, "m_takedamage", 0);
        PrintToChat(sender, "[SM] The selected player now has god mode [Activated]");
    }
}

Action timerRainTimeout(Handle timer)
{
    g_bGnomeRain = false;
    return Plugin_Continue;
}

Action timerSpawnGnome(Handle timer, int client)
{
    client = GetClientOfUserId(client);
    float pos[3];
    int gnome = CreateEntityByName("weapon_gnome");
    DispatchSpawn(gnome);

    if (!g_bGnomeRain)
    { return Plugin_Stop; }

    GetClientAbsOrigin(client, pos);
    pos[2] += 350.0;
    float radius = g_fRainRadius;
    pos[0] += GetRandomFloat(radius*-1, radius);
    pos[1] += GetRandomFloat(radius*-1, radius);
    TeleportEntity(gnome, pos, NULL_VECTOR, NULL_VECTOR);
    return Plugin_Continue;
}

Action timerSpawnL4d(Handle timer, int client)
{
    client = GetClientOfUserId(client);
    float pos[3];
    int body = CreateEntityByName("prop_ragdoll");
    switch (GetRandomInt(1,3))
    {
        case 1: DispatchKeyValue(body, "model", ZOEY_MODEL);
        case 2: DispatchKeyValue(body, "model", FRANCIS_MODEL);
        case 3: DispatchKeyValue(body, "model", LOUIS_MODEL);
    }
    DispatchSpawn(body);

    if (!g_bGnomeRain)
    { return Plugin_Stop; }

    GetClientAbsOrigin(client, pos);
    pos[2] += 350.0;
    float radius = g_fRainRadius;
    pos[0] += GetRandomFloat(radius*-1, radius);
    pos[1] += GetRandomFloat(radius*-1, radius);
    TeleportEntity(body, pos, NULL_VECTOR, NULL_VECTOR);
    return Plugin_Continue;
}

void CheatCommand(int client, const char[] command, const char[] arguments)
{
    if (!IsValidClient(client)) return;

    int admindata = GetUserFlagBits(client);
    SetUserFlagBits(client, ADMFLAG_UNBAN);

    int flags = GetCommandFlags(command);
    SetCommandFlags(command, flags & ~FCVAR_CHEAT);
    FakeClientCommand(client, "%s %s", command, arguments);
    SetCommandFlags(command, flags);
    SetUserFlagBits(client, admindata);
}

void Shake(int client, int sender, float duration)
{
    if (!Cmd_CheckClient(client, sender, false, -1, true)) return;

    Handle hBf = StartMessageOne("Shake", client);
    if (hBf != null)
    {
        BfWriteByte(hBf, 0);
        BfWriteFloat(hBf, 16.0);            // shake magnitude/amplitude
        BfWriteFloat(hBf, 0.5);             // shake noise frequency
        BfWriteFloat(hBf, duration);                // shake lasts this long
        EndMessage();
    }
}

void InstructorHint(const char[] content)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i))
        { ClientCommand(i, "gameinstructor_enable 1"); }
    }

    int entity = CreateEntityByName("env_instructor_hint");
    if (RealValidEntity(entity))
    {
        DispatchKeyValue(entity, "hint_auto_start", "0");
        DispatchKeyValue(entity, "hint_alphaoption", "1");
        DispatchKeyValue(entity, "hint_timeout", "10");
        DispatchKeyValue(entity, "hint_forcecaption", "Yes");
        DispatchKeyValue(entity, "hint_static", "1");
        DispatchKeyValue(entity, "hint_icon_offscreen", "icon_alert");
        DispatchKeyValue(entity, "hint_icon_onscreen", "icon_alert");
        DispatchKeyValue(entity, "hint_caption", content);
        DispatchKeyValue(entity, "hint_range", "1");
        DispatchKeyValue(entity, "hint_color", "255 255 255");

        DispatchSpawn(entity);
        AcceptEntityInput(entity, "ShowHint");

        SetVariantString("OnUser1 !self:Kill::15.0:1");
        AcceptEntityInput(entity, "AddOutput");

        SetVariantString("OnUser1 !self:FireUser2::14.9:1");
        AcceptEntityInput(entity, "AddOutput");

        AcceptEntityInput(entity, "FireUser1");
        HookSingleEntityOutput(entity, "OnUser2", OnTrigger_DisableInstructor, true);
    }
    else
    { LogError("Failed to create the instructor hint entity."); }
}

void OnTrigger_DisableInstructor(const char[] output, int caller, int activator, float delay)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsValidClient(i)) return;
        ClientCommand(i, "gameinstructor_enable 0");
    }
}

bool IsValidWeapon(const char[] weapon)
{
    if (strcmp(weapon, "rifle") == 0
    || strcmp(weapon, "smg") == 0
    || strcmp(weapon, "pumpshotgun") == 0
    || strcmp(weapon, "first_aid_kit") == 0
    || strcmp(weapon, "autoshotgun") == 0
    || strcmp(weapon, "molotov") == 0
    || strcmp(weapon, "pain_pills") == 0
    || strcmp(weapon, "pipe_bomb") == 0
    || strcmp(weapon, "hunting_rifle") == 0
    || strcmp(weapon, "pistol") == 0
    || strcmp(weapon, "gascan") == 0
    || strcmp(weapon, "propanetank") == 0)
    { return true; }

    if (strcmp(weapon, "rifle_desert") == 0
    || strcmp(weapon, "rifle_ak47") == 0
    || strcmp(weapon, "sniper_military") == 0
    || strcmp(weapon, "shotgun_spas") == 0
    || strcmp(weapon, "shotgun_chrome") == 0
    || strcmp(weapon, "chainsaw") == 0
    || strcmp(weapon, "adrenaline") == 0
    || strcmp(weapon, "sniper_scout") == 0
    || strcmp(weapon, "upgradepack_incendiary") == 0
    || strcmp(weapon, "upgradepack_explosive") == 0
    || strcmp(weapon, "vomitjar") == 0
    || strcmp(weapon, "smg_silenced") == 0
    || strcmp(weapon, "smg_mp5") == 0
    || strcmp(weapon, "sniper_awp") == 0
    || strcmp(weapon, "sniper_scout") == 0
    || strcmp(weapon, "rifle_sg552") == 0
    || strcmp(weapon, "gnome") == 0
    || strcmp(weapon, "pistol_magnum") == 0
    || strcmp(weapon, "grenade_launcher") == 0
    || strcmp(weapon, "rifle_m60") == 0
    || strcmp(weapon, "defibrillator") == 0)
    { return true; }

    return false;
}

void CreateParticle(int client, const char[] Particle_Name, bool parent, float duration)
{
    float pos[3]; char sName[64], sTargetName[64];
    int Particle = CreateEntityByName("info_particle_system");
    GetClientAbsOrigin(client, pos);
    TeleportEntity(Particle, pos, NULL_VECTOR, NULL_VECTOR);
    DispatchKeyValue(Particle, "effect_name", Particle_Name);

    if (parent)
    {
        int userid = GetClientUserId(client);
        Format(sName, sizeof(sName), "%d", userid+25);
        DispatchKeyValue(client, "targetname", sName);
        GetEntPropString(client, Prop_Data, "m_iName", sName, sizeof(sName));

        Format(sTargetName, sizeof(sTargetName), "%d", userid+1000);
        DispatchKeyValue(Particle, "targetname", sTargetName);
        DispatchKeyValue(Particle, "parentname", sName);
    }

    DispatchSpawn(Particle);

    if (parent)
    {
        SetVariantString(sName);
        AcceptEntityInput(Particle, "SetParent", Particle, Particle);
    }
    ActivateEntity(Particle);
    AcceptEntityInput(Particle, "start");

    static char variant_str[128];
    Format(variant_str, sizeof(variant_str), "OnUser1 !self:Hurt::%f:1", duration);
    SetVariantString(variant_str);
    AcceptEntityInput(Particle, "AddOutput");
    AcceptEntityInput(Particle, "FireUser1");
}

void IgnitePlayer(int client, float duration)
{
    if (Cmd_CheckClient(client, -1, false, -1, false))
    {
        float pos[3];
        GetClientAbsOrigin(client, pos);

        static char sUser[256];
        IntToString(GetClientUserId(client)+25, sUser, sizeof(sUser));

        CreateParticle(client, BURN_IGNITE_PARTICLE, true, duration);

        int Damage = CreateEntityByName("point_hurt");
        DispatchKeyValue(Damage, "Damage", "1");
        DispatchKeyValue(Damage, "DamageType", "8");
        DispatchKeyValue(client, "targetname", sUser);
        DispatchKeyValue(Damage, "DamageTarget", sUser);
        DispatchSpawn(Damage);
        TeleportEntity(Damage, pos, NULL_VECTOR, NULL_VECTOR);
        AcceptEntityInput(Damage, "Hurt");

        SetVariantString("OnUser1 !self:Hurt::0.1:1");
        AcceptEntityInput(Damage, "AddOutput");

        static char variant_str[64];
        Format(variant_str, sizeof(variant_str), "OnUser1 !self:Kill::%f:1", duration);
        SetVariantString(variant_str);
        AcceptEntityInput(Damage, "AddOutput");
        AcceptEntityInput(Damage, "FireUser1");
    }
    else if (RealValidEntity(client))
    { IgniteEntity(client, duration); }
}

bool TraceRayDontHitSelf(int entity, int mask, any data)
{
    if (entity == data) // Check if the TraceRay hit the itself.
    {
        return false; // Don't let the entity be hit
    }
    return true; // It didn't hit itself
}

// DEVELOPMENT //

void PrecacheParticle(const char[] ParticleName)
{
    int Particle = CreateEntityByName("info_particle_system");
    if (!RealValidEntity(Particle)) return;

    DispatchKeyValue(Particle, "effect_name", ParticleName);
    DispatchSpawn(Particle);
    ActivateEntity(Particle);
    AcceptEntityInput(Particle, "start");

    SetVariantString("OnUser1 !self:Kill::0.3:1");
    AcceptEntityInput(Particle, "AddOutput");
    AcceptEntityInput(Particle, "FireUser1");
}

void LogCommand(const char[] format, any ...)
{
    if (!g_bLog) return;

    static char buffer[512];
    VFormat(buffer, sizeof(buffer), format, 2);
    Handle file;

    static char FileName[256], sTime[256];
    FormatTime(sTime, sizeof(sTime), "%Y%m%d");
    BuildPath(Path_SM, FileName, sizeof(FileName), "logs/customcmds_%s.log", sTime);
    file = OpenFile(FileName, "a+");
    FormatTime(sTime, sizeof(sTime), "%b %d |%H:%M:%S| %Y");
    WriteFileLine(file, "%s: %s", sTime, buffer);
    FlushFile(file);
    CloseHandle(file);
}

void GrabLookingEntity(int client)
{
    int entity = GetLookingEntity(client);
    if (g_bGrab[client])
    { PrintToChat(client, "[SM] You are already grabbing an entity"); return; }
    else if (g_bGrabbed[entity])
    { PrintToChat(client, "[SM] The entity is already moving"); return; }

    if (Cmd_CheckClient(client, -1, false, -1, false))
    {
        g_bGrab[client] = true;
        g_bGrabbed[entity] = true;
        g_iLastGrabbedEntity[client] = entity;
        PrintToChat(client, "[SM] You are now grabbing an entity");

        static char sName[64], sObjectName[64];
        Format(sName, sizeof(sName), "%d", GetClientUserId(client)+25);
        Format(sObjectName, sizeof(sObjectName), "%d", entity+100);

        DispatchKeyValue(entity, "targetname", sObjectName);
        DispatchKeyValue(client, "targetname", sName);
        GetEntPropString(client, Prop_Data, "m_iName", sName, sizeof(sName));
        DispatchKeyValue(entity, "parentname", sName);
        SetVariantString(sName);
        AcceptEntityInput(entity, "SetParent", entity, entity);
    }
    else
    { PrintToChat(client, "[SM] Invalid client!"); }
}

void ReleaseLookingEntity(int client)
{
    int entity = g_iLastGrabbedEntity[client];
    if (RealValidEntity(entity))
    {
        g_bGrab[client] = false;
        g_bGrabbed[entity] = false;
        PrintToChat(client, "[SM] You are no longer grabbing an object");
        DispatchKeyValue(entity, "targetname", "");
        DispatchKeyValue(entity, "parentname", "");
        SetEntityRenderColor(entity, 255, 255 ,255, 255);
        AcceptEntityInput(entity, "SetParent");
    }
    else
    { PrintToChat(client, "[SM] The grabbed entity is not valid"); }
}

void CreateAcidSpill(int client, int sender)
{
    if (!Cmd_CheckClient(client, sender, false, -1, true)) return;

    float vecPos[3];
    GetClientAbsOrigin(client, vecPos);
    vecPos[2]+=16.0;

    Logic_RunScript("DropSpit(Vector(%f, %f, %f))", vecPos[0], vecPos[1], vecPos[2]);
}

void SetAdrenalineEffect(int client, int sender, float timelimit = -1.0)
{
    if (!Cmd_CheckClient(client, sender, false, -1, true)) return;

    float final_time = timelimit;
    if (!timelimit || timelimit <= 0.0)
    { final_time = 15.0; }
    Logic_RunScript("GetPlayerFromUserID(%d).UseAdrenaline(%f)", GetClientUserId(client), final_time);
}

void SetTempHealth(int client, float flAmount)
{
    Logic_RunScript("GetPlayerFromUserID(%d).SetHealthBuffer(%f)", GetClientUserId(client), flAmount);
}

void RevivePlayer_Cmd(int client, int sender)
{
    if (!Cmd_CheckClient(client, sender, true, 1, true)) return;

    if (!GetEntProp(client, Prop_Send, "m_isIncapacitated") && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
    { PrintToChat(sender, "[SM] The player is not incapacitated"); }

    RevivePlayer(client);
}

void RevivePlayer(int client)
{
    if (!GetEntProp(client, Prop_Send, "m_isIncapacitated") && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge")) return;
    Logic_RunScript("GetPlayerFromUserID(%d).ReviveFromIncap()", GetClientUserId(client));
}

void ShovePlayer_Cmd(int client, int sender)
{
    if (!Cmd_CheckClient(client, sender, true, -1, true)) return;

    float vecOrigin[3];
    GetClientAbsOrigin(sender, vecOrigin);
    Logic_RunScript("GetPlayerFromUserID(%d).Stagger(Vector(%f, %f, %f))", GetClientUserId(client), vecOrigin[0], vecOrigin[1], vecOrigin[2]);
}

int GetClientTempHealth(int client)
{
    //First filter -> Must be a valid client and not a spectator (They dont have health).
    if (!Cmd_CheckClient(client, -1, true, -1, false)) return -1;

    //First, we get the amount of temporal health the client has
    float buffer = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");

    //We declare the permanent and temporal health variables
    float TempHealth;

    //In case the buffer is 0 or less, we set the temporal health as 0, because the client has not used any pills or adrenaline yet
    if (buffer <= 0.0)
    {
        TempHealth = 0.0;
    }

    //In case it is higher than 0, we proceed to calculate the temporl health
    else
    {
        //This is the difference between the time we used the temporal item, and the current time
        float difference = GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime");

        //We get the decay rate from this convar (Note: Adrenaline uses this value)
        //This is a constant we create to determine the amount of health. This is the amount of time it has to pass
        //before 1 Temporal HP is consumed.
        float constant = 1.0 / g_fPillsDecay;

        //Then we do the calcs
        TempHealth = buffer - (difference / constant);
    }

    //If the temporal health resulted less than 0, then it is just 0.
    if (TempHealth < 0.0)
    {
        TempHealth = 0.0;
    }

    //Return the value
    return RoundToFloor(TempHealth);
}

void RemoveTempHealth(int client)
{
    if (!Cmd_CheckClient(client, -1, true, -1, false)) return;
    SetTempHealth(client, 0.0);
}

void PanicEvent()
{
    int Director = CreateEntityByName("info_director");
    DispatchSpawn(Director);
    AcceptEntityInput(Director, "ForcePanicEvent");
    AcceptEntityInput(Director, "Kill");
}

int GetLookingEntity(int client)
{
    if (!IsValidClient(client)) return -1;

    float VecOrigin[3], VecAngles[3];
    GetClientEyePosition(client, VecOrigin);
    GetClientEyeAngles(client, VecAngles);
    TR_TraceRayFilter(VecOrigin, VecAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitSelf, client);
    if (TR_DidHit(null))
    {
        int entity = TR_GetEntityIndex(null);
        if (RealValidEntity(entity))
        {
            return entity;
        }
    }
    return -1;
}

#define PLUGIN_SCRIPTLOGIC "plugin_scripting_logic_entity"

void Logic_RunScript(const char[] sCode, any ...)
{
    int iScriptLogic = FindEntityByTargetname(-1, PLUGIN_SCRIPTLOGIC);
    if (!RealValidEntity(iScriptLogic))
    {
        iScriptLogic = CreateEntityByName("logic_script");
        DispatchKeyValue(iScriptLogic, "targetname", PLUGIN_SCRIPTLOGIC);
        DispatchSpawn(iScriptLogic);
    }

    static char sBuffer[512];
    VFormat(sBuffer, sizeof(sBuffer), sCode, 2);

    SetVariantString(sBuffer);
    AcceptEntityInput(iScriptLogic, "RunScriptCode");
}

void SetDTCountdownTimer(int entity, const char[] classname, const char[] timer_str, float duration)
{
    int info = FindSendPropInfo(classname, timer_str);
    SetEntDataFloat(entity, (info+4), duration, true);
    SetEntDataFloat(entity, (info+8), GetGameTime()+duration, true);
}

stock int FindEntityByTargetname(int index, const char[] findname, bool onlyNetworked = false)
{
    for (int i = index; i < (onlyNetworked ? GetMaxEntities() : (GetMaxEntities()*2)); i++) {
        if (!RealValidEntity(i)) continue;
        static char name[128];
        GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
        if (strcmp(name, findname, false) == 0) continue;
        return i;
    }
    return -1;
}

stock bool IsSurvivor(int client) {
    return GetClientTeam(client) == 2 || GetClientTeam(client) == 4;
}

stock bool IsInfected(int client) {
    return GetClientTeam(client) == 3;
}

void EmitAmbientGenericSound(float pos[3], const char[] snd_str)
{
    int snd_ent = CreateEntityByName("ambient_generic");

    TeleportEntity(snd_ent, pos, NULL_VECTOR, NULL_VECTOR);
    DispatchKeyValue(snd_ent, "message", snd_str);
    DispatchKeyValue(snd_ent, "health", "10");
    DispatchKeyValue(snd_ent, "spawnflags", "48");
    DispatchSpawn(snd_ent);
    ActivateEntity(snd_ent);

    AcceptEntityInput(snd_ent, "PlaySound");

    AcceptEntityInput(snd_ent, "Kill");
}

stock bool IsValidClient(int client) {
    return client > 0 && client <= MaxClients && IsClientInGame(client);
}

stock bool RealValidEntity(int entity) {
    return (entity > 0 && IsValidEntity(entity));
}

stock bool Cmd_CheckClient(int client, int sender = -1, bool must_be_alive = false, int must_be_survivor = -1, bool print = true)
{
    if (!IsValidClient(client))
    { if (print && IsValidClient(sender)) PrintToChat(sender, "[SM] Invalid client!"); return false; }

    if (must_be_alive && (!IsPlayerAlive(client) || IsClientObserver(client)))
    { if (print && IsValidClient(sender)) PrintToChat(sender, "[SM] Client is not a living player!"); return false; }

    if (must_be_survivor > 0)
    {
        if (!IsSurvivor(client))
        { if (print && IsValidClient(sender)) PrintToChat(sender, "[SM] Client is not a survivor!"); return false; }
    }
    else if (must_be_survivor == 0)
    {
        if (!IsInfected(client))
        { if (print && IsValidClient(sender)) PrintToChat(sender, "[SM] Client is not an infected!"); return false; }
    }

    return true;
}

stock int Cmd_GetTargets(int client, const char[] arg, int[] target_list, int filter = COMMAND_FILTER_ALIVE)
{
    static char target_name[MAX_TARGET_LENGTH]; target_name[0] = '\0';
    int target_count;
    bool tn_is_ml;
    if ((target_count = ProcessTargetString(
            arg,
            client,
            target_list,
            MAXPLAYERS,
            filter,
            target_name,
            sizeof(target_name),
            tn_is_ml)) <= 0)
    { ReplyToTargetError(client, target_count); return -1; }
    return target_count;
}

void DoClientTrace(int client, int mask = MASK_OPAQUE, bool print_to_cl = false, float targ_vec[3])
{
    if (!IsValidClient(client)) return;

    float VecAngles[3];
    GetClientEyePosition(client, targ_vec);
    GetClientEyeAngles(client, VecAngles);
    TR_TraceRayFilter(targ_vec, VecAngles, mask, RayType_Infinite, TraceRayDontHitSelf, client);
    if (TR_DidHit(null))
    {
        TR_GetEndPosition(targ_vec);
    }
    else if (print_to_cl)
    {
        PrintToChat(client, "[SM] Vector out of world geometry. Getting origin instead.");
    }
}