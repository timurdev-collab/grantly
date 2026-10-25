package com.grantly.android

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
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
import java.time.Instant
import java.util.UUID

/** In-app notification inbox. Uses existing user-scoped app_notifications RLS only. */
internal data class EduTNotification(
    val id: String,
    val kind: String,
    val title: String,
    val body: String,
    val createdAt: String,
    val readAt: String?
)

internal data class NotificationPage(
    val items: List<EduTNotification>,
    val hasMore: Boolean
)

internal object NotificationInboxRepository {
    private suspend fun accountId(): Pair<AuthSession, String> {
        val session = AuthRepository.activeSession()
        val id = try {
            UUID.fromString(session.userId).toString()
        } catch (_: IllegalArgumentException) {
            throw IOException("Invalid account. Please sign in again.")
        }
        return session to id
    }

    private fun apiBase(): String {
        val base = BuildConfig.SUPABASE_URL.trimEnd('/')
        if (!base.startsWith("https://") || BuildConfig.SUPABASE_PUBLISHABLE_KEY.isBlank()) {
            throw IOException("Notification service is not configured.")
        }
        return base
    }

    private fun open(path: String, token: String): HttpURLConnection {
        return (URL(apiBase() + path).openConnection() as HttpURLConnection).apply {
            connectTimeout = 12_000
            readTimeout = 15_000
            instanceFollowRedirects = false
            setRequestProperty("apikey", BuildConfig.SUPABASE_PUBLISHABLE_KEY)
            setRequestProperty("Authorization", "Bearer $token")
            setRequestProperty("Accept", "application/json")
        }
    }

    suspend fun loadPage(offset: Int = 0, limit: Int = 30): NotificationPage =
        withContext(Dispatchers.IO) {
            require(offset in 0..10_000 && limit in 1..50) { "Invalid notification page." }
            val (session, userId) = accountId()
            val path = "/rest/v1/app_notifications" +
                "?select=id,kind,title,body,created_at,read_at" +
                "&user_id=eq.$userId&order=created_at.desc,id.desc" +
                "&limit=${limit + 1}&offset=$offset"
            val connection = open(path, session.accessToken)
            try {
                connection.requestMethod = "GET"
                val status = connection.responseCode
                if (status !in 200..299) throw IOException(
                    if (status == 401 || status == 403) "Sign in again to view notifications."
                    else "Unable to load notifications (HTTP $status)."
                )
                val rows = JSONArray(
                    connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
                )
                val items = buildList {
                    for (i in 0 until minOf(limit, rows.length())) {
                        val row = rows.optJSONObject(i) ?: continue
                        val id = row.optString("id")
                        if (runCatching { UUID.fromString(id) }.isFailure) continue
                        add(
                            EduTNotification(
                                id = id,
                                kind = row.optString("kind"),
                                title = row.optString("title").take(250),
                                body = row.optString("body").take(2000),
                                createdAt = row.optString("created_at"),
                                readAt = if (row.isNull("read_at")) null else row.optString("read_at")
                            )
                        )
                    }
                }
                NotificationPage(items, rows.length() > limit)
            } finally {
                connection.disconnect()
            }
        }

    suspend fun markRead(notificationId: String) = markReadWhere(
        "id=eq.${UUID.fromString(notificationId)}&read_at=is.null"
    )

    suspend fun markAllRead() = markReadWhere("read_at=is.null")

    private suspend fun markReadWhere(filter: String) = withContext(Dispatchers.IO) {
        val (session, userId) = accountId()
        val connection = open(
            "/rest/v1/app_notifications?user_id=eq.$userId&$filter",
            session.accessToken
        )
        try {
            connection.requestMethod = "PATCH"
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Prefer", "return=minimal")
            val payload = JSONObject().put("read_at", Instant.now().toString())
            connection.outputStream.use {
                it.write(payload.toString().toByteArray(Charsets.UTF_8))
            }
            val status = connection.responseCode
            if (status !in 200..299) throw IOException(
                if (status == 401 || status == 403) "You cannot update these notifications."
                else "Unable to mark notifications read (HTTP $status)."
            )
        } finally {
            connection.disconnect()
        }
    }
}

@Composable
internal fun NotificationInboxContent(onBack: () -> Unit) {
    val session = AuthRepository.session
    var notifications by remember(session?.userId) { mutableStateOf<List<EduTNotification>>(emptyList()) }
    var loading by remember(session?.userId) { mutableStateOf(true) }
    var loadingMore by remember(session?.userId) { mutableStateOf(false) }
    var hasMore by remember(session?.userId) { mutableStateOf(false) }
    var nextOffset by remember(session?.userId) { mutableIntStateOf(0) }
    var busy by remember(session?.userId) { mutableStateOf(false) }
    var error by remember(session?.userId) { mutableStateOf<String?>(null) }
    var refresh by remember(session?.userId) { mutableIntStateOf(0) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(session?.userId, refresh) {
        if (session == null) {
            loading = false
            notifications = emptyList()
            hasMore = false
            return@LaunchedEffect
        }
        loading = true
        error = null
        try {
            val page = NotificationInboxRepository.loadPage()
            notifications = page.items
            nextOffset = 30
            hasMore = page.hasMore
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failure: Exception) {
            error = failure.message ?: "Unable to load notifications."
        } finally {
            loading = false
        }
    }

    Column(
        modifier = Modifier.fillMaxWidth().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        TextButton(onClick = onBack, enabled = !busy) { Text("← Back to Home") }
        Text("Notifications", style = MaterialTheme.typography.headlineSmall)
        Text(
            "Application deadlines, tasks and messages appear here when available. Android push notifications are not enabled.",
            style = MaterialTheme.typography.bodySmall
        )
        if (session == null) {
            Text("Sign in to view your notifications.")
            return@Column
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = { refresh++ }, enabled = !busy && !loading) {
                Text("Refresh")
            }
            if (notifications.any { it.readAt == null }) {
                OutlinedButton(
                    enabled = !busy && !loading,
                    onClick = {
                        busy = true
                        scope.launch {
                            try {
                                NotificationInboxRepository.markAllRead()
                                refresh++
                            } catch (cancelled: CancellationException) {
                                throw cancelled
                            } catch (failure: Exception) {
                                error = failure.message ?: "Unable to mark notifications read."
                            } finally {
                                busy = false
                            }
                        }
                    }
                ) { Text("Mark all read") }
            }
        }
        if (loading) LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
        if (error != null) Text(error!!, color = MaterialTheme.colorScheme.error)
        if (!loading && notifications.isEmpty() && error == null) {
            Text("No notifications yet.")
        }
        notifications.forEach { notification ->
            Surface(
                shape = RoundedCornerShape(14.dp),
                tonalElevation = if (notification.readAt == null) 3.dp else 0.dp,
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(
                    modifier = Modifier.padding(14.dp),
                    verticalArrangement = Arrangement.spacedBy(5.dp)
                ) {
                    Text(
                        notification.title.ifBlank { "Notification" } +
                            if (notification.readAt == null) " • New" else "",
                        fontWeight = FontWeight.SemiBold
                    )
                    Text(notification.body, style = MaterialTheme.typography.bodyMedium)
                    Text(
                        notification.createdAt.take(10) + " · " + notification.kind,
                        style = MaterialTheme.typography.labelSmall
                    )
                    if (notification.readAt == null) {
                        TextButton(
                            enabled = !busy,
                            onClick = {
                                busy = true
                                scope.launch {
                                    try {
                                        NotificationInboxRepository.markRead(notification.id)
                                        notifications = notifications.map {
                                            if (it.id == notification.id)
                                                it.copy(readAt = Instant.now().toString())
                                            else it
                                        }
                                    } catch (cancelled: CancellationException) {
                                        throw cancelled
                                    } catch (failure: Exception) {
                                        error = failure.message ?: "Unable to mark notification read."
                                    } finally {
                                        busy = false
                                    }
                                }
                            }
                        ) { Text("Mark read") }
                    }
                }
            }
        }
        if (hasMore) {
            Button(
                enabled = !loadingMore && !loading && !busy,
                onClick = {
                    loadingMore = true
                    error = null
                    scope.launch {
                        try {
                            val page = NotificationInboxRepository.loadPage(offset = nextOffset)
                            val seen = notifications.map { it.id }.toHashSet()
                            notifications = notifications + page.items.filter { seen.add(it.id) }
                            nextOffset += 30
                            hasMore = page.hasMore
                        } catch (cancelled: CancellationException) {
                            throw cancelled
                        } catch (failure: Exception) {
                            error = failure.message ?: "Unable to load more notifications."
                        } finally {
                            loadingMore = false
                        }
                    }
                }
            ) { Text(if (loadingMore) "Loading..." else "Load more notifications") }
        }
    }
}
