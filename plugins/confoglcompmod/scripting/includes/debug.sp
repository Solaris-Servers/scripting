#if defined __DEBUG__
    #endinput
#endif
#define __DEBUG__

#if DEBUG_ALL
    #define DEBUG_DEFAULT "1"
#else
    #define DEBUG_DEFAULT "0"
#endif

ConVar cvDebugConfogl;
bool   bDebugConfogl;

void Debug_OnModuleStart() {
    cvDebugConfogl = CreateConVarEx("debug", DEBUG_DEFAULT, "Turn on Debug Logging in all Confogl Modules");
    cvDebugConfogl.AddChangeHook(Debug_ConVarChange);
    bDebugConfogl = cvDebugConfogl.BoolValue;
}

void Debug_ConVarChange(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    bDebugConfogl = cvDebugConfogl.BoolValue;
}

stock bool IsDebugEnabled() {
    return bDebugConfogl || DEBUG_ALL;
}