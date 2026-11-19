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
        val allowed = setOf(
            CommunityUploadCheckpointRules.Phase.STAGED to CommunityUploadCheckpointRules.Phase.SESSION_CREATED,
            CommunityUploadCheckpointRules.Phase.STAGED to CommunityUploadCheckpointRules.Phase.CANCELLED,
            CommunityUploadCheckpointRules.Phase.SESSION_CREATED to CommunityUploadCheckpointRules.Phase.UPLOADING,
            CommunityUploadCheckpointRules.Phase.SESSION_CREATED to CommunityUploadCheckpointRules.Phase.UPLOAD_COMPLETE_PUBLISH_PENDING,
            CommunityUploadCheckpointRules.Phase.SESSION_CREATED to CommunityUploadCheckpointRules.Phase.CANCELLED,
            CommunityUploadCheckpointRules.Phase.UPLOADING to CommunityUploadCheckpointRules.Phase.UPLOADING,
            CommunityUploadCheckpointRules.Phase.UPLOADING to CommunityUploadCheckpointRules.Phase.SESSION_CREATED,
            CommunityUploadCheckpointRules.Phase.UPLOADING to CommunityUploadCheckpointRules.Phase.UPLOAD_COMPLETE_PUBLISH_PENDING,
            CommunityUploadCheckpointRules.Phase.UPLOADING to CommunityUploadCheckpointRules.Phase.CANCELLED,
            CommunityUploadCheckpointRules.Phase.UPLOAD_COMPLETE_PUBLISH_PENDING to CommunityUploadCheckpointRules.Phase.INSERT_ATTEMPTED,
            CommunityUploadCheckpointRules.Phase.UPLOAD_COMPLETE_PUBLISH_PENDING to CommunityUploadCheckpointRules.Phase.CANCELLED,
            CommunityUploadCheckpointRules.Phase.INSERT_ATTEMPTED to CommunityUploadCheckpointRules.Phase.PUBLISHED,
            CommunityUploadCheckpointRules.Phase.INSERT_ATTEMPTED to CommunityUploadCheckpointRules.Phase.RECONCILIATION_REQUIRED,
            CommunityUploadCheckpointRules.Phase.RECONCILIATION_REQUIRED to CommunityUploadCheckpointRules.Phase.PUBLISHED
        )
        for (from in CommunityUploadCheckpointRules.Phase.values()) {
            for (to in CommunityUploadCheckpointRules.Phase.values()) {
                org.junit.Assert.assertEquals(
                    "Unexpected checkpoint transition: $from -> $to",
                    (from to to) in allowed,
                    rules.canTransition(from, to)
                )
            }
        }
    }

}
