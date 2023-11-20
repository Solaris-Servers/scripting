#if defined __CONVARS__
    #endinput
#endif
#define __CONVARS__

ConVar cvBlockChatCommands;
bool   bBlockChatCommands;
ConVar cvProtectAddress;

void ConVars_OnModuleStart() {
    CreateConVar("hlx_plugin_version", "2.8",                     "HLstatsX Ingame Plugin",  FCVAR_SPONLY|FCVAR_NOTIFY);
    CreateConVar("hlx_webpage",        "http://www.hlstatsx.com", "http://www.hlstatsx.com", FCVAR_SPONLY|FCVAR_NOTIFY);

    cvBlockChatCommands = CreateConVar(
    "hlx_block_commands", "1",
    "If activated HLstatsX commands are blocked from the chat area",
    FCVAR_PROTECTED|FCVAR_UNLOGGED|FCVAR_DONTRECORD, true, 0.0, true, 1.0);
    bBlockChatCommands = cvBlockChatCommands.BoolValue;
    cvBlockChatCommands.AddChangeHook(OnBlockChatCommandsChange);

    cvProtectAddress = CreateConVar(
    "hlx_protect_address", "",
    "Address to be protected for logging/forwarding",
    FCVAR_PROTECTED|FCVAR_UNLOGGED|FCVAR_DONTRECORD, false, 0.0, false, 0.0);
    cvProtectAddress.AddChangeHook(OnProtectAddressChange);
}

void OnBlockChatCommandsChange(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    bBlockChatCommands = cvBlockChatCommands.BoolValue;
}

void OnProtectAddressChange(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    if (strlen(szNewVal) > 0) {
        char szLogCmd[192];
        Format(szLogCmd, sizeof(szLogCmd), "logaddress_add %s", szNewVal);
        LogToGame("Command: %s", szLogCmd);
        ServerCommand(szLogCmd);
    }
}