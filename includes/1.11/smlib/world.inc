#if defined _smlib_world_included
    #endinput
#endif
#define _smlib_world_included

#include <sourcemod>

/*
 * Gets the world's max size
 *
 * @param vec       Vector buffer
 */
stock void World_GetMaxs(float vec[3]) {

    GetEntPropVector(0, Prop_Data, "m_WorldMaxs", vec);
}
