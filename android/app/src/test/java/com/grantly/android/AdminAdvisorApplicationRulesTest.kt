package com.grantly.android

import org.junit.Assert.assertEquals
import org.junit.Test

class AdminAdvisorApplicationRulesTest {
    private fun application(status: String) = AdminAdvisorApplication(
        id = "00000000-0000-0000-0000-000000000001",
        name = "Test advisor",
        title = "Counselor",
        organization = "School",
        status = status,
        version = 1,
        specialties = emptyList(),
        bio = "",
        reviewNote = ""
    )

    @Test fun statusFiltersDoNotMisclassifyUnknownApplications() {
        val items = listOf(application("pending"), application("approved"),
            application("changes_requested"), application("unexpected"))
        assertEquals(4, AdminAdvisorApplicationRules.visible(items, "all").size)
        assertEquals(1, AdminAdvisorApplicationRules.visible(items, "pending").size)
        assertEquals(1, AdminAdvisorApplicationRules.visible(items, "approved").size)
        assertEquals(1, AdminAdvisorApplicationRules.visible(items, "changes_requested").size)
        assertEquals(0, AdminAdvisorApplicationRules.visible(items, "rejected").size)
        assertEquals("Status unavailable", AdminAdvisorApplicationRules.label("unexpected"))
    }
}
