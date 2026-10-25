package com.grantly.android

import java.time.Instant
import java.time.temporal.ChronoUnit
import java.time.format.DateTimeParseException

/** Extra client-side safety check; database RLS remains authoritative. */
internal object CommunityStoryRules {
    /** iOS publishes stories with a 24-hour expiry; use UTC ISO-8601 for PostgREST. */
    fun expirationForNewStory(now: Instant): String = now.plus(24, ChronoUnit.HOURS).toString()

    fun isCurrent(kind: String, active: Boolean, expiresAt: String?, now: Instant): Boolean {
        if (kind != "story" || !active || expiresAt.isNullOrBlank()) return false
        val expiration = try {
            Instant.parse(expiresAt)
        } catch (_: DateTimeParseException) {
            return false
        }
        return expiration.isAfter(now)
    }
}
