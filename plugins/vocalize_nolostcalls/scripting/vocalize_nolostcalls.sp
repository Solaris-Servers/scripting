/*
    Vocalize No Lost Call
    Copyright (C) 2013  Buster "Mr. Zero" Nielsen

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#pragma newdecls required
#pragma semicolon 1

/* Includes */
#include <sourcemod>
#include <sceneprocessor>

/* Plugin Information */
public Plugin myinfo =  {
    name        = "Vocalize No Lost Call",
    author      = "Buster \"Mr. Zero\" Nielsen",
    description = "Stops Survivors from vocalize their \"lost call\" lines",
    version     = "1.0.0",
    url         = "https://forums.alliedmods.net/showthread.php?t=241585&highlight=lostcall"
}

/* Plugin Functions */
public void OnSceneStageChanged(int iScene, SceneStages ssStage) {
    switch (ssStage) {
        case SceneStage_Started: {
            char szFile[PLATFORM_MAX_PATH];
            if (!GetSceneFile(iScene, szFile, sizeof(szFile)))
                return;

            if (StrContains(szFile, "lostcall", false) == -1)
                return;

            CancelScene(iScene);
        }
    }
}