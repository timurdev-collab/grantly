package com.grantly.android

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/**
 * Read-only photo preview. The social-media bucket is private: never use a public
 * Storage URL or put the user's access token into an image URL.
 */
internal object CommunityPhotoRepository {
    private const val maxImageBytes = 8 * 1024 * 1024
    private val safePath = Regex(
        "^[0-9a-fA-F-]{36}/[A-Za-z0-9_-]{1,100}\\.(jpg|jpeg|png|heic|heif)$",
        RegexOption.IGNORE_CASE
    )

    suspend fun loadPhoto(mediaPath: String): Bitmap = withContext(Dispatchers.IO) {
        if (!safePath.matches(mediaPath) || mediaPath.contains("..")) {
            throw IOException("This photo has an unsupported storage path.")
        }
        val session = AuthRepository.activeSession()
        val base = BuildConfig.SUPABASE_URL.trimEnd('/')
        val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
        if (!base.startsWith("https://") || key.isBlank()) {
            throw IOException("Community media is not configured.")
        }
        val encodedPath = mediaPath.split('/').joinToString("/") {
            URLEncoder.encode(it, "UTF-8").replace("+", "%20")
        }
        val signing = URL(base + "/storage/v1/object/sign/social-media/" + encodedPath)
            .openConnection() as HttpURLConnection
        val signedURL = try {
            signing.requestMethod = "POST"
            signing.connectTimeout = 12_000
            signing.readTimeout = 15_000
            signing.doOutput = true
            signing.instanceFollowRedirects = false
            signing.setRequestProperty("apikey", key)
            signing.setRequestProperty("Authorization", "Bearer " + session.accessToken)
            signing.setRequestProperty("Content-Type", "application/json")
            signing.setRequestProperty("Accept", "application/json")
            signing.outputStream.use {
                it.write(JSONObject().put("expiresIn", 3600).toString().toByteArray(Charsets.UTF_8))
            }
            val status = signing.responseCode
            if (status !in 200..299) {
                throw IOException(
                    if (status == 401 || status == 403)
                        "This photo is unavailable to your account."
                    else "Unable to open Community photo (HTTP " + status + ")."
                )
            }
            val response = JSONObject(signing.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() })
            val value = response.optString("signedURL").ifBlank { response.optString("signedUrl") }
            when {
                value.startsWith("/object/sign/social-media/") -> base + "/storage/v1" + value
                value.startsWith("/storage/v1/object/sign/social-media/") -> base + value
                value.startsWith("https://") -> value
                else -> throw IOException("Media service returned an invalid photo URL.")
            }
        } finally {
            signing.disconnect()
        }

        // Signed URLs are bearer capabilities. Never follow third-party redirects.
        val imageURL = URL(signedURL)
        val serviceURL = URL(base)
        if (imageURL.protocol != "https" ||
            imageURL.host != serviceURL.host ||
            imageURL.port != serviceURL.port ||
            !imageURL.path.startsWith("/storage/v1/object/sign/social-media/")
        ) {
            throw IOException("Media service returned an untrusted photo URL.")
        }
        val connection = imageURL.openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "GET"
            connection.connectTimeout = 12_000
            connection.readTimeout = 20_000
            connection.instanceFollowRedirects = false
            val status = connection.responseCode
            if (status !in 200..299) {
                throw IOException("Photo unavailable (HTTP " + status + ").")
            }
            if (connection.contentLengthLong > maxImageBytes) {
                throw IOException("This photo is too large to preview.")
            }
            val bytes = ByteArrayOutputStream()
            connection.inputStream.use { stream ->
                val buffer = ByteArray(16 * 1024)
                var total = 0
                while (true) {
                    val read = stream.read(buffer)
                    if (read < 0) break
                    total += read
                    if (total > maxImageBytes) {
                        throw IOException("This photo is too large to preview.")
                    }
                    bytes.write(buffer, 0, read)
                }
            }
            val data = bytes.toByteArray()
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(data, 0, data.size, bounds)
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0 ||
                bounds.outWidth > 30_000 || bounds.outHeight > 30_000
            ) {
                throw IOException("This photo format cannot be displayed.")
            }
            var sample = 1
            while (bounds.outWidth / sample > 1600 || bounds.outHeight / sample > 1600) {
                sample *= 2
            }
            BitmapFactory.decodeByteArray(
                data, 0, data.size,
                BitmapFactory.Options().apply { inSampleSize = sample }
            ) ?: throw IOException("Unable to decode this photo.")
        } finally {
            connection.disconnect()
        }
    }
}

@Composable
internal fun CommunityPhotoPreview(post: CommunityPost, onBack: () -> Unit) {
    var bitmap by remember(post.id) { mutableStateOf<Bitmap?>(null) }
    var loading by remember(post.id) { mutableStateOf(true) }
    var error by remember(post.id) { mutableStateOf<String?>(null) }
    var retry by remember(post.id) { mutableIntStateOf(0) }

    LaunchedEffect(post.id, retry) {
        bitmap = null
        loading = true
        error = null
        try {
            val path = post.mediaPath ?: throw IOException("Photo storage path is missing.")
            bitmap = CommunityPhotoRepository.loadPhoto(path)
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failure: Exception) {
            error = failure.message ?: "Unable to display this photo."
        } finally {
            loading = false
        }
    }

    Column(
        modifier = Modifier.fillMaxWidth().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        TextButton(onClick = onBack) { Text("← Back to Community") }
        Text("Community photo", style = MaterialTheme.typography.headlineSmall)
        if (loading) LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
        if (error != null) {
            Text(error!!, color = MaterialTheme.colorScheme.error)
            OutlinedButton(onClick = { retry++ }, enabled = !loading) { Text("Retry photo") }
        }
        bitmap?.let {
            Image(
                bitmap = it.asImageBitmap(),
                contentDescription = "Photo attached to a Community post",
                modifier = Modifier.fillMaxWidth().height(320.dp),
                contentScale = ContentScale.Fit
            )
        }
        if (post.caption.isNotBlank()) Text(post.caption)
    }
}
