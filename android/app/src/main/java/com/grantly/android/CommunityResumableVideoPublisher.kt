package com.grantly.android

import android.content.Context
import android.net.Uri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.DataInputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.io.RandomAccessFile
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant
import java.util.UUID

/** Private 200 MiB bounded MP4 uploads through the existing Supabase Storage TUS API. */
internal object CommunityResumableVideoPublisher {
    suspend fun publish(
        context: Context, uri: Uri, caption: String, kind: String,
        userId: String, accessToken: String, key: String, base: String,
        onProgress: suspend (Long, Long) -> Unit = { _, _ -> }
    ) = withContext(Dispatchers.IO) {
        require(kind in setOf("post", "story", "short"))
        val endpoint = CommunityResumableUploadRules.endpoint(base)
            ?: throw IOException("A trusted Community upload endpoint is not configured.")
        val staged = File.createTempFile("edut-community-", ".mp4", context.cacheDir)
        try {
            val fileSize = stageVideo(context, uri, staged)
            onProgress(0L, fileSize)
            val path = "$userId/${UUID.randomUUID()}.mp4"
            val uploadLocation = createUpload(endpoint, fileSize, path, accessToken, key)
            uploadChunks(uploadLocation, staged, fileSize, accessToken, key, onProgress)
            try {
                val post = URL("$base/rest/v1/social_posts").openConnection() as HttpURLConnection
                try {
                    post.requestMethod = "POST"
                    post.instanceFollowRedirects = false
                    post.connectTimeout = 12_000
                    post.readTimeout = 20_000
                    post.doOutput = true
                    post.setRequestProperty("apikey", key)
                    post.setRequestProperty("Authorization", "Bearer $accessToken")
                    post.setRequestProperty("Content-Type", "application/json")
                    post.setRequestProperty("Accept", "application/json")
                    post.setRequestProperty("Prefer", "return=minimal")
                    val payload = JSONObject()
                        .put("author_id", userId)
                        .put("kind", kind)
                        .put("caption", caption)
                        .put("media_path", path)
                        .put("media_type", "video")
                    if (kind == "story") {
                        payload.put("expires_at", CommunityStoryRules.expirationForNewStory(Instant.now()))
                    }
                    post.outputStream.use { it.write(payload.toString().toByteArray(Charsets.UTF_8)) }
                    val status = post.responseCode
                    if (status !in 200..299) {
                        throw IOException("Video uploaded but Community post creation failed (HTTP $status).")
                    }
                } finally {
                    post.disconnect()
                }
            } catch (failure: Exception) {
                if (!deletePrivateMedia(base, path, accessToken, key)) {
                    throw IOException(
                        "Post creation failed and the private video could not be cleaned up. Contact support before retrying.",
                        failure
                    )
                }
                throw failure
            }
        } finally {
            staged.delete()
        }
    }

    private fun stageVideo(context: Context, uri: Uri, staged: File): Long {
        var size = 0L
        val input = context.contentResolver.openInputStream(uri)
            ?: throw IOException("Unable to read the selected video.")
        input.use { source ->
            FileOutputStream(staged).use { destination ->
                val buffer = ByteArray(64 * 1024)
                while (true) {
                    val read = source.read(buffer)
                    if (read < 0) break
                    size += read
                    if (!CommunityResumableUploadRules.allowsVideoSize(size)) {
                        throw IOException("Choose an MP4 video no larger than 200 MiB.")
                    }
                    destination.write(buffer, 0, read)
                }
            }
        }
        if (size < 16) throw IOException("The selected video is empty or invalid.")
        val header = ByteArray(minOf(size, 64L * 1024).toInt())
        DataInputStream(FileInputStream(staged)).use { it.readFully(header) }
        if (CommunityUploadRules.detect(header) != CommunityUploadRules.Format.MP4) {
            throw IOException("Only valid MP4 video containers are supported.")
        }
        return size
    }

    private fun connection(url: String, token: String, key: String): HttpURLConnection =
        (URL(url).openConnection() as HttpURLConnection).apply {
            instanceFollowRedirects = false
            connectTimeout = 15_000
            readTimeout = 60_000
            setRequestProperty("Tus-Resumable", "1.0.0")
            setRequestProperty("apikey", key)
            setRequestProperty("Authorization", "Bearer $token")
        }

    private fun createUpload(
        endpoint: String, size: Long, path: String, token: String, key: String
    ): String {
        val request = connection(endpoint, token, key)
        try {
            request.requestMethod = "POST"
            request.setRequestProperty("Upload-Length", size.toString())
            request.setRequestProperty("Upload-Metadata", CommunityResumableUploadRules.metadata(path))
            val status = request.responseCode
            if (status !in 200..299) {
                throw IOException("Could not start video upload (HTTP $status).")
            }
            return CommunityResumableUploadRules.trustedUploadLocation(
                endpoint, request.getHeaderField("Location")
            ) ?: throw IOException("The upload server returned an untrusted video upload location.")
        } finally {
            request.disconnect()
        }
    }

    private suspend fun uploadChunks(
        url: String, staged: File, size: Long, token: String, key: String,
        onProgress: suspend (Long, Long) -> Unit
    ) {
        var offset = 0L
        RandomAccessFile(staged, "r").use { file ->
            while (offset < size) {
                currentCoroutineContext().ensureActive()
                var attempts = 0
                while (true) {
                    val amount = minOf(CommunityResumableUploadRules.chunkBytes.toLong(), size - offset).toInt()
                    val bytes = ByteArray(amount)
                    file.seek(offset)
                    file.readFully(bytes)
                    try {
                        val request = connection(url, token, key)
                        try {
                            request.requestMethod = "PATCH"
                            request.doOutput = true
                            request.setFixedLengthStreamingMode(amount)
                            request.setRequestProperty("Upload-Offset", offset.toString())
                            request.setRequestProperty("Content-Type", "application/offset+octet-stream")
                            request.outputStream.use { it.write(bytes) }
                            val status = request.responseCode
                            if (status !in 200..299) {
                                throw IOException("Video upload interrupted (HTTP $status).")
                            }
                            val acknowledged = CommunityResumableUploadRules.chunkOffset(
                                offset, request.getHeaderField("Upload-Offset"), size, amount
                            )
                            if (acknowledged == null || acknowledged > offset + amount) {
                                throw IOException("The upload server returned an invalid progress offset.")
                            }
                            offset = acknowledged
                            onProgress(offset, size)
                            break
                        } finally {
                            request.disconnect()
                        }
                    } catch (failure: IOException) {
                        // A failed PATCH might have succeeded server-side. Reconcile before retry.
                        val reconciled = try { serverOffset(url, token, key, size, offset, amount) }
                            catch (_: IOException) { null }
                        if (reconciled != null && reconciled > offset) {
                            offset = reconciled
                            onProgress(offset, size)
                            break
                        }
                        attempts++
                        if (attempts >= 4) throw failure
                        delay((attempts * 1000).toLong())
                    }
                }
            }
        }
    }

    private fun serverOffset(url: String, token: String, key: String, size: Long, previous: Long, sentBytes: Int): Long? {
        val request = connection(url, token, key)
        try {
            request.requestMethod = "HEAD"
            if (request.responseCode !in 200..299) return null
            return request.getHeaderField("Upload-Offset")?.toLongOrNull()
                ?.takeIf { it in previous..size && it - previous <= sentBytes.toLong() }
        } finally {
            request.disconnect()
        }
    }

    private fun deletePrivateMedia(base: String, path: String, token: String, key: String): Boolean =
        try {
            val request = (URL("$base/storage/v1/object/social-media")
                .openConnection() as HttpURLConnection)
            try {
                request.requestMethod = "DELETE"
                request.instanceFollowRedirects = false
                request.connectTimeout = 12_000
                request.readTimeout = 15_000
                request.doOutput = true
                request.setRequestProperty("apikey", key)
                request.setRequestProperty("Authorization", "Bearer $token")
                request.setRequestProperty("Content-Type", "application/json")
                val payload = JSONObject().put("prefixes", JSONArray().put(path))
                request.outputStream.use { it.write(payload.toString().toByteArray(Charsets.UTF_8)) }
                request.responseCode in 200..299
            } finally {
                request.disconnect()
            }
        } catch (_: Exception) { false }
}
