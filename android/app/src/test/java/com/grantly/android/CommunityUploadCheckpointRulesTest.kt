package com.grantly.android

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CommunityUploadCheckpointRulesTest {
    private val rules = CommunityUploadCheckpointRules

    @Test fun uploadMayResumeButCannotSkipToPublication() {
        assertTrue(rules.canTransition(CommunityUploadCheckpointRules.Phase.STAGED, CommunityUploadCheckpointRules.Phase.SESSION_CREATED))
        assertTrue(rules.canTransition(CommunityUploadCheckpointRules.Phase.SESSION_CREATED, CommunityUploadCheckpointRules.Phase.UPLOADING))
        assertTrue(rules.canTransition(CommunityUploadCheckpointRules.Phase.UPLOADING, CommunityUploadCheckpointRules.Phase.UPLOADING))
        assertTrue(rules.canTransition(CommunityUploadCheckpointRules.Phase.UPLOADING, CommunityUploadCheckpointRules.Phase.SESSION_CREATED))
        assertTrue(rules.canTransition(CommunityUploadCheckpointRules.Phase.UPLOADING, CommunityUploadCheckpointRules.Phase.UPLOAD_COMPLETE_PUBLISH_PENDING))
        assertFalse(rules.canTransition(CommunityUploadCheckpointRules.Phase.STAGED, CommunityUploadCheckpointRules.Phase.INSERT_ATTEMPTED))
        assertFalse(rules.canTransition(CommunityUploadCheckpointRules.Phase.UPLOADING, CommunityUploadCheckpointRules.Phase.PUBLISHED))
    }

    @Test fun onlyPublishPendingMayIssueInsert() {
        for (phase in CommunityUploadCheckpointRules.Phase.values()) {
            if (phase == CommunityUploadCheckpointRules.Phase.UPLOAD_COMPLETE_PUBLISH_PENDING) {
                assertTrue(rules.canIssuePostInsert(phase))
            } else {
                assertFalse(rules.canIssuePostInsert(phase))
            }
        }
        assertTrue(rules.canTransition(CommunityUploadCheckpointRules.Phase.UPLOAD_COMPLETE_PUBLISH_PENDING, CommunityUploadCheckpointRules.Phase.INSERT_ATTEMPTED))
        assertFalse(rules.canTransition(CommunityUploadCheckpointRules.Phase.INSERT_ATTEMPTED, CommunityUploadCheckpointRules.Phase.UPLOAD_COMPLETE_PUBLISH_PENDING))
        assertFalse(rules.canTransition(CommunityUploadCheckpointRules.Phase.RECONCILIATION_REQUIRED, CommunityUploadCheckpointRules.Phase.INSERT_ATTEMPTED))
    }

    @Test fun uncertainInsertMustReconcileAndTerminalPhasesStayTerminal() {
        assertTrue(rules.canTransition(CommunityUploadCheckpointRules.Phase.INSERT_ATTEMPTED, CommunityUploadCheckpointRules.Phase.RECONCILIATION_REQUIRED))
        assertTrue(rules.canTransition(CommunityUploadCheckpointRules.Phase.RECONCILIATION_REQUIRED, CommunityUploadCheckpointRules.Phase.PUBLISHED))
        assertTrue(rules.canTransition(CommunityUploadCheckpointRules.Phase.INSERT_ATTEMPTED, CommunityUploadCheckpointRules.Phase.PUBLISHED))
        for (phase in CommunityUploadCheckpointRules.Phase.values()) {
            assertFalse(rules.canTransition(CommunityUploadCheckpointRules.Phase.PUBLISHED, phase))
            assertFalse(rules.canTransition(CommunityUploadCheckpointRules.Phase.CANCELLED, phase))
        }
    }

    @Test fun cancellationCannotEraseUncertainPublication() {
        assertTrue(rules.canTransition(CommunityUploadCheckpointRules.Phase.STAGED, CommunityUploadCheckpointRules.Phase.CANCELLED))
        assertTrue(rules.canTransition(CommunityUploadCheckpointRules.Phase.UPLOADING, CommunityUploadCheckpointRules.Phase.CANCELLED))
        assertFalse(rules.canTransition(CommunityUploadCheckpointRules.Phase.INSERT_ATTEMPTED, CommunityUploadCheckpointRules.Phase.CANCELLED))
        assertFalse(rules.canTransition(CommunityUploadCheckpointRules.Phase.RECONCILIATION_REQUIRED, CommunityUploadCheckpointRules.Phase.CANCELLED))
    }
    @Test fun everyCheckpointTransitionMatchesTheExplicitAllowlist() {
        val phase = CommunityUploadCheckpointRules.Phase
        val allowed = setOf(
            phase.STAGED to phase.SESSION_CREATED,
            phase.STAGED to phase.CANCELLED,
            phase.SESSION_CREATED to phase.UPLOADING,
            phase.SESSION_CREATED to phase.UPLOAD_COMPLETE_PUBLISH_PENDING,
            phase.SESSION_CREATED to phase.CANCELLED,
            phase.UPLOADING to phase.UPLOADING,
            phase.UPLOADING to phase.SESSION_CREATED,
            phase.UPLOADING to phase.UPLOAD_COMPLETE_PUBLISH_PENDING,
            phase.UPLOADING to phase.CANCELLED,
            phase.UPLOAD_COMPLETE_PUBLISH_PENDING to phase.INSERT_ATTEMPTED,
            phase.UPLOAD_COMPLETE_PUBLISH_PENDING to phase.CANCELLED,
            phase.INSERT_ATTEMPTED to phase.PUBLISHED,
            phase.INSERT_ATTEMPTED to phase.RECONCILIATION_REQUIRED,
            phase.RECONCILIATION_REQUIRED to phase.PUBLISHED
        )
        for (from in phase.values()) {
            for (to in phase.values()) {
                org.junit.Assert.assertEquals(
                    "Unexpected checkpoint transition: $from -> $to",
                    (from to to) in allowed,
                    rules.canTransition(from, to)
                )
            }
        }
    }

}
