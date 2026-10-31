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
}
