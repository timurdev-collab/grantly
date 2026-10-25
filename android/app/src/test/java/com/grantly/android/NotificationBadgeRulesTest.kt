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

    @Test fun accessibilityAnnouncesUnreadCountWithoutMisreadingBadge() {
        assertEquals("Open notifications", NotificationBadgeRules.accessibilityLabel(0))
        assertEquals("Open notifications", NotificationBadgeRules.accessibilityLabel(-1))
        assertEquals("Open notifications, 1 unread", NotificationBadgeRules.accessibilityLabel(1))
        assertEquals("Open notifications, 9 unread", NotificationBadgeRules.accessibilityLabel(9))
        assertEquals("Open notifications, 10 or more unread", NotificationBadgeRules.accessibilityLabel(10))
        assertEquals("Open notifications, 10 or more unread", NotificationBadgeRules.accessibilityLabel(999))
    }
}
