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

    @Test fun failsClosedForMissingOrInvalidExpiry() {
        assertFalse(CommunityStoryRules.isCurrent("story", true, null, now))
        assertFalse(CommunityStoryRules.isCurrent("story", true, "", now))
        assertFalse(CommunityStoryRules.isCurrent("story", true, "not-a-date", now))
    }
}
