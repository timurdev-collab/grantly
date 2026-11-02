package com.grantly.android

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AdvisorNavigationRulesTest {
    @Test fun restoredSessionOnHomeStillChecksAdvisorRole() {
        assertTrue(AdvisorNavigationRules.shouldVerifyRole(
            isProfileVisible = false,
            roleCheckedForSession = false
        ))
    }

    @Test fun leavingProfileKeepsPreviouslyVerifiedAdvisorDestination() {
        assertFalse(AdvisorNavigationRules.shouldVerifyRole(
            isProfileVisible = false,
            roleCheckedForSession = true
        ))
    }

    @Test fun returningToProfileRechecksRoleAndApproval() {
        assertTrue(AdvisorNavigationRules.shouldVerifyRole(
            isProfileVisible = true,
            roleCheckedForSession = true
        ))
    }
}
