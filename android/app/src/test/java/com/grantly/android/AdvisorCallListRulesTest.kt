package com.grantly.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.ZoneId

class AdvisorCallListRulesTest {
    private val callId = "01234567-1234-4abc-8def-0123456789ab"
    private val assignmentId = "12345678-1234-4abc-8def-0123456789ab"
    private val active = setOf(assignmentId)

    @Test fun acceptsOnlyOpenCallsFromCurrentActiveAssignments() {
        for (status in listOf("requested", "scheduled", "active")) {
            assertTrue(AdvisorCallListRules.isVisible(callId, assignmentId, status, active))
        }
        for (status in listOf("ended", "cancelled", "", "unknown")) {
            assertFalse(AdvisorCallListRules.isVisible(callId, assignmentId, status, active))
        }
        assertFalse(AdvisorCallListRules.isVisible(callId, assignmentId, "active", emptySet()))
        assertFalse(AdvisorCallListRules.isVisible(callId, "23456789-1234-4abc-8def-0123456789ab", "active", active))
    }

    @Test fun rejectsMalformedAndNoncanonicalIdentifiers() {
        for (id in listOf("bad-id", "", "01234567-1234-4ABC-8DEF-0123456789AB")) {
            assertFalse(AdvisorCallListRules.isVisible(id, assignmentId, "active", active))
        }
        assertFalse(AdvisorCallListRules.isVisible(callId, assignmentId.uppercase(), "active", setOf(assignmentId.uppercase())))
    }

    @Test fun displaysOnlyKnownStatesAndBoundedTimes() {
        assertEquals("Requested", AdvisorCallListRules.label("requested"))
        assertEquals("Scheduled", AdvisorCallListRules.label("scheduled"))
        assertEquals("Active", AdvisorCallListRules.label("active"))
        assertEquals("Unavailable", AdvisorCallListRules.label("ended"))
        assertEquals("Not scheduled", AdvisorCallListRules.displayTime(""))
        assertEquals("Not scheduled", AdvisorCallListRules.displayTime("null"))
        assertEquals(40, AdvisorCallListRules.displayTime("a".repeat(100)).length)
    }

    @Test fun convertsUtcScheduleToDeviceTimezoneWithExplicitOffset() {
        val scheduled = "2026-11-01T10:00:00Z"
        assertEquals(
            "Nov 1, 2026 5:00 PM +07:00",
            AdvisorCallListRules.displayTime(scheduled, ZoneId.of("Asia/Ho_Chi_Minh"))
        )
        assertEquals(
            "Nov 1, 2026 2:00 AM -08:00",
            AdvisorCallListRules.displayTime(scheduled, ZoneId.of("America/Los_Angeles"))
        )
    }

    @Test fun preservesBoundedLegacyTimestampWhenTimezoneIsUnknown() {
        assertEquals(
            "2026-11-01 10:00:00",
            AdvisorCallListRules.displayTime("2026-11-01T10:00:00", ZoneId.of("Asia/Ho_Chi_Minh"))
        )
    }

    @Test fun boundedServerScanContinuesPastFilteredRows() {
        assertEquals(listOf(0, 100, 200), AdvisorCallListRules.scanOffsets().toList())
        assertTrue(AdvisorCallListRules.shouldScanNext(100, 0, 100))
        assertTrue(AdvisorCallListRules.shouldScanNext(100, 42, 200))
        assertFalse(AdvisorCallListRules.shouldScanNext(99, 0, 100))
        assertFalse(AdvisorCallListRules.shouldScanNext(100, 100, 100))
        assertFalse(AdvisorCallListRules.shouldScanNext(100, 25, 300))
        assertFalse(AdvisorCallListRules.shouldScanNext(0, 0, 100))
    }

    @Test fun overlappingServerPagesDoNotDuplicateCallsOrConsumeThePageQuota() {
        val calls = mutableListOf<AdvisorCallListItem>()
        val seen = mutableSetOf<String>()
        val first = AdvisorCallListItem(
            id = callId,
            assignmentId = assignmentId,
            studentName = "Student",
            status = "scheduled",
            scheduledFor = "",
            createdAt = "",
            recordingRequested = false
        )
        assertTrue(AdvisorCallListRules.appendUnique(calls, seen, first))
        assertFalse(AdvisorCallListRules.appendUnique(calls, seen, first))
        assertEquals(1, calls.size)
        assertEquals(1, seen.size)

        repeat(99) { index ->
            assertTrue(AdvisorCallListRules.appendUnique(calls, seen, first.copy(id = "call-$index")))
        }
        assertEquals(100, calls.size)
        assertFalse(AdvisorCallListRules.appendUnique(calls, seen, first.copy(id = "overflow")))
        assertEquals(100, calls.size)
        assertFalse("overflow" in seen)
        assertEquals(callId, calls.first().id)
    }

    @Test fun pagesCallCardsWithoutLosingOrReorderingRows() {
        val calls = List(45) { index ->
            AdvisorCallListItem(
                id = callId,
                assignmentId = assignmentId,
                studentName = "Student $index",
                status = "scheduled",
                scheduledFor = "",
                createdAt = "",
                recordingRequested = false
            )
        }
        assertEquals(emptyList<AdvisorCallListItem>(), AdvisorCallListRules.page(calls, -1))
        assertEquals(calls.take(20), AdvisorCallListRules.page(calls, 20))
        assertEquals(calls.take(40), AdvisorCallListRules.page(calls, 40))
        assertEquals(calls, AdvisorCallListRules.page(calls, 60))
        assertEquals(calls, AdvisorCallListRules.page(calls, 500))
    }
}
