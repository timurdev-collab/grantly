package com.grantly.android

/**
 * Pure recovery checkpoint policy. This does not enable background uploads or
 * process-death recovery; the future coordinator must persist transitions atomically.
 *
 * A timed-out post insertion is never safe to retry automatically without
 * backend-enforced idempotency. See CommunityPublicationRecoveryRules.
 */
internal object CommunityUploadCheckpointRules {
    enum class Phase {
        STAGED,
        SESSION_CREATED,
        UPLOADING,
        UPLOAD_COMPLETE_PUBLISH_PENDING,
        INSERT_ATTEMPTED,
        PUBLISHED,
        RECONCILIATION_REQUIRED,
        CANCELLED
    }

    /**
     * Reject invalid or regressive checkpoints, especially transitions that
     * could resend a post insertion after an uncertain result.
     */
    fun canTransition(from: Phase, to: Phase): Boolean = when (from) {
        Phase.STAGED -> to == Phase.SESSION_CREATED || to == Phase.CANCELLED
        Phase.SESSION_CREATED ->
            to == Phase.UPLOADING || to == Phase.UPLOAD_COMPLETE_PUBLISH_PENDING ||
                to == Phase.CANCELLED
        Phase.UPLOADING ->
            to == Phase.UPLOADING || to == Phase.SESSION_CREATED ||
                to == Phase.UPLOAD_COMPLETE_PUBLISH_PENDING || to == Phase.CANCELLED
        Phase.UPLOAD_COMPLETE_PUBLISH_PENDING ->
            to == Phase.INSERT_ATTEMPTED || to == Phase.CANCELLED
        Phase.INSERT_ATTEMPTED ->
            to == Phase.PUBLISHED || to == Phase.RECONCILIATION_REQUIRED
        Phase.RECONCILIATION_REQUIRED -> to == Phase.PUBLISHED
        Phase.PUBLISHED, Phase.CANCELLED -> false
    }

    /**
     * Persist INSERT_ATTEMPTED *before* issuing the network insertion.
     * After a crash, a coordinator must reconcile rather than insert again.
     */
    fun canIssuePostInsert(phase: Phase): Boolean =
        phase == Phase.UPLOAD_COMPLETE_PUBLISH_PENDING
}
