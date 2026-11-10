package com.grantly.android

/**
 * Pure validation for a future durable Community TUS upload coordinator.
 *
 * This is intentionally not wired into the uploader yet: process-death recovery
 * must remain disabled until account-scoped persistence, ownership checks and
 * publication idempotency are implemented and tested.
 */
internal object CommunityUploadRecoveryGuard {
    enum class Decision {
        RESUME_FROM_SERVER_OFFSET,
        COMPLETE_UPLOAD,
        RESTART_WITH_NEW_OBJECT,
        REJECT
    }

    /**
     * Never use a locally cached offset to choose the next PATCH position.
     * The authenticated server HEAD offset is authoritative.
     */
    fun decide(
        expectedAccountId: String,
        storedAccountId: String,
        stagedFileSize: Long,
        stagedFileExists: Boolean,
        sessionExpired: Boolean,
        serverOffset: Long?,
        serverSessionMissing: Boolean
    ): Decision {
        if (expectedAccountId.isBlank() || storedAccountId.isBlank() ||
            expectedAccountId != storedAccountId ||
            expectedAccountId != expectedAccountId.trim() ||
            storedAccountId != storedAccountId.trim() || !stagedFileExists ||
            stagedFileSize <= 0L || stagedFileSize > 200L * 1024 * 1024
        ) return Decision.REJECT

        if (sessionExpired || serverSessionMissing) return Decision.RESTART_WITH_NEW_OBJECT
        if (serverOffset == null || serverOffset < 0L || serverOffset > stagedFileSize) {
            return Decision.REJECT
        }
        return if (serverOffset == stagedFileSize) {
            Decision.COMPLETE_UPLOAD
        } else {
            Decision.RESUME_FROM_SERVER_OFFSET
        }
    }
}
