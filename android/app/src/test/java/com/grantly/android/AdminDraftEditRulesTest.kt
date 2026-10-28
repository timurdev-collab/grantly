package com.grantly.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class AdminDraftEditRulesTest {
    @Test fun trimsFieldsAndPreservesBlankOptionalValues() {
        val values = AdminDraftEditRules.validate(
            "  Global Scholarship  ", " University ", " Japan ", "  Full funding  ", ""
        )
        assertEquals("Global Scholarship", values.title)
        assertEquals("University", values.provider)
        assertEquals("Japan", values.country)
        assertEquals("Full funding", values.fundingType)
        assertEquals("", values.deadline)
    }

    @Test fun rejectsMissingRequiredFields() {
        assertThrows(IllegalArgumentException::class.java) {
            AdminDraftEditRules.validate(" ", "University", "Japan", "", "")
        }
        assertThrows(IllegalArgumentException::class.java) {
            AdminDraftEditRules.validate("Scholarship", "", "Japan", "", "")
        }
        assertThrows(IllegalArgumentException::class.java) {
            AdminDraftEditRules.validate("Scholarship", "University", " ", "", "")
        }
    }

    @Test fun acceptsRealIsoDateAndRejectsImpossibleDates() {
        assertEquals("2028-02-29", AdminDraftEditRules.validate(
            "Scholarship", "University", "Japan", "", "2028-02-29"
        ).deadline)
        assertThrows(IllegalArgumentException::class.java) {
            AdminDraftEditRules.validate("Scholarship", "University", "Japan", "", "2027-02-29")
        }
        assertThrows(IllegalArgumentException::class.java) {
            AdminDraftEditRules.validate("Scholarship", "University", "Japan", "", "29/02/2028")
        }
    }

    @Test fun rejectsOversizedFields() {
        assertThrows(IllegalArgumentException::class.java) {
            AdminDraftEditRules.validate("x".repeat(201), "University", "Japan", "", "")
        }
        assertThrows(IllegalArgumentException::class.java) {
            AdminDraftEditRules.validate("Scholarship", "University", "Japan", "x".repeat(81), "")
        }
    }

    @Test fun trimsAndValidatesOptionalApplicationCycle() {
        val values = AdminDraftEditRules.validate(
            "Scholarship", "University", "Japan", "", "", "  Annual  "
        )
        assertEquals("Annual", values.applicationCycle)
        assertEquals("", AdminDraftEditRules.validate(
            "Scholarship", "University", "Japan", "", ""
        ).applicationCycle)
        assertThrows(IllegalArgumentException::class.java) {
            AdminDraftEditRules.validate(
                "Scholarship", "University", "Japan", "", "", "x".repeat(81)
            )
        }
    }

    @Test fun acceptsSafeOfficialUrlAndAllowsClearingIt() {
        val values = AdminDraftEditRules.validate(
            "Scholarship", "University", "Japan", "", "", "",
            "  https://university.example/scholarships  "
        )
        assertEquals("https://university.example/scholarships", values.officialUrl)
        val cleared = AdminDraftEditRules.validate(
            "Scholarship", "University", "Japan", "", "", "", "",
            "https://university.example/scholarships"
        )
        assertEquals("", cleared.officialUrl)
    }

    @Test fun rejectsUnsafeOfficialUrlWhenChanged() {
        for (url in listOf("http://university.example", "https://", "https://user@university.example",
            "https://university.example/space here", "https://university.example/" + "x".repeat(2049))) {
            assertThrows(IllegalArgumentException::class.java) {
                AdminDraftEditRules.validate("Scholarship", "University", "Japan", "", "", "", url)
            }
        }
    }

    @Test fun doesNotBlockUnrelatedEditsForUnchangedLegacyUrl() {
        val legacy = "http://legacy.example/scholarship"
        val values = AdminDraftEditRules.validate(
            "Scholarship", "University", "Japan", "", "", "", legacy, legacy
        )
        assertEquals(legacy, values.officialUrl)
    }

    @Test fun trimsRegionAndPreventsClearingPopulatedValue() {
        val populated = AdminDraftEditRules.validate(
            "Scholarship", "University", "Japan", "", "", region = "  East Asia  "
        )
        assertEquals("East Asia", populated.region)
        assertThrows(IllegalArgumentException::class.java) {
            AdminDraftEditRules.validate(
                "Scholarship", "University", "Japan", "", "",
                region = "", originalRegion = "East Asia"
            )
        }
        // Unchanged legacy blank regions must not prevent unrelated field edits.
        assertEquals("", AdminDraftEditRules.validate(
            "Scholarship", "University", "Japan", "", "",
            region = "", originalRegion = ""
        ).region)
    }

    @Test fun deadlineNotesCanBeEditedAndCleared() {
        val edited = AdminDraftEditRules.validate(
            "Scholarship", "University", "Japan", "", "",
            deadlineNotes = "  Deadline varies by program.  "
        )
        assertEquals("Deadline varies by program.", edited.deadlineNotes)
        val cleared = AdminDraftEditRules.validate(
            "Scholarship", "University", "Japan", "", "",
            deadlineNotes = "", originalDeadlineNotes = "Rolling admissions"
        )
        assertEquals("", cleared.deadlineNotes)
    }

    @Test fun deadlineNotesRejectOversizedChangesButPreserveUnchangedLegacyText() {
        val legacy = " x".repeat(1_100)
        assertThrows(IllegalArgumentException::class.java) {
            AdminDraftEditRules.validate(
                "Scholarship", "University", "Japan", "", "",
                deadlineNotes = legacy
            )
        }
        assertEquals(legacy, AdminDraftEditRules.validate(
            "Scholarship", "University", "Japan", "", "",
            deadlineNotes = legacy, originalDeadlineNotes = legacy
        ).deadlineNotes)
    }

    @Test fun descriptionCanBeEditedAndCleared() {
        val edited = AdminDraftEditRules.validate(
            "Scholarship", "University", "Japan", "", "",
            description = "  Supports innovative research.  "
        )
        assertEquals("Supports innovative research.", edited.description)
        val cleared = AdminDraftEditRules.validate(
            "Scholarship", "University", "Japan", "", "",
            description = "", originalDescription = "Previous description"
        )
        assertEquals("", cleared.description)
    }

    @Test fun descriptionRejectsOversizedChangesButPreservesLegacyText() {
        val legacy = "Research".repeat(600)
        assertThrows(IllegalArgumentException::class.java) {
            AdminDraftEditRules.validate(
                "Scholarship", "University", "Japan", "", "", description = legacy
            )
        }
        assertEquals(legacy, AdminDraftEditRules.validate(
            "Scholarship", "University", "Japan", "", "",
            description = legacy, originalDescription = legacy
        ).description)
    }

    @Test fun studyLevelsAreNormalizedAndDeduplicated() {
        val values = AdminDraftEditRules.validate(
            "Scholarship", "University", "Japan", "", "",
            degreeLevels = " Bachelor's, Master's, Bachelor's, PhD "
        )
        assertEquals(listOf("Bachelor's", "Master's", "PhD"), values.degreeLevels)
        assertEquals(emptyList<String>(), AdminDraftEditRules.validate(
            "Scholarship", "University", "Japan", "", "",
            degreeLevels = "", originalDegreeLevels = listOf("Bachelor's")
        ).degreeLevels)
    }

    @Test fun studyLevelsRejectOversizedChangesAndPreserveLegacyValues() {
        val legacy = listOf("Unusually long legacy level ".repeat(5))
        assertEquals(legacy, AdminDraftEditRules.validate(
            "Scholarship", "University", "Japan", "", "",
            degreeLevels = legacy.joinToString(", "), originalDegreeLevels = legacy
        ).degreeLevels)
        try {
            AdminDraftEditRules.validate("Scholarship", "University", "Japan", "", "",
                degreeLevels = "x".repeat(81))
            org.junit.Assert.fail("Oversized level should be rejected")
        } catch (_: IllegalArgumentException) { }
        try {
            AdminDraftEditRules.validate("Scholarship", "University", "Japan", "", "",
                degreeLevels = (1..13).joinToString(", ") { "Level$it" })
            org.junit.Assert.fail("Too many levels should be rejected")
        } catch (_: IllegalArgumentException) { }
    }

    @Test fun benefitsCanBeEditedAndCleared() {
        val edited = AdminDraftEditRules.validate(
            "Scholarship", "University", "Japan", "", "",
            tuitionCoverage = "  Full tuition  ", stipend = "  USD 1,000 monthly  "
        )
        assertEquals("Full tuition", edited.tuitionCoverage)
        assertEquals("USD 1,000 monthly", edited.stipend)
        val cleared = AdminDraftEditRules.validate(
            "Scholarship", "University", "Japan", "", "",
            tuitionCoverage = "", originalTuitionCoverage = "Full tuition",
            stipend = "", originalStipend = "USD 1,000 monthly"
        )
        assertEquals("", cleared.tuitionCoverage)
        assertEquals("", cleared.stipend)
    }

    @Test fun benefitsRejectOversizedEditsAndPreserveUnchangedLegacyValues() {
        val legacy = "Long funding detail ".repeat(20)
        val unchanged = AdminDraftEditRules.validate(
            "Scholarship", "University", "Japan", "", "",
            tuitionCoverage = legacy, originalTuitionCoverage = legacy,
            stipend = legacy, originalStipend = legacy
        )
        assertEquals(legacy, unchanged.tuitionCoverage)
        assertEquals(legacy, unchanged.stipend)
        assertThrows(IllegalArgumentException::class.java) {
            AdminDraftEditRules.validate("Scholarship", "University", "Japan", "", "",
                tuitionCoverage = "x".repeat(121))
        }
        assertThrows(IllegalArgumentException::class.java) {
            AdminDraftEditRules.validate("Scholarship", "University", "Japan", "", "",
                stipend = "x".repeat(121))
        }
    }

    @Test fun rejectsRegionOverLimit() {
        assertThrows(IllegalArgumentException::class.java) {
            AdminDraftEditRules.validate(
                "Scholarship", "University", "Japan", "", "", region = "x".repeat(121)
            )
        }
    }
}
