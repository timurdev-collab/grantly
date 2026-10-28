package com.grantly.android

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AdminDraftPublishRulesTest {
    private val ready = AdminDraftReadiness(true, emptyList(), emptyList(), "")
    private val blocked = AdminDraftReadiness(false, listOf("Missing source"), emptyList(), "")
    private fun candidate(score: Double?) = AdminDraftDuplicateCandidate(
        "00000000-0000-0000-0000-000000000001", "Similar", "Provider", "Country", score
    )

    @Test fun readinessMustBeCheckedAndPass() {
        assertFalse(AdminDraftPublishRules.canOfferPublish(null, emptyList()))
        assertFalse(AdminDraftPublishRules.canOfferPublish(blocked, emptyList()))
    }

    @Test fun duplicateCheckMustBeCompleted() {
        assertFalse(AdminDraftPublishRules.canOfferPublish(ready, null))
        assertTrue(AdminDraftPublishRules.canOfferPublish(ready, emptyList()))
    }

    @Test fun highSimilarityBlocksPublication() {
        assertTrue(AdminDraftPublishRules.canOfferPublish(ready, listOf(candidate(89.0))))
        assertFalse(AdminDraftPublishRules.canOfferPublish(ready, listOf(candidate(90.0))))
        assertFalse(AdminDraftPublishRules.canOfferPublish(ready, listOf(candidate(90.1))))
        assertTrue(AdminDraftPublishRules.canOfferPublish(ready, listOf(candidate(89.9))))
        assertFalse(AdminDraftPublishRules.canOfferPublish(ready, listOf(candidate(100.0))))
    }

    @Test fun unknownSimilarityFailsClosed() {
        assertFalse(AdminDraftPublishRules.canOfferPublish(ready, listOf(candidate(null))))
        assertFalse(AdminDraftPublishRules.canOfferPublish(ready,
            listOf(candidate(12.0), candidate(null))))
    }
}
