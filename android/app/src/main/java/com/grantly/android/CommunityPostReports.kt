package com.grantly.android

import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
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
 * Report visible posts through the existing social_post_reports insert policy.
 * No moderator permissions, new tables, or production changes are required.
 */
internal object CommunityPostReportsRepository {
    val reasons = listOf(
        "Spam or misleading",
        "Harassment or bullying",
        "Hate or abusive content",
        "Unsafe or inappropriate",
        "Other"
    )

    private fun validId(value: String): String = try {
        UUID.fromString(value).toString()
    } catch (_: IllegalArgumentException) {
        throw IOException("Invalid Community identifier. Refresh and try again.")
    }

    suspend fun report(post: CommunityPost, reason: String, details: String) {
        require(reason in reasons) { "Select a valid report reason." }
        val trimmedDetails = details.trim()
        require(trimmedDetails.length <= 1000) { "Report details cannot exceed 1,000 characters." }
        val session = AuthRepository.activeSession()
        val reporterId = validId(session.userId)
        val postId = validId(post.id)
        val authorId = validId(post.authorId)
        require(reporterId != authorId) { "You cannot report your own post." }

        withContext(Dispatchers.IO) {
            val base = BuildConfig.SUPABASE_URL.trimEnd('/')
            val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
            if (!base.startsWith("https://") || key.isBlank()) {
                throw IOException("Community safety service is not configured.")
            }
            val connection = URL(base + "/rest/v1/social_post_reports")
                .openConnection() as HttpURLConnection
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
                    .put("post_id", postId)
                    .put("reporter_id", reporterId)
                    .put("reported_user_id", authorId)
                    .put("reason", reason)
                    .put("details", trimmedDetails)
                connection.outputStream.use {
                    it.write(payload.toString().toByteArray(Charsets.UTF_8))
                }
                val status = connection.responseCode
                if (status !in 200..299) {
                    throw IOException(when (status) {
                        401 -> "Your session expired. Please sign in again."
                        403 -> "This post is not available for reporting with your account."
                        409 -> "You have already reported this post."
                        429 -> "Too many reports. Please try again later."
                        else -> "Unable to submit report (HTTP $status). Please retry."
                    })
                }
            } finally {
                connection.disconnect()
            }
        }
    }
}

@Composable
internal fun CommunityPostReportDialog(
    post: CommunityPost,
    onDismiss: () -> Unit,
    onSubmitted: () -> Unit
) {
    var reason by remember(post.id) { mutableStateOf(CommunityPostReportsRepository.reasons.first()) }
    var details by remember(post.id) { mutableStateOf("") }
    var submitting by remember(post.id) { mutableStateOf(false) }
    var error by remember(post.id) { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    AlertDialog(
        onDismissRequest = { if (!submitting) onDismiss() },
        title = { Text("Report Community post") },
        text = {
            Column(
                modifier = Modifier.heightIn(max = 480.dp).verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text("Why are you reporting this post?")
                CommunityPostReportsRepository.reasons.forEach { option ->
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        RadioButton(
                            selected = reason == option,
                            onClick = { reason = option },
                            enabled = !submitting
                        )
                        Text(option, modifier = Modifier.padding(top = 12.dp))
                    }
                }
                OutlinedTextField(
                    value = details,
                    onValueChange = { if (it.length <= 1000) details = it },
                    label = { Text("Additional details (optional)") },
                    minLines = 2,
                    maxLines = 4,
                    enabled = !submitting,
                    modifier = Modifier.fillMaxWidth()
                )
                Text("${details.length}/1,000 characters", style = MaterialTheme.typography.labelSmall)
                if (error != null) Text(error!!, color = MaterialTheme.colorScheme.error)
                if (submitting) LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
            }
        },
        confirmButton = {
            TextButton(
                enabled = !submitting,
                onClick = {
                    submitting = true
                    error = null
                    scope.launch {
                        try {
                            CommunityPostReportsRepository.report(post, reason, details)
                            onSubmitted()
                        } catch (cancelled: CancellationException) {
                            throw cancelled
                        } catch (failure: Exception) {
                            error = failure.message ?: "Unable to report post."
                        } finally {
                            submitting = false
                        }
                    }
                }
            ) { Text(if (submitting) "Submitting..." else "Submit report") }
        },
        dismissButton = {
            TextButton(enabled = !submitting, onClick = onDismiss) { Text("Cancel") }
        }
    )
}
