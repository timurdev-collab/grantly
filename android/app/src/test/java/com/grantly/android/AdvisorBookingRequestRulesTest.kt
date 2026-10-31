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

    @Test fun bookingValidatesEmailDomainAndLocalPart() {
        val valid = listOf("student@example.com", "student.name+edu@uni.ac.uk", " Student@Example.org ")
        val invalid = listOf(
            "", "a@@example.com", "student@domain", "student@domain..com",
            ".student@example.com", "student..name@example.com",
            "student@-domain.com", "student@domain-.com",
            "student@example.c", "student @example.com", "student@exam ple.com"
        )
        valid.forEach { assertEquals(it, true, AdvisorBookingRequestRules.validEmail(it)) }
        invalid.forEach { assertEquals(it, false, AdvisorBookingRequestRules.validEmail(it)) }
    }

    @Test fun bookingValidatesWhatsAppCharactersAndDigitCount() {
        val valid = listOf("+84 123 456 789", "84123456789", "+1 (415) 555-0123")
        val invalid = listOf(
            "", "123456", "1234567890123456", "abc1234567",
            "123+456789", "++84123456789", "+84/123456789"
        )
        valid.forEach { assertEquals(it, true, AdvisorBookingRequestRules.validWhatsAppNumber(it)) }
        invalid.forEach { assertEquals(it, false, AdvisorBookingRequestRules.validWhatsAppNumber(it)) }
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
