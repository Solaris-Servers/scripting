#if defined __stocks_strings_included
    #endinput
#endif
#define __stocks_strings_included

stock void ST_StrToUpper(const char[] szSource, char[] szDest, int size) {
    for(int i = 0; i < size; i++) {
        szDest[i] = CharToUpper(szSource[i]);
    }
}

stock void ST_StrToLower(const char[] szSource, char[] szDest, int size) {
    for(int i = 0; i < size; i++) {
        szDest[i] = CharToLower(szSource[i]);
    }
}

stock void ST_StrCapitalizeFirstAndLowerRest(const char[] szSource, char[] szDest, int size) {
    for(int i = 0; i < size; i++) {
        if (i == 0) {
            szDest[i] = CharToUpper(szSource[i]);
        } else {
            szDest[i] = CharToLower(szSource[i]);
        }
    }
}