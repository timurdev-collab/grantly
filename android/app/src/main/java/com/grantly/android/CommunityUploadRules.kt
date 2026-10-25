package com.grantly.android

/** Signature-based validation for bounded Community media uploads. */
internal object CommunityUploadRules {
    const val maxBytes = 6 * 1024 * 1024

    enum class Format(val extension: String, val mimeType: String, val mediaType: String) {
        JPEG("jpg", "image/jpeg", "image"),
        PNG("png", "image/png", "image"),
        MP4("mp4", "video/mp4", "video")
    }

    fun detect(bytes: ByteArray): Format? {
        if (bytes.size >= 3 &&
            (bytes[0].toInt() and 0xff) == 0xff &&
            (bytes[1].toInt() and 0xff) == 0xd8 &&
            (bytes[2].toInt() and 0xff) == 0xff
        ) return Format.JPEG

        val pngHeader = byteArrayOf(137.toByte(), 80, 78, 71, 13, 10, 26, 10)
        if (bytes.size >= pngHeader.size &&
            pngHeader.indices.all { bytes[it] == pngHeader[it] }
        ) return Format.PNG

        // ISO base media: verify the complete ftyp box rather than trusting
        // only its first 12 bytes. The box includes a size, major brand, minor
        // version and optional compatible brands. This is still a container
        // signature check, not proof that the video can be decoded.
        if (bytes.size >= 16 && String(bytes, 4, 4, Charsets.US_ASCII) == "ftyp") {
            val boxSize = (0..3).fold(0L) { size, index ->
                (size shl 8) or (bytes[index].toLong() and 0xffL)
            }
            if (boxSize >= 16 && boxSize <= bytes.size && (boxSize - 16) % 4 == 0L) {
                val supportedBrands = setOf(
                    "isom", "iso2", "iso3", "iso4", "iso5", "iso6",
                    "mp41", "mp42", "avc1", "M4V "
                )
                if (String(bytes, 8, 4, Charsets.US_ASCII) in supportedBrands) {
                    return Format.MP4
                }
                var offset = 16
                while (offset + 4 <= boxSize.toInt()) {
                    if (String(bytes, offset, 4, Charsets.US_ASCII) in supportedBrands) {
                        return Format.MP4
                    }
                    offset += 4
                }
            }
        }

        return null
    }
}
