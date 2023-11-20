#if defined _l4d2_third_person_detect_included
    #endinput
#endif
#define _l4d2_third_person_detect_included

/**
*   @param  iClient         Client Index.
*   @param  bIsThirdPerson  true = Is in thirdperson shoulder, false otherwise.
*/
forward void TP_OnThirdPersonChanged(int iClient, bool bIsThirdPerson);

/**
 * Returns true if c_thirdpersonshoulder is equal to 1
 *
 * @return  bool
 */
native bool TP_IsInThirdPerson(int iClient);