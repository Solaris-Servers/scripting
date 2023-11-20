#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks/anim>
#include <actions>

#define GAMEDATA_FILE "l4d_fix_common_shove"

int    g_iInfectedBodyOffs;
Handle g_hCall_SetDesiredPosture;

ConVar g_cvShoveFlag;
int    g_iShoveFlag;

enum ActivityType {
    MOTION_CONTROLLED_XY    = 0x0001,   // XY position and orientation of the bot is driven by the animation.
    MOTION_CONTROLLED_Z     = 0x0002,   // Z position of the bot is driven by the animation.
    ACTIVITY_UNINTERRUPTIBLE= 0x0004,   // activity can't be changed until animation finishes
    ACTIVITY_TRANSITORY     = 0x0008,   // a short animation that takes over from the underlying animation momentarily, resuming it upon completion
    ENTINDEX_PLAYBACK_RATE  = 0x0010,   // played back at different rates based on entindex
};

enum PostureType {
    STAND,
    CROUCH,
    SIT,
    CRAWL,
    LIE
};

methodmap IBody {
    public void SetDesiredPosture(PostureType posture) {
        SDKCall(g_hCall_SetDesiredPosture, this, posture);
    }
}

methodmap ZombieBotBody < IBody {
    property int m_activity {
        public get() {
            return LoadFromAddress(view_as<Address>(this) + view_as<Address>(80), NumberType_Int32);
        }

        public set(int iActor) {
            StoreToAddress(view_as<Address>(this) + view_as<Address>(80), iActor, NumberType_Int32);
        }
    }

    property ActivityType m_activityType {
        public get() {
            return LoadFromAddress(view_as<Address>(this) + view_as<Address>(84), NumberType_Int32);
        }

        public set(ActivityType flags) {
            StoreToAddress(view_as<Address>(this) + view_as<Address>(84), flags, NumberType_Int32);
        }
    }
}

enum {
    SHOVE_CROUCHING = 1,
    SHOVE_FALLING   = (1 << 1),
    SHOVE_LANDING   = (1 << 2)
};

enum PendingShoveState {
    PendingShove_Invalid = 0,
    PendingShove_Yes,
    PendingShove_Callback,
};

enum struct PendingShoveInfo {
    int key;
    PendingShoveState state;
    float direction_x;
    float direction_y;
    float direction_z;
}

methodmap PendingShoveStore < ArrayList {
    public PendingShoveStore() {
        return view_as<PendingShoveStore>(new ArrayList(sizeof(PendingShoveInfo) + 1));
    }

    public PendingShoveState GetState(int iEnt) {
        PendingShoveState state;
        int iIdx = this.FindValue(EntIndexToEntRef(iEnt), PendingShoveInfo::key);
        if (iIdx != -1)
            state = this.Get(iIdx, PendingShoveInfo::state);
        return state;
    }

    public void SetState(int iEnt, PendingShoveState state) {
        int key = EntIndexToEntRef(iEnt);
        int iIdx = this.FindValue(key, PendingShoveInfo::key);
        if (iIdx == -1)
            iIdx = this.Push(key);
        this.Set(iIdx, state, PendingShoveInfo::state);
    }

    public bool GetDirection(int iEnt, float vDirection[3]) {
        int iIdx = this.FindValue(EntIndexToEntRef(iEnt), PendingShoveInfo::key);
        if (iIdx != -1) {
            vDirection[0] = this.Get(iIdx, PendingShoveInfo::direction_x);
            vDirection[1] = this.Get(iIdx, PendingShoveInfo::direction_y);
            vDirection[2] = this.Get(iIdx, PendingShoveInfo::direction_z);
            return true;
        }
        return false;
    }

    public void SetDirection(int iEnt, const float vDirection[3]) {
        int key = EntIndexToEntRef(iEnt);
        int iIdx = this.FindValue(key, PendingShoveInfo::key);
        if (iIdx == -1)
            iIdx = this.Push(key);
        this.Set(iIdx, vDirection[0], PendingShoveInfo::direction_x);
        this.Set(iIdx, vDirection[1], PendingShoveInfo::direction_y);
        this.Set(iIdx, vDirection[2], PendingShoveInfo::direction_z);
    }

    public bool Delete(int iEnt) {
        int iIdx = this.FindValue(EntIndexToEntRef(iEnt), PendingShoveInfo::key);
        if (iIdx != -1) {
            this.Erase(iIdx);
            return true;
        }

        return false;
    }
}

PendingShoveStore g_PendingShoveStore;

public Plugin myinfo = {
    name        = "[L4D & 2] Fix Common Shove",
    author      = "Forgetest",
    description = "Fix commons being immune to shoves when crouching, falling and landing.",
    version     = "1.2",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins",
}

public void OnPluginStart() {
    GameData gmConf = new GameData(GAMEDATA_FILE);
    if (!gmConf) SetFailState("Missing gamedata \""...GAMEDATA_FILE..."\"");

    StartPrepSDKCall(SDKCall_Raw);
    if (!PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, "ZombieBotBody::SetDesiredPosture"))
        SetFailState("Missing signature \"ZombieBotBody::SetDesiredPosture\"");
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    g_hCall_SetDesiredPosture = EndPrepSDKCall();

    g_iInfectedBodyOffs = gmConf.GetOffset("Infected::m_body");
    if (g_iInfectedBodyOffs == -1)
        SetFailState("Missing offset \"Infected::m_body\"");

    delete gmConf;

    g_PendingShoveStore = new PendingShoveStore();

    g_cvShoveFlag = CreateConVar(
    "l4d_common_shove_flag", "7",
    "Flag for fixing common shove. 1 = Crouch, 2 = Falling, 4 = Landing",
    FCVAR_CHEAT, true, 0.0, true, 7.0);
    g_iShoveFlag = g_cvShoveFlag.IntValue;
    g_cvShoveFlag.AddChangeHook(CvarChg_ShoveFlag);
}

void CvarChg_ShoveFlag(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    g_iShoveFlag = g_cvShoveFlag.IntValue;
}

public void OnMapStart() {
    g_PendingShoveStore.Clear();
}

public void OnEntityDestroyed(int iEnt) {
    if (!IsInfected(iEnt))
        return;

    g_PendingShoveStore.Delete(iEnt);
}

public void OnActionCreated(BehaviorAction action, int iActor, const char[] szName) {
    if (szName[0] == 'I' && strcmp(szName, "InfectedShoved") == 0) {
        action.OnStart = InfectedShoved_OnStart;
        action.OnShoved = InfectedShoved_OnShoved;
        action.OnLandOnGroundPost = InfectedShoved_OnLandOnGroundPost;
    }
}

Action InfectedShoved_OnStart(BehaviorAction action, int iActor, any priorAction, ActionResult result) {
    // falling check
    if (GetEntPropEnt(iActor, Prop_Data, "m_hGroundEntity") == -1)  {
        if (g_iShoveFlag & SHOVE_FALLING) {
            result.type = CONTINUE; // do not exit

            g_PendingShoveStore.SetState(iActor, PendingShove_Yes); // for later use in "InfectedShoved_OnLandOnGroundPost"

            float vDirection[3];
            vDirection[0] = action.Get(56, NumberType_Int32);
            vDirection[1] = action.Get(60, NumberType_Int32);
            vDirection[2] = action.Get(64, NumberType_Int32);

            float vPos[3];
            GetEntPropVector(iActor, Prop_Data, "m_vecAbsOrigin", vPos);

            SubtractVectors(vDirection, vPos, vDirection);
            g_PendingShoveStore.SetDirection(iActor, vDirection);

            // almost certain that shove does nothing at the moment, just skip it
            return Plugin_Handled;
        }

        return Plugin_Continue;
    }

    if (g_iShoveFlag & SHOVE_CROUCHING) {
        Infected_GetBodyInterface(iActor).SetDesiredPosture(STAND); // force standing to activate shoves
    }

    if (g_iShoveFlag & SHOVE_LANDING || (g_iShoveFlag & SHOVE_FALLING && g_PendingShoveStore.GetState(iActor) == PendingShove_Callback)) {
        ForceActivityInterruptible(iActor); // if they happen to land on ground at the time, override
    }

    if (g_PendingShoveStore.GetState(iActor) == PendingShove_Callback) {
        float vDirection[3];
        g_PendingShoveStore.GetDirection(iActor, vDirection);

        float vPos[3];
        GetEntPropVector(iActor, Prop_Data, "m_vecAbsOrigin", vPos);
        AddVectors(vPos, vDirection, vPos);

        action.Set(56, vPos[0], NumberType_Int32);
        action.Set(60, vPos[1], NumberType_Int32);
        action.Set(64, vPos[2], NumberType_Int32);

        g_PendingShoveStore.Delete(iActor);
    }

    return Plugin_Continue;
}

Action InfectedShoved_OnShoved(BehaviorAction action, int iActor, int iEnt, ActionDesiredResult result) {
    // falling check
	if (GetEntPropEnt(iActor, Prop_Data, "m_hGroundEntity") != -1) {
		if (g_iShoveFlag & SHOVE_CROUCHING)
			Infected_GetBodyInterface(iActor).SetDesiredPosture(STAND); // force standing to activate shoves
	}

	return Plugin_Continue;
}

Action InfectedShoved_OnLandOnGroundPost(BehaviorAction action, int iActor, int iEnt, ActionDesiredResult result) {
    if (~g_iShoveFlag & SHOVE_FALLING || g_PendingShoveStore.GetState(iActor) != PendingShove_Yes)
        return Plugin_Continue;

    action.IsStarted = false; // trick the action into calling OnStart as if actor get shoved this frame
    g_PendingShoveStore.SetState(iActor, PendingShove_Callback);

    ForceActivityInterruptible(iActor); // if they happen to land on ground at the time, override

    return Plugin_Handled;
}

bool ForceActivityInterruptible(int iInfected) {
    ZombieBotBody body = Infected_GetBodyInterface(iInfected);

    // perhaps unnecessary
    switch (body.m_activity)  {
        case L4D2_ACT_TERROR_JUMP_LANDING,
            L4D2_ACT_TERROR_JUMP_LANDING_HARD,
            L4D2_ACT_TERROR_JUMP_LANDING_NEUTRAL,
            L4D2_ACT_TERROR_JUMP_LANDING_HARD_NEUTRAL: {
            body.m_activityType &= ~ACTIVITY_UNINTERRUPTIBLE;
            return true;
        }
    }

    return false;
}

ZombieBotBody Infected_GetBodyInterface(int iInfected) {
    return view_as<ZombieBotBody>(GetEntData(iInfected, g_iInfectedBodyOffs, 4));
}

bool IsInfected(int iEnt) {
    if (iEnt <= MaxClients)
        return false;

    if (!IsValidEdict(iEnt))
        return false;

    char szClsName[64];
    GetEdictClassname(iEnt, szClsName, sizeof(szClsName));
    return strcmp(szClsName, "infected") == 0;
}