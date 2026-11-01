package com.grantly.android

import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class HomeDeadlineRulesTest {
    @Test fun onlyVerifiedScholarshipsAreEligibleForClosingSoon() {
        assertTrue(HomeDeadlineRules.isVerified("verified"))
        for (status in listOf(null, "", "pending", "rejected", "unverified")) {
            assertFalse("Unverified scholarships must not appear: $status",
                HomeDeadlineRules.isVerified(status))
        }
    }

    @Test fun acceptsPublishedDateAndTimestampFormats() {
        val date = LocalDate.of(2026, 11, 2)
        assertEquals(date, HomeDeadlineRules.parseDate("2026-11-02"))
        assertEquals(date, HomeDeadlineRules.parseDate("2026-11-02T23:59:00Z"))
        assertEquals(date, HomeDeadlineRules.parseDate(" 2026-11-02 23:59:00+00:00 "))
        assertEquals(date, HomeDeadlineRules.parseDate("2026-11-02T23:59:00.123Z"))
        assertEquals(date, HomeDeadlineRules.parseDate("2026-11-02T23:59:00+08:00"))
    }

    @Test fun rejectsRollingMalformedAndNonexistentDates() {
        for (value in listOf(null, "", "Rolling", "2026-11", "2026-11-02garbage", "2026-02-30", "2026-13-01",
            "2026-11-02Tgarbage", "2026-11-02T99:99:99Z",
            "2026-11-02T23:59:00garbage", "2026-11-02 23:59:00+99:00")) {
            assertNull("Invalid deadline should not get an urgency label: $value",
                HomeDeadlineRules.parseDate(value))
        }
    }

    @Test fun heroAndClosingSoonShareVerifiedUpcomingPolicy() {
        val today = LocalDate.of(2026, 11, 2)
        assertEquals(today, HomeDeadlineRules.eligibleUpcomingDate(
            "verified", "2026-11-02", today))
        assertEquals(today.plusDays(3), HomeDeadlineRules.eligibleUpcomingDate(
            "verified", "2026-11-05T23:59:00Z", today))
        for (status in listOf(null, "", "pending", "unverified", "rejected")) {
            assertNull("Unverified Home listing must be excluded: $status",
                HomeDeadlineRules.eligibleUpcomingDate(status, "2026-11-05", today))
        }
        for (deadline in listOf(null, "", "Rolling", "2026-11-01", "2026-02-30")) {
            assertNull("Invalid or expired Home deadline must be excluded: $deadline",
                HomeDeadlineRules.eligibleUpcomingDate("verified", deadline, today))
        }
    }

    @Test fun personalizedHeroSkipsInvalidTopMatchesBeforeChoosingAnEligibleOne() {
        val today = LocalDate.of(2026, 11, 2)
        data class Candidate(val status: String?, val deadline: String?)
        val candidates = listOf(
            Candidate("pending", "2026-11-03"),
            Candidate("verified", "Rolling"),
            Candidate("verified", "2026-11-01"),
            Candidate("verified", "2026-11-04")
        )
        val selected = candidates.firstOrNull { candidate ->
            HomeDeadlineRules.eligibleUpcomingDate(
                candidate.status, candidate.deadline, today
            ) != null
        }
        assertEquals("2026-11-04", selected?.deadline)
        assertNull(candidates.take(3).firstOrNull { candidate ->
            HomeDeadlineRules.eligibleUpcomingDate(
                candidate.status, candidate.deadline, today
            ) != null
        })
    }

    @Test fun usesCalendarDaysAndMatchesIosUrgencyWording() {
        val today = LocalDate.of(2026, 11, 2)
        assertEquals(0L, HomeDeadlineRules.daysUntil(today, today))
        assertEquals("Today", HomeDeadlineRules.urgencyText(0))
        assertEquals("1 day left", HomeDeadlineRules.urgencyText(
            HomeDeadlineRules.daysUntil(today.plusDays(1), today)))
        assertEquals("7 days left", HomeDeadlineRules.urgencyText(7))
        assertEquals("8 days left", HomeDeadlineRules.urgencyText(8))
        assertTrue(HomeDeadlineRules.isUrgent(7))
        assertFalse(HomeDeadlineRules.isUrgent(8))
    }
}
