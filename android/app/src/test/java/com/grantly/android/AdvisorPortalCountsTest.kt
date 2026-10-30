package com.grantly.android

import org.junit.Assert.assertEquals
import org.junit.Test

class AdvisorPortalCountsTest {
    private fun student(status: String) = AdvisorStudentItem(
        assignmentId = "assignment",
        studentId = "student",
        fullName = "Student",
        status = status,
        degreeLevel = "",
        intendedMajor = "",
        targetCountries = emptyList()
    )

    private fun consultation(status: String) = AdvisorIncomingConsultation(
        id = "request",
        studentName = "Student",
        serviceTitle = "Consultation",
        topic = "",
        status = status,
        durationMinutes = 30,
        priceCents = 0,
        currency = "USD",
        preferredStart = "",
        createdAt = ""
    )

    @Test fun overviewCountsOnlyRecognizedActiveAndOpenStates() {
        val students = listOf(
            student("requested"), student("requested"), student("active"),
            student("ended"), student("declined"), student("suspended")
        )
        val consultations = listOf(
            consultation("requested"), consultation("contacted"),
            consultation("awaiting_payment"), consultation("paid"),
            consultation("confirmed"), consultation("completed"),
            consultation("cancelled"), consultation("unexpected")
        )
        val counts = AdvisorPortalCounts.from(students, consultations)
        assertEquals(1, counts.activeStudents)
        assertEquals(2, counts.registrationRequests)
        assertEquals(5, counts.openConsultations)
    }

    @Test fun emptyOverviewHasZeroCounts() {
        val counts = AdvisorPortalCounts.from(emptyList(), emptyList())
        assertEquals(0, counts.activeStudents)
        assertEquals(0, counts.registrationRequests)
        assertEquals(0, counts.openConsultations)
    }
}
