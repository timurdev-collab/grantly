package com.grantly.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AdminDraftDuplicateRulesTest {
    @Test fun acceptsWholeAndFractionalScoresWithinPercentageRange() {
        assertEquals(0.0, AdminDraftDuplicateRules.similarityScore(0)!!, 0.0)
        assertEquals(89.0, AdminDraftDuplicateRules.similarityScore(89)!!, 0.0)
        assertEquals(90.0, AdminDraftDuplicateRules.similarityScore(90)!!, 0.0)
        assertEquals(100.0, AdminDraftDuplicateRules.similarityScore(100L)!!, 0.0)
        assertEquals(95.0, AdminDraftDuplicateRules.similarityScore(95.0)!!, 0.0)
        assertEquals(89.5, AdminDraftDuplicateRules.similarityScore(89.5)!!, 0.0)
        assertEquals(90.1, AdminDraftDuplicateRules.similarityScore(90.1)!!, 0.0)
    }

    @Test fun missingMalformedOrOutOfRangeScoresStayUnknown() {
        assertNull(AdminDraftDuplicateRules.similarityScore(null))
        assertNull(AdminDraftDuplicateRules.similarityScore("90"))
        assertNull(AdminDraftDuplicateRules.similarityScore(-1))
        assertNull(AdminDraftDuplicateRules.similarityScore(101))
        assertNull(AdminDraftDuplicateRules.similarityScore(Double.NaN))
        assertNull(AdminDraftDuplicateRules.similarityScore(Double.POSITIVE_INFINITY))
    }

    @Test fun rejectsTruncatedDuplicateResponses() {
        assertTrue(AdminDraftDuplicateRules.isSupportedResultCount(0))
        assertTrue(AdminDraftDuplicateRules.isSupportedResultCount(20))
        assertFalse(AdminDraftDuplicateRules.isSupportedResultCount(21))
        assertFalse(AdminDraftDuplicateRules.isSupportedResultCount(-1))
    }

    @Test fun rejectsMalformedCandidateIdentifiers() {
        assertTrue(AdminDraftDuplicateRules.isValidCandidateId("123e4567-e89b-12d3-a456-426614174000"))
        assertFalse(AdminDraftDuplicateRules.isValidCandidateId(""))
        assertFalse(AdminDraftDuplicateRules.isValidCandidateId("not-a-uuid"))
        assertFalse(AdminDraftDuplicateRules.isValidCandidateId("1-1-1-1-1"))
    }

    @Test fun highSimilarityMatchesIosWarningThreshold() {
        assertFalse(AdminDraftDuplicateRules.isHighSimilarity(null))
        assertFalse(AdminDraftDuplicateRules.isHighSimilarity(89.0))
        assertFalse(AdminDraftDuplicateRules.isHighSimilarity(89.9))
        assertTrue(AdminDraftDuplicateRules.isHighSimilarity(90.0))
        assertTrue(AdminDraftDuplicateRules.isHighSimilarity(90.1))
        assertTrue(AdminDraftDuplicateRules.isHighSimilarity(100.0))
    }
}
