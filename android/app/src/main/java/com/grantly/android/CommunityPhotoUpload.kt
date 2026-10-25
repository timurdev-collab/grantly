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
import java.time.Instant
import java.util.UUID

/**
 * Bounded photo and small MP4 Community publishing, using the existing private social-media bucket
 * and social_posts RLS. No public URL, service-role key, or schema change is used.
 *
 * The upload is intentionally limited to JPEG/PNG/MP4 under 6 MiB. Larger media,
 * HEIC and long videos require a separate resumable uploader. Stories use
 * the same private upload path with the existing story expiry schema.
 */
internal object CommunityPhotoPublisher {
    private const val maxBytes = CommunityUploadRules.maxBytes

    suspend fun publish(context: Context, uri: Uri, caption: String, kind: String = "post", isVideo: Boolean = false) = withContext(Dispatchers.IO) {
        require(kind in setOf("post", "story", "short")) { "Unsupported Community post type." }
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
                throw IOException("Media posting is unavailable until your Community profile is visible.")
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
                    throw IOException("Choose a JPEG/PNG photo or MP4 video smaller than 6 MiB.")
                }
                output.write(buffer, 0, count)
            }
            output.toByteArray()
        } ?: throw IOException("Unable to read the selected photo.")
        if (bytes.isEmpty()) throw IOException("The selected photo is empty.")
        val format = CommunityUploadRules.detect(bytes)
            ?: throw IOException("Only JPEG/PNG photos and MP4 videos are supported.")
        if (!CommunityUploadRules.allows(kind, format)) {
            throw IOException("Community Shorts require an MP4 video.")
        }
        if (isVideo != (format == CommunityUploadRules.Format.MP4)) {
            throw IOException(if (isVideo) "Choose a valid MP4 video." else "Choose a JPEG or PNG photo.")
        }
        if (!isVideo) {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
            if (bounds.outWidth !in 1..20_000 || bounds.outHeight !in 1..20_000) {
                throw IOException("This photo could not be decoded safely.")
            }
        }

        val extension = format.extension
        val mime = format.mimeType
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
                    401, 403 -> "Media upload is not permitted for this account."
                    413 -> "This media exceeds the upload limit."
                    else -> "Media upload failed (HTTP " + status + ")."
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
                    .put("kind", kind)
                    .put("caption", text)
                    .put("media_path", path)
                    .put("media_type", format.mediaType)
                if (kind == "story") {
                    payload.put("expires_at", CommunityStoryRules.expirationForNewStory(Instant.now()))
                }
                post.outputStream.use { it.write(payload.toString().toByteArray(Charsets.UTF_8)) }
                val status = post.responseCode
                if (status !in 200..299) {
                    throw IOException(when (status) {
                        401, 403 -> "Posting is not permitted. Check Community profile visibility."
                        else -> "Media uploaded but the post could not be created (HTTP " + status + ")."
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
                throw IOException("Post creation failed and the private media could not be cleaned up. Contact support before retrying.", failure)
            }
            throw failure
        }
    }
}
