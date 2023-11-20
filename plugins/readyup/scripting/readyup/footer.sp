#if defined _readyup_footer_included
    #endinput
#endif
#define _readyup_footer_included

#define MAX_FOOTER_LEN 65

methodmap Footer < ArrayList {
    public Footer() {
        return view_as<Footer>(new ArrayList(ByteCountToCells(MAX_FOOTER_LEN)));
    }
    public int Add(const char[] szBuffer) {
        if (!IsEmptyString(szBuffer, MAX_FOOTER_LEN)) {
            return this.PushString(szBuffer);
        }
        return -1;
    }
    public bool Edit(int iIndex, const char[] szStr) {
        if (this.Length > iIndex) {
            this.SetString(iIndex, szStr);
            return true;
        }
        return false;
    }
    public int Find(const char[] szStr) {
        return this.FindString(szStr);
    }
    public char[] Get(int iIndex) {
        static char szBuffer[MAX_FOOTER_LEN];
        if (this.Length > iIndex) {
            this.GetString(iIndex, szBuffer, sizeof(szBuffer));
            return szBuffer;
        } else {
            szBuffer[0] = '\0';
        }
        return szBuffer;
    }
}