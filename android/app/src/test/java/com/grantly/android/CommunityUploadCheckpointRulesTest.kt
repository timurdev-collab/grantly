package com.grantly.android

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CommunityUploadCheckpointRulesTest {
    private val rules = CommunityUploadCheckpointRules

    @Test fun uploadMayResumeButCannotSkipToPublication() {
        assertTrue(rules.canTransition(rules.Phase.STAGED, rules.Phase.SESSION_CREATED))
        assertTrue(rules.canTransition(rules.Phase.SESSION_CREATED, rules.Phase.UPLOADING))
        assertTrue(rules.canTransition(rules.Phase.UPLOADING, rules.Phase.UPLOADING))
        assertTrue(rules.canTransition(rules.Phase.UPLOADING, rules.Phase.SESSION_CREATED))
        assertTrue(rules.canTransition(rules.Phase.UPLOADING, rules.Phase.UPLOAD_COMPLETE_PUBLISH_PENDING))
        assertFalse(rules.canTransition(rules.Phase.STAGED, rules.Phase.INSERT_ATTEMPTED))
        assertFalse(rules.canTransition(rules.Phase.UPLOADING, rules.Phase.PUBLISHED))
    }

    @Test fun onlyPublishPendingMayIssueInsert() {
        for (phase in rules.Phase.values()) {
            if (phase == rules.Phase.UPLOAD_COMPLETE_PUBLISH_PENDING) {
                assertTrue(rules.canIssuePostInsert(phase))
            } else {
                assertFalse(rules.canIssuePostInsert(phase))
            }
        }
        assertTrue(rules.canTransition(rules.Phase.UPLOAD_COMPLETE_PUBLISH_PENDING, rules.Phase.INSERT_ATTEMPTED))
        assertFalse(rules.canTransition(rules.Phase.INSERT_ATTEMPTED, rules.Phase.UPLOAD_COMPLETE_PUBLISH_PENDING))
        assertFalse(rules.canTransition(rules.Phase.RECONCILIATION_REQUIRED, rules.Phase.INSERT_ATTEMPTED))
    }

    @Test fun uncertainInsertMustReconcileAndTerminalPhasesStayTerminal() {
        assertTrue(rules.canTransition(rules.Phase.INSERT_ATTEMPTED, rules.Phase.RECONCILIATION_REQUIRED))
        assertTrue(rules.canTransition(rules.Phase.RECONCILIATION_REQUIRED, rules.Phase.PUBLISHED))
        assertTrue(rules.canTransition(rules.Phase.INSERT_ATTEMPTED, rules.Phase.PUBLISHED))
        for (phase in rules.Phase.values()) {
            assertFalse(rules.canTransition(rules.Phase.PUBLISHED, phase))
            assertFalse(rules.canTransition(rules.Phase.CANCELLED, phase))
        }
    }

    @Test fun cancellationCannotEraseUncertainPublication() {
        assertTrue(rules.canTransition(rules.Phase.STAGED, rules.Phase.CANCELLED))
        assertTrue(rules.canTransition(rules.Phase.UPLOADING, rules.Phase.CANCELLED))
        assertFalse(rules.canTransition(rules.Phase.INSERT_ATTEMPTED, rules.Phase.CANCELLED))
        assertFalse(rules.canTransition(rules.Phase.RECONCILIATION_REQUIRED, rules.Phase.CANCELLED))
    }
}
