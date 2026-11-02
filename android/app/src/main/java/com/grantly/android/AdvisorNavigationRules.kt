package com.grantly.android

/**
 * Check an advisor's role when a session first loads, including Home restoration.
 * Recheck on Profile visits, but preserve a previously verified Advisor tab
 * while the same account navigates among other destinations.
 */
internal object AdvisorNavigationRules {
    fun shouldVerifyRole(isProfileVisible: Boolean, roleCheckedForSession: Boolean): Boolean =
        isProfileVisible || !roleCheckedForSession
}
