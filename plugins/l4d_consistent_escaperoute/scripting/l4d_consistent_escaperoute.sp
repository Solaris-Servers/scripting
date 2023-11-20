#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <solaris/stocks>

int    g_iMainPathAreaCountOffs;
int    g_iFlowToGoalOffs;
int    g_iMapMaxFlowDistanceOffs;

Handle g_hSDKCallResetPath;
Handle g_hSDKCallAddArea;
Handle g_hSDKCallFinishPath;

methodmap CEscapeRoute {
    public CEscapeRoute(Address addr) {
        return view_as<CEscapeRoute>(addr);
    }
    public void ResetPath() {
        SDKCall(g_hSDKCallResetPath, this);
    }
    public void AddArea(TerrorNavArea area) {
        SDKCall(g_hSDKCallAddArea, this, area);
    }
    public void FinishPath() {
        SDKCall(g_hSDKCallFinishPath, this);
    }
    public TerrorNavArea GetMainPathArea(int iIdx) {
        return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iMainPathAreaCountOffs + 8) + view_as<Address>(iIdx * 4), NumberType_Int32);
    }
    property int MainPathAreaCount {
        public get() {
            return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iMainPathAreaCountOffs), NumberType_Int32);
        }
    }
}

methodmap CUtlVector {
    public int Size() {
        return LoadFromAddress(view_as<Address>(this) + view_as<Address>(12), NumberType_Int32);
    }
    property Address Elements {
        public get() {
            return LoadFromAddress(view_as<Address>(this), NumberType_Int32);
        }
    }
}

methodmap NavAreaVector < CUtlVector {
    public NavAreaVector(Address addr) {
        return view_as<NavAreaVector>(addr);
    }
    public TerrorNavArea At(int iIdx) {
        return LoadFromAddress(this.Elements + view_as<Address>(iIdx * 4), NumberType_Int32);
    }
}

methodmap TerrorNavArea {
    public TerrorNavArea(Address addr) {
        return view_as<TerrorNavArea>(addr);
    }
    public int GetId() {
        return L4D_GetNavAreaID(view_as<Address>(this));
    }
    public void RemoveSpawnAttributes(int iFlag) {
        int iSpawnAttributes = L4D_GetNavArea_SpawnAttributes(view_as<Address>(this));
        L4D_SetNavArea_SpawnAttributes(view_as<Address>(this), iSpawnAttributes & ~iFlag);
    }
    property float FlowToGoal {
        public get() {
            return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iFlowToGoalOffs), NumberType_Int32);
        }
        public set(float fFlow) {
            StoreToAddress(view_as<Address>(this) + view_as<Address>(g_iFlowToGoalOffs), fFlow, NumberType_Int32);
        }
    }
    property float FlowFromStart {
        public get() {
            return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iFlowToGoalOffs + 4), NumberType_Int32);
        }
        public set(float fFlow) {
            StoreToAddress(view_as<Address>(this) + view_as<Address>(g_iFlowToGoalOffs + 4), fFlow, NumberType_Int32);
        }
    }
}

methodmap TerrorNavMesh {
    public TerrorNavArea GetNavAreaByID(int id) {
        return view_as<TerrorNavArea>(L4D_GetNavAreaByID(id));
    }
    property float m_flMapMaxFlowDistance {
        public get() {
            return LoadFromAddress(L4D_GetPointer(POINTER_NAVMESH) + view_as<Address>(g_iMapMaxFlowDistanceOffs), NumberType_Int32);
        }
        public set(float fFlow) {
            StoreToAddress(L4D_GetPointer(POINTER_NAVMESH) + view_as<Address>(g_iMapMaxFlowDistanceOffs), fFlow, NumberType_Int32);
        }
    }
}

CEscapeRoute  g_SpawnPath;
Address       g_pSpawnPath;

NavAreaVector TheNavAreas;
TerrorNavMesh TheNavMesh;

ArrayList     g_aSpawnPathAreas;

enum {
    NAV_AREA_ID,
    FLOW_TO_GOAL,
    FLOW_FROM_START,
    NUM_OF_FLOW_INFO
}

ArrayList g_aAreaFlows;
float     g_fMapMaxFlowDistance;

public Plugin myinfo = {
    name        = "[L4D & 2] Consistent Escape Route",
    author      = "Forgetest",
    description = "True L4D.",
    version     = "1.1.2",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

public void OnPluginStart() {
    InitGameData();
    g_aSpawnPathAreas = new ArrayList();
    g_aAreaFlows      = new ArrayList(NUM_OF_FLOW_INFO);
    HookEvent("round_start_post_nav", Event_RoundStartPostNav);
}

void InitGameData() {
    GameData gmConf = new GameData("l4d_consistent_escaperoute");
    if (gmConf == null) SetFailState("Missing gamedata \"l4d_consistent_escaperoute\"");

    g_pSpawnPath = gmConf.GetAddress("TheEscapeRoute");
    if (g_pSpawnPath == Address_Null) SetFailState("Missing address \"TheEscapeRoute\"");

    g_iMainPathAreaCountOffs = gmConf.GetOffset("CEscapeRoute::m_nMainPathAreaCount");
    if (g_iMainPathAreaCountOffs == -1) SetFailState("Missing offset \"CEscapeRoute::m_nMainPathAreaCount\"");

    g_iFlowToGoalOffs = gmConf.GetOffset("TerrorNavArea::m_flowToGoal");
    if (g_iFlowToGoalOffs == -1) SetFailState("Missing offset \"TerrorNavArea::m_flowToGoal\"");

    g_iMapMaxFlowDistanceOffs = gmConf.GetOffset("TerrorNavMesh::m_flMapMaxFlowDistance");
    if (g_iMapMaxFlowDistanceOffs == -1) SetFailState("Missing offset \"TerrorNavMesh::m_flMapMaxFlowDistance\"");

    StartPrepSDKCall(SDKCall_Raw);
    if (!PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, "CEscapeRoute::ResetPath"))
        SetFailState("Missing signature \"CEscapeRoute::ResetPath\"");
    g_hSDKCallResetPath = EndPrepSDKCall();
    if (g_hSDKCallResetPath == null)
        SetFailState("Failed to create SDKCall \"CEscapeRoute::ResetPath\"");

    StartPrepSDKCall(SDKCall_Raw);
    if (!PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, "CEscapeRoute::AddArea"))
        SetFailState("Missing signature \"CEscapeRoute::AddArea\"");
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // TerrorNavArea
    g_hSDKCallAddArea = EndPrepSDKCall();
    if (g_hSDKCallAddArea == null)
        SetFailState("Failed to create SDKCall \"CEscapeRoute::AddArea\"");

    StartPrepSDKCall(SDKCall_Raw);
    if (!PrepSDKCall_SetFromConf(gmConf, SDKConf_Signature, "CEscapeRoute::FinishPath"))
        SetFailState("Missing signature \"CEscapeRoute::FinishPath\"");
    g_hSDKCallFinishPath = EndPrepSDKCall();
    if (g_hSDKCallFinishPath == null)
        SetFailState("Failed to create SDKCall \"CEscapeRoute::FinishPath\"");

    delete gmConf;
}

void Event_RoundStartPostNav(Event eEvent, const char[] szName, bool bDontBroadcast) {
    CreateTimer(0.1, Timer_RoundStartPostNav, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_RoundStartPostNav(Handle hTimer) {
    if (!SDK_IsVersus())
        return Plugin_Stop;

    g_SpawnPath = LoadFromAddress(g_pSpawnPath, NumberType_Int32);
    TheNavAreas = NavAreaVector(L4D_GetPointer(POINTER_THENAVAREAS));

    if (InSecondHalfOfRound()) {
        if (g_aAreaFlows.Length) {
            for (int i = 0; i < g_aAreaFlows.Length; i++) {
                TerrorNavArea area = TheNavMesh.GetNavAreaByID(g_aAreaFlows.Get(i, NAV_AREA_ID));
                area.FlowToGoal    = g_aAreaFlows.Get(i, FLOW_TO_GOAL);
                area.FlowFromStart = g_aAreaFlows.Get(i, FLOW_FROM_START);
            }

            TheNavMesh.m_flMapMaxFlowDistance = g_fMapMaxFlowDistance;
        }

        if (g_aSpawnPathAreas.Length) {
            for (int i = 0; i < g_SpawnPath.MainPathAreaCount; i++) {
                TerrorNavArea area = g_SpawnPath.GetMainPathArea(i);
                area.RemoveSpawnAttributes(NAV_SPAWN_ESCAPE_ROUTE);
            }

            PrintToServer("[l4d_consistent_escaperoute] Second half (%i / %i nav) (%.5f)", g_SpawnPath.MainPathAreaCount, TheNavAreas.Size(), g_fMapMaxFlowDistance);
            g_SpawnPath.ResetPath();

            for (int i = 0; i < g_aSpawnPathAreas.Length; i++) {
                int iId = g_aSpawnPathAreas.Get(i);
                TerrorNavArea area = TheNavMesh.GetNavAreaByID(iId);
                g_SpawnPath.AddArea(area);
            }

            g_SpawnPath.FinishPath();
        }

        PrintToServer("[l4d_consistent_escaperoute] Restored escape route from last half (%i / %i nav)", g_aSpawnPathAreas.Length, TheNavAreas.Size());
        return Plugin_Stop;
    }

    g_aSpawnPathAreas.Clear();
    g_aAreaFlows.Clear();

    for (int i = 0; i < g_SpawnPath.MainPathAreaCount; i++) {
        TerrorNavArea area = g_SpawnPath.GetMainPathArea(i);
        g_aSpawnPathAreas.Push(area.GetId());
    }

    g_aAreaFlows.Resize(TheNavAreas.Size());

    for (int i = 0; i < TheNavAreas.Size(); i++) {
        TerrorNavArea area = TheNavAreas.At(i);
        g_aAreaFlows.Set(i, area.GetId(), NAV_AREA_ID);
        g_aAreaFlows.Set(i, area.FlowToGoal, FLOW_TO_GOAL);
        g_aAreaFlows.Set(i, area.FlowFromStart, FLOW_FROM_START);
    }

    g_fMapMaxFlowDistance = TheNavMesh.m_flMapMaxFlowDistance;
    PrintToServer("[l4d_consistent_escaperoute] Cached escape route of first half (%i / %i nav) (%.5f)", g_aSpawnPathAreas.Length, TheNavAreas.Size(), g_fMapMaxFlowDistance);
    return Plugin_Stop;
}

stock bool InSecondHalfOfRound() {
    return view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"));
}