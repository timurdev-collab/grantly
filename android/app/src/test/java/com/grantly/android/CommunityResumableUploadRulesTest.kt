package com.grantly.android

import org.junit.Assert.*
import org.junit.Test
import java.util.Base64

class CommunityResumableUploadRulesTest {
    private val rules = CommunityResumableUploadRules

    @Test fun videoSizeBoundaries() {
        assertFalse(rules.allowsVideoSize(0))
        assertTrue(rules.allowsVideoSize(1))
        assertTrue(rules.allowsVideoSize(rules.maxVideoBytes))
        assertFalse(rules.allowsVideoSize(rules.maxVideoBytes + 1))
        assertEquals(6 * 1024 * 1024, rules.chunkBytes)
    }

    @Test fun progressIsBoundedAndRejectsInvalidOffsets() {
        assertEquals(0f, rules.progressFraction(0, 200)!!, 0.0001f)
        assertEquals(0.5f, rules.progressFraction(100, 200)!!, 0.0001f)
        assertEquals(1f, rules.progressFraction(200, 200)!!, 0.0001f)
        assertNull(rules.progressFraction(-1, 200))
        assertNull(rules.progressFraction(201, 200))
        assertNull(rules.progressFraction(0, 0))
        assertNull(rules.progressFraction(1, -1))
    }

    @Test fun onlyTrustedSupabaseTusEndpoint() {
        val expected = "https://project-123.storage.supabase.co/storage/v1/upload/resumable"
        assertEquals(expected, rules.endpoint("https://project-123.supabase.co"))
        assertEquals(expected, rules.endpoint("https://project-123.supabase.co/"))
        for (url in listOf(
            "http://project-123.supabase.co",
            "https://project-123.supabase.co.evil.example",
            "https://project-123.supabase.co@evil.example",
            "https://project-123.supabase.co:8443",
            "https://foo.bar.supabase.co",
            "https://project-123.supabase.co/path",
            "https://project-123.supabase.co/?redirect=1",
            "invalid"
        )) assertNull(url, rules.endpoint(url))
    }

    @Test fun rejectUntrustedUploadLocation() {
        val base = rules.endpoint("https://project-123.supabase.co")!!
        val valid = "$base/upload-token"
        assertEquals(valid, rules.trustedUploadLocation(base, valid))
        assertEquals(valid, rules.trustedUploadLocation(base, "resumable/upload-token"))
        for (location in listOf(
            "https://evil.example/storage/v1/upload/resumable/steal",
            "//evil.example/storage/v1/upload/resumable/steal",
            "http://project-123.storage.supabase.co/storage/v1/upload/resumable/token",
            "$base",
            "$base/../private/token",
            "$base/%2e%2e/private/token",
            "$base/token%2fextra",
            "$base/token?token=secret",
            "$base/token#fragment"
        )) assertNull(location, rules.trustedUploadLocation(base, location))
    }

    @Test fun metadataContainsOnlyExpectedFields() {
        val path = "00000000-0000-4000-8000-000000000001/00000000-0000-4000-8000-000000000002.mp4"
        val values = rules.metadata(path).split(",").associate { item ->
            val pair = item.split(" ", limit = 2)
            pair[0] to String(Base64.getDecoder().decode(pair[1]), Charsets.UTF_8)
        }
        assertEquals(
            mapOf("bucketName" to "social-media", "objectName" to path,
                "contentType" to "video/mp4", "cacheControl" to "3600"), values
        )
        for (bad in listOf("../outside.mp4", "a/b.mp4", "$path/extra", path.removeSuffix(".mp4") + ".png")) {
            try {
                rules.metadata(bad)
                fail("Accepted unsafe path: $bad")
            } catch (_: IllegalArgumentException) { }
        }
    }

    @Test fun chunkAcknowledgementCannotSkipUnsentBytes() {
        assertEquals(6L, rules.chunkOffset(0, "6", 20, 6))
        assertEquals(20L, rules.chunkOffset(14, "20", 20, 6))
        assertNull(rules.chunkOffset(0, "7", 20, 6))
        assertNull(rules.chunkOffset(0, "6", 20, 0))
        assertNull(rules.chunkOffset(0, "0", 20, 6))
        assertNull(rules.chunkOffset(0, "21", 20, 6))
        assertNull(rules.chunkOffset(-1, "2", 20, 6))
        assertNull(rules.chunkOffset(20, "21", 20, 6))
        assertNull(rules.chunkOffset(0, "not-an-offset", 20, 6))
    }

    @Test fun patchOffsetMustAdvanceWithinFile() {
        assertEquals(6L, rules.acknowledgedOffset(0, "6", 10))
        assertEquals(10L, rules.acknowledgedOffset(6, "10", 10))
        for (header in listOf(null, "", "0", "-1", "11", "nan")) {
            assertNull(rules.acknowledgedOffset(0, header, 10))
        }
        assertNull(rules.acknowledgedOffset(6, "6", 10))
        assertNull(rules.acknowledgedOffset(-1, "1", 10))
    }
}
