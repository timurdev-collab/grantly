package com.grantly.android

import android.content.Context
import android.net.Uri
import android.widget.MediaController
import android.widget.VideoView
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/**
 * Read-only private video preview. Downloads a bounded file to app-private cache
 * before playback so signed Storage URLs never reach a redirect-following player.
 * No service-role credentials, public Storage URLs or backend changes are used.
 */
internal object CommunityVideoRepository {
    private const val maxVideoBytes = 200L * 1024 * 1024
    private val safePath = Regex(
        "^[0-9a-fA-F-]{36}/[A-Za-z0-9_-]{1,100}\\.(mp4|mov|m4v)$",
        RegexOption.IGNORE_CASE
    )

    suspend fun download(context: Context, mediaPath: String): File = withContext(Dispatchers.IO) {
        if (!safePath.matches(mediaPath) || mediaPath.contains("..")) {
            throw IOException("This video has an unsupported storage path.")
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
            signing.instanceFollowRedirects = false
            signing.doOutput = true
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
                        "This video is unavailable to your account."
                    else "Unable to open Community video (HTTP " + status + ")."
                )
            }
            val response = JSONObject(signing.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() })
            val value = response.optString("signedURL").ifBlank { response.optString("signedUrl") }
            when {
                value.startsWith("/object/sign/social-media/") -> base + "/storage/v1" + value
                value.startsWith("/storage/v1/object/sign/social-media/") -> base + value
                value.startsWith("https://") -> value
                else -> throw IOException("Media service returned an invalid video URL.")
            }
        } finally {
            signing.disconnect()
        }

        val videoURL = URL(signedURL)
        val serviceURL = URL(base)
        if (videoURL.protocol != "https" ||
            videoURL.host != serviceURL.host ||
            videoURL.port != serviceURL.port ||
            !videoURL.path.startsWith("/storage/v1/object/sign/social-media/")
        ) {
            throw IOException("Media service returned an untrusted video URL.")
        }

        val connection = videoURL.openConnection() as HttpURLConnection
        val file = File.createTempFile("community-video-", ".mp4", context.cacheDir)
        try {
            connection.requestMethod = "GET"
            connection.connectTimeout = 12_000
            connection.readTimeout = 30_000
            connection.instanceFollowRedirects = false
            val status = connection.responseCode
            if (status !in 200..299) {
                throw IOException("Video unavailable (HTTP " + status + ").")
            }
            if (connection.contentLengthLong > maxVideoBytes) {
                throw IOException("This video exceeds the 200 MiB preview limit.")
            }
            var total = 0L
            connection.inputStream.use { input ->
                FileOutputStream(file).use { output ->
                    val buffer = ByteArray(64 * 1024)
                    while (true) {
                        currentCoroutineContext().ensureActive()
                        val read = input.read(buffer)
                        if (read < 0) break
                        total += read
                        if (total > maxVideoBytes) {
                            throw IOException("This video exceeds the 200 MiB preview limit.")
                        }
                        output.write(buffer, 0, read)
                    }
                }
            }
            if (total == 0L) throw IOException("The video file is empty.")
            file
        } catch (failure: Exception) {
            file.delete()
            throw failure
        } finally {
            connection.disconnect()
        }
    }
}

@Composable
internal fun CommunityVideoPreview(post: CommunityPost, onBack: () -> Unit) {
    val context = LocalContext.current
    var videoFile by remember(post.id) { mutableStateOf<File?>(null) }
    var loading by remember(post.id) { mutableStateOf(true) }
    var error by remember(post.id) { mutableStateOf<String?>(null) }
    var playbackError by remember(post.id) { mutableStateOf<String?>(null) }
    var retry by remember(post.id) { mutableIntStateOf(0) }

    LaunchedEffect(post.id, retry) {
        videoFile?.delete()
        videoFile = null
        loading = true
        error = null
        playbackError = null
        try {
            val path = post.mediaPath ?: throw IOException("Video storage path is missing.")
            videoFile = CommunityVideoRepository.download(context.applicationContext, path)
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failure: Exception) {
            error = failure.message ?: "Unable to display this video."
        } finally {
            loading = false
        }
    }

    DisposableEffect(post.id) {
        onDispose { videoFile?.delete() }
    }

    Column(
        modifier = Modifier.fillMaxWidth().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        TextButton(onClick = onBack) { Text("← Back to Community") }
        Text("Community video", style = MaterialTheme.typography.headlineSmall)
        if (loading) {
            LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
            Text("Preparing private video for playback. Large videos may take a while.")
        }
        if (error != null) {
            Text(error!!, color = MaterialTheme.colorScheme.error)
            OutlinedButton(onClick = { retry++ }, enabled = !loading) { Text("Retry video") }
        }
        videoFile?.let { file ->
            val player = remember(file) {
                VideoView(context).apply {
                    setVideoURI(Uri.fromFile(file))
                    setMediaController(MediaController(context))
                    setOnErrorListener { _, _, _ ->
                        playbackError = "This device cannot play the attached video."
                        true
                    }
                }
            }
            DisposableEffect(player) {
                onDispose {
                    player.stopPlayback()
                    file.delete()
                }
            }
            AndroidView(
                factory = { player },
                modifier = Modifier.fillMaxWidth().height(280.dp)
            )
            Button(onClick = { player.start() }) { Text("Play video") }
            Text("Playback uses a temporary private file. It is removed when you leave this screen.")
            if (playbackError != null) {
                Text(playbackError!!, color = MaterialTheme.colorScheme.error)
            }
        }
        if (post.caption.isNotBlank()) Text(post.caption)
    }
}
