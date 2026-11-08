package com.grantly.android

/**
 * Check an advisor's role when a session first loads, including Home restoration.
 * Recheck on Profile visits, but preserve a previously verified Advisor tab
 * while the same account navigates among other destinations.
 */
internal object AdvisorNavigationRules {
    /** Return control is never exposed to guests or unverified advisors. */
    fun canReturnToAdvisorPortal(approvedAdvisor: Boolean, signedIn: Boolean): Boolean =
        approvedAdvisor && signedIn

    fun shouldVerifyRole(isProfileVisible: Boolean, roleCheckedForSession: Boolean): Boolean =
        isProfileVisible || !roleCheckedForSession

    /** Route an approved advisor to their portal on initial Home entry only.
     * Never interrupt a screen the user opened while verification was pending.
     */
    fun shouldOpenAdvisorOnFirstVerifiedHome(
        roleCheckedForSession: Boolean,
        approvedAdvisor: Boolean,
        onHomeRoot: Boolean
    ): Boolean = !roleCheckedForSession && approvedAdvisor && onHomeRoot
}
