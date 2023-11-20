#if defined __CMDS__
    #endinput
#endif
#define __CMDS__

#define ANTISPAM 5

int iPreviousTime[MAXPLAYERS + 1];
int iCurrentTime [MAXPLAYERS + 1];

#include "cmds/hours.sp"
#include "cmds/info.sp"
#include "cmds/lerps.sp"
#include "cmds/loading.sp"
#include "cmds/rates.sp"

void OnModuleStart_Cmds() {
    RegConsoleCmd("sm_info",      Cmd_Info);
    RegConsoleCmd("sm_hours",     Cmd_Hours);
    RegConsoleCmd("sm_loadtimes", Cmd_LoadingTimes);
    RegConsoleCmd("sm_fps",       Cmd_Rates);
    RegConsoleCmd("sm_rates",     Cmd_Rates);
    RegConsoleCmd("sm_lerps",     Cmd_Lerps);

    LoadTranslations("common.phrases");
}