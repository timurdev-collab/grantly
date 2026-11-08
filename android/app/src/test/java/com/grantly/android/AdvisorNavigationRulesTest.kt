package com.grantly.android

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AdvisorNavigationRulesTest {
    @Test fun approvedAdvisorCanReturnToPortalFromStudentView() {
        assertTrue(AdvisorNavigationRules.canReturnToAdvisorPortal(
            approvedAdvisor = true, signedIn = true
        ))
    }

    @Test fun guestsAndUnapprovedAdvisorsCannotReturnToPortal() {
        assertFalse(AdvisorNavigationRules.canReturnToAdvisorPortal(
            approvedAdvisor = true, signedIn = false
        ))
        assertFalse(AdvisorNavigationRules.canReturnToAdvisorPortal(
            approvedAdvisor = false, signedIn = true
        ))
    }

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

    @Test fun failedRoleLookupCanRetryOnHomeWithoutOpeningProfile() {
        // A transient network failure must leave roleCheckedForSession false.
        assertTrue(AdvisorNavigationRules.shouldVerifyRole(
            isProfileVisible = false,
            roleCheckedForSession = false
        ))
        // Once a lookup succeeds, ordinary Home refreshes must not refetch.
        assertFalse(AdvisorNavigationRules.shouldVerifyRole(
            isProfileVisible = false,
            roleCheckedForSession = true
        ))
    }

    @Test fun firstApprovedAdvisorHomeEntryOpensPortal() {
        assertTrue(AdvisorNavigationRules.shouldOpenAdvisorOnFirstVerifiedHome(
            roleCheckedForSession = false,
            approvedAdvisor = true,
            onHomeRoot = true
        ))
    }

    @Test fun verificationDoesNotInterruptOtherDestinations() {
        assertFalse(AdvisorNavigationRules.shouldOpenAdvisorOnFirstVerifiedHome(
            roleCheckedForSession = false,
            approvedAdvisor = true,
            onHomeRoot = false
        ))
    }

    @Test fun returningToHomeAfterRoleWasCheckedDoesNotForceAdvisorPortal() {
        assertFalse(AdvisorNavigationRules.shouldOpenAdvisorOnFirstVerifiedHome(
            roleCheckedForSession = true,
            approvedAdvisor = true,
            onHomeRoot = true
        ))
    }

    @Test fun guestOrUnapprovedAdvisorCannotAutoOpenPortal() {
        assertFalse(AdvisorNavigationRules.shouldOpenAdvisorOnFirstVerifiedHome(
            roleCheckedForSession = false,
            approvedAdvisor = false,
            onHomeRoot = true
        ))
    }
}
