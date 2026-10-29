package com.grantly.android

import org.junit.Assert.assertEquals
import org.junit.Test

class AdminAdvisorMediaRulesTest {
    private val advisorId = "00000000-0000-0000-0000-000000000001"
    private val base = "https://example.supabase.co"

    @Test fun privateMediaPathMustBelongToSelectedAdvisor() {
        assertEquals(
            "$advisorId/intro/video%20one.mp4",
            AdminAdvisorMediaRules.encodedStoragePath(advisorId, "$advisorId/intro/video one.mp4")
        )
        assertEquals(null, AdminAdvisorMediaRules.encodedStoragePath(
            advisorId, "00000000-0000-0000-0000-000000000002/intro/video.mp4"
        ))
        assertEquals(null, AdminAdvisorMediaRules.encodedStoragePath(advisorId, "../video.mp4"))
        assertEquals(null, AdminAdvisorMediaRules.encodedStoragePath(advisorId, "$advisorId/../video.mp4"))
        assertEquals(null, AdminAdvisorMediaRules.encodedStoragePath(advisorId, "$advisorId/intro/"))
        assertEquals(null, AdminAdvisorMediaRules.encodedStoragePath(advisorId, "$advisorId/intro\\video.mp4"))
        assertEquals(null, AdminAdvisorMediaRules.encodedStoragePath(advisorId, "$advisorId/intro/video.mp4?token=x"))
    }


    @Test fun advisorAvatarUsesTheSamePrivateObjectChecksAsIntroVideo() {
        val avatarPath = "$advisorId/avatar/headshot 2026.jpg"
        val encoded = AdminAdvisorMediaRules.encodedStoragePath(advisorId, avatarPath)
        assertEquals("$advisorId/avatar/headshot%202026.jpg", encoded)
        val signed = "$base/storage/v1/object/sign/advisor-media/$encoded?token=abc"
        assertEquals(signed, AdminAdvisorMediaRules.signedUrlForPath(base, signed, encoded!!))
        assertEquals(null, AdminAdvisorMediaRules.signedUrlForPath(
            base, "$base/storage/v1/object/sign/advisor-media/$advisorId/avatar/other.jpg?token=abc",
            encoded
        ))
        assertEquals(null, AdminAdvisorMediaRules.encodedStoragePath(
            advisorId, "00000000-0000-0000-0000-000000000002/avatar/headshot.jpg"
        ))
    }

    @Test fun signedMediaUrlMustMatchTheExactRequestedObject() {
        val requested = "$advisorId/intro/video%20one.mp4"
        val signed = "$base/storage/v1/object/sign/advisor-media/$requested?token=abc"
        assertEquals(signed, AdminAdvisorMediaRules.signedUrlForPath(
            base, signed, requested
        ))
        assertEquals(signed, AdminAdvisorMediaRules.signedUrlForPath(
            base, "/object/sign/advisor-media/$requested?token=abc", requested
        ))
        assertEquals(null, AdminAdvisorMediaRules.signedUrlForPath(
            base, "$base/storage/v1/object/sign/advisor-media/$advisorId/intro/other.mp4?token=abc",
            requested
        ))
        assertEquals(null, AdminAdvisorMediaRules.signedUrlForPath(
            base, "$base/storage/v1/object/sign/advisor-media/00000000-0000-0000-0000-000000000002/intro/video%20one.mp4?token=abc",
            requested
        ))
        assertEquals(null, AdminAdvisorMediaRules.signedUrlForPath(
            base, "$base/storage/v1/object/sign/advisor-media/$advisorId/intro%2Fvideo%20one.mp4?token=abc",
            requested
        ))
        assertEquals(null, AdminAdvisorMediaRules.signedUrlForPath(
            base, signed, "../$requested"
        ))
        assertEquals(null, AdminAdvisorMediaRules.signedUrlForPath(
            base, signed, "$requested?token=abc"
        ))
    }

    @Test fun signedMediaUrlMustStayOnConfiguredStorageOrigin() {
        val expected = "$base/storage/v1/object/sign/advisor-media/$advisorId/intro/video.mp4?token=abc"
        assertEquals(expected, AdminAdvisorMediaRules.signedUrl(
            base, "/object/sign/advisor-media/$advisorId/intro/video.mp4?token=abc"
        ))
        assertEquals(expected, AdminAdvisorMediaRules.signedUrl(base, expected))
        assertEquals(null, AdminAdvisorMediaRules.signedUrl(
            base, "https://evil.example/storage/v1/object/sign/advisor-media/a?token=abc"
        ))
        assertEquals(null, AdminAdvisorMediaRules.signedUrl(
            base, "/object/sign/other-bucket/file.mp4?token=abc"
        ))
        assertEquals(null, AdminAdvisorMediaRules.signedUrl(
            base, "/object/sign/advisor-media/$advisorId/video.mp4"
        ))
        assertEquals(null, AdminAdvisorMediaRules.signedUrl(
            base, "https://example.supabase.co.evil.example/storage/v1/object/sign/advisor-media/a?token=abc"
        ))
        assertEquals(null, AdminAdvisorMediaRules.signedUrl(base, "javascript:alert(1)"))
    }
}
