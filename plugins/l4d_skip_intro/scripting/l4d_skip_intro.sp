/*
*   First Map - Skip Intro Cutscenes
*   Copyright (C) 2022 Silvers
*
*   This program is free software: you can redistribute it and/or modify
*   it under the terms of the GNU General Public License as published by
*   the Free Software Foundation, either version 3 of the License, or
*   (at your option) any later version.
*
*   This program is distributed in the hope that it will be useful,
*   but WITHOUT ANY WARRANTY; without even the implied warranty of
*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*   GNU General Public License for more details.
*
*   You should have received a copy of the GNU General Public License
*   along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

/*======================================================================================
    Plugin Info:

*   Name    :   [L4D & L4D2] First Map - Skip Intro Cutscenes
*   Author  :   SilverShot
*   Descrp  :   Makes players skip seeing the intro cutscene on first maps, so they can move right away.
*   Link    :   https://forums.alliedmods.net/showthread.php?t=321993
*   Plugins :   https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
    Change Log:

1.13 (10-Apr-2022)
    - Fixed the "l4d_skip_intro_modes_tog" cvar always turning off the plugin. Thanks to "Thefollors" for reporting.

1.12 (01-Dec-2021)
    - Changes to fix warnings when compiling on SourceMod 1.11.
    - Minor change to fix bad coding practice.

1.11 (11-Jul-2021)
    - Slight optimization and change to fix the unhook event errors.

1.10 (21-Jun-2021)
    - Changes to fix the last update potentially not working for all maps.

1.9 (20-Jun-2021)
    - Changed some code to prevent adding multiple identical outputs.

1.8 (15-Feb-2021)
    - Blocked working on finale maps when not using left4dhooks. Thanks to "Zheldorg" for reporting.

1.7 (10-Oct-2020)
    - Minor change again to hopefully fix unhook event errors.

1.6 (05-Oct-2020)
    - Changes to hopefully fix unhook event errors.

1.5 (01-Oct-2020)
    - Changes to support "The Last Stand" update.
    - Fixed lateload not enabling the plugin.

1.4 (10-May-2020)
    - Added cvars: "l4d_skip_intro_allow", "l4d_skip_intro_modes", "l4d_skip_intro_modes_off" and "l4d_skip_intro_modes_tog".
    - Cvar config saved as "l4d_skip_intro.cfg" in "cfgs/sourcemod" folder.
    - Extra checks to skip intro on some addon maps that use a different entity.
    - Thanks to "TiTz" for reporting.

1.3 (29-Apr-2020)
    - Increased the timer delay from 0.1 to 1.0 due to some conditions failing to skip intro. Thanks to "TiTz" for reporting.

1.2 (08-Apr-2020)
    - Added a check incase the director entity was not found. Thanks to "TiTz" for reporting.

1.1 (16-Mar-2020)
    - Fixed not working on all maps when info_director is named differently.

1.0 (10-Mar-2020)
    - Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

bool g_bFaded, g_bOutput1, g_bOutput2;

// ====================================================================================================
//                  PLUGIN INFO / START
// ====================================================================================================
public Plugin myinfo = {
    name        = "[L4D & L4D2] First Map - Skip Intro Cutscenes",
    author      = "SilverShot",
    description = "Makes players skip seeing the intro cutscene on first maps, so they can move right away.",
    version     = "1.13",
    url         = "https://forums.alliedmods.net/showthread.php?t=321993"
}

public void OnPluginStart() {
    // Because round_start can be too early when clients are not in-game. This triggers when the cutscene starts.
    HookEvent("gameinstructor_nodraw", Event_NoDraw, EventHookMode_PostNoCopy);
}

// ====================================================================================================
//                  EVENTS
// ====================================================================================================
void Event_NoDraw(Event eEvent, const char[] szName, bool bDontBroadcast) {
    if (!L4D_IsFirstMapInScenario())
        return;

    g_bFaded   = false;
    g_bOutput1 = false;
    g_bOutput2 = false;

    // Multiple times to make sure it works
    CreateTimer(1.0, TimerStart);
    CreateTimer(5.0, TimerStart);
    CreateTimer(6.0, TimerStart);
    CreateTimer(6.5, TimerStart);
    CreateTimer(7.0, TimerStart);
    CreateTimer(8.0, TimerStart);
}

Action TimerStart(Handle hTimer) {
    // 128 should be long enough, 3rd party maps could be longer than Valves ~52 chars (including OnUser1 below)?
    char szBuffer[128];

    // Every map should have a director, but apparently some still throw -1 error.
    int iEnt = FindEntityByClassname(-1, "info_director");
    if (iEnt != -1) {
        char szDirector[32];
        GetEntPropString(iEnt, Prop_Data, "m_iName", szDirector, sizeof(szDirector));

        for (int i = 0; i < 2; i++) {
            iEnt = -1;
            while ((iEnt = FindEntityByClassname(iEnt, i == 0 ? "point_viewcontrol_survivor" : "point_viewcontrol_multiplayer")) != INVALID_ENT_REFERENCE) {
                // ALLOW CONTROL
                if ((i == 0 && !g_bOutput1) || (i == 1 && !g_bOutput2)) {
                    // ALLOW MOVEMENT
                    FormatEx(szBuffer, sizeof(szBuffer), "OnUser1 %s:ReleaseSurvivorPositions::0:-1", szDirector);
                    SetVariantString(szBuffer);
                    AcceptEntityInput(iEnt, "AddOutput");

                    FormatEx(szBuffer, sizeof(szBuffer), "OnUser1 %s:FinishIntro::0:-1", szDirector);
                    SetVariantString(szBuffer);
                    AcceptEntityInput(iEnt, "AddOutput");
                    AcceptEntityInput(iEnt, "FireUser1");

                    if (i == 0) {
                        g_bOutput1 = true;
                    } else if (i == 1) {
                        g_bOutput2 = true;
                    }
                } else {
                    AcceptEntityInput(iEnt, "FireUser1");
                }

                // STOP SCENE
                SetVariantString("!self");
                AcceptEntityInput(iEnt, "StartMovement");
            }
        }

        // FADE IN
        if ((g_bOutput1 || g_bOutput2) && !g_bFaded) {
            g_bFaded = true;

            iEnt = CreateEntityByName("env_fade");
            DispatchKeyValue(iEnt, "spawnflags", "1");
            DispatchKeyValue(iEnt, "rendercolor", "0 0 0");
            DispatchKeyValue(iEnt, "renderamt", "255");
            DispatchKeyValue(iEnt, "holdtime", "1");
            DispatchKeyValue(iEnt, "duration", "1");
            DispatchSpawn(iEnt);
            AcceptEntityInput(iEnt, "Fade");

            SetVariantString("OnUser1 !self:Kill::2.5:-1");
            AcceptEntityInput(iEnt, "AddOutput");
            AcceptEntityInput(iEnt, "FireUser1");
        }
    }

    return Plugin_Continue;
}