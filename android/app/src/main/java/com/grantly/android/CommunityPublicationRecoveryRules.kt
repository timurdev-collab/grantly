package com.grantly.android

/**
 * Conservative publication-retry policy for a future durable Community uploader.
 * This helper does not perform network requests or enable process-death recovery.
 * A media-key lookup must be scoped to the authenticated author.
 */
internal object CommunityPublicationRecoveryRules {
    enum class Decision {
        ALREADY_PUBLISHED,
        SAFE_TO_ATTEMPT_INSERT,
        REQUIRE_MANUAL_RECONCILIATION
    }

    /**
     * A missing row is sufficient to attempt an insert only if no earlier insert
     * was sent. Following a timeout or unknown result, the existing backend does
     * not provide atomic idempotency, so never blindly retry.
     */
    fun decide(
        uploadCompleted: Boolean,
        accountMatches: Boolean,
        mediaKeyMatches: Boolean,
        matchingPublishedPostCount: Int?,
        insertPreviouslyAttempted: Boolean
    ): Decision {
        if (!uploadCompleted || !accountMatches || !mediaKeyMatches) {
            return Decision.REQUIRE_MANUAL_RECONCILIATION
        }
        if (matchingPublishedPostCount == null || matchingPublishedPostCount < 0) {
            return Decision.REQUIRE_MANUAL_RECONCILIATION
        }
        if (matchingPublishedPostCount > 0) return Decision.ALREADY_PUBLISHED
        return if (insertPreviouslyAttempted) {
            Decision.REQUIRE_MANUAL_RECONCILIATION
        } else {
            Decision.SAFE_TO_ATTEMPT_INSERT
        }
    }
}
