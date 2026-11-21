package com.grantly.android

import org.junit.Assert.assertEquals
import org.junit.Test

class CommunityPublicationRecoveryPolicyTest {
    private val policy = CommunityPublicationRecoveryPolicy

    @Test fun unauthenticatedOrMismatchedAccountNeverResumesAnyPhase() {
        for (phase in CommunityPublicationRecoveryPolicy.Phase.values()) {
            assertEquals(CommunityPublicationRecoveryPolicy.Action.NO_ACTION,
                policy.nextAction(phase, authenticatedAccountMatches = false))
        }
    }

    @Test fun authenticatedRecoveryActionsAreExhaustivelyFailClosed() {
        val expected = mapOf(
            CommunityPublicationRecoveryPolicy.Phase.STAGED to CommunityPublicationRecoveryPolicy.Action.RESUME_UPLOAD,
            CommunityPublicationRecoveryPolicy.Phase.SESSION_CREATED to CommunityPublicationRecoveryPolicy.Action.RESUME_UPLOAD,
            CommunityPublicationRecoveryPolicy.Phase.UPLOADING to CommunityPublicationRecoveryPolicy.Action.RESUME_UPLOAD,
            CommunityPublicationRecoveryPolicy.Phase.UPLOAD_COMPLETE_PUBLISH_PENDING to CommunityPublicationRecoveryPolicy.Action.VERIFY_UPLOADED_OBJECT,
            CommunityPublicationRecoveryPolicy.Phase.INSERT_ATTEMPTED to CommunityPublicationRecoveryPolicy.Action.RECONCILE_EXISTING_POST,
            CommunityPublicationRecoveryPolicy.Phase.RECONCILIATION_REQUIRED to CommunityPublicationRecoveryPolicy.Action.REQUIRE_MANUAL_RECONCILIATION,
            CommunityPublicationRecoveryPolicy.Phase.PUBLISHED to CommunityPublicationRecoveryPolicy.Action.VERIFY_PUBLISHED_POST,
            CommunityPublicationRecoveryPolicy.Phase.CANCELLED to CommunityPublicationRecoveryPolicy.Action.NO_ACTION
        )
        assertEquals(CommunityPublicationRecoveryPolicy.Phase.values().toSet(), expected.keys)
        for ((phase, action) in expected) {
            assertEquals("Unexpected recovery action for $phase", action,
                policy.nextAction(phase, authenticatedAccountMatches = true))
        }
    }

    @Test fun ambiguousInsertNeverSchedulesAutomaticInsertRetry() {
        assertEquals(CommunityPublicationRecoveryPolicy.Action.RECONCILE_EXISTING_POST,
            policy.nextAction(CommunityPublicationRecoveryPolicy.Phase.INSERT_ATTEMPTED, true))
        assertEquals(CommunityPublicationRecoveryPolicy.Action.REQUIRE_MANUAL_RECONCILIATION,
            policy.nextAction(CommunityPublicationRecoveryPolicy.Phase.RECONCILIATION_REQUIRED, true))
        assertEquals(CommunityPublicationRecoveryPolicy.Phase.RECONCILIATION_REQUIRED,
            policy.reconcileInsertAttempt(true, exactMediaKeyMatchFound = false))
    }

    @Test fun onlyExactAuthenticatedMediaMatchCanConfirmPublication() {
        assertEquals(CommunityPublicationRecoveryPolicy.Phase.PUBLISHED,
            policy.reconcileInsertAttempt(true, exactMediaKeyMatchFound = true))
        assertEquals(CommunityPublicationRecoveryPolicy.Phase.RECONCILIATION_REQUIRED,
            policy.reconcileInsertAttempt(false, exactMediaKeyMatchFound = true))
    }

    @Test fun uploadedMediaMustBeVerifiedBeforeInsertAndTerminalStatesDoNotResume() {
        assertEquals(CommunityPublicationRecoveryPolicy.Action.VERIFY_UPLOADED_OBJECT,
            policy.nextAction(CommunityPublicationRecoveryPolicy.Phase.UPLOAD_COMPLETE_PUBLISH_PENDING, true))
        assertEquals(CommunityPublicationRecoveryPolicy.Action.VERIFY_PUBLISHED_POST,
            policy.nextAction(CommunityPublicationRecoveryPolicy.Phase.PUBLISHED, true))
        assertEquals(CommunityPublicationRecoveryPolicy.Action.NO_ACTION,
            policy.nextAction(CommunityPublicationRecoveryPolicy.Phase.CANCELLED, true))
    }
}
