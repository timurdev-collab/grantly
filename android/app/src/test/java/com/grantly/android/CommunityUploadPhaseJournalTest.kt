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

    @Test fun persistsOnlyAllowedTransitionsAcrossReads() {
        val root = Files.createTempDirectory("edut-journal").toFile()
        try {
            assertNull(journal.read(root, account, operation))
            assertFalse(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.INSERT_ATTEMPTED))
            assertTrue(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.STAGED))
            assertEquals(CommunityUploadCheckpointRules.Phase.STAGED, journal.read(root, account, operation))
            assertFalse(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.PUBLISHED))
            assertTrue(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.SESSION_CREATED))
            assertTrue(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.UPLOAD_COMPLETE_PUBLISH_PENDING))
            assertTrue(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.INSERT_ATTEMPTED))
            assertFalse(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.UPLOAD_COMPLETE_PUBLISH_PENDING))
            assertEquals(CommunityUploadCheckpointRules.Phase.INSERT_ATTEMPTED, journal.read(root, account, operation))
        } finally { root.deleteRecursively() }
    }

    @Test fun accountAndOperationAreIsolatedAndInvalidIdsRejected() {
        val root = Files.createTempDirectory("edut-journal").toFile()
        try {
            assertTrue(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.STAGED))
            assertNull(journal.read(root, UUID.randomUUID().toString(), operation))
            assertNull(journal.read(root, account, UUID.randomUUID().toString()))
            assertFalse(journal.write(root, "../escape", operation, CommunityUploadCheckpointRules.Phase.STAGED))
            assertFalse(journal.write(root, account, "../escape", CommunityUploadCheckpointRules.Phase.STAGED))
        } finally { root.deleteRecursively() }
    }

    @Test fun malformedCheckpointCannotBeOverwritten() {
        val root = Files.createTempDirectory("edut-journal").toFile()
        try {
            val accountDir = java.io.File(root, account).apply { mkdirs() }
            java.io.File(accountDir, "$operation.phase").writeText("unexpected")
            assertNull(journal.read(root, account, operation))
            assertFalse(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.STAGED))
        } finally { root.deleteRecursively() }
    }

    @Test fun temporaryFileCollisionDoesNotOverwriteExistingCheckpoint() {
        val root = Files.createTempDirectory("edut-journal").toFile()
        try {
            assertTrue(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.STAGED))
            val temporary = java.io.File(java.io.File(root, account), "$operation.phase.tmp")
            temporary.writeText("unrelated-data")
            assertFalse(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.SESSION_CREATED))
            assertEquals("unrelated-data", temporary.readText())
            assertEquals(CommunityUploadCheckpointRules.Phase.STAGED, journal.read(root, account, operation))
        } finally { root.deleteRecursively() }
    }

    @Test fun symlinkedAccountDirectoryCannotEscapePrivateRoot() {
        val root = Files.createTempDirectory("edut-journal").toFile()
        val outside = Files.createTempDirectory("edut-outside").toFile()
        try {
            Files.createSymbolicLink(java.io.File(root, account).toPath(), outside.toPath())
            assertFalse(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.STAGED))
            assertNull(journal.read(root, account, operation))
            assertFalse(java.io.File(outside, "$operation.phase").exists())
        } finally {
            root.deleteRecursively()
            outside.deleteRecursively()
        }
    }

    @Test fun symlinkedCheckpointCannotBeReadOrReplaced() {
        val root = Files.createTempDirectory("edut-journal").toFile()
        val outside = Files.createTempFile("edut-outside-phase", ".txt").toFile()
        try {
            val accountDir = java.io.File(root, account).apply { mkdirs() }
            outside.writeText("edut-phase-v1\nSTAGED\n")
            Files.createSymbolicLink(java.io.File(accountDir, "$operation.phase").toPath(), outside.toPath())
            assertNull(journal.read(root, account, operation))
            assertFalse(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.STAGED))
            assertEquals("edut-phase-v1\nSTAGED\n", outside.readText())
        } finally {
            root.deleteRecursively()
            outside.delete()
        }
    }

    @Test fun malformedPhaseWithTrailingRecordFailsClosed() {
        val root = Files.createTempDirectory("edut-journal").toFile()
        try {
            val accountDir = java.io.File(root, account).apply { mkdirs() }
            java.io.File(accountDir, "$operation.phase").writeText("edut-phase-v1\nSTAGED\nPUBLISHED\n")
            assertNull(journal.read(root, account, operation))
            assertFalse(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.STAGED))
        } finally { root.deleteRecursively() }
    }

    @Test fun oversizedCheckpointFailsClosedWithoutBeingReplaced() {
        val root = Files.createTempDirectory("edut-journal").toFile()
        try {
            val accountDir = java.io.File(root, account).apply { mkdirs() }
            val checkpoint = java.io.File(accountDir, "$operation.phase")
            val malformed = "edut-phase-v1\nSTAGED\n" + "x".repeat(100)
            checkpoint.writeText(malformed)
            assertNull(journal.read(root, account, operation))
            assertFalse(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.STAGED))
            assertEquals(malformed, checkpoint.readText())
        } finally { root.deleteRecursively() }
    }

    @Test fun unknownPhaseFailsClosedWithoutBeingReplaced() {
        val root = Files.createTempDirectory("edut-journal").toFile()
        try {
            val accountDir = java.io.File(root, account).apply { mkdirs() }
            val checkpoint = java.io.File(accountDir, "$operation.phase")
            val malformed = "edut-phase-v1\nUNKNOWN_PHASE\n"
            checkpoint.writeText(malformed)
            assertNull(journal.read(root, account, operation))
            assertFalse(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.STAGED))
            assertEquals(malformed, checkpoint.readText())
        } finally { root.deleteRecursively() }
    }


    @Test fun uncertainInsertCannotBeReplayedAfterJournalReload() {
        val root = Files.createTempDirectory("edut-journal").toFile()
        try {
            assertTrue(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.STAGED))
            assertTrue(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.SESSION_CREATED))
            assertTrue(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.UPLOAD_COMPLETE_PUBLISH_PENDING))
            assertTrue(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.INSERT_ATTEMPTED))
            assertEquals(CommunityUploadCheckpointRules.Phase.INSERT_ATTEMPTED, journal.read(root, account, operation))
            assertFalse(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.UPLOAD_COMPLETE_PUBLISH_PENDING))
            assertTrue(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.RECONCILIATION_REQUIRED))
            assertFalse(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.INSERT_ATTEMPTED))
            assertEquals(CommunityUploadCheckpointRules.Phase.RECONCILIATION_REQUIRED, journal.read(root, account, operation))
            assertTrue(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.PUBLISHED))
            assertFalse(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.CANCELLED))
            assertEquals(CommunityUploadCheckpointRules.Phase.PUBLISHED, journal.read(root, account, operation))
        } finally { root.deleteRecursively() }
    }

    @Test fun cancellationIsDurablyTerminal() {
        val root = Files.createTempDirectory("edut-journal").toFile()
        try {
            assertTrue(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.STAGED))
            assertTrue(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.CANCELLED))
            assertEquals(CommunityUploadCheckpointRules.Phase.CANCELLED, journal.read(root, account, operation))
            assertFalse(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.SESSION_CREATED))
            assertFalse(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.STAGED))
            assertEquals(CommunityUploadCheckpointRules.Phase.CANCELLED, journal.read(root, account, operation))
        } finally { root.deleteRecursively() }
    }
}
