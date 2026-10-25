package com.grantly.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CommunityUploadRulesTest {
    @Test fun recognizesJpegAndPngSignatures() {
        assertEquals(
            CommunityUploadRules.Format.JPEG,
            CommunityUploadRules.detect(byteArrayOf(0xff.toByte(), 0xd8.toByte(), 0xff.toByte(), 0x00))
        )
        assertEquals(
            CommunityUploadRules.Format.PNG,
            CommunityUploadRules.detect(byteArrayOf(137.toByte(), 80, 78, 71, 13, 10, 26, 10))
        )
    }

    @Test fun recognizesCommonMp4Brands() {
        for (brand in listOf("isom", "iso2", "mp41", "mp42", "avc1", "M4V ")) {
            val data = byteArrayOf(0, 0, 0, 24) + "ftyp".toByteArray() + brand.toByteArray()
            assertEquals(CommunityUploadRules.Format.MP4, CommunityUploadRules.detect(data))
        }
    }

    @Test fun rejectsRenamedOrTruncatedFiles() {
        assertNull(CommunityUploadRules.detect("video.mp4".toByteArray()))
        assertNull(CommunityUploadRules.detect("ftypisom".toByteArray()))
        assertNull(CommunityUploadRules.detect(byteArrayOf(0, 0, 0, 24) + "ftyp".toByteArray() + "evil".toByteArray()))
        assertNull(CommunityUploadRules.detect(byteArrayOf()))
    }

    @Test fun formatsHaveExpectedPrivateStorageMetadata() {
        assertEquals("video/mp4", CommunityUploadRules.Format.MP4.mimeType)
        assertEquals("video", CommunityUploadRules.Format.MP4.mediaType)
        assertEquals("mp4", CommunityUploadRules.Format.MP4.extension)
        assertEquals(6 * 1024 * 1024, CommunityUploadRules.maxBytes)
    }
}
