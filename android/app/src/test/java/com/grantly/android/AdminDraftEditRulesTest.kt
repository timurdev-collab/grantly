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
}
