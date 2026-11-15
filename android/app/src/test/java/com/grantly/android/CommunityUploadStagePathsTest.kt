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

}
