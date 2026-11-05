package com.grantly.android

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId

class ChecklistDueDateCodecTest {
    @Test fun newDatesRemainStableAcrossTimeZones() {
        val date = LocalDate.of(2027, 1, 2)
        val stored = ChecklistDueDateCodec.encode(date)
        assertEquals("2027-01-02T23:59:59Z", stored)
        for (zone in listOf("Pacific/Honolulu", "Asia/Tokyo", "Pacific/Auckland", "UTC")) {
            assertEquals(date, ChecklistDueDateCodec.decode(stored, ZoneId.of(zone)))
        }
    }

    @Test fun legacyLocalNoonRecordsKeepPreviousInterpretation() {
        val old = "2027-01-02T03:00:00Z" // 12:00 in Tokyo
        assertEquals(LocalDate.of(2027, 1, 2),
            ChecklistDueDateCodec.decode(old, ZoneId.of("Asia/Tokyo")))
        assertEquals(LocalDate.of(2027, 1, 1),
            ChecklistDueDateCodec.decode(old, ZoneId.of("Pacific/Honolulu")))
    }

    @Test fun leapDayAndYearBoundaryRemainCalendarDates() {
        for (date in listOf(LocalDate.of(2028, 2, 29), LocalDate.of(2027, 12, 31))) {
            assertEquals(date, ChecklistDueDateCodec.decode(
                ChecklistDueDateCodec.encode(date), ZoneId.of("America/Los_Angeles")))
        }
    }
}
