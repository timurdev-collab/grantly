package com.grantly.android

import org.junit.Assert.assertEquals
import org.junit.Test

class AdvisorStudentRulesTest {
    @Test fun studentQueueRequiresApprovedAdvisorStatus() {
        assertEquals(true, AdvisorStudentRules.canAccess("advisor", "approved"))
        for (status in listOf("pending", "changes_requested", "rejected",
            "suspended", "unknown", "")) {
            assertEquals(false, AdvisorStudentRules.canAccess("advisor", status))
        }
        assertEquals(false, AdvisorStudentRules.canAccess("advisor", null))
        for (role in listOf("student", "admin", "", "unknown")) {
            assertEquals(false, AdvisorStudentRules.canAccess(role, "approved"))
        }
    }

    private fun student(status: String, id: String) = AdvisorStudentItem(
        assignmentId = id,
        studentId = id,
        fullName = "Student $id",
        status = status,
        degreeLevel = "Bachelor",
        intendedMajor = "Computer Science",
        targetCountries = listOf("Korea")
    )

    @Test fun pendingAndActiveCountsNeverTreatUnknownStatusesAsActive() {
        val items = listOf(student("requested", "1"), student("active", "2"),
            student("requested", "3"), student("unknown", "4"))
        assertEquals(2, AdvisorStudentRules.pending(items))
        assertEquals(1, AdvisorStudentRules.active(items))
        assertEquals(4, AdvisorStudentRules.visible(items, "all").size)
        assertEquals(2, AdvisorStudentRules.visible(items, "requested").size)
        assertEquals(1, AdvisorStudentRules.visible(items, "active").size)
        assertEquals(0, AdvisorStudentRules.visible(items, "suspended").size)
    }

    @Test fun pastFilterIncludesOnlyFinishedRegistrations() {
        val items = listOf(
            student("requested", "1"), student("active", "2"),
            student("declined", "3"), student("ended", "4"),
            student("unknown", "5")
        )
        assertEquals(listOf("3", "4"),
            AdvisorStudentRules.visible(items, "past").map { it.studentId })
        assertEquals(2, AdvisorStudentRules.count(items, "past"))
        assertEquals(1, AdvisorStudentRules.count(items, "requested"))
        assertEquals(1, AdvisorStudentRules.count(items, "active"))
        assertEquals(5, AdvisorStudentRules.count(items, "all"))
        assertEquals(0, AdvisorStudentRules.count(items, "unrecognized"))
        assertEquals(emptyList<AdvisorStudentItem>(),
            AdvisorStudentRules.visible(items, "unrecognized"))
    }

    @Test fun pagingKeepsServerOrderAndDoesNotDropPendingStudents() {
        val items = (1..45).map { student(if (it % 2 == 0) "requested" else "active", "$it") }
        val requested = AdvisorStudentRules.visible(items, "requested")
        assertEquals(22, requested.size)
        assertEquals(20, AdvisorStudentRules.page(requested, 20).size)
        assertEquals("2", AdvisorStudentRules.page(requested, 20).first().studentId)
        assertEquals("40", AdvisorStudentRules.page(requested, 20).last().studentId)
        assertEquals(22, AdvisorStudentRules.page(requested, 40).size)
        assertEquals(0, AdvisorStudentRules.page(requested, -1).size)
        assertEquals(0, AdvisorStudentRules.page(requested, 0).size)
    }


    @Test fun searchMatchesNameDegreeMajorAndDestinationsWithoutReordering() {
        val items = listOf(
            student("requested", "1").copy(fullName = "Amina Karim"),
            student("active", "2").copy(degreeLevel = "Master", targetCountries = listOf("Japan")),
            student("ended", "3").copy(intendedMajor = "Visa Policy", targetCountries = listOf("Canada")),
            student("declined", "4").copy(fullName = "Another student", targetCountries = listOf("Korea"))
        )
        assertEquals(listOf("1", "2", "3", "4"),
            AdvisorStudentRules.search(items, "  ").map { it.studentId })
        assertEquals(listOf("1"),
            AdvisorStudentRules.search(items, " AMINA ").map { it.studentId })
        assertEquals(listOf("2"),
            AdvisorStudentRules.search(items, "mAsTeR").map { it.studentId })
        assertEquals(listOf("3"),
            AdvisorStudentRules.search(items, "visa").map { it.studentId })
        assertEquals(listOf("2"),
            AdvisorStudentRules.search(items, "JAPAN").map { it.studentId })
        assertEquals(emptyList<AdvisorStudentItem>(),
            AdvisorStudentRules.search(items, "not present"))
        assertEquals(4, items.size)
    }

    @Test fun searchAndOtherFilterKeepUnexpectedStatusesVisibleButNotActionable() {
        val items = listOf(
            student("requested", "1").copy(fullName = "Amina"),
            student("suspended", "2").copy(fullName = "Amina"),
            student("ended", "3").copy(fullName = "Amina"),
            student("unexpected", "4").copy(fullName = "Elsewhere")
        )
        val matches = AdvisorStudentRules.search(items, "amina")
        assertEquals(listOf("1", "2", "3"), matches.map { it.studentId })
        assertEquals(listOf("2"), AdvisorStudentRules.visible(matches, "other").map { it.studentId })
        assertEquals(1, AdvisorStudentRules.count(matches, "other"))
        assertEquals(false, AdvisorStudentActionRules.allowed("suspended", "accept"))
        assertEquals(false, AdvisorStudentActionRules.allowed("suspended", "end"))
    }

    @Test fun searchIgnoresInputBeyondTheUiLimit() {
        val items = listOf(student("active", "1").copy(fullName = "A".repeat(100) + "hidden"))
        assertEquals(listOf("1"),
            AdvisorStudentRules.search(items, "A".repeat(100) + "extra").map { it.studentId })
    }

    @Test fun advisorActionsAreRestrictedToExpectedRegistrationStates() {
        assertEquals(true, AdvisorStudentActionRules.allowed("requested", "accept"))
        assertEquals(true, AdvisorStudentActionRules.allowed("requested", "decline"))
        assertEquals(true, AdvisorStudentActionRules.allowed("active", "end"))
        for (status in listOf("declined", "ended", "unknown", "", "requested")) {
            assertEquals(false, AdvisorStudentActionRules.allowed(status, "end"))
        }
        assertEquals(false, AdvisorStudentActionRules.allowed("active", "accept"))
        assertEquals(false, AdvisorStudentActionRules.allowed("active", "decline"))
        assertEquals(false, AdvisorStudentActionRules.allowed("requested", "delete"))
        assertEquals(false, AdvisorStudentActionRules.allowed("unknown", "accept"))
    }

    @Test fun advisorActionResultsMatchExistingRpcStatusTransitions() {
        assertEquals("active", AdvisorStudentActionRules.resultingStatus("accept"))
        assertEquals("declined", AdvisorStudentActionRules.resultingStatus("decline"))
        assertEquals("ended", AdvisorStudentActionRules.resultingStatus("end"))
        assertEquals("", AdvisorStudentActionRules.resultingStatus("delete"))
        assertEquals("End advising", AdvisorStudentActionRules.label("end"))
    }
}
