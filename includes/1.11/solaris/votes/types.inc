#if defined __solaris_votes_types_included
    #endinput
#endif
#define __solaris_votes_types_included

#define GM_DEFAULT             0       // default vote is created for all non-spec players and can be called on all gamemodes
#define GM_VERSUS              (1<<1)  // vote can be started in versus modes
#define GM_COOP                (1<<2)  // vote can be started in coop modes
#define GM_SCAV                (1<<3)  // vote can be started in scavenge modes
#define GM_SURVIVAL            (1<<4)  // vote can be started in survival modes
#define GM_REALISM             (1<<5)  // vote can be started in realism mode
#define GM_HOLDOUT             (1<<6)  // vote can be started in holdout mode
#define GM_DASH                (1<<7)  // vote can be started in dash mode
#define GM_SHOOTZONES          (1<<8)  // vote can be started in shootzones mode

#define POOL_ALL_NON_SPEC      0
#define POOL_INITIATOR_TEAM    1
#define POOL_SURVIVORS         2
#define POOL_INFECTED          3
#define POOL_SPECTATORS        4

#define RV_DEFAULT             0       // Yes votes > No votes
#define RV_HALF                1       // Yes votes >= No votes
#define RV_MORETHANHALF        2       // Yes votes > 50%
#define RV_MAJORITY            3       // Yes votes > 50% in both teams

typedef VotePassedCallback = function void();

enum VotingState
{
    Voting_Allowed              = 0,
    Voting_InProgress,
    Voting_InCooldown
}

enum VotePermission
{
    VotePermission_Allowed      = 0,       // vote can be started
    VotePermission_InLoading,              // players are loading
    VotePermission_InProgress,             // another vote is pending
    VotePermission_InCooldown,             // voting is on global cooldown
    VotePermission_CaptainsModeActive,     // captains mode is in progress
    VotePermission_NotInGame,              // vote initiator is not in game
    VotePermission_FakeClient,             // vote initiator is a fake client
    VotePermission_Spectator,              // vote initiator is not in Survivor or Infected team
    VotePermission_NVNotAllowed,           // NativeVotes disallows the voting
    VotePermission_RoundStarted,           // voting allowed only before RoundStart
    VotePermission_RestrictedFromSurf,     // voting not allowed on surf configs
    VotePermission_RestrictedFromGauntlet, // voting not allowed on gauntlet configs
    VotePermission_NotInFirstHalf,         // voting allowed only in second half
    VotePermission_GMDisallowed,           // vote is not allowed for current gamemode
    VotePermission_NotEnoughPlayers,       // not enough players to start a vote
    VotePermission_NotInPool               // client is not in pool for current vote
}

methodmap SolarisVote < StringMap {
    property bool HasStarted {
        public set(bool bVal) {
            this.SetValue("bHasStarted", bVal, true);
        }

        public get() {
            bool bHasStarted;
            this.GetValue("bHasStarted", bHasStarted);
            return bHasStarted;
        }
    }

    property int Pool {
        public set(int iVal) {
            this.SetValue("iPool", iVal, true);
        }

        public get() {
            int iPool;
            this.GetValue("iPool", iPool);
            return iPool;
        }
    }

    property int RequiredPlayers {
        public set(int iPlayers) {
            this.SetValue("iMinPlayers", iPlayers, true);
        }

        public get() {
            int iPlayers;
            this.GetValue("iMinPlayers", iPlayers);
            return iPlayers;
        }
    }

    property int GamemodeFlags {
        public set(int iFlags) {
            this.SetValue("iGamemodes", iFlags, true);
        }

        public get() {
            int iFlags;
            this.GetValue("iGamemodes", iFlags);
            return iFlags;
        }
    }

    property int RequiredVotesFlags {
        public set(int iFlags) {
            this.SetValue("iRequiredVotes", iFlags, true);
        }

        public get() {
            int iFlags;
            this.GetValue("iRequiredVotes", iFlags);
            return iFlags;
        }
    }

    property bool FirstHalfOnly {
        public set(bool bVal) {
            this.SetValue("bFirstHalfOnly", bVal, true);
        }

        public get() {
            bool bFirstHalfOnly;
            this.GetValue("bFirstHalfOnly", bFirstHalfOnly);
            return bFirstHalfOnly;
        }
    }

    property bool BeforeRoundOnly {
        public set(bool bVal) {
            this.SetValue("bBeforeRoundOnly", bVal, true);
        }

        public get() {
            bool bBeforeRoundOnly;
            this.GetValue("bBeforeRoundOnly", bBeforeRoundOnly);
            return bBeforeRoundOnly;
        }
    }

    property bool RestrictedFromSurf {
        public set(bool bVal) {
            this.SetValue("bRestrictedFromSurf", bVal, true);
        }

        public get() {
            bool bRestrictedFromSurf;
            this.GetValue("bRestrictedFromSurf", bRestrictedFromSurf);
            return bRestrictedFromSurf;
        }
    }

    property bool RestrictedFromGauntlet {
        public set(bool bVal) {
            this.SetValue("bRestrictedFromGauntlet", bVal, true);
        }

        public get() {
            bool bRestrictedFromGauntlet;
            this.GetValue("bRestrictedFromGauntlet", bRestrictedFromGauntlet);
            return bRestrictedFromGauntlet;
        }
    }

    property bool AllowedOnPracticogl {
        public set(bool bVal) {
            this.SetValue("bAllowedOnPracticogl", bVal, true);
        }

        public get() {
            bool bAllowedOnPracticogl;
            this.GetValue("bAllowedOnPracticogl", bAllowedOnPracticogl);
            return bAllowedOnPracticogl;
        }
    }

    property bool PrintToAll {
        public set(bool bVal) {
            this.SetValue("bPrintToAll", bVal, true);
        }

        public get() {
            bool bPrintToAll;
            this.GetValue("bPrintToAll", bPrintToAll);
            return bPrintToAll;
        }
    }

    /**
    * Attempts to start a new vote
    * @param   iClient         Client, initiating the vote
    * @return  bool            Vote was initiated
    */
    public native bool Start(int iClient);
    // visual flavors
    public native bool StartChangeAllTalkVote(int iClient, bool bEnable);
    public native bool StartChangeChapterVote(int iClient, const char[] szChNum);
    public native bool StartChangeDifficultyVote(int iClient, const char[] szDifficulty);
    public native bool StartChangeMissionVote(int iClient, const char[] szCmpCode);
    public native bool StartKickVote(int iClient, int iUserId);
    public native bool StartRestartVote(int iClient);
    public native bool StartReturnToLobbyVote(int iClient);

    public native SolarisVote OnSuccess(VotePassedCallback cb);

    public void Reset() {
        PrivateForward passedFwd;
        this.GetValue("fwdPassedCb", passedFwd);
        if (passedFwd) delete passedFwd;
        this.Clear();
        this.SetString("szPrint", "", true);
        this.SetString("szTitle", "", true);
        this.SetString("szSuccessMsg", "", true);
        this.SetValue("fwdPassedCb", INVALID_HANDLE, true);
        this.SetValue("bHasStarted", false, true);
        this.SetValue("bPrintToAll", true, true);
        this.HasStarted             = false;
        this.Pool                   = 0;
        this.RequiredPlayers        = 0;
        this.GamemodeFlags          = GM_DEFAULT;
        this.RequiredVotesFlags     = RV_DEFAULT;
        this.FirstHalfOnly          = false;
        this.BeforeRoundOnly        = false;
        this.RestrictedFromSurf     = false;
        this.RestrictedFromGauntlet = false;
        this.AllowedOnPracticogl    = false;
    }

    public SolarisVote ForAllPlayers() {
        this.Pool = POOL_ALL_NON_SPEC;
        return this;
    }

    public SolarisVote ForInitiatorTeam() {
        this.Pool = POOL_INITIATOR_TEAM;
        return this;
    }

    public SolarisVote ForSurvivors() {
        this.Pool = POOL_SURVIVORS;
        return this;
    }

    public SolarisVote ForInfected() {
        this.Pool = POOL_INFECTED;
        return this;
    }

    public SolarisVote ForSpectators() {
        this.Pool = POOL_SPECTATORS;
        return this;
    }

    public SolarisVote SetPrint(const char[] szVotePrint, bool bVotePrintToAll = true) {
        char szFormated[128];
        VFormat(szFormated, sizeof(szFormated), szVotePrint, 2);
        this.SetString("szPrint", szFormated, true);
        this.SetValue("bPrintToAll", bVotePrintToAll, true);
        return this;
    }

    public void GetPrint(char[] szPrintBuf, int iBufLength) {
        this.GetString("szPrint", szPrintBuf, iBufLength);
    }

    public SolarisVote SetTitle(const char[] szVoteTitle, any ...) {
        char szFormated[128];
        VFormat(szFormated, sizeof(szFormated), szVoteTitle, 2);
        this.SetString("szTitle", szFormated, true);
        return this;
    }

    public void GetTitle(char[] szTitleBuf, int iBufLength) {
        this.GetString("szTitle", szTitleBuf, iBufLength);
    }

    public SolarisVote SetSuccessMessage(const char[] szSuccessMsg, any ...) {
        char szFormated[128];
        VFormat(szFormated, sizeof(szFormated), szSuccessMsg, 2);
        this.SetString("szSuccessMsg", szFormated, true);
        return this;
    }

    public void GetSuccessMessage(char[] szSuccessMsgBuf, int iBufLength) {
        this.GetString("szSuccessMsg", szSuccessMsgBuf, iBufLength);
    }

    public SolarisVote SetRequiredPlayers(int iPlayers) {
        this.RequiredPlayers = iPlayers;
        return this;
    }

    public SolarisVote RestrictToGamemodes(int iGMFlags) {
        this.GamemodeFlags = iGMFlags;
        return this;
    }

    public SolarisVote SetRequiredVotes(int iRVFlags) {
        this.RequiredVotesFlags = iRVFlags;
        return this;
    }

    public SolarisVote RestrictToFirstHalf() {
        this.FirstHalfOnly = true;
        return this;
    }

    public SolarisVote RestrictToBeforeRoundStart() {
        this.BeforeRoundOnly = true;
        return this;
    }

    public SolarisVote RestrictFromSurf() {
        this.RestrictedFromSurf = true;
        return this;
    }

    public SolarisVote RestrictFromGauntlet() {
        this.RestrictedFromGauntlet = true;
        return this;
    }

    public SolarisVote AllowOnPracticogl() {
        this.AllowedOnPracticogl = true;
        return this;
    }

    public SolarisVote() {
        SolarisVote self = view_as<SolarisVote>(new StringMap());
        self.Reset();
        return self;
    }
}