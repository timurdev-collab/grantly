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
    var storyMode by remember { mutableStateOf(false) }
    var submitting by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    // Prevent Android system Back from closing the composer during an upload.
    BackHandler { if (!submitting) onBack() }
    val photoPicker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (!submitting && uri != null) {
            selectedPhoto = uri
            error = null
        }
    }
    Column(
        modifier = Modifier.fillMaxWidth().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        TextButton(onClick = onBack, enabled = !submitting) { Text("← Back to Community") }
        Text(if (storyMode) "Create Community story" else "Create Community post", style = MaterialTheme.typography.headlineSmall)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            FilterChip(selected = !storyMode, onClick = { storyMode = false }, enabled = !submitting, label = { Text("Post") })
            FilterChip(selected = storyMode, onClick = { storyMode = true }, enabled = !submitting, label = { Text("Story") })
        }
        Text(
            if (storyMode) "Stories require one JPEG/PNG photo (up to 6 MB) and expire after 24 hours. Existing Community profile permissions apply."
            else "Text posts and single JPEG/PNG photos (up to 6 MB) are supported. Posting requires a visible Community profile; existing server permissions apply.",
            style = MaterialTheme.typography.bodySmall
        )
        OutlinedTextField(
            value = caption,
            onValueChange = { if (it.length <= 2000) caption = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text(if (storyMode) "Add a story caption (optional)" else "Share something with students") },
            minLines = 4,
            maxLines = 10,
            enabled = !submitting
        )
        Text("${caption.length}/2,000 characters", style = MaterialTheme.typography.labelSmall)
        OutlinedButton(
            onClick = { photoPicker.launch(arrayOf("image/jpeg", "image/png")) },
            enabled = !submitting
        ) { Text(if (selectedPhoto == null) "Attach photo" else "Change photo") }
        if (selectedPhoto != null) {
            Text("One private photo selected (JPEG/PNG, max 6 MB).", style = MaterialTheme.typography.bodySmall)
            TextButton(onClick = { selectedPhoto = null }, enabled = !submitting) {
                Text("Remove photo")
            }
        }
        if (error != null) Text(error!!, color = MaterialTheme.colorScheme.error)
        if (submitting) LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
        Button(
            enabled = !submitting && (selectedPhoto != null || (!storyMode && caption.trim().isNotEmpty())),
            onClick = {
                submitting = true
                error = null
                scope.launch {
                    try {
                        val photo = selectedPhoto
                        if (photo == null) {
                            CommunityPostPublisher.publish(caption)
                        } else {
                            CommunityPhotoPublisher.publish(context.applicationContext, photo, caption, if (storyMode) "story" else "post")
                        }
                        onPosted()
                    } catch (cancelled: CancellationException) {
                        throw cancelled
                    } catch (failure: Exception) {
                        error = failure.message ?: "Unable to publish post."
                    } finally {
                        submitting = false
                    }
                }
            }
        ) { Text(if (submitting) "Publishing..." else if (storyMode) "Publish story" else "Publish post") }
    }
}
