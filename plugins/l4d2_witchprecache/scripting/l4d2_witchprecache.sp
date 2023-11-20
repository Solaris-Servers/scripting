#pragma newdecls required
#pragma semicolon 1

public void OnMapStart()
{
    if (!IsModelPrecached("models/infected/witch.mdl"))
    {
        PrecacheModel("models/infected/witch.mdl");
    }

    if (!IsModelPrecached("models/infected/witch_bride.mdl"))
    {
        PrecacheModel("models/infected/witch_bride.mdl");
    }
}