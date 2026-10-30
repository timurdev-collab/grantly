package com.grantly.android

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AdvisorProfessionalProfileRulesTest {
    @Test fun approvedAdvisorMayViewOwnProfessionalProfile() {
        assertTrue(AdvisorProfessionalProfileRules.canView("advisor", "approved"))
    }

    @Test fun unapprovedOrUnknownAdvisorStatusesFailClosed() {
        listOf(null, "", "pending", "rejected", "suspended", "changes_requested", "unexpected")
            .forEach { status ->
                assertFalse(AdvisorProfessionalProfileRules.canView("advisor", status))
            }
    }

    @Test fun nonAdvisorRolesCannotUseProfessionalProfile() {
        listOf("", "student", "admin", "unknown").forEach { role ->
            assertFalse(AdvisorProfessionalProfileRules.canView(role, "approved"))
        }
    }
}
