package com.grantly.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.file.Files
import java.util.UUID

class CommunityUploadPhaseJournalTest {
    private val account = UUID.randomUUID().toString()
    private val operation = UUID.randomUUID().toString()
    private val journal = CommunityUploadPhaseJournal
    private val phase = CommunityUploadCheckpointRules.Phase

    @Test fun persistsOnlyAllowedTransitionsAcrossReads() {
        val root = Files.createTempDirectory("edut-journal").toFile()
        try {
            assertNull(journal.read(root, account, operation))
            assertFalse(journal.write(root, account, operation, phase.INSERT_ATTEMPTED))
            assertTrue(journal.write(root, account, operation, phase.STAGED))
            assertEquals(phase.STAGED, journal.read(root, account, operation))
            assertFalse(journal.write(root, account, operation, phase.PUBLISHED))
            assertTrue(journal.write(root, account, operation, phase.SESSION_CREATED))
            assertTrue(journal.write(root, account, operation, phase.UPLOAD_COMPLETE_PUBLISH_PENDING))
            assertTrue(journal.write(root, account, operation, phase.INSERT_ATTEMPTED))
            assertFalse(journal.write(root, account, operation, phase.UPLOAD_COMPLETE_PUBLISH_PENDING))
            assertEquals(phase.INSERT_ATTEMPTED, journal.read(root, account, operation))
        } finally { root.deleteRecursively() }
    }

    @Test fun accountAndOperationAreIsolatedAndInvalidIdsRejected() {
        val root = Files.createTempDirectory("edut-journal").toFile()
        try {
            assertTrue(journal.write(root, account, operation, phase.STAGED))
            assertNull(journal.read(root, UUID.randomUUID().toString(), operation))
            assertNull(journal.read(root, account, UUID.randomUUID().toString()))
            assertFalse(journal.write(root, "../escape", operation, phase.STAGED))
            assertFalse(journal.write(root, account, "../escape", phase.STAGED))
        } finally { root.deleteRecursively() }
    }

    @Test fun malformedCheckpointCannotBeOverwritten() {
        val root = Files.createTempDirectory("edut-journal").toFile()
        try {
            val accountDir = java.io.File(root, account).apply { mkdirs() }
            java.io.File(accountDir, "$operation.phase").writeText("unexpected")
            assertNull(journal.read(root, account, operation))
            assertFalse(journal.write(root, account, operation, phase.STAGED))
        } finally { root.deleteRecursively() }
    }
}
