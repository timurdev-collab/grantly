package com.grantly.android

import java.io.IOException
import java.io.StringReader
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class AdvisorDirectoryResponseRulesTest {
    @Test fun acceptsCurrentAccount() {
        AdvisorDirectoryResponseRules.requireSameAccount("student-a", "student-a")
    }

    @Test fun rejectsAccountSwitchAndSignOut() {
        for (current in listOf("student-b", null)) {
            val error = assertThrows(IOException::class.java) {
                AdvisorDirectoryResponseRules.requireSameAccount("student-a", current)
            }
            assertTrue(error.message.orEmpty().contains("account changed"))
        }
    }

    @Test fun readsEmptyAndOrdinaryDirectoryResponses() {
        assertEquals("", AdvisorDirectoryResponseRules.readBounded(StringReader("")))
        assertEquals("[]", AdvisorDirectoryResponseRules.readBounded(StringReader("[]")))
    }

    @Test fun acceptsResponseAtExactLimit() {
        val response = "x".repeat(AdvisorDirectoryResponseRules.MAX_CHARS)
        assertEquals(response, AdvisorDirectoryResponseRules.readBounded(StringReader(response)))
    }

    @Test fun rejectsOversizedResponseBeforeJsonParsing() {
        val response = "x".repeat(AdvisorDirectoryResponseRules.MAX_CHARS + 1)
        val error = assertThrows(IOException::class.java) {
            AdvisorDirectoryResponseRules.readBounded(StringReader(response))
        }
        assertTrue(error.message.orEmpty().contains("too large"))
    }
}
