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
    @Test fun allInvalidPrerequisitesFailClosedEvenWhenMatchingPostExists() {
        for (uploadCompleted in listOf(false, true)) {
            for (accountMatches in listOf(false, true)) {
                for (mediaKeyMatches in listOf(false, true)) {
                    if (uploadCompleted && accountMatches && mediaKeyMatches) continue
                    for (count in listOf<Int?>(null, -1, 0, 1, 2)) {
                        for (attempted in listOf(false, true)) {
                            assertEquals(
                                "upload=$uploadCompleted account=$accountMatches media=$mediaKeyMatches count=$count attempted=$attempted",
                                CommunityPublicationRecoveryRules.Decision.REQUIRE_MANUAL_RECONCILIATION,
                                decide(uploadCompleted, accountMatches, mediaKeyMatches, count, attempted)
                            )
                        }
                    }
                }
            }
        }
    }

    @Test fun completedVerifiedUploadHasExplicitDecisionForEveryLookupState() {
        for (attempted in listOf(false, true)) {
            for (count in listOf<Int?>(null, -1, 0, 1, 2, Int.MAX_VALUE)) {
                val expected = when {
                    count == 1 -> CommunityPublicationRecoveryRules.Decision.ALREADY_PUBLISHED
                    count == 0 && !attempted ->
                        CommunityPublicationRecoveryRules.Decision.SAFE_TO_ATTEMPT_INSERT
                    else -> CommunityPublicationRecoveryRules.Decision.REQUIRE_MANUAL_RECONCILIATION
                }
                assertEquals("count=$count attempted=$attempted",
                    expected, decide(matchingPublishedPostCount = count,
                        insertPreviouslyAttempted = attempted))
            }
        }
    }

}
