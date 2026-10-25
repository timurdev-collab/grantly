package com.grantly.android

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class CommunityStoryRulesTest {
    private val now = Instant.parse("2026-10-25T10:00:00Z")

    @Test fun showsOnlyActiveUnexpiredStories() {
        assertTrue(CommunityStoryRules.isCurrent("story", true, "2026-10-25T10:00:01Z", now))
        assertFalse(CommunityStoryRules.isCurrent("story", true, "2026-10-25T10:00:00Z", now))
        assertFalse(CommunityStoryRules.isCurrent("story", true, "2026-10-25T09:59:59Z", now))
        assertFalse(CommunityStoryRules.isCurrent("story", false, "2026-10-26T10:00:00Z", now))
        assertFalse(CommunityStoryRules.isCurrent("post", true, "2026-10-26T10:00:00Z", now))
    }

    @Test fun handlesPostgresTimestampOffsetsAndMicroseconds() {
        assertTrue(
            CommunityStoryRules.isCurrent(
                "story", true, "2026-10-25T10:00:00.000001+00:00", now
            )
        )
        assertFalse(
            CommunityStoryRules.isCurrent(
                "story", true, "2026-10-25T09:59:59.999999+00:00", now
            )
        )
    }

    @Test fun failsClosedForMissingOrInvalidExpiry() {
        assertFalse(CommunityStoryRules.isCurrent("story", true, null, now))
        assertFalse(CommunityStoryRules.isCurrent("story", true, "", now))
        assertFalse(CommunityStoryRules.isCurrent("story", true, "not-a-date", now))
    }
    @Test fun newStoryExpiresExactly24HoursAfterPublication() {
        val expiry = CommunityStoryRules.expirationForNewStory(now)
        assertTrue(expiry == "2026-10-26T10:00:00Z")
        assertTrue(CommunityStoryRules.isCurrent("story", true, expiry, now))
        assertFalse(CommunityStoryRules.isCurrent("story", true, expiry, now.plusSeconds(86_400)))
    }

    @Test fun expiryCalculationHandlesYearBoundary() {
        val newYearsEve = Instant.parse("2026-12-31T23:30:00Z")
        assertTrue(
            CommunityStoryRules.expirationForNewStory(newYearsEve) ==
                "2027-01-01T23:30:00Z"
        )
    }

}
