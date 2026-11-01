package com.grantly.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import java.io.IOException
import java.io.StringReader

class NotificationResponseRulesTest {
    @Test fun acceptsOnlyTheRequestedAccount() {
        NotificationResponseRules.requireSameAccount("user-a", "user-a")
        for (current in listOf("user-b", "", null)) {
            assertThrows(IOException::class.java) {
                NotificationResponseRules.requireSameAccount("user-a", current)
            }
        }
    }

    @Test fun acceptsEmptyAndExactlyBoundedResponses() {
        assertEquals("", NotificationResponseRules.readBounded(StringReader(""), 8))
        assertEquals("12345678", NotificationResponseRules.readBounded(StringReader("12345678"), 8))
    }

    @Test fun rejectsOversizedBadgeAndInboxResponses() {
        for (limit in listOf(NotificationResponseRules.MAX_BADGE_CHARS,
            NotificationResponseRules.MAX_INBOX_CHARS)) {
            assertThrows(IOException::class.java) {
                NotificationResponseRules.readBounded(StringReader("x".repeat(limit + 1)), limit)
            }
        }
    }

    @Test fun rejectsInvalidResponseLimit() {
        assertThrows(IllegalArgumentException::class.java) {
            NotificationResponseRules.readBounded(StringReader("ok"), 0)
        }
    }
}
