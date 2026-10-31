package com.grantly.android

import java.io.IOException
import java.io.StringReader
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class AdvisorBookingRequestRulesTest {
    @Test fun bookingAcceptsTheInitiatingAccount() {
        AdvisorBookingRequestRules.requireActiveAccount(
            "student-a", "student-a", "student-a"
        )
    }

    @Test fun bookingRejectsAnAuthenticatedAccountSwitch() {
        assertThrows(IOException::class.java) {
            AdvisorBookingRequestRules.requireActiveAccount(
                "student-a", "student-b", "student-b"
            )
        }
        assertThrows(IOException::class.java) {
            AdvisorBookingRequestRules.requireActiveAccount(
                "student-a", "student-b", "student-a"
            )
        }
    }

    @Test fun bookingRejectsSignOutOrAChangedCurrentSession() {
        assertThrows(IOException::class.java) {
            AdvisorBookingRequestRules.requireActiveAccount(
                "student-a", "student-a", null
            )
        }
        assertThrows(IOException::class.java) {
            AdvisorBookingRequestRules.requireActiveAccount(
                "student-a", "student-a", "student-b"
            )
        }
    }

    @Test fun bookingResponsesAreBoundedBeforeParsing() {
        assertEquals("[{}]", AdvisorBookingRequestRules.read(StringReader("[{}]")))
        val maxChars = 1_048_576
        assertEquals(maxChars, AdvisorBookingRequestRules.read(
            StringReader("x".repeat(maxChars))
        ).length)
        assertThrows(IOException::class.java) {
            AdvisorBookingRequestRules.read(StringReader("x".repeat(maxChars + 1)))
        }
    }
}
