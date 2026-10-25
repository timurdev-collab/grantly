package com.grantly.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AuthValidationTest {
    @Test fun normalizesEmailLikeIos() {
        assertEquals("student@example.com", AuthValidation.normalizedEmail("  Student@Example.COM  "))
    }

    @Test fun acceptsValidAddressesAfterTrimming() {
        assertTrue(AuthValidation.isValidEmail("  Student@Example.COM  "))
        assertTrue(AuthValidation.isValidEmail("a@university.edu"))
        assertTrue(AuthValidation.isValidEmail("name+tag@school.ac.kr"))
    }

    @Test fun rejectsInvalidEmailShapes() {
        listOf(
            "", " ", "plainaddress", "@example.com", "student@", "student@example",
            "student@.example.com", "student@example.com.", "student @example.com",
            "student@example .com"
        ).forEach { assertFalse("Unexpectedly valid: $it", AuthValidation.isValidEmail(it)) }
    }

    @Test fun rejectsEmailsLongerThan254Characters() {
        val email = "a".repeat(243) + "@example.com" // 255 characters
        assertEquals(255, email.length)
        assertFalse(AuthValidation.isValidEmail(email))
    }

    @Test fun passwordLengthBoundariesMatchIos() {
        assertEquals("Use at least 8 characters.", AuthValidation.passwordIssue("a".repeat(7)))
        assertNull(AuthValidation.passwordIssue("a".repeat(8)))
        assertNull(AuthValidation.passwordIssue("a".repeat(128)))
        assertEquals("Password is too long.", AuthValidation.passwordIssue("a".repeat(129)))
    }
}
