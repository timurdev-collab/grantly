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

    @Test fun sameOperationIdInDifferentAccountsHasIndependentPhaseHistory() {
        val root = Files.createTempDirectory("edut-journal").toFile()
        val otherAccount = UUID.randomUUID().toString()
        try {
            assertTrue(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.STAGED))
            assertTrue(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.SESSION_CREATED))
            assertTrue(journal.write(root, otherAccount, operation, CommunityUploadCheckpointRules.Phase.STAGED))
            assertEquals(CommunityUploadCheckpointRules.Phase.SESSION_CREATED, journal.read(root, account, operation))
            assertEquals(CommunityUploadCheckpointRules.Phase.STAGED, journal.read(root, otherAccount, operation))
            assertFalse(journal.write(root, otherAccount, operation, CommunityUploadCheckpointRules.Phase.INSERT_ATTEMPTED))
            assertEquals(CommunityUploadCheckpointRules.Phase.SESSION_CREATED, journal.read(root, account, operation))
            assertEquals(CommunityUploadCheckpointRules.Phase.STAGED, journal.read(root, otherAccount, operation))
        } finally { root.deleteRecursively() }
    }

    @Test fun journalRootFileCollisionFailsClosedWithoutChangingTheFile() {
        val root = Files.createTempFile("edut-journal-root-collision", ".txt").toFile()
        try {
            root.writeText("preserve-root-file")
            assertNull(journal.read(root, account, operation))
            assertFalse(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.STAGED))
            assertEquals("preserve-root-file", root.readText())
        } finally { root.delete() }
    }

    @Test fun accountDirectoryCollisionFailsClosedWithoutTouchingExistingFile() {
        val root = Files.createTempDirectory("edut-journal").toFile()
        try {
            val collision = java.io.File(root, account)
            collision.writeText("keep-account-collision")
            assertNull(journal.read(root, account, operation))
            assertFalse(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.STAGED))
            assertEquals("keep-account-collision", collision.readText())
            assertFalse(java.io.File(collision, "$operation.phase").exists())
        } finally { root.deleteRecursively() }
    }

    @Test fun checkpointDirectoryCollisionFailsClosedWithoutDeletingContents() {
        val root = Files.createTempDirectory("edut-journal").toFile()
        try {
            val accountDir = java.io.File(root, account).apply { mkdirs() }
            val collision = java.io.File(accountDir, "$operation.phase").apply { mkdirs() }
            val sentinel = java.io.File(collision, "keep.txt").apply { writeText("preserve") }
            assertNull(journal.read(root, account, operation))
            assertFalse(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.STAGED))
            assertTrue(collision.isDirectory)
            assertEquals("preserve", sentinel.readText())
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

    @Test fun temporaryDirectoryCollisionPreservesExistingContentsAndCheckpoint() {
        val root = Files.createTempDirectory("edut-journal").toFile()
        try {
            assertTrue(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.STAGED))
            val temporary = java.io.File(java.io.File(root, account), "$operation.phase.tmp").apply { mkdirs() }
            val sentinel = java.io.File(temporary, "keep.txt").apply { writeText("do-not-delete") }
            assertFalse(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.SESSION_CREATED))
            assertTrue(temporary.isDirectory)
            assertEquals("do-not-delete", sentinel.readText())
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

    @Test fun staleTemporaryFileBlocksFreshCheckpointWithoutDeletingIt() {
        val root = Files.createTempDirectory("edut-journal").toFile()
        try {
            val accountDir = java.io.File(root, account).apply { mkdirs() }
            val temporary = java.io.File(accountDir, "$operation.phase.tmp")
            temporary.writeText("unknown-crash-recovery-state")
            assertFalse(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.STAGED))
            assertEquals("unknown-crash-recovery-state", temporary.readText())
            assertNull(journal.read(root, account, operation))
        } finally { root.deleteRecursively() }
    }


    @Test fun symlinkedTemporaryCheckpointCannotReplaceOrDeleteOutsideFile() {
        val root = Files.createTempDirectory("edut-journal").toFile()
        val outside = Files.createTempFile("edut-outside-temp", ".txt").toFile()
        try {
            assertTrue(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.STAGED))
            val temporary = java.io.File(java.io.File(root, account), "$operation.phase.tmp")
            outside.writeText("keep-this-outside-file")
            Files.createSymbolicLink(temporary.toPath(), outside.toPath())
            assertFalse(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.SESSION_CREATED))
            assertEquals("keep-this-outside-file", outside.readText())
            assertTrue(Files.isSymbolicLink(temporary.toPath()))
            assertEquals(CommunityUploadCheckpointRules.Phase.STAGED, journal.read(root, account, operation))
        } finally {
            root.deleteRecursively()
            outside.delete()
        }
    }


    @Test fun symlinkedJournalRootCannotWriteOutsidePrivateStorage() {
        val outside = Files.createTempDirectory("edut-outside-root").toFile()
        val linkParent = Files.createTempDirectory("edut-root-link").toFile()
        try {
            val linkedRoot = java.io.File(linkParent, "journal")
            Files.createSymbolicLink(linkedRoot.toPath(), outside.toPath())
            assertFalse(journal.write(linkedRoot, account, operation, CommunityUploadCheckpointRules.Phase.STAGED))
            assertNull(journal.read(linkedRoot, account, operation))
            assertFalse(java.io.File(outside, account).exists())
        } finally {
            linkParent.deleteRecursively()
            outside.deleteRecursively()
        }
    }


    @Test fun noncanonicalUuidAliasesCannotAccessExistingCheckpoint() {
        val root = Files.createTempDirectory("edut-journal").toFile()
        try {
            assertTrue(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.STAGED))
            val uppercaseAccount = account.uppercase(java.util.Locale.ROOT)
            val uppercaseOperation = operation.uppercase(java.util.Locale.ROOT)
            assertFalse(journal.write(root, uppercaseAccount, operation, CommunityUploadCheckpointRules.Phase.STAGED))
            assertFalse(journal.write(root, account, uppercaseOperation, CommunityUploadCheckpointRules.Phase.STAGED))
            assertNull(journal.read(root, uppercaseAccount, operation))
            assertNull(journal.read(root, account, uppercaseOperation))
            assertEquals(CommunityUploadCheckpointRules.Phase.STAGED, journal.read(root, account, operation))
        } finally { root.deleteRecursively() }
    }

    @Test fun interruptedUploadMayResumeButCannotReturnToStaging() {
        val root = Files.createTempDirectory("edut-journal").toFile()
        try {
            assertTrue(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.STAGED))
            assertFalse(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.STAGED))
            assertTrue(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.SESSION_CREATED))
            assertTrue(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.UPLOADING))
            assertTrue(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.UPLOADING))
            assertTrue(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.SESSION_CREATED))
            assertFalse(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.STAGED))
            assertTrue(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.UPLOAD_COMPLETE_PUBLISH_PENDING))
            assertFalse(journal.write(root, account, operation, CommunityUploadCheckpointRules.Phase.UPLOADING))
            assertEquals(CommunityUploadCheckpointRules.Phase.UPLOAD_COMPLETE_PUBLISH_PENDING, journal.read(root, account, operation))
        } finally { root.deleteRecursively() }
    }

}
