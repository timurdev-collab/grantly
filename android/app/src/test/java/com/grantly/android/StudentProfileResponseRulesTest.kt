package com.grantly.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import java.io.IOException
import java.io.StringReader

class StudentProfileResponseRulesTest {
    @Test fun allowsOnlyCurrentAccount() {
        StudentProfileResponseRules.requireSameAccount("student-a", "student-a")
        for (current in listOf("student-b", "", null)) {
            assertThrows(IOException::class.java) {
                StudentProfileResponseRules.requireSameAccount("student-a", current)
            }
        }
    }

    @Test fun acceptsResponseAtSizeLimit() {
        val response = "x".repeat(StudentProfileResponseRules.MAX_CHARS)
        assertEquals(response, StudentProfileResponseRules.readBounded(StringReader(response)))
    }

    @Test fun rejectsOversizedPrivateProfileResponse() {
        assertThrows(IOException::class.java) {
            StudentProfileResponseRules.readBounded(
                StringReader("x".repeat(StudentProfileResponseRules.MAX_CHARS + 1))
            )
        }
    }

    @Test fun acceptsEmptyProfileResponse() {
        assertEquals("", StudentProfileResponseRules.readBounded(StringReader("")))
    }
}
