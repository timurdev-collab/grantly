package com.grantly.android

import org.junit.Assert.assertEquals
import org.junit.Test

class CommunityUploadRecoveryGuardTest {
    private fun decide(
        expectedAccountId: String = "student-a",
        storedAccountId: String = "student-a",
        stagedFileSize: Long = 1024L,
        stagedFileExists: Boolean = true,
        sessionExpired: Boolean = false,
        serverOffset: Long? = 0L,
        serverSessionMissing: Boolean = false
    ) = CommunityUploadRecoveryGuard.decide(
        expectedAccountId, storedAccountId, stagedFileSize,
        stagedFileExists, sessionExpired, serverOffset, serverSessionMissing
    )

    @Test fun resumesOnlyFromServerOffsetWithinFile() {
        assertEquals(CommunityUploadRecoveryGuard.Decision.RESUME_FROM_SERVER_OFFSET, decide(serverOffset = 0L))
        assertEquals(CommunityUploadRecoveryGuard.Decision.RESUME_FROM_SERVER_OFFSET, decide(serverOffset = 512L))
        assertEquals(CommunityUploadRecoveryGuard.Decision.COMPLETE_UPLOAD, decide(serverOffset = 1024L))
    }

    @Test fun rejectsMissingOrMismatchedAccount() {
        assertEquals(CommunityUploadRecoveryGuard.Decision.REJECT, decide(expectedAccountId = ""))
        assertEquals(CommunityUploadRecoveryGuard.Decision.REJECT, decide(storedAccountId = ""))
        assertEquals(CommunityUploadRecoveryGuard.Decision.REJECT, decide(storedAccountId = "student-b"))
    }

    @Test fun rejectsMissingEmptyOrOversizedStagedFile() {
        assertEquals(CommunityUploadRecoveryGuard.Decision.REJECT, decide(stagedFileExists = false))
        assertEquals(CommunityUploadRecoveryGuard.Decision.REJECT, decide(stagedFileSize = 0L))
        assertEquals(CommunityUploadRecoveryGuard.Decision.REJECT, decide(stagedFileSize = -1L))
        assertEquals(CommunityUploadRecoveryGuard.Decision.REJECT, decide(stagedFileSize = 200L * 1024 * 1024 + 1L))
        assertEquals(CommunityUploadRecoveryGuard.Decision.COMPLETE_UPLOAD,
            decide(stagedFileSize = 200L * 1024 * 1024, serverOffset = 200L * 1024 * 1024))
    }

    @Test fun rejectsUnknownNegativeOrOutOfBoundsServerOffset() {
        assertEquals(CommunityUploadRecoveryGuard.Decision.REJECT, decide(serverOffset = null))
        assertEquals(CommunityUploadRecoveryGuard.Decision.REJECT, decide(serverOffset = -1L))
        assertEquals(CommunityUploadRecoveryGuard.Decision.REJECT, decide(serverOffset = 1025L))
    }

    @Test fun missingOrExpiredServerSessionRequiresNewObject() {
        assertEquals(CommunityUploadRecoveryGuard.Decision.RESTART_WITH_NEW_OBJECT,
            decide(sessionExpired = true))
        assertEquals(CommunityUploadRecoveryGuard.Decision.RESTART_WITH_NEW_OBJECT,
            decide(serverSessionMissing = true))
        // A missing staged file must not be bypassed by an expired session.
        assertEquals(CommunityUploadRecoveryGuard.Decision.REJECT,
            decide(stagedFileExists = false, sessionExpired = true))
        assertEquals(CommunityUploadRecoveryGuard.Decision.REJECT,
            decide(storedAccountId = "student-b", serverSessionMissing = true))
    }
    @Test fun accountOwnershipIsCaseSensitiveAndNotSubstringBased() {
        assertEquals(CommunityUploadRecoveryGuard.Decision.REJECT,
            decide(expectedAccountId = "student-a", storedAccountId = "Student-a"))
        assertEquals(CommunityUploadRecoveryGuard.Decision.REJECT,
            decide(expectedAccountId = "student-a", storedAccountId = "student-a-other"))
        assertEquals(CommunityUploadRecoveryGuard.Decision.REJECT,
            decide(expectedAccountId = "student-a", storedAccountId = " student-a"))
    }

    @Test fun expiredSessionCanRestartWithoutKnownOffsetButNeverWithoutValidFile() {
        assertEquals(CommunityUploadRecoveryGuard.Decision.RESTART_WITH_NEW_OBJECT,
            decide(sessionExpired = true, serverOffset = null))
        assertEquals(CommunityUploadRecoveryGuard.Decision.RESTART_WITH_NEW_OBJECT,
            decide(serverSessionMissing = true, serverOffset = -1L))
        assertEquals(CommunityUploadRecoveryGuard.Decision.REJECT,
            decide(sessionExpired = true, stagedFileSize = 0L, serverOffset = null))
        assertEquals(CommunityUploadRecoveryGuard.Decision.REJECT,
            decide(serverSessionMissing = true, expectedAccountId = "", serverOffset = null))
    }

    @Test fun offsetMustMatchExactFileLengthBeforeCompletion() {
        val size = 200L * 1024 * 1024
        assertEquals(CommunityUploadRecoveryGuard.Decision.RESUME_FROM_SERVER_OFFSET,
            decide(stagedFileSize = size, serverOffset = size - 1L))
        assertEquals(CommunityUploadRecoveryGuard.Decision.COMPLETE_UPLOAD,
            decide(stagedFileSize = size, serverOffset = size))
        assertEquals(CommunityUploadRecoveryGuard.Decision.REJECT,
            decide(stagedFileSize = size, serverOffset = size + 1L))
    }

    @Test fun rejectsWhitespaceOnlyAccountIdsAndExtremeOffsets() {
        assertEquals(CommunityUploadRecoveryGuard.Decision.REJECT,
            decide(expectedAccountId = "   "))
        assertEquals(CommunityUploadRecoveryGuard.Decision.REJECT,
            decide(storedAccountId = "\t\n"))
        assertEquals(CommunityUploadRecoveryGuard.Decision.REJECT,
            decide(serverOffset = Long.MAX_VALUE))
        assertEquals(CommunityUploadRecoveryGuard.Decision.REJECT,
            decide(serverOffset = Long.MIN_VALUE))
    }


    @Test fun rejectsMatchingButWhitespacePaddedAccountIdentifiers() {
        assertEquals(CommunityUploadRecoveryGuard.Decision.REJECT,
            decide(expectedAccountId = " student-a", storedAccountId = " student-a"))
        assertEquals(CommunityUploadRecoveryGuard.Decision.REJECT,
            decide(expectedAccountId = "student-a ", storedAccountId = "student-a "))
        assertEquals(CommunityUploadRecoveryGuard.Decision.REJECT,
            decide(expectedAccountId = "\tstudent-a", storedAccountId = "\tstudent-a"))
        assertEquals(CommunityUploadRecoveryGuard.Decision.RESUME_FROM_SERVER_OFFSET,
            decide(expectedAccountId = "student-a", storedAccountId = "student-a"))
    }

    @Test fun rejectsEmbeddedControlCharactersEvenWhenBothAccountIdsMatch() {
        for (invalidId in listOf("student\\na", "student\\ta", "student\\u0000a", "student\\u007fa")) {
            assertEquals(CommunityUploadRecoveryGuard.Decision.REJECT,
                decide(expectedAccountId = invalidId, storedAccountId = invalidId))
        }
        assertEquals(CommunityUploadRecoveryGuard.Decision.RESUME_FROM_SERVER_OFFSET,
            decide(expectedAccountId = "student-a", storedAccountId = "student-a"))
    }

}
