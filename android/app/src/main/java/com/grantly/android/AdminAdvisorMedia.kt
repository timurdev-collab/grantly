package com.grantly.android

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL
import java.net.URLEncoder
import java.util.UUID

/** Resolves private advisor-media only through the authenticated Supabase signing endpoint. */
internal object AdminAdvisorMediaRules {
    fun encodedStoragePath(advisorId: String, path: String): String? {
        if (runCatching { UUID.fromString(advisorId) }.isFailure ||
            path.length !in 1..500 || path.any { it == '\\' || it == '?' || it == '#' || it.code < 32 }) {
            return null
        }
        val segments = path.split('/')
        if (segments.size < 2 || segments.first() != advisorId ||
            segments.any { it.isBlank() || it == "." || it == ".." }) return null
        return segments.joinToString("/") {
            URLEncoder.encode(it, "UTF-8").replace("+", "%20")
        }
    }

    fun signedUrl(base: String, raw: String): String? {
        val prefix = "/storage/v1/object/sign/advisor-media/"
        val value = raw.trim()
        val candidate = when {
            value.startsWith("/object/sign/advisor-media/") -> base.trimEnd('/') + "/storage/v1" + value
            value.startsWith(prefix) -> base.trimEnd('/') + value
            value.startsWith("https://", ignoreCase = true) -> value
            else -> return null
        }
        return runCatching {
            val root = URI(base.trimEnd('/'))
            val signed = URI(candidate)
            if (!signed.scheme.equals("https", ignoreCase = true) ||
                signed.host != root.host || signed.port != root.port ||
                signed.userInfo != null || signed.fragment != null ||
                !signed.rawPath.startsWith(prefix) ||
                signed.rawQuery?.split('&')?.none { it.startsWith("token=") && it.length > 6 } != false) {
                null
            } else signed.toASCIIString()
        }.getOrNull()
    }

    /** A signed link must resolve to the exact media object requested, not merely its bucket. */
    fun signedUrlForPath(base: String, raw: String, expectedEncodedPath: String): String? {
        if (expectedEncodedPath.isBlank() || expectedEncodedPath.startsWith('/') ||
            expectedEncodedPath.contains('?') || expectedEncodedPath.contains('#')) return null
        val url = signedUrl(base, raw) ?: return null
        return runCatching {
            if (URI(url).rawPath ==
                "/storage/v1/object/sign/advisor-media/$expectedEncodedPath") url else null
        }.getOrNull()
    }
}

internal object AdminAdvisorMediaRepository {
    suspend fun signedIntroVideoUrl(adminId: String, application: AdminAdvisorApplication): String =
        signedMediaUrl(adminId, application, application.introVideoStoragePath)

    suspend fun signedAvatarUrl(adminId: String, application: AdminAdvisorApplication): String =
        signedMediaUrl(adminId, application, application.avatarStoragePath)

    /** Apply identical ownership, role and signed-object checks to video and photo. */
    private suspend fun signedMediaUrl(
        adminId: String,
        application: AdminAdvisorApplication,
        storagePath: String
    ): String =
        withContext(Dispatchers.IO) {
            val encoded = AdminAdvisorMediaRules.encodedStoragePath(
                application.id, storagePath
            ) ?: throw IOException("The advisor media has an invalid storage path.")
            val session = AuthRepository.activeSession()
            if (session.userId != adminId || AuthRepository.session?.userId != adminId ||
                StudentProfileRepository.load().role != "admin") {
                throw IOException("Administrator access is required.")
            }
            val base = BuildConfig.SUPABASE_URL.trimEnd('/')
            val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
            if (!base.startsWith("https://") || key.isBlank()) {
                throw IOException("Advisor media service is not configured.")
            }
            val connection = URL("$base/storage/v1/object/sign/advisor-media/$encoded")
                .openConnection() as HttpURLConnection
            try {
                connection.requestMethod = "POST"
                connection.instanceFollowRedirects = false
                connection.connectTimeout = 12_000
                connection.readTimeout = 20_000
                connection.doOutput = true
                connection.setRequestProperty("apikey", key)
                connection.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
                connection.setRequestProperty("Content-Type", "application/json")
                connection.setRequestProperty("Accept", "application/json")
                connection.outputStream.use {
                    it.write(JSONObject().put("expiresIn", 3600).toString().toByteArray(Charsets.UTF_8))
                }
                val code = connection.responseCode
                if (code !in 200..299) {
                    throw IOException(if (code == 401 || code == 403)
                        "You do not have permission to view this introduction video."
                    else "Unable to open introduction video (HTTP $code).")
                }
                val response = connection.inputStream.bufferedReader(Charsets.UTF_8).use { reader ->
                    val buffer = CharArray(1024)
                    val result = StringBuilder()
                    while (true) {
                        val count = reader.read(buffer)
                        if (count < 0) break
                        if (result.length + count > 8192) throw IOException("Invalid media link response.")
                        result.append(buffer, 0, count)
                    }
                    result.toString()
                }
                if (AuthRepository.session?.userId != adminId) {
                    throw IOException("Your account changed. Please reload.")
                }
                val json = JSONObject(response)
                val raw = json.optString("signedURL").ifBlank { json.optString("signedUrl") }
                AdminAdvisorMediaRules.signedUrlForPath(base, raw, encoded)
                    ?: throw IOException("The media service returned an invalid secure link.")
            } finally {
                connection.disconnect()
            }
        }
}
