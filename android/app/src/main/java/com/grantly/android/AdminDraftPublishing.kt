package com.grantly.android

import androidx.compose.material3.*
import androidx.compose.runtime.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

internal object AdminDraftPublishRules {
    fun canOfferPublish(
        readiness: AdminDraftReadiness?,
        duplicates: List<AdminDraftDuplicateCandidate>?
    ): Boolean = readiness?.ready == true && duplicates != null &&
        duplicates.none { AdminDraftDuplicateRules.isHighSimilarity(it.similarityScore) }
}

internal object AdminDraftPublishingRepository {
    suspend fun publish(draft: AdminDraftSummary) = withContext(Dispatchers.IO) {
        val id = try { UUID.fromString(draft.id).toString() }
            catch (_: IllegalArgumentException) { throw IOException("Invalid scholarship draft.") }
        val session = AuthRepository.activeSession()
        if (StudentProfileRepository.load().role != "admin" ||
            AuthRepository.session?.userId != session.userId) {
            throw IOException("Administrator access is required.")
        }

        // Previous UI checks may be stale. Recheck before making a live change.
        if (!AdminDraftRepository.readiness(id).ready) {
            throw IOException("Draft is not ready. Recheck the publication blockers.")
        }
        if (AdminDraftRepository.duplicates(draft).any {
                AdminDraftDuplicateRules.isHighSimilarity(it.similarityScore)
            }) {
            throw IOException("High-similarity scholarship found. Review duplicates first.")
        }
        if (AuthRepository.session?.userId != session.userId) {
            throw IOException("Your account changed. Please reload.")
        }

        val base = BuildConfig.SUPABASE_URL.trimEnd('/')
        val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
        if (!base.startsWith("https://") || key.isBlank()) {
            throw IOException("Publishing service is not configured.")
        }
        val connection = URL("$base/rest/v1/rpc/publish_scholarship_draft")
            .openConnection() as HttpURLConnection
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
            val body = JSONObject().put("p_scholarship_id", id).toString()
            connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            val status = connection.responseCode
            if (status !in 200..299) {
                throw IOException(if (status == 401 || status == 403) {
                    "Administrator access was denied. Sign in again."
                } else {
                    "Publication could not be confirmed (HTTP $status). Refresh before retrying."
                })
            }
            val response = connection.inputStream.bufferedReader(Charsets.UTF_8).use { reader ->
                val text = StringBuilder()
                val buffer = CharArray(4_096)
                while (true) {
                    val count = reader.read(buffer)
                    if (count < 0) break
                    if (text.length + count > 65_536) {
                        throw IOException("Publication response too large. Refresh to confirm status.")
                    }
                    text.append(buffer, 0, count)
                }
                text.toString()
            }
            val result = try { JSONObject(response) }
                catch (_: Exception) {
                    throw IOException("Publication response unclear. Refresh to confirm status.")
                }
            if (result.optString("id") != id || result.optString("status") != "published") {
                throw IOException("Publication status not confirmed. Refresh the queue.")
            }
            if (AuthRepository.session?.userId != session.userId) {
                throw IOException("Your account changed. Refresh to confirm publication.")
            }
        } finally {
            connection.disconnect()
        }
    }
}

/** Publication always requires a separate confirmation and server-side authorization. */
@Composable
internal fun AdminDraftPublisher(
    draft: AdminDraftSummary,
    readiness: AdminDraftReadiness?,
    duplicates: List<AdminDraftDuplicateCandidate>?,
    onPublished: () -> Unit
) {
    var confirming by remember(draft.id) { mutableStateOf(false) }
    var publishing by remember(draft.id) { mutableStateOf(false) }
    var error by remember(draft.id) { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val canPublish = AdminDraftPublishRules.canOfferPublish(readiness, duplicates)

    if (readiness == null) {
        Text("Check publication readiness first.", style = MaterialTheme.typography.labelSmall)
    } else if (!readiness.ready) {
        Text("Resolve publication blockers first.", style = MaterialTheme.typography.labelSmall)
    } else if (duplicates == null) {
        Text("Check possible duplicates first.", style = MaterialTheme.typography.labelSmall)
    } else if (!canPublish) {
        Text("High-similarity scholarships block publication.",
            color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.labelSmall)
    }
    OutlinedButton(onClick = { confirming = true; error = null },
        enabled = canPublish && !publishing) {
        Text(if (publishing) "Publishing…" else "Review publication")
    }
    if (error != null) Text(error!!, color = MaterialTheme.colorScheme.error)
    if (confirming) {
        AlertDialog(
            onDismissRequest = { if (!publishing) confirming = false },
            title = { Text("Publish scholarship?") },
            text = {
                Text("Publish \"${draft.title}\" by ${draft.provider} to the public catalog? " +
                    "This changes live data. The server will recheck readiness. " +
                    "Only proceed after reviewing the official source and duplicates.")
            },
            confirmButton = {
                Button(enabled = canPublish && !publishing, onClick = {
                    // Review conditions can change while this dialog is open.
                    if (!canPublish) return@Button
                    confirming = false
                    publishing = true
                    error = null
                    val expectedUser = AuthRepository.session?.userId
                    scope.launch {
                        try {
                            AdminDraftPublishingRepository.publish(draft)
                            if (AuthRepository.session?.userId == expectedUser) onPublished()
                        } catch (cancelled: CancellationException) {
                            throw cancelled
                        } catch (failure: Exception) {
                            if (AuthRepository.session?.userId == expectedUser) {
                                error = failure.message ?: "Publication status unknown. Refresh."
                            }
                        } finally {
                            publishing = false
                        }
                    }
                }) { Text("Publish now") }
            },
            dismissButton = {
                OutlinedButton(onClick = { confirming = false }) { Text("Cancel") }
            }
        )
    }
}
