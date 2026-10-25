package com.grantly.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CommunityUploadRulesTest {
    private fun mp4Box(
        majorBrand: String,
        compatibleBrands: List<String> = emptyList(),
        declaredSize: Int? = null
    ): ByteArray {
        require(majorBrand.length == 4 && compatibleBrands.all { it.length == 4 })
        val size = declaredSize ?: (16 + 4 * compatibleBrands.size)
        return byteArrayOf(
            (size ushr 24).toByte(),
            (size ushr 16).toByte(),
            (size ushr 8).toByte(),
            size.toByte()
        ) + "ftyp".toByteArray(Charsets.US_ASCII) +
            majorBrand.toByteArray(Charsets.US_ASCII) +
            byteArrayOf(0, 0, 0, 0) +
            compatibleBrands.flatMap { it.toByteArray(Charsets.US_ASCII).toList() }.toByteArray()
    }

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
            assertEquals(CommunityUploadRules.Format.MP4, CommunityUploadRules.detect(mp4Box(brand)))
        }
    }

    @Test fun recognizesCompatibleBrandWhenMajorBrandIsDifferent() {
        assertEquals(
            CommunityUploadRules.Format.MP4,
            CommunityUploadRules.detect(mp4Box("test", listOf("abcd", "mp42")))
        )
    }

    @Test fun rejectsRenamedTruncatedOrMalformedMp4Boxes() {
        assertNull(CommunityUploadRules.detect("video.mp4".toByteArray()))
        assertNull(CommunityUploadRules.detect("ftypisom".toByteArray()))
        assertNull(CommunityUploadRules.detect(mp4Box("mp42").copyOf(12)))
        assertNull(CommunityUploadRules.detect(mp4Box("evil")))
        assertNull(CommunityUploadRules.detect(mp4Box("mp42", declaredSize = 0)))
        assertNull(CommunityUploadRules.detect(mp4Box("mp42", declaredSize = 1)))
        assertNull(CommunityUploadRules.detect(mp4Box("mp42", declaredSize = 15)))
        assertNull(CommunityUploadRules.detect(mp4Box("mp42", declaredSize = 17)))
        assertNull(CommunityUploadRules.detect(mp4Box("mp42", declaredSize = 100)))
        assertNull(CommunityUploadRules.detect(byteArrayOf()))
    }

    @Test fun formatsHaveExpectedPrivateStorageMetadata() {
        assertEquals("video/mp4", CommunityUploadRules.Format.MP4.mimeType)
        assertEquals("video", CommunityUploadRules.Format.MP4.mediaType)
        assertEquals("mp4", CommunityUploadRules.Format.MP4.extension)
        assertEquals(6 * 1024 * 1024, CommunityUploadRules.maxBytes)
    }
}
