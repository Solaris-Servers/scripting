#if defined __CUSTOM_TAGS__
    #endinput
#endif
#define __CUSTOM_TAGS__

// COPYRIGHT PSYCHONIC
// USED WITH PERMISSION
#define CUSTOM_TAGS_VERSION 4

#define TAG_SIZE     64
#define SV_TAGS_SIZE 256

ConVar    cvTags;
ArrayList CustomTagsArray;
bool      bTagsHooked;
bool      bIgnoreNextChange;

stock void AddCustomServerTag(const char[] szTag) {
    if (cvTags == null)
        cvTags = FindConVar("sv_tags");
    if (CustomTagsArray == null)
        CustomTagsArray = new ArrayList(TAG_SIZE);
    if (CustomTagsArray.FindString(szTag) == -1)
        CustomTagsArray.PushString(szTag);
    char szCurrentTags[SV_TAGS_SIZE];
    cvTags.GetString(szCurrentTags, sizeof(szCurrentTags));
    // already have this tag
    if (StrContains(szCurrentTags, szTag) > -1)
        return;
    char szNewTags[SV_TAGS_SIZE];
    Format(szNewTags, sizeof(szNewTags), "%s%s%s", szCurrentTags, szCurrentTags[0] != 0 ? ", " : "", szTag);
    int iFlags = cvTags.Flags;
    cvTags.Flags = iFlags & ~FCVAR_NOTIFY;
    bIgnoreNextChange = true;
    cvTags.SetString(szNewTags);
    bIgnoreNextChange = false;
    cvTags.Flags = iFlags;
    if (!bTagsHooked) {
        cvTags.AddChangeHook(OnTagsChanged);
        bTagsHooked = true;
    }
}

stock void RemoveCustomServerTag(const char[] szTag) {
    if (cvTags == null)
        cvTags = FindConVar("sv_tags");
    // we wouldn't have to check this if people aren't removing before adding, but... you know...
    if (CustomTagsArray != null) {
        int Idx = CustomTagsArray.FindString(szTag);
        if (Idx > -1) CustomTagsArray.Erase(Idx);
    }
    char szCurrentTags[SV_TAGS_SIZE];
    cvTags.GetString(szCurrentTags, sizeof(szCurrentTags));
    // tag isn't on here, just bug out
    if (StrContains(szCurrentTags, szTag) == -1)
        return;
    ReplaceString(szCurrentTags, sizeof(szCurrentTags), szTag, "");
    ReplaceString(szCurrentTags, sizeof(szCurrentTags), ", , ", "");
    int iFlags = cvTags.Flags;
    cvTags.Flags = iFlags & ~FCVAR_NOTIFY;
    bIgnoreNextChange = true;
    cvTags.SetString(szCurrentTags);
    bIgnoreNextChange = false;
    cvTags.Flags = iFlags;
}

void OnTagsChanged(ConVar cv, const char[] szOldVal, const char[] szNewVal) {
    // we fired this callback, no need to reapply tags
    if (bIgnoreNextChange)
        return;
    // reapply each custom tag
    for (int i = 0; i < CustomTagsArray.Length; i++) {
        char szTag[TAG_SIZE];
        CustomTagsArray.GetString(i, szTag, sizeof(szTag));
        AddCustomServerTag(szTag);
    }
}