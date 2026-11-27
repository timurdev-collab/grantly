package com.grantly.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AdvisorIntroductionUrlTest {
    @Test fun acceptsTrustedHttpsYoutubeLinks() {
        listOf(
            "https://www.youtube.com/watch?v=example",
            "https://youtu.be/example",
            "https://m.youtube.com/watch?v=example",
            "https://youtube.com:443/watch?v=example"
        ).forEach { url ->
            assertEquals(url, AdvisorProfessionalProfileRules.youtubeIntroduction("  $url  "))
        }
    }

    @Test fun rejectsUntrustedOrMalformedLinks() {
        listOf(
            "", "not a URL", "http://youtube.com/watch?v=example",
            "https://youtube.com.evil.example/watch",
            "https://evil.example/?youtube.com",
            "https://youtube.com@evil.example/watch",
            "https://evil.example@youtube.com/watch",
            "https://youtube.com:8443/watch",
            "javascript:alert(1)", "//youtube.com/watch",
            "https://youtube.com/watch?v=bad value"
        ).forEach { url ->
            assertNull(url, AdvisorProfessionalProfileRules.youtubeIntroduction(url))
        }
    }
}
