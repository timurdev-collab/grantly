package com.grantly.android

import java.time.Instant
import java.time.format.DateTimeParseException

/** Extra client-side safety check; database RLS remains authoritative. */
internal object CommunityStoryRules {
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
