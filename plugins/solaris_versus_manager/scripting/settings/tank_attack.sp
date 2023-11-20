#if defined __TANK_ATTACK__
    #endinput
#endif
#define __TANK_ATTACK__

ConVar cvBlockPunchRock;
ConVar cvBlockJumpRock;

void AskPluginLoad2_TankAttack() {
    CreateNative("Solaris_BlockPunchRock", Native_BlockPunchRock);
    CreateNative("Solaris_BlockJumpRock",  Native_BlockJumpRock);
}

any Native_BlockPunchRock(Handle hPlugin, int iNumParams) {
    return BlockPunchRock();
}

any Native_BlockJumpRock(Handle hPlugin, int iNumParams) {
    return BlockJumpRock();
}

void OnAllPluginsLoaded_TankAttack() {
    // Block Punch rock
    cvBlockPunchRock = FindConVar("l4d2_block_punch_rock");
    BlockPunchRock(true, cvBlockPunchRock.BoolValue);
    cvBlockPunchRock.AddChangeHook(CvChg_PunchRock);

    // Block Jump rock
    cvBlockJumpRock = FindConVar("l4d2_block_jump_rock");
    BlockJumpRock(true, cvBlockJumpRock.BoolValue);
    cvBlockJumpRock.AddChangeHook(CvChg_BlockJumpRock);
}

void CvChg_PunchRock(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    if (strcmp(szOldVal, szNewVal) == 0)
        return;

    BlockPunchRock(true, cvBlockPunchRock.BoolValue);
}

void CvChg_BlockJumpRock(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    if (strcmp(szOldVal, szNewVal) == 0)
        return;

    BlockJumpRock(true, cvBlockJumpRock.BoolValue);
}

bool BlockPunchRock(bool bSet = false, bool bVal = false) {
    static bool bBlock;

    if (bSet)
        bBlock = bVal;

    return bBlock;
}

bool BlockJumpRock(bool bSet = false, bool bVal = false) {
    static bool bBlock;

    if (bSet)
        bBlock = bVal;

    return bBlock;
}