package com.grantly.android

import java.net.URI
import java.util.Base64
import java.util.UUID

/**
 * Pure validation/metadata helpers for a future bounded TUS video uploader.
 *
 * Not yet wired into Community publishing: the existing 6 MiB direct uploader
 * remains the only enabled Android upload path.
 */
internal object CommunityResumableUploadRules {
    const val chunkBytes = 6 * 1024 * 1024
    const val maxVideoBytes = 200 * 1024 * 1024L

    fun allowsVideoSize(bytes: Long): Boolean = bytes in 1..maxVideoBytes

    /**
     * Construct only the expected Supabase Storage TUS origin.
     * Never send bearer tokens to a redirect or an arbitrary upload URL.
     */
    fun endpoint(supabaseUrl: String): String? {
        val uri = try { URI(supabaseUrl) } catch (_: Exception) { return null }
        val host = uri.host ?: return null
        if (uri.scheme != "https" || uri.userInfo != null || uri.port != -1 ||
            uri.rawQuery != null || uri.rawFragment != null ||
            (uri.path != "" && uri.path != "/") ||
            !host.matches(Regex("[a-z0-9-]+\\.supabase\\.co"))
        ) return null
        val project = host.removeSuffix(".supabase.co")
        if (project.isBlank()) return null
        return "https://$project.storage.supabase.co/storage/v1/upload/resumable"
    }

    /** Only accept a TUS Location that resolves to the trusted upload origin/path. */
    fun trustedUploadLocation(endpoint: String, location: String?): String? {
        if (location.isNullOrBlank()) return null
        return try {
            val base = URI(endpoint)
            val resolved = base.resolve(location)
            if (resolved.scheme != "https" || resolved.host != base.host ||
                resolved.port != -1 || resolved.userInfo != null ||
                resolved.rawFragment != null || resolved.rawQuery != null ||
                !resolved.path.startsWith("/storage/v1/upload/resumable/") ||
                resolved.path.removePrefix("/storage/v1/upload/resumable/").isBlank()
            ) null else resolved.toASCIIString()
        } catch (_: Exception) { null }
    }

    fun metadata(path: String): String {
        val parts = path.split("/")
        require(parts.size == 2 && parts[1].endsWith(".mp4"))
        val user = parts[0]
        val file = parts[1].removeSuffix(".mp4")
        require(UUID.fromString(user).toString() == user &&
            UUID.fromString(file).toString() == file) {
            "Invalid private Community media path."
        }
        fun pair(key: String, value: String): String =
            "$key ${Base64.getEncoder().encodeToString(value.toByteArray(Charsets.UTF_8))}"
        return listOf(
            pair("bucketName", "social-media"),
            pair("objectName", path),
            pair("contentType", "video/mp4"),
            pair("cacheControl", "3600")
        ).joinToString(",")
    }

    /** PATCH must acknowledge positive progress without exceeding the file length. */
    fun acknowledgedOffset(previous: Long, header: String?, fileSize: Long): Long? {
        val offset = header?.toLongOrNull() ?: return null
        return offset.takeIf { previous >= 0 && previous < it && it <= fileSize }
    }
}
