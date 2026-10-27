package com.grantly.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AdminDraftDuplicateRulesTest {
    @Test fun acceptsOnlyWholeScoresWithinPercentageRange() {
        assertEquals(0, AdminDraftDuplicateRules.similarityScore(0))
        assertEquals(89, AdminDraftDuplicateRules.similarityScore(89))
        assertEquals(90, AdminDraftDuplicateRules.similarityScore(90))
        assertEquals(100, AdminDraftDuplicateRules.similarityScore(100L))
        assertEquals(95, AdminDraftDuplicateRules.similarityScore(95.0))
    }

    @Test fun missingMalformedOrOutOfRangeScoresStayUnknown() {
        assertNull(AdminDraftDuplicateRules.similarityScore(null))
        assertNull(AdminDraftDuplicateRules.similarityScore("90"))
        assertNull(AdminDraftDuplicateRules.similarityScore(-1))
        assertNull(AdminDraftDuplicateRules.similarityScore(101))
        assertNull(AdminDraftDuplicateRules.similarityScore(89.5))
        assertNull(AdminDraftDuplicateRules.similarityScore(Double.NaN))
        assertNull(AdminDraftDuplicateRules.similarityScore(Double.POSITIVE_INFINITY))
    }

    @Test fun highSimilarityMatchesIosWarningThreshold() {
        assertFalse(AdminDraftDuplicateRules.isHighSimilarity(null))
        assertFalse(AdminDraftDuplicateRules.isHighSimilarity(89))
        assertTrue(AdminDraftDuplicateRules.isHighSimilarity(90))
        assertTrue(AdminDraftDuplicateRules.isHighSimilarity(100))
    }
}
