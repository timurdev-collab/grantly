package com.grantly.android

import java.io.IOException
import java.io.StringReader
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class AdvisorConsultationResponseRulesTest {
    @Test fun sameAccountCanReadConsultations() {
        AdvisorConsultationResponseRules.requireSameAccount("student-a", "student-a")
    }

    @Test fun accountSwitchRejectsConsultationResponse() {
        val failure = assertThrows(IOException::class.java) {
            AdvisorConsultationResponseRules.requireSameAccount("student-a", "student-b")
        }
        assertTrue(failure.message.orEmpty().contains("account changed"))
    }

    @Test fun signOutRejectsConsultationResponse() {
        assertThrows(IOException::class.java) {
            AdvisorConsultationResponseRules.requireSameAccount("student-a", null)
        }
    }

    @Test fun emptyAndOrdinaryResponsesArePreserved() {
        assertEquals("", AdvisorConsultationResponseRules.readBounded(StringReader("")))
        assertEquals("[]", AdvisorConsultationResponseRules.readBounded(StringReader("[]")))
    }

    @Test fun responseAtLimitIsAccepted() {
        val body = "x".repeat(AdvisorConsultationResponseRules.MAX_CHARS)
        assertEquals(body, AdvisorConsultationResponseRules.readBounded(StringReader(body)))
    }

    @Test fun oversizedResponseIsRejectedBeforeParsing() {
        val body = "x".repeat(AdvisorConsultationResponseRules.MAX_CHARS + 1)
        val failure = assertThrows(IOException::class.java) {
            AdvisorConsultationResponseRules.readBounded(StringReader(body))
        }
        assertTrue(failure.message.orEmpty().contains("too large"))
    }
}
