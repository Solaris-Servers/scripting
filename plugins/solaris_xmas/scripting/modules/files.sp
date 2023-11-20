#if defined __FILES__
    #endinput
#endif
#define __FILES__

void Files_OnMapStart() {
    // Add files to download
    AddFileToDownloadsTable("models/models_kit_go/xmas/xmastree_mini.dx80.vtx");
    AddFileToDownloadsTable("models/models_kit_go/xmas/xmastree_mini.dx90.vtx");
    AddFileToDownloadsTable("models/models_kit_go/xmas/xmastree_mini.mdl");
    AddFileToDownloadsTable("models/models_kit_go/xmas/xmastree_mini.phy");
    AddFileToDownloadsTable("models/models_kit_go/xmas/xmastree_mini.sw.vtx");
    AddFileToDownloadsTable("models/models_kit_go/xmas/xmastree_mini.vvd");
    AddFileToDownloadsTable("models/models_kit_go/xmas/xmastree_mini.xbox.vtx");
    AddFileToDownloadsTable("materials/models/models_kit_go/xmas/xmastree_miscA.vmt");
    AddFileToDownloadsTable("materials/models/models_kit_go/xmas/xmastree_miscA.vtf");
    AddFileToDownloadsTable("materials/models/models_kit_go/xmas/xmastree_miscA_skin2.vmt");
    AddFileToDownloadsTable("materials/models/models_kit_go/xmas/xmastree_miscA_skin2.vtf");
    AddFileToDownloadsTable("materials/models/models_kit_go/xmas/xmastree_miscB.vmt");
    AddFileToDownloadsTable("materials/models/models_kit_go/xmas/xmastree_miscB.vtf");
    AddFileToDownloadsTable("materials/models/models_kit_go/xmas/xmastree_miscB_skin2.vmt");
    AddFileToDownloadsTable("materials/models/models_kit_go/xmas/xmastree_miscB_skin2.vtf");
    AddFileToDownloadsTable("materials/models/models_kit_go/xmas/xmastree_miscB_spec.vtf");

    // Precache models
    PrecacheModel("models/models_kit_go/xmas/xmastree_mini.mdl", true);

    // Precache sounds
    PrecacheSound("UI/LittleReward.wav");
    PrecacheSound("music/flu/jukebox/all_i_want_for_xmas.wav");
    PrecacheSound("npc/moustachio/strengthlvl5_sostrong.wav");
}