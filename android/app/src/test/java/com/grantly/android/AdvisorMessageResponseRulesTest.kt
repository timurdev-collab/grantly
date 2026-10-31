package com.grantly.android

import java.io.IOException
import java.io.StringReader
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class AdvisorMessageResponseRulesTest {
    @Test fun emptyAndOrdinaryResponsesArePreserved() {
        assertEquals("", AdvisorMessageResponseRules.read(StringReader("")))
        assertEquals("[{\"body\":\"hello\"}]",
            AdvisorMessageResponseRules.read(StringReader("[{\"body\":\"hello\"}]")))
    }

    @Test fun responseAtLimitIsAccepted() {
        val body = "x".repeat(AdvisorMessageResponseRules.MAX_CHARS)
        assertEquals(body, AdvisorMessageResponseRules.read(StringReader(body)))
    }

    @Test fun oversizedResponseIsRejectedBeforeJsonParsing() {
        val body = "x".repeat(AdvisorMessageResponseRules.MAX_CHARS + 1)
        val failure = assertThrows(IOException::class.java) {
            AdvisorMessageResponseRules.read(StringReader(body))
        }
        assertTrue(failure.message.orEmpty().contains("too large"))
    }
}
