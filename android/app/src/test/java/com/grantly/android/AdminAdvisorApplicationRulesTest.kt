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
        assertEquals(1, AdminAdvisorApplicationRules.visible(items, "other").size)
        assertEquals("Other", AdminAdvisorApplicationRules.label("other"))
    }

    @Test fun applicantSearchIsCaseInsensitiveAndRespectsStatusFilter() {
        val items = listOf(
            application("pending").copy(name = "Amira Khan", organization = "Oxford", specialties = listOf("Visa support")),
            application("approved").copy(name = "Mina Lee", title = "Research Mentor", organization = "Seoul"),
            application("pending").copy(name = "John Park", organization = "Tokyo", specialties = listOf("Engineering"))
        )
        assertEquals(1, AdminAdvisorApplicationRules.visible(items, "all", "amira").size)
        assertEquals(1, AdminAdvisorApplicationRules.visible(items, "pending", "VISA").size)
        assertEquals(1, AdminAdvisorApplicationRules.visible(items, "approved", "research").size)
        assertEquals(0, AdminAdvisorApplicationRules.visible(items, "pending", "research").size)
        assertEquals(3, AdminAdvisorApplicationRules.visible(items, "all", "  ").size)
        assertEquals(1, AdminAdvisorApplicationRules.visible(items, "all", "SeOuL").size)
    }

    @Test fun unknownOrMissingStatusCanBeFoundInOtherWithoutChangingKnownStatusFilters() {
        val items = listOf(application("pending"), application("unexpected"), application(""))
        assertEquals(2, AdminAdvisorApplicationRules.visible(items, "other").size)
        assertEquals(1, AdminAdvisorApplicationRules.visible(items, "pending").size)
        assertEquals(2, AdminAdvisorApplicationRules.visible(items, "other", "test advisor").size)
        assertEquals(0, AdminAdvisorApplicationRules.visible(items, "other", "not found").size)
    }
    @Test fun administratorReviewActionsFollowIosStatusTransitions() {
        assertEquals(
            listOf("approve", "request_changes", "reject"),
            AdminAdvisorReviewRules.actionsFor("pending")
        )
        assertEquals(
            listOf("approve", "request_changes", "reject"),
            AdminAdvisorReviewRules.actionsFor("changes_requested")
        )
        assertEquals(listOf("suspend"), AdminAdvisorReviewRules.actionsFor("approved"))
        assertEquals(listOf("restore"), AdminAdvisorReviewRules.actionsFor("suspended"))
        assertEquals(emptyList<String>(), AdminAdvisorReviewRules.actionsFor("rejected"))
        assertEquals(emptyList<String>(), AdminAdvisorReviewRules.actionsFor("unexpected"))
        assertEquals(emptyList<String>(), AdminAdvisorReviewRules.actionsFor(""))
    }

    @Test fun administratorDecisionsRejectInvalidTransitionsAndMissingNotes() {
        assertEquals(null, AdminAdvisorReviewRules.validationError("pending", "approve", ""))
        assertEquals(null, AdminAdvisorReviewRules.validationError("pending", "reject", "Reason"))
        assertEquals(null, AdminAdvisorReviewRules.validationError("pending", "request_changes", "Please update"))
        assertEquals(null, AdminAdvisorReviewRules.validationError("approved", "suspend", ""))
        assertEquals(null, AdminAdvisorReviewRules.validationError("suspended", "restore", ""))
        assertEquals(true, AdminAdvisorReviewRules.validationError("pending", "reject", "  ") != null)
        assertEquals(true, AdminAdvisorReviewRules.validationError("pending", "request_changes", "") != null)
        assertEquals(true, AdminAdvisorReviewRules.validationError("approved", "approve", "") != null)
        assertEquals(true, AdminAdvisorReviewRules.validationError("rejected", "approve", "") != null)
        assertEquals(true, AdminAdvisorReviewRules.validationError("unexpected", "restore", "") != null)
        assertEquals(true, AdminAdvisorReviewRules.validationError("pending", "approve", "x".repeat(501)) != null)
    }
}
