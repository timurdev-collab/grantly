package com.grantly.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import java.io.IOException
import java.io.StringReader

class AdvisorCallPreparationRulesTest {
    private val room = "grantly-0123456789abcdef0123456789abcdef"
    private val token = "eyJhbGciOiJIUzI1NiJ9.eyJyb29tIjoiZ3JhbnRseSJ9.signature123"

    @Test fun acceptsOnlySecureLiveKitCredentials() {
        val credentials = AdvisorCallPreparationRules.validate(
            "wss://calls.example.livekit.cloud", token, room
        )
        assertEquals("wss://calls.example.livekit.cloud", credentials.url)
        assertEquals(token, credentials.token)
        assertEquals(room, credentials.roomName)
    }

    @Test fun rejectsInsecureOrRedirectableEndpoints() {
        for (url in listOf(
            "http://calls.example.com", "https://calls.example.com",
            "ws://calls.example.com", "wss://user:pass@calls.example.com",
            "wss://calls.example.com?token=secret",
            "wss://calls.example.com/#fragment", "wss://calls.example.com/other",
            "wss://", "not a URL"
        )) {
            assertThrows(IOException::class.java) {
                AdvisorCallPreparationRules.validate(url, token, room)
            }
        }
    }

    @Test fun rejectsUnexpectedRoomsAndMalformedTokens() {
        for (badRoom in listOf("", "room-123", "grantly-123", "grantly-" + "g".repeat(32))) {
            assertThrows(IOException::class.java) {
                AdvisorCallPreparationRules.validate("wss://calls.example.com", token, badRoom)
            }
        }
        for (badToken in listOf("", "secret", "a.b", "a.b.c.d", "a.b.c?", "a".repeat(8193))) {
            assertThrows(IOException::class.java) {
                AdvisorCallPreparationRules.validate("wss://calls.example.com", badToken, room)
            }
        }
    }

    @Test fun rejectsChangedOrSignedOutAccounts() {
        AdvisorCallPreparationRules.requireSameAccount("account-a", "account-a")
        for (current in listOf("account-b", "", null)) {
            assertThrows(IOException::class.java) {
                AdvisorCallPreparationRules.requireSameAccount("account-a", current)
            }
        }
    }

    @Test fun validatesCallIdsAndBoundsResponses() {
        val callId = "AB12CD34-1234-4A5B-8C9D-ABCDEF123456"
        assertEquals(callId.lowercase(), AdvisorCallPreparationRules.validCallId(callId))
        assertThrows(IOException::class.java) {
            AdvisorCallPreparationRules.validCallId("not-a-uuid")
        }
        assertEquals("ok", AdvisorCallPreparationRules.readBounded(StringReader("ok")))
        assertEquals(32768,
            AdvisorCallPreparationRules.readBounded(StringReader("a".repeat(32768))).length)
        assertThrows(IOException::class.java) {
            AdvisorCallPreparationRules.readBounded(StringReader("a".repeat(32769)))
        }
    }

    @Test fun rejectsNonCanonicalCallIds() {
        for (invalid in listOf("1-1-1-1-1", " 01234567-1234-1234-1234-123456789abc",
            "01234567-1234-1234-1234-123456789abc ", "01234567123412341234123456789abc")) {
            assertThrows(IOException::class.java) {
                AdvisorCallPreparationRules.validCallId(invalid)
            }
        }
    }

    @Test fun requiresActiveRelationshipAndCallParticipant() {
        val callId = "01234567-1234-4abc-8def-0123456789ab"
        val assignmentId = "12345678-1234-4abc-8def-0123456789ab"
        val studentId = "23456789-1234-4abc-8def-0123456789ab"
        val advisorId = "34567890-1234-4abc-8def-0123456789ab"
        for (status in listOf("requested", "scheduled", "active")) {
            AdvisorCallPreparationRules.requireJoinableCall(
                callId, callId, status, assignmentId, assignmentId, "active",
                studentId, advisorId, studentId
            )
            AdvisorCallPreparationRules.requireJoinableCall(
                callId, callId, status, assignmentId, assignmentId, "active",
                studentId, advisorId, advisorId
            )
        }
        for (status in listOf("ended", "cancelled", "", "unknown")) {
            assertThrows(IOException::class.java) {
                AdvisorCallPreparationRules.requireJoinableCall(
                    callId, callId, status, assignmentId, assignmentId, "active",
                    studentId, advisorId, studentId
                )
            }
        }
        for (assignmentStatus in listOf("requested", "ended", "declined", "")) {
            assertThrows(IOException::class.java) {
                AdvisorCallPreparationRules.requireJoinableCall(
                    callId, callId, "active", assignmentId, assignmentId,
                    assignmentStatus, studentId, advisorId, studentId
                )
            }
        }
        for (badValue in listOf("00000000-1234-4abc-8def-0123456789ab", "")) {
            assertThrows(IOException::class.java) {
                AdvisorCallPreparationRules.requireJoinableCall(
                    callId, badValue, "active", assignmentId, assignmentId, "active",
                    studentId, advisorId, studentId
                )
            }
            assertThrows(IOException::class.java) {
                AdvisorCallPreparationRules.requireJoinableCall(
                    callId, callId, "active", assignmentId, badValue, "active",
                    studentId, advisorId, studentId
                )
            }
        }
        assertThrows(IOException::class.java) {
            AdvisorCallPreparationRules.requireJoinableCall(
                callId, callId, "active", assignmentId, assignmentId, "active",
                studentId, advisorId, "45678901-1234-4abc-8def-0123456789ab"
            )
        }
    }
}
