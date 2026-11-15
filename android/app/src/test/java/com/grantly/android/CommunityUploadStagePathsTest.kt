package com.grantly.android

import org.junit.Assert.*
import org.junit.Test
import java.io.File

class CommunityUploadStagePathsTest {
    private val account = "00000000-0000-4000-8000-000000000001"
    private val operation = "00000000-0000-4000-8000-000000000002"
    private val root = File("private-community-staging")

    @Test fun canonicalAccountAndOperationStayInOwnDirectory() {
        val expected = File(File(root, account), "$operation.mp4")
        assertEquals(expected, CommunityUploadStagePaths.stageFile(root, account, operation))
        assertTrue(CommunityUploadStagePaths.matches(root, expected, account, operation))
        assertFalse(CommunityUploadStagePaths.matches(root, expected, "00000000-0000-4000-8000-000000000003", operation))
    }

    @Test fun invalidIdentifiersCannotSelectPaths() {
        for (invalid in listOf("", "../outside", "UPPERCASE", "00000000-0000-4000-8000-000000000001/../", "  $account", "$account/", "0-0-0-0-1", "00000000-0000-4000-8000-000000000001\n")) {
            assertNull(CommunityUploadStagePaths.stageFile(root, invalid, operation))
            assertNull(CommunityUploadStagePaths.stageFile(root, account, invalid))
        }
    }

    @Test fun differentOperationOrDirectoryNeverMatches() {
        val selected = CommunityUploadStagePaths.stageFile(root, account, operation)!!
        assertFalse(CommunityUploadStagePaths.matches(root, selected, account, "00000000-0000-4000-8000-000000000004"))
        assertFalse(CommunityUploadStagePaths.matches(root, File("other-root/$account/$operation.mp4"), account, operation))
    }
    @Test fun aliasedPathsCannotImpersonateStagedFile() {
        val selected = CommunityUploadStagePaths.stageFile(root, account, operation)!!
        val aliased = File(File(root, account), "../$account/$operation.mp4")
        assertEquals(selected.canonicalFile, aliased.canonicalFile)
        assertFalse(CommunityUploadStagePaths.matches(root, aliased, account, operation))
    }
    @Test fun symlinkedStagingFileIsRejected() {
        val temp = java.nio.file.Files.createTempDirectory("community-stage-test")
        try {
            val accountDir = java.nio.file.Files.createDirectories(temp.resolve(account))
            val outside = java.nio.file.Files.createTempFile(temp, "outside-", ".mp4")
            val link = accountDir.resolve("$operation.mp4")
            try {
                java.nio.file.Files.createSymbolicLink(link, outside)
            } catch (e: UnsupportedOperationException) {
                org.junit.Assume.assumeNoException(e)
            } catch (e: java.nio.file.FileSystemException) {
                org.junit.Assume.assumeNoException(e)
            } catch (e: SecurityException) {
                org.junit.Assume.assumeNoException(e)
            }
            assertFalse(CommunityUploadStagePaths.matches(temp.toFile(), link.toFile(), account, operation))
        } finally {
            temp.toFile().deleteRecursively()
        }
    }

    @Test fun symlinkedAccountDirectoryIsRejected() {
        val temp = java.nio.file.Files.createTempDirectory("community-stage-parent-test")
        try {
            val outside = java.nio.file.Files.createDirectories(temp.resolve("outside"))
            val link = temp.resolve(account)
            try {
                java.nio.file.Files.createSymbolicLink(link, outside)
            } catch (e: UnsupportedOperationException) {
                org.junit.Assume.assumeNoException(e)
            } catch (e: java.nio.file.FileSystemException) {
                org.junit.Assume.assumeNoException(e)
            } catch (e: SecurityException) {
                org.junit.Assume.assumeNoException(e)
            }
            val candidate = link.resolve("$operation.mp4")
            assertFalse(CommunityUploadStagePaths.matches(temp.toFile(), candidate.toFile(), account, operation))
        } finally {
            temp.toFile().deleteRecursively()
        }
    }

    @Test fun symlinkedStagingRootIsRejected() {
        val temp = java.nio.file.Files.createTempDirectory("community-stage-root-test")
        try {
            val actualRoot = java.nio.file.Files.createDirectories(temp.resolve("actual-root"))
            val aliasRoot = temp.resolve("alias-root")
            try {
                java.nio.file.Files.createSymbolicLink(aliasRoot, actualRoot)
            } catch (e: UnsupportedOperationException) {
                org.junit.Assume.assumeNoException(e)
            } catch (e: java.nio.file.FileSystemException) {
                org.junit.Assume.assumeNoException(e)
            } catch (e: SecurityException) {
                org.junit.Assume.assumeNoException(e)
            }
            val candidate = aliasRoot.resolve(account).resolve("$operation.mp4")
            assertFalse(CommunityUploadStagePaths.matches(aliasRoot.toFile(), candidate.toFile(), account, operation))
        } finally {
            temp.toFile().deleteRecursively()
        }
    }

    @Test fun recoveredMp4MustBeRegularNonemptyAndWithinLimit() {
        val temp = java.nio.file.Files.createTempDirectory("community-stage-content-test")
        try {
            val accountDir = java.nio.file.Files.createDirectories(temp.resolve(account))
            val candidate = accountDir.resolve("$operation.mp4").toFile()
            val rootDir = temp.toFile()
            assertFalse(CommunityUploadStagePaths.isSafeStagedMp4(rootDir, candidate, account, operation, 10))
            candidate.writeBytes(byteArrayOf())
            assertFalse(CommunityUploadStagePaths.isSafeStagedMp4(rootDir, candidate, account, operation, 10))
            candidate.writeBytes(byteArrayOf(0, 0, 0, 16, 102, 116, 121, 112, 105, 115, 111, 109, 0, 0, 0, 0))
            assertTrue(CommunityUploadStagePaths.isSafeStagedMp4(rootDir, candidate, account, operation, 16))
            assertFalse(CommunityUploadStagePaths.isSafeStagedMp4(rootDir, candidate, account, operation, 15))
            candidate.writeBytes(byteArrayOf(0, 0, 0, 12, 102, 116, 121, 112, 105, 115, 111, 109))
            assertFalse(CommunityUploadStagePaths.isSafeStagedMp4(rootDir, candidate, account, operation, 16))
            candidate.writeBytes(byteArrayOf(0, 0, 0, 32, 102, 116, 121, 112, 105, 115, 111, 109, 0, 0, 0, 0))
            assertFalse(CommunityUploadStagePaths.isSafeStagedMp4(rootDir, candidate, account, operation, 16))
            candidate.writeBytes(byteArrayOf(0, 0, 0, 16, 110, 111, 116, 33, 105, 115, 111, 109, 0, 0, 0, 0))
            assertFalse(CommunityUploadStagePaths.isSafeStagedMp4(rootDir, candidate, account, operation, 16))
            candidate.writeBytes(byteArrayOf(0, 0, 0, 16, 102, 116, 121, 112))
            assertFalse(CommunityUploadStagePaths.isSafeStagedMp4(rootDir, candidate, account, operation, 16))
            assertFalse(CommunityUploadStagePaths.isSafeStagedMp4(rootDir, candidate, account, operation, 0))
            assertFalse(CommunityUploadStagePaths.isSafeStagedMp4(rootDir, candidate, account,
                "00000000-0000-4000-8000-000000000003", 10))
            candidate.delete()
            candidate.mkdir()
            assertFalse(CommunityUploadStagePaths.isSafeStagedMp4(rootDir, candidate, account, operation, 10))
        } finally {
            temp.toFile().deleteRecursively()
        }
    }

}
