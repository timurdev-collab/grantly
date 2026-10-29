package com.grantly.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.assertFalse
import org.junit.Test

class AdvisorApplicationDraftTest {
    private val valid = AdvisorApplicationDraft(
        displayName = "Sample Advisor",
        title = "Admissions Advisor",
        yearsExperience = "5",
        bio = "I have helped students plan university applications and scholarships for many years. " +
            "My work includes reviewing applications and providing detailed mentoring.",
        specialties = "Scholarships, Admissions",
        languages = "English",
        introVideoUrl = "https://example.org/introduction"
    )

    @Test fun acceptsCompletedThreeStepApplication() {
        assertNull(valid.completeIssue(hasPhoto = true))
        assertNull(valid.copy(avatarStoragePath = "user/avatar/photo.jpg")
            .completeIssue(hasPhoto = false))
        // Older approved advisor profiles may have a public avatar URL only.
        assertNull(valid.copy(avatarUrl = "https://example.org/advisor.jpg")
            .completeIssue(hasPhoto = false))
    }

    @Test fun blocksApprovedAdvisorApplicationResubmission() {
        assertFalse(valid.copy(approvalStatus = "approved").isApplicationResubmittable())
        assertFalse(valid.copy(approvalStatus = "suspended").isApplicationResubmittable())
        for (status in listOf(null, "pending", "rejected", "changes_requested")) {
            assertTrue("Expected status to allow application: $status",
                valid.copy(approvalStatus = status).isApplicationResubmittable())
        }
    }

    @Test fun requiresProfessionalPhotoAndIdentity() {
        assertEquals("Please enter your full name.",
            valid.copy(displayName = " ").validationIssue(0, true))
        assertEquals("Please enter your professional title.",
            valid.copy(title = " ").validationIssue(0, true))
        assertEquals("Please add a professional profile photo.",
            valid.validationIssue(0, false))
    }

    @Test fun rejectsInvalidExperienceWithoutCrashing() {
        for (value in listOf("-1", "81", "abc", "1.5", "99999999999999")) {
            assertEquals("Please check your years of experience.",
                valid.copy(yearsExperience = value).validationIssue(0, true))
        }
        assertNull(valid.copy(yearsExperience = "").validationIssue(0, true))
        assertNull(valid.copy(yearsExperience = "0").validationIssue(0, true))
        assertNull(valid.copy(yearsExperience = "80").validationIssue(0, true))
    }

    @Test fun requiresDetailedBackgroundSpecialtyAndLanguage() {
        assertEquals("Please add a little more detail to your professional background.",
            valid.copy(bio = "Short").validationIssue(1, true))
        assertEquals("Please add at least one specialty.",
            valid.copy(specialties = " , ").validationIssue(1, true))
        assertEquals("Please add at least one language.",
            valid.copy(languages = "").validationIssue(1, true))
        assertEquals(listOf("Admissions", "Scholarships"),
            valid.csv(" Admissions, , Scholarships, "))
    }

    @Test fun rejectsInsecureOrMalformedUrls() {
        for (value in listOf("", "http://example.org", "https://", "https://bad host",
            "javascript:alert(1)", "https://user:pass@example.org/video")) {
            assertFalse("Unexpected URL: $value", AdvisorApplicationDraft.isHttpsUrl(value))
        }
        assertTrue(AdvisorApplicationDraft.isHttpsUrl(" https://example.org/video "))
        assertEquals("Please add a valid HTTPS introduction video link.",
            valid.copy(introVideoUrl = "http://example.org").validationIssue(2, true))
        assertEquals("Please check your LinkedIn URL.",
            valid.copy(linkedinUrl = "http://example.org").validationIssue(2, true))
        assertEquals("Please check your website URL.",
            valid.copy(websiteUrl = "not-a-url").validationIssue(2, true))
    }
}
