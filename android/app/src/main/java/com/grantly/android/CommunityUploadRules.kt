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

        // MP4 is an ISO base-media container. A filename or provider MIME alone
        // is not sufficient to authorize uploading a file as video/mp4.
        if (bytes.size >= 12 &&
            String(bytes, 4, 4, Charsets.US_ASCII) == "ftyp" &&
            String(bytes, 8, 4, Charsets.US_ASCII) in setOf(
                "isom", "iso2", "iso3", "iso4", "iso5", "iso6",
                "mp41", "mp42", "avc1", "M4V "
            )
        ) return Format.MP4

        return null
    }
}
