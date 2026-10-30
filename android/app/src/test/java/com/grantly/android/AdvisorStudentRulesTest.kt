package com.grantly.android

import org.junit.Assert.assertEquals
import org.junit.Test

class AdvisorStudentRulesTest {
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
}
