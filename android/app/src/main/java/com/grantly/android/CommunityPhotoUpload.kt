package com.grantly.android

import android.content.Context
import android.graphics.BitmapFactory
import android.net.Uri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

/**
 * Single-photo Community publishing, using the existing private social-media bucket
 * and social_posts RLS. No public URL, service-role key, or schema change is used.
 *
 * The upload is intentionally limited to JPEG/PNG under 6 MiB. Larger photos,
 * HEIC, video and stories require separate, tested implementations.
 */
internal object CommunityPhotoPublisher {
    private const val maxBytes = 6 * 1024 * 1024

    suspend fun publish(context: Context, uri: Uri, caption: String) = withContext(Dispatchers.IO) {
        val text = caption.trim()
        require(text.length <= 2000) { "Use at most 2,000 characters." }
        val session = AuthRepository.activeSession()
        val userId = try {
            UUID.fromString(session.userId).toString()
        } catch (_: IllegalArgumentException) {
            throw IOException("Invalid account. Sign in again.")
        }
        val base = BuildConfig.SUPABASE_URL.trimEnd('/')
        val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
        if (!base.startsWith("https://") || key.isBlank()) {
            throw IOException("Community service is not configured.")
        }

        // A previous release intentionally hid Community profiles. Avoid uploading
        // an orphan file when this account is not currently allowed to post.
        val profile = URL(base + "/rest/v1/community_profiles?select=is_visible&id=eq." +
            userId + "&limit=1").openConnection() as HttpURLConnection
        try {
            profile.requestMethod = "GET"
            profile.connectTimeout = 12_000
            profile.readTimeout = 15_000
            profile.setRequestProperty("apikey", key)
            profile.setRequestProperty("Authorization", "Bearer " + session.accessToken)
            profile.setRequestProperty("Accept", "application/json")
            val status = profile.responseCode
            if (status !in 200..299) {
                throw IOException(if (status == 401 || status == 403)
                    "Sign in again to access Community."
                else "Could not check Community posting permission (HTTP " + status + ").")
            }
            val rows = JSONArray(profile.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() })
            if (rows.length() != 1 || !rows.optJSONObject(0).optBoolean("is_visible", false)) {
                throw IOException("Photo posting is unavailable until your Community profile is visible.")
            }
        } finally {
            profile.disconnect()
        }

        // Content providers may not report a trustworthy file size or MIME type.
        // Read a bounded stream and identify the image from its actual signature.
        val bytes = context.contentResolver.openInputStream(uri)?.use { stream ->
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            while (true) {
                val count = stream.read(buffer)
                if (count < 0) break
                if (output.size() + count > maxBytes) {
                    throw IOException("Choose a JPEG or PNG photo smaller than 6 MB.")
                }
                output.write(buffer, 0, count)
            }
            output.toByteArray()
        } ?: throw IOException("Unable to read the selected photo.")
        if (bytes.isEmpty()) throw IOException("The selected photo is empty.")
        val jpeg = bytes.size >= 3 &&
            (bytes[0].toInt() and 255) == 255 &&
            (bytes[1].toInt() and 255) == 216 &&
            (bytes[2].toInt() and 255) == 255
        val pngHeader = byteArrayOf(137.toByte(), 80, 78, 71, 13, 10, 26, 10)
        val png = bytes.size >= pngHeader.size &&
            pngHeader.indices.all { bytes[it] == pngHeader[it] }
        if (!jpeg && !png) throw IOException("Only JPEG and PNG photos are supported.")
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        if (bounds.outWidth !in 1..20_000 || bounds.outHeight !in 1..20_000) {
            throw IOException("This photo could not be decoded safely.")
        }

        val extension = if (png) "png" else "jpg"
        val mime = if (png) "image/png" else "image/jpeg"
        val path = userId + "/" + UUID.randomUUID().toString() + "." + extension
        val storage = URL(base + "/storage/v1/object/social-media/" + path)
            .openConnection() as HttpURLConnection
        try {
            storage.requestMethod = "POST"
            storage.connectTimeout = 12_000
            storage.readTimeout = 30_000
            storage.doOutput = true
            storage.instanceFollowRedirects = false
            storage.setFixedLengthStreamingMode(bytes.size)
            storage.setRequestProperty("apikey", key)
            storage.setRequestProperty("Authorization", "Bearer " + session.accessToken)
            storage.setRequestProperty("Content-Type", mime)
            storage.setRequestProperty("x-upsert", "false")
            storage.outputStream.use { it.write(bytes) }
            val status = storage.responseCode
            if (status !in 200..299) {
                throw IOException(when (status) {
                    401, 403 -> "Photo upload is not permitted for this account."
                    413 -> "This photo exceeds the upload limit."
                    else -> "Photo upload failed (HTTP " + status + ")."
                })
            }
        } finally {
            storage.disconnect()
        }

        try {
            val post = URL(base + "/rest/v1/social_posts")
                .openConnection() as HttpURLConnection
            try {
                post.requestMethod = "POST"
                post.connectTimeout = 12_000
                post.readTimeout = 15_000
                post.doOutput = true
                post.instanceFollowRedirects = false
                post.setRequestProperty("apikey", key)
                post.setRequestProperty("Authorization", "Bearer " + session.accessToken)
                post.setRequestProperty("Content-Type", "application/json")
                post.setRequestProperty("Accept", "application/json")
                post.setRequestProperty("Prefer", "return=minimal")
                val payload = JSONObject()
                    .put("author_id", userId)
                    .put("kind", "post")
                    .put("caption", text)
                    .put("media_path", path)
                    .put("media_type", "image")
                post.outputStream.use { it.write(payload.toString().toByteArray(Charsets.UTF_8)) }
                val status = post.responseCode
                if (status !in 200..299) {
                    throw IOException(when (status) {
                        401, 403 -> "Posting is not permitted. Check Community profile visibility."
                        else -> "Photo uploaded but the post could not be created (HTTP " + status + ")."
                    })
                }
            } finally {
                post.disconnect()
            }
        } catch (failure: Exception) {
            // Match iOS storage rollback when inserting the post fails.
            // Report failed cleanup rather than silently leaving a private orphan.
            val cleaned = try {
                val cleanup = URL(base + "/storage/v1/object/social-media")
                    .openConnection() as HttpURLConnection
                try {
                    cleanup.requestMethod = "DELETE"
                    cleanup.connectTimeout = 12_000
                    cleanup.readTimeout = 15_000
                    cleanup.doOutput = true
                    cleanup.instanceFollowRedirects = false
                    cleanup.setRequestProperty("apikey", key)
                    cleanup.setRequestProperty("Authorization", "Bearer " + session.accessToken)
                    cleanup.setRequestProperty("Content-Type", "application/json")
                    val payload = JSONObject().put("prefixes", JSONArray().put(path))
                    cleanup.outputStream.use { it.write(payload.toString().toByteArray(Charsets.UTF_8)) }
                    cleanup.responseCode in 200..299
                } finally {
                    cleanup.disconnect()
                }
            } catch (_: Exception) { false }
            if (!cleaned) {
                throw IOException("Post creation failed and the private photo could not be cleaned up. Contact support before retrying.", failure)
            }
            throw failure
        }
    }
}
