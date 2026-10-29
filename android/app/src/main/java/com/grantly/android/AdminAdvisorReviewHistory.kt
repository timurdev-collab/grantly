package com.grantly.android

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

/** Read-only advisor review audit trail using the existing iOS table and administrator RLS. */
internal data class AdminAdvisorReviewEvent(
    val action: String,
    val previousStatus: String,
    val newStatus: String,
    val note: String,
    val applicationVersion: Int,
    val createdAt: String
)

internal object AdminAdvisorReviewHistoryRepository {
    suspend fun load(userId: String, advisorId: String): List<AdminAdvisorReviewEvent> =
        withContext(Dispatchers.IO) {
            val safeAdvisorId = try { UUID.fromString(advisorId).toString() }
                catch (_: IllegalArgumentException) { throw IOException("Invalid advisor identifier.") }
            val session = AuthRepository.activeSession()
            if (session.userId != userId ||
                StudentProfileRepository.load().role != "admin" ||
                AuthRepository.session?.userId != userId) {
                throw IOException("Administrator access is required.")
            }
            val base = BuildConfig.SUPABASE_URL.trimEnd('/')
            val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
            if (!base.startsWith("https://") || key.isBlank()) {
                throw IOException("Advisor review service is not configured.")
            }
            val url = URL("$base/rest/v1/advisor_review_events?select=action,previous_status,new_status,note,application_version,created_at&advisor_id=eq.$safeAdvisorId&order=created_at.desc&limit=30")
            val connection = url.openConnection() as HttpURLConnection
            try {
                connection.requestMethod = "GET"
                connection.instanceFollowRedirects = false
                connection.connectTimeout = 12_000
                connection.readTimeout = 20_000
                connection.setRequestProperty("apikey", key)
                connection.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
                connection.setRequestProperty("Accept", "application/json")
                val code = connection.responseCode
                if (code !in 200..299) {
                    throw IOException(if (code == 401 || code == 403)
                        "Review history access denied." else "Unable to load review history (HTTP $code).")
                }
                val response = connection.inputStream.bufferedReader(Charsets.UTF_8).use { reader ->
                    val builder = StringBuilder()
                    val buffer = CharArray(4096)
                    while (true) {
                        val count = reader.read(buffer)
                        if (count < 0) break
                        if (builder.length + count > 262_144) {
                            throw IOException("Review history exceeds the supported size.")
                        }
                        builder.append(buffer, 0, count)
                    }
                    builder.toString()
                }
                val rows = JSONArray(response)
                if (rows.length() > 30) throw IOException("Review history returned too many records.")
                if (AuthRepository.session?.userId != userId) {
                    throw IOException("Your account changed. Please reload.")
                }
                buildList {
                    for (index in 0 until rows.length()) {
                        val row = rows.optJSONObject(index)
                            ?: throw IOException("Review history returned an invalid record.")
                        fun field(name: String, max: Int): String =
                            if (row.isNull(name)) "" else row.optString(name).take(max)
                        add(AdminAdvisorReviewEvent(
                            action = field("action", 64),
                            previousStatus = field("previous_status", 64),
                            newStatus = field("new_status", 64),
                            note = field("note", 500),
                            applicationVersion = row.optInt("application_version", 1).coerceAtLeast(1),
                            createdAt = field("created_at", 64)
                        ))
                    }
                }
            } finally {
                connection.disconnect()
            }
        }
}

@Composable
internal fun AdminAdvisorReviewHistoryContent(userId: String, advisorId: String) {
    var events by remember(userId, advisorId) { mutableStateOf<List<AdminAdvisorReviewEvent>>(emptyList()) }
    var loading by remember(userId, advisorId) { mutableStateOf(true) }
    var error by remember(userId, advisorId) { mutableStateOf<String?>(null) }
    var refresh by remember(userId, advisorId) { mutableIntStateOf(0) }

    LaunchedEffect(userId, advisorId, refresh) {
        loading = true
        error = null
        events = emptyList()
        try {
            val loaded = AdminAdvisorReviewHistoryRepository.load(userId, advisorId)
            if (AuthRepository.session?.userId == userId) events = loaded
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failure: Exception) {
            if (AuthRepository.session?.userId == userId) {
                error = failure.message ?: "Unable to load review history."
            }
        } finally {
            loading = false
        }
    }

    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        HorizontalDivider()
        Text("Recent review history", style = MaterialTheme.typography.titleSmall)
        Text("Most recent 30 recorded decisions. Read-only.",
            style = MaterialTheme.typography.bodySmall)
        if (loading) LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
        if (error != null) Text(error.orEmpty(), color = MaterialTheme.colorScheme.error)
        if (!loading && error == null && events.isEmpty()) {
            Text("No recorded review decisions.", style = MaterialTheme.typography.bodySmall)
        }
        events.forEach { event ->
            Text(event.action.replace('_', ' ') + " · " +
                advisorStatusTitle(event.previousStatus) + " → " +
                advisorStatusTitle(event.newStatus),
                style = MaterialTheme.typography.labelLarge)
            Text("Application v${event.applicationVersion} · ${event.createdAt}",
                style = MaterialTheme.typography.bodySmall)
            if (event.note.isNotBlank()) Text("Note: ${event.note}",
                style = MaterialTheme.typography.bodySmall)
        }
        OutlinedButton(onClick = { refresh++ }, enabled = !loading) {
            Text("Refresh review history")
        }
    }
}
