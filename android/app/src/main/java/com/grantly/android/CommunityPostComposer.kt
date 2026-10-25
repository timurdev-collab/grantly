package com.grantly.android

import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

/**
 * Publish a text-only Community post using the existing social_posts insert RLS.
 * Server policy requires the author's community profile to be visible.
 * No storage uploads or privileged credentials are used.
 */
internal object CommunityPostPublisher {
    suspend fun publish(caption: String) {
        val text = caption.trim()
        require(text.length in 1..2000) { "Write a post of 1–2,000 characters." }
        val session = AuthRepository.activeSession()
        val authorId = try {
            UUID.fromString(session.userId).toString()
        } catch (_: IllegalArgumentException) {
            throw IOException("Invalid account. Please sign in again.")
        }
        withContext(Dispatchers.IO) {
            val base = BuildConfig.SUPABASE_URL.trimEnd('/')
            val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
            if (!base.startsWith("https://") || key.isBlank()) {
                throw IOException("Community service is not configured.")
            }
            val connection = URL(base + "/rest/v1/social_posts").openConnection() as HttpURLConnection
            try {
                connection.requestMethod = "POST"
                connection.instanceFollowRedirects = false
                connection.connectTimeout = 12_000
                connection.readTimeout = 15_000
                connection.doOutput = true
                connection.setRequestProperty("apikey", key)
                connection.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
                connection.setRequestProperty("Content-Type", "application/json")
                connection.setRequestProperty("Accept", "application/json")
                connection.setRequestProperty("Prefer", "return=minimal")
                val payload = JSONObject()
                    .put("author_id", authorId)
                    .put("kind", "post")
                    .put("caption", text)
                connection.outputStream.use {
                    it.write(payload.toString().toByteArray(Charsets.UTF_8))
                }
                val status = connection.responseCode
                if (status !in 200..299) {
                    throw IOException(when (status) {
                        401 -> "Your session expired. Sign in again."
                        403 -> "Posting is not permitted for this account. A visible Community profile is required."
                        429 -> "Too many requests. Try again later."
                        else -> "Could not publish post (HTTP $status). Check Community access."
                    })
                }
            } finally {
                connection.disconnect()
            }
        }
    }
}

@Composable
internal fun CommunityPostComposer(
    onBack: () -> Unit,
    onPosted: () -> Unit
) {
    var caption by remember { mutableStateOf("") }
    var selectedPhoto by remember { mutableStateOf<Uri?>(null) }
    var selectedIsVideo by remember { mutableStateOf(false) }
    var postKind by remember { mutableStateOf("post") }
    var submitting by remember { mutableStateOf(false) }
    var cancellingUpload by remember { mutableStateOf(false) }
    var uploadJob by remember { mutableStateOf<Job?>(null) }
    var videoProgress by remember { mutableStateOf<Float?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    // Prevent Android system Back from closing the composer during an upload.
    BackHandler { if (!submitting) onBack() }
    val photoPicker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (!submitting && uri != null) {
            selectedPhoto = uri
            selectedIsVideo = false
            error = null
        }
    }
    val videoPicker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (!submitting && uri != null) {
            selectedPhoto = uri
            selectedIsVideo = true
            error = null
        }
    }
    Column(
        modifier = Modifier.fillMaxWidth().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        TextButton(onClick = onBack, enabled = !submitting) { Text("← Back to Community") }
        Text(when (postKind) { "story" -> "Create Community story"; "short" -> "Create Community Short"; else -> "Create Community post" }, style = MaterialTheme.typography.headlineSmall)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            FilterChip(selected = postKind == "post", onClick = { postKind = "post" }, enabled = !submitting, label = { Text("Post") })
            FilterChip(selected = postKind == "story", onClick = { postKind = "story" }, enabled = !submitting, label = { Text("Story") })
            FilterChip(selected = postKind == "short", onClick = {
                postKind = "short"
                if (!selectedIsVideo) selectedPhoto = null
            }, enabled = !submitting, label = { Text("Short") })
        }
        Text(
            when (postKind) {
                "story" -> "Stories require one JPEG/PNG photo (up to 6 MiB) or MP4 video (up to 200 MiB) and expire after 24 hours."
                "short" -> "Shorts require an MP4 video up to 200 MiB. Video uploads may take several minutes."
                else -> "Text posts, JPEG/PNG photos (up to 6 MiB) and MP4 videos (up to 200 MiB) are supported. Posting requires a visible Community profile."
            },
            style = MaterialTheme.typography.bodySmall
        )
        OutlinedTextField(
            value = caption,
            onValueChange = { if (it.length <= 2000) caption = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text(if (postKind == "story") "Add a story caption (optional)" else "Share something with students") },
            minLines = 4,
            maxLines = 10,
            enabled = !submitting
        )
        Text("${caption.length}/2,000 characters", style = MaterialTheme.typography.labelSmall)
        OutlinedButton(
            onClick = { photoPicker.launch(arrayOf("image/jpeg", "image/png")) },
            enabled = !submitting && postKind != "short"
        ) { Text(if (selectedPhoto == null) "Attach photo" else "Change photo") }
        OutlinedButton(
            onClick = { videoPicker.launch(arrayOf("video/mp4")) },
            enabled = !submitting
        ) { Text(if (selectedPhoto != null && selectedIsVideo) "Change video" else "Attach MP4 video") }
        if (selectedPhoto != null) {
            Text(if (selectedIsVideo) "One private MP4 video selected (max 200 MiB; upload is resumable while this screen stays open)." else "One private JPEG/PNG photo selected (max 6 MiB).", style = MaterialTheme.typography.bodySmall)
            TextButton(onClick = { selectedPhoto = null }, enabled = !submitting) {
                Text("Remove media")
            }
        }
        if (error != null) Text(error!!, color = MaterialTheme.colorScheme.error)
        if (submitting) {
            val progress = videoProgress
            if (selectedIsVideo && progress != null) {
                LinearProgressIndicator(progress = { progress }, modifier = Modifier.fillMaxWidth())
                Text("Uploading video: ${(progress * 100).toInt()}%", style = MaterialTheme.typography.labelSmall)
            } else {
                LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
            }
        }
        // Allow users to stop a large video upload without leaving the composer.
        // Keep the screen locked until the publisher finishes private-media cleanup.
        if (submitting && selectedIsVideo && !cancellingUpload && (videoProgress ?: 0f) < 1f) {
            TextButton(onClick = {
                cancellingUpload = true
                uploadJob?.cancel()
            }) { Text("Cancel video upload") }
        }
        if (cancellingUpload) {
            Text("Cancelling upload and cleaning up private media…", style = MaterialTheme.typography.bodySmall)
        }
        Button(
            enabled = !submitting && (selectedPhoto != null || (postKind == "post" && caption.trim().isNotEmpty())),
            onClick = {
                submitting = true
                cancellingUpload = false
                videoProgress = null
                error = null
                uploadJob = scope.launch {
                    try {
                        val photo = selectedPhoto
                        if (photo == null) {
                            CommunityPostPublisher.publish(caption)
                        } else {
                            CommunityPhotoPublisher.publish(
                                context.applicationContext, photo, caption, postKind,
                                isVideo = selectedIsVideo,
                                onVideoProgress = { uploaded, total ->
                                    withContext(Dispatchers.Main) {
                                        videoProgress = CommunityResumableUploadRules.progressFraction(uploaded, total)
                                    }
                                }
                            )
                        }
                        onPosted()
                    } catch (cancelled: CancellationException) {
                        if (cancellingUpload) error = "Video upload cancelled."
                        throw cancelled
                    } catch (failure: Exception) {
                        error = failure.message ?: "Unable to publish Community content."
                    } finally {
                        submitting = false
                        cancellingUpload = false
                        uploadJob = null
                    }
                }
            }
        ) { Text(if (submitting) "Publishing..." else when (postKind) { "story" -> "Publish story"; "short" -> "Publish Short"; else -> "Publish post" }) }
    }
}
