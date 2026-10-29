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
