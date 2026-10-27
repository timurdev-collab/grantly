package com.grantly.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AdminSourceLinkRulesTest {
    @Test fun acceptsCompleteHttpsSource() {
        val source = "https://scholarships.example.org/apply?year=2026"
        assertEquals(source, AdminSourceLinkRules.safeHttpsUrl(source))
    }

    @Test fun rejectsNonHttpsAndCredentialBearingSources() {
        assertNull(AdminSourceLinkRules.safeHttpsUrl("http://example.org/apply"))
        assertNull(AdminSourceLinkRules.safeHttpsUrl("javascript:alert(1)"))
        assertNull(AdminSourceLinkRules.safeHttpsUrl("https://user:secret@example.org/apply"))
    }

    @Test fun rejectsMalformedOrUnsafeSources() {
        assertNull(AdminSourceLinkRules.safeHttpsUrl(""))
        assertNull(AdminSourceLinkRules.safeHttpsUrl("https://"))
        assertNull(AdminSourceLinkRules.safeHttpsUrl("https://example.org/\n"))
        assertNull(AdminSourceLinkRules.safeHttpsUrl(" https://example.org/apply"))
        assertNull(AdminSourceLinkRules.safeHttpsUrl("https://example.org:999999/apply"))
    }

    @Test fun rejectsOversizedSourceWithoutTruncating() {
        assertNull(AdminSourceLinkRules.safeHttpsUrl("https://example.org/" + "a".repeat(2_050)))
    }
}
