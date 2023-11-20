#if defined _solarisapi_contests_url_included
 #endinput
#endif
#define _solarisapi_contests_url_included

methodmap ContestUrlBuilder {
    /**
    * PATCH https://api.solaris-servers.ru/v1/contests/:contestId/set-reward-amount
    * 
    * @param szBuffer           Buffer to write URL to
    * @param iMaxlength         Maximum length of szBuffer
    * @param contestId          Existing Contest ID
    */
    public static void SetRewardAmount(char[] szBuffer, int iMaxlength, const char[] contestId) {
        Format(szBuffer, iMaxlength, "%s/v1/contests/%s/set-reward-amount", SAPI_BASE, contestId);
    }

    /**
    * POST https://api.solaris-servers.ru/v1/contests/:contestId/award-points
    * 
    * @param szBuffer           Buffer to write URL to
    * @param iMaxlength         Maximum length of szBuffer
    * @param contestId          Existing Contest ID
    */
    public static void AwardPoints(char[] szBuffer, int iMaxlength, const char[] contestId) {
        Format(szBuffer, iMaxlength, "%s/v1/contests/%s/award-points", SAPI_BASE, contestId);
    }
}