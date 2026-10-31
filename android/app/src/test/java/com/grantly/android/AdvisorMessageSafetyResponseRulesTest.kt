package com.grantly.android

import java.io.IOException
import java.io.StringReader
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class AdvisorMessageSafetyResponseRulesTest {
    @Test fun responseForSameAccountIsAccepted() {
        AdvisorMessageSafetyResponseRules.requireSameAccount("advisor-a", "advisor-a")
    }

    @Test fun accountSwitchOrSignOutRejectsStaleResponse() {
        assertThrows(IOException::class.java) {
            AdvisorMessageSafetyResponseRules.requireSameAccount("advisor-a", "advisor-b")
        }
        assertThrows(IOException::class.java) {
            AdvisorMessageSafetyResponseRules.requireSameAccount("advisor-a", null)
        }
    }

    @Test fun safetyResponseUsesExistingBoundedReader() {
        assertEquals("[{}]", AdvisorMessageResponseRules.read(StringReader("[{}]")))
        assertThrows(IOException::class.java) {
            AdvisorMessageResponseRules.read(
                StringReader("x".repeat(AdvisorMessageResponseRules.MAX_CHARS + 1))
            )
        }
    }
}
