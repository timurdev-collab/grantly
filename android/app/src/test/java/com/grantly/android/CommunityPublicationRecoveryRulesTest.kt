package com.grantly.android

import org.junit.Assert.assertEquals
import org.junit.Test

class CommunityPublicationRecoveryRulesTest {
    private fun decide(
        uploadCompleted: Boolean = true,
        accountMatches: Boolean = true,
        mediaKeyMatches: Boolean = true,
        matchingPublishedPostCount: Int? = 0,
        insertPreviouslyAttempted: Boolean = false
    ) = CommunityPublicationRecoveryRules.decide(
        uploadCompleted, accountMatches, mediaKeyMatches,
        matchingPublishedPostCount, insertPreviouslyAttempted
    )

    @Test fun firstInsertRequiresVerifiedCompletedUploadAndNoMatchingPost() {
        assertEquals(CommunityPublicationRecoveryRules.Decision.SAFE_TO_ATTEMPT_INSERT, decide())
        assertEquals(CommunityPublicationRecoveryRules.Decision.REQUIRE_MANUAL_RECONCILIATION,
            decide(uploadCompleted = false))
        assertEquals(CommunityPublicationRecoveryRules.Decision.REQUIRE_MANUAL_RECONCILIATION,
            decide(accountMatches = false))
        assertEquals(CommunityPublicationRecoveryRules.Decision.REQUIRE_MANUAL_RECONCILIATION,
            decide(mediaKeyMatches = false))
    }

    @Test fun ambiguousPreviousInsertNeverTriggersBlindRetry() {
        assertEquals(CommunityPublicationRecoveryRules.Decision.REQUIRE_MANUAL_RECONCILIATION,
            decide(insertPreviouslyAttempted = true))
        assertEquals(CommunityPublicationRecoveryRules.Decision.ALREADY_PUBLISHED,
            decide(insertPreviouslyAttempted = true, matchingPublishedPostCount = 1))
    }

    @Test fun unknownOrInvalidLookupNeverPermitsInsert() {
        for (count in listOf(null, -1)) {
            assertEquals(CommunityPublicationRecoveryRules.Decision.REQUIRE_MANUAL_RECONCILIATION,
                decide(matchingPublishedPostCount = count))
        }
        assertEquals(CommunityPublicationRecoveryRules.Decision.REQUIRE_MANUAL_RECONCILIATION,
            decide(matchingPublishedPostCount = 2))
        assertEquals(CommunityPublicationRecoveryRules.Decision.REQUIRE_MANUAL_RECONCILIATION,
            decide(matchingPublishedPostCount = Int.MAX_VALUE))
    }
}
