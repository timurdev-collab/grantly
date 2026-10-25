package com.grantly.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class NotificationBadgeRulesTest {
    @Test fun noBadgeForSignedOutOrZeroUnread() {
        assertNull(NotificationBadgeRules.label(0))
        assertNull(NotificationBadgeRules.label(-1))
    }

    @Test fun singleDigitCountsAreVisible() {
        assertEquals("1", NotificationBadgeRules.label(1))
        assertEquals("5", NotificationBadgeRules.label(5))
        assertEquals("9", NotificationBadgeRules.label(9))
    }

    @Test fun tenOrMoreUnreadAreCapped() {
        assertEquals("9+", NotificationBadgeRules.label(10))
        assertEquals("9+", NotificationBadgeRules.label(999))
    }
}
