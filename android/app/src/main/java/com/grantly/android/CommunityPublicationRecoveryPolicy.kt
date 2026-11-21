package com.grantly.android

/**
 * Conservative publication recovery policy for a future durable Community uploader.
 *
 * Pure decision logic only. It is not connected to active publishing. An ambiguous
 * insert result must never trigger an automatic second insert.
 */
internal object CommunityPublicationRecoveryPolicy {
    enum class Phase {
        STAGED, SESSION_CREATED, UPLOADING, UPLOAD_COMPLETE_PUBLISH_PENDING,
        INSERT_ATTEMPTED, RECONCILIATION_REQUIRED, PUBLISHED, CANCELLED
    }

    enum class Action {
        RESUME_UPLOAD, VERIFY_UPLOADED_OBJECT, RECONCILE_EXISTING_POST,
        REQUIRE_MANUAL_RECONCILIATION, VERIFY_PUBLISHED_POST, NO_ACTION
    }

    fun nextAction(phase: Phase, authenticatedAccountMatches: Boolean): Action {
        if (!authenticatedAccountMatches) return Action.NO_ACTION
        return when (phase) {
            Phase.STAGED, Phase.SESSION_CREATED, Phase.UPLOADING -> Action.RESUME_UPLOAD
            Phase.UPLOAD_COMPLETE_PUBLISH_PENDING -> Action.VERIFY_UPLOADED_OBJECT
            Phase.INSERT_ATTEMPTED -> Action.RECONCILE_EXISTING_POST
            Phase.RECONCILIATION_REQUIRED -> Action.REQUIRE_MANUAL_RECONCILIATION
            Phase.PUBLISHED -> Action.VERIFY_PUBLISHED_POST
            Phase.CANCELLED -> Action.NO_ACTION
        }
    }

    /** Only exact, authenticated object-key matches are evidence of publication. */
    fun reconcileInsertAttempt(
        authenticatedAccountMatches: Boolean,
        exactMediaKeyMatchFound: Boolean
    ): Phase = if (authenticatedAccountMatches && exactMediaKeyMatchFound) {
        Phase.PUBLISHED
    } else {
        Phase.RECONCILIATION_REQUIRED
    }
}
