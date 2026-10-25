package com.grantly.android

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

/** Existing user-scoped notification_preferences settings; no push-device registration. */
internal data class NotificationPreferences(
    val deadlineReminders: Boolean = true,
    val taskReminders: Boolean = true,
    val messageNotifications: Boolean = true,
    val scholarshipMatchNotifications: Boolean = true
)

internal object NotificationPreferencesRepository {
    private suspend fun account(): Pair<AuthSession, String> {
        val session = AuthRepository.activeSession()
        val userId = try {
            UUID.fromString(session.userId).toString()
        } catch (_: IllegalArgumentException) {
            throw IOException("Invalid account. Please sign in again.")
        }
        return session to userId
    }

    private fun connection(path: String, token: String): HttpURLConnection {
        val base = BuildConfig.SUPABASE_URL.trimEnd('/')
        if (!base.startsWith("https://") || BuildConfig.SUPABASE_PUBLISHABLE_KEY.isBlank()) {
            throw IOException("Notification preferences are not configured.")
        }
        return (URL(base + path).openConnection() as HttpURLConnection).apply {
            connectTimeout = 12_000
            readTimeout = 15_000
            instanceFollowRedirects = false
            setRequestProperty("apikey", BuildConfig.SUPABASE_PUBLISHABLE_KEY)
            setRequestProperty("Authorization", "Bearer $token")
            setRequestProperty("Accept", "application/json")
        }
    }

    suspend fun load(): NotificationPreferences = withContext(Dispatchers.IO) {
        val (session, userId) = account()
        val path = "/rest/v1/notification_preferences" +
            "?select=deadline_reminders,task_reminders,message_notifications,scholarship_match_notifications" +
            "&user_id=eq.$userId&limit=1"
        val request = connection(path, session.accessToken)
        try {
            request.requestMethod = "GET"
            val status = request.responseCode
            if (status !in 200..299) throw IOException(
                if (status == 401 || status == 403) "Sign in again to view preferences."
                else "Unable to load preferences (HTTP $status)."
            )
            val rows = JSONArray(request.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() })
            if (rows.length() == 0) NotificationPreferences()
            else {
                val row = rows.getJSONObject(0)
                NotificationPreferences(
                    deadlineReminders = row.getBoolean("deadline_reminders"),
                    taskReminders = row.getBoolean("task_reminders"),
                    messageNotifications = row.getBoolean("message_notifications"),
                    scholarshipMatchNotifications = row.getBoolean("scholarship_match_notifications")
                )
            }
        } finally {
            request.disconnect()
        }
    }

    suspend fun save(preferences: NotificationPreferences) = withContext(Dispatchers.IO) {
        val (session, userId) = account()
        val request = connection(
            "/rest/v1/notification_preferences?on_conflict=user_id",
            session.accessToken
        )
        try {
            request.requestMethod = "POST"
            request.doOutput = true
            request.setRequestProperty("Content-Type", "application/json")
            request.setRequestProperty("Prefer", "resolution=merge-duplicates,return=minimal")
            val payload = JSONObject()
                .put("user_id", userId)
                .put("deadline_reminders", preferences.deadlineReminders)
                .put("task_reminders", preferences.taskReminders)
                .put("message_notifications", preferences.messageNotifications)
                .put("scholarship_match_notifications", preferences.scholarshipMatchNotifications)
            request.outputStream.use { it.write(payload.toString().toByteArray(Charsets.UTF_8)) }
            val status = request.responseCode
            if (status !in 200..299) throw IOException(
                if (status == 401 || status == 403) "You cannot update these preferences."
                else "Unable to save preferences (HTTP $status)."
            )
        } finally {
            request.disconnect()
        }
    }
}

@Composable
internal fun NotificationPreferencesContent(onBack: () -> Unit) {
    val session = AuthRepository.session
    var preferences by remember(session?.userId) { mutableStateOf(NotificationPreferences()) }
    var loading by remember(session?.userId) { mutableStateOf(true) }
    // Keep successfully loaded switches visible if a later save fails.
    var hasLoaded by remember(session?.userId) { mutableStateOf(false) }
    var busy by remember(session?.userId) { mutableStateOf(false) }
    var error by remember(session?.userId) { mutableStateOf<String?>(null) }
    var retry by remember(session?.userId) { mutableIntStateOf(0) }
    val scope = rememberCoroutineScope()

    // Match the disabled on-screen Back button: do not abandon an in-flight save.
    BackHandler(enabled = busy) { }

    LaunchedEffect(session?.userId, retry) {
        if (session == null) {
            loading = false
            return@LaunchedEffect
        }
        loading = true
        hasLoaded = false
        error = null
        try {
            preferences = NotificationPreferencesRepository.load()
            hasLoaded = true
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failure: Exception) {
            error = failure.message ?: "Unable to load preferences."
        } finally {
            loading = false
        }
    }

    Column(
        modifier = Modifier.fillMaxWidth().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        TextButton(onClick = onBack, enabled = !busy) { Text("← Back to notifications") }
        Text("Notification preferences", style = MaterialTheme.typography.headlineSmall)
        Text(
            "Choose which existing in-app reminders and updates you want. " +
                "Android push notifications are not available yet.",
            style = MaterialTheme.typography.bodySmall
        )
        if (session == null) {
            Text("Sign in to manage notification preferences.")
            return@Column
        }
        if (loading) LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
        if (error != null) {
            Text(error!!, color = MaterialTheme.colorScheme.error)
            TextButton(onClick = { retry++ }, enabled = !busy && !loading) { Text("Retry") }
        }
        if (!loading && hasLoaded) {
            val options = listOf(
                Triple("Scholarship deadlines", preferences.deadlineReminders, 0),
                Triple("Application tasks", preferences.taskReminders, 1),
                Triple("Advisor messages", preferences.messageNotifications, 2),
                Triple("Scholarship matches", preferences.scholarshipMatchNotifications, 3)
            )
            options.forEach { (label, enabled, index) ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(label, modifier = Modifier.weight(1f))
                    Switch(
                        checked = enabled,
                        modifier = Modifier.semantics { contentDescription = label },
                        enabled = !busy,
                        onCheckedChange = { checked ->
                            val next = when (index) {
                                0 -> preferences.copy(deadlineReminders = checked)
                                1 -> preferences.copy(taskReminders = checked)
                                2 -> preferences.copy(messageNotifications = checked)
                                else -> preferences.copy(scholarshipMatchNotifications = checked)
                            }
                            busy = true
                            error = null
                            scope.launch {
                                try {
                                    NotificationPreferencesRepository.save(next)
                                    preferences = next
                                } catch (cancelled: CancellationException) {
                                    throw cancelled
                                } catch (failure: Exception) {
                                    error = failure.message ?: "Unable to save preferences."
                                } finally {
                                    busy = false
                                }
                            }
                        }
                    )
                }
            }
        }
    }
}
