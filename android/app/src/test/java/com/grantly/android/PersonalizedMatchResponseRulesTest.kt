package com.grantly.android

import java.io.IOException
import java.io.StringReader
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class PersonalizedMatchResponseRulesTest {
    @Test fun acceptsCurrentAccount() {
        PersonalizedMatchResponseRules.requireSameAccount("student-a", "student-a")
    }

    @Test fun rejectsAccountSwitchAndSignOut() {
        for (current in listOf("student-b", null)) {
            val error = assertThrows(IOException::class.java) {
                PersonalizedMatchResponseRules.requireSameAccount("student-a", current)
            }
            assertTrue(error.message.orEmpty().contains("account changed"))
        }
    }

    @Test fun readsEmptyAndOrdinaryResponses() {
        assertEquals("", PersonalizedMatchResponseRules.readBounded(StringReader("")))
        assertEquals("[]", PersonalizedMatchResponseRules.readBounded(StringReader("[]")))
    }

    @Test fun acceptsResponseAtExactLimit() {
        val response = "x".repeat(PersonalizedMatchResponseRules.MAX_CHARS)
        assertEquals(response, PersonalizedMatchResponseRules.readBounded(StringReader(response)))
    }

    @Test fun rejectsOversizedResponseBeforeJsonParsing() {
        val response = "x".repeat(PersonalizedMatchResponseRules.MAX_CHARS + 1)
        val error = assertThrows(IOException::class.java) {
            PersonalizedMatchResponseRules.readBounded(StringReader(response))
        }
        assertTrue(error.message.orEmpty().contains("too large"))
    }
}
