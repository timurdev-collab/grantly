package com.grantly.android

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

/** Existing advisor-only messaging APIs; no community direct-message fallback. */
internal data class AdvisorConversation(
    val id: String,
    val title: String,
    val lastMessage: String,
    val unreadCount: Int,
    val lastMessageAt: String
)

internal data class AdvisorMessage(
    val id: String,
    val senderId: String,
    val body: String,
    val createdAt: String
)

internal object AdvisorMessagesRepository {
    private fun validId(value: String): String = try {
        UUID.fromString(value).toString()
    } catch (_: IllegalArgumentException) {
        throw IOException("Invalid conversation identifier.")
    }

    private suspend fun request(
        path: String,
        body: JSONObject,
        method: String = "POST"
    ): String {
        val session = AuthRepository.activeSession()
        return withContext(Dispatchers.IO) {
            val base = BuildConfig.SUPABASE_URL.trimEnd('/')
            val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
            if (!base.startsWith("https://") || key.isBlank()) {
                throw IOException("Messaging service is not configured.")
            }
            val connection = URL(base + path).openConnection() as HttpURLConnection
            try {
                connection.requestMethod = method
                connection.connectTimeout = 12_000
                connection.readTimeout = 15_000
                connection.doOutput = true
                connection.setRequestProperty("apikey", key)
                connection.setRequestProperty("Authorization", "Bearer " + session.accessToken)
                connection.setRequestProperty("Content-Type", "application/json")
                connection.setRequestProperty("Accept", "application/json")
                if (path == "/rest/v1/messages") {
                    connection.setRequestProperty("Prefer", "return=minimal")
                }
                connection.outputStream.use {
                    it.write(body.toString().toByteArray(Charsets.UTF_8))
                }
                val status = connection.responseCode
                if (status !in 200..299) {
                    throw IOException(when (status) {
                        401, 403 -> "Messaging is unavailable for this account or conversation. Sign in again if needed."
                        429 -> "Too many requests. Please wait before retrying."
                        else -> "Messaging request failed (HTTP " + status + "). Check access or try again."
                    })
                }
                connection.inputStream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
            } finally {
                connection.disconnect()
            }
        }
    }

    private suspend fun rpc(name: String, params: JSONObject): String {
        require(name in setOf(
            "get_my_conversation_summaries",
            "get_messages_page",
            "mark_conversation_read",
            "ensure_advisor_direct_conversation"
        ))
        return request("/rest/v1/rpc/" + name, params)
    }

    suspend fun conversations(): List<AdvisorConversation> {
        val rows = JSONArray(rpc("get_my_conversation_summaries", JSONObject()))
        return buildList {
            for (i in 0 until rows.length()) {
                val row = rows.optJSONObject(i) ?: continue
                val id = row.optString("conversation_id")
                if (runCatching { validId(id) }.isFailure) continue
                add(AdvisorConversation(
                    id = id,
                    title = row.optString("display_name").ifBlank { "EduT advisor" },
                    lastMessage = row.optString("last_message").takeUnless { it == "null" }.orEmpty(),
                    unreadCount = row.optInt("unread_count").coerceAtLeast(0),
                    lastMessageAt = row.optString("last_message_at").takeUnless { it == "null" }.orEmpty()
                ))
            }
        }
    }

    suspend fun page(conversationId: String, before: String? = null): List<AdvisorMessage> {
        val params = JSONObject()
            .put("p_conversation_id", validId(conversationId))
            .put("p_before", before ?: JSONObject.NULL)
            .put("p_limit", 40)
        val rows = JSONArray(rpc("get_messages_page", params))
        return buildList {
            for (i in rows.length() - 1 downTo 0) {
                val row = rows.optJSONObject(i) ?: continue
                add(AdvisorMessage(
                    id = row.optString("id"),
                    senderId = row.optString("sender_id"),
                    body = row.optString("body"),
                    createdAt = row.optString("created_at")
                ))
            }
        }
    }

    suspend fun markRead(conversationId: String) {
        rpc("mark_conversation_read", JSONObject().put("p_conversation_id", validId(conversationId)))
    }

    suspend fun send(conversationId: String, text: String) {
        val body = text.trim()
        require(body.isNotEmpty() && body.length <= 2000) {
            "Messages must be between 1 and 2,000 characters."
        }
        val userId = validId(AuthRepository.activeSession().userId)
        request("/rest/v1/messages", JSONObject()
            .put("conversation_id", validId(conversationId))
            .put("sender_id", userId)
            .put("body", body))
    }

    suspend fun startAdvisorChat(advisorId: String): String {
        val raw = rpc("ensure_advisor_direct_conversation",
            JSONObject().put("p_advisor_id", validId(advisorId)))
        val id = raw.trim().trim('"')
        return validId(id)
    }
}

@Composable
internal fun AdvisorMessagesContent() {
    val userId = AuthRepository.session?.userId
    var conversations by remember(userId) { mutableStateOf<List<AdvisorConversation>>(emptyList()) }
    var loading by remember(userId) { mutableStateOf(false) }
    var error by remember(userId) { mutableStateOf<String?>(null) }
    var refresh by remember(userId) { mutableIntStateOf(0) }
    var query by remember { mutableStateOf("") }
    var selected by remember(userId) { mutableStateOf<AdvisorConversation?>(null) }

    if (selected != null) {
        TextButton(onClick = { selected = null; refresh++ }) { Text("← All messages") }
        AdvisorMessageThreadContent(selected!!.id, selected!!.title)
        return
    }

    Text("Messages", style = MaterialTheme.typography.headlineMedium, color = Color(0xFF123E30))
    Text("Private conversations with approved advisors. Pull-to-refresh is not yet available; use Refresh.",
        style = MaterialTheme.typography.bodySmall)
    Spacer(Modifier.height(12.dp))
    if (userId == null) {
        Text("Sign in from Profile to view your messages.")
        return
    }
    LaunchedEffect(userId, refresh) {
        loading = true
        error = null
        try {
            val rows = AdvisorMessagesRepository.conversations()
            if (AuthRepository.session?.userId == userId) conversations = rows
        } catch (failure: Exception) {
            if (AuthRepository.session?.userId == userId) {
                error = failure.message ?: "Unable to load messages."
            }
        } finally {
            loading = false
        }
    }
    OutlinedButton(onClick = { refresh++ }, enabled = !loading) { Text("Refresh") }
    if (loading) CircularProgressIndicator()
    if (error != null) Text(error.orEmpty(), color = MaterialTheme.colorScheme.error)
    OutlinedTextField(
        value = query,
        onValueChange = { query = it },
        label = { Text("Search conversations") },
        singleLine = true,
        modifier = Modifier.fillMaxWidth()
    )
    Spacer(Modifier.height(10.dp))
    val matches = conversations.filter {
        it.title.contains(query.trim(), ignoreCase = true) ||
            it.lastMessage.contains(query.trim(), ignoreCase = true)
    }
    if (!loading && matches.isEmpty()) {
        Text(if (query.isBlank()) "No advisor conversations yet. Open an advisor profile to start one."
             else "No matching conversations.")
    }
    matches.forEach { conversation ->
        Card(
            modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp)
                .clickable { selected = conversation },
            shape = RoundedCornerShape(14.dp)
        ) {
            Column(Modifier.padding(14.dp)) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(conversation.title, fontWeight = FontWeight.Bold)
                    if (conversation.unreadCount > 0) {
                        Text(conversation.unreadCount.toString() + " unread",
                            color = Color(0xFF123E30))
                    }
                }
                if (conversation.lastMessage.isNotBlank()) {
                    Text(conversation.lastMessage, maxLines = 2)
                }
                Text("Open conversation →", style = MaterialTheme.typography.labelSmall)
            }
        }
    }
}

@Composable
internal fun AdvisorMessageThreadContent(conversationId: String, title: String) {
    val userId = AuthRepository.session?.userId
    val scope = rememberCoroutineScope()
    var messages by remember(userId, conversationId) { mutableStateOf<List<AdvisorMessage>>(emptyList()) }
    var loading by remember(userId, conversationId) { mutableStateOf(false) }
    var loadingOlder by remember(userId, conversationId) { mutableStateOf(false) }
    var sending by remember(userId, conversationId) { mutableStateOf(false) }
    var hasMore by remember(userId, conversationId) { mutableStateOf(false) }
    var error by remember(userId, conversationId) { mutableStateOf<String?>(null) }
    var draft by remember(userId, conversationId) { mutableStateOf("") }
    var refresh by remember(userId, conversationId) { mutableIntStateOf(0) }

    Text(title, style = MaterialTheme.typography.titleLarge, color = Color(0xFF123E30))
    Text("Advisor messaging · manually refreshed preview", style = MaterialTheme.typography.bodySmall)
    Spacer(Modifier.height(10.dp))
    if (userId == null) {
        Text("Sign in to view this conversation.")
        return
    }
    LaunchedEffect(userId, conversationId, refresh) {
        loading = true
        error = null
        try {
            val rows = AdvisorMessagesRepository.page(conversationId)
            if (AuthRepository.session?.userId == userId) {
                messages = rows
                hasMore = rows.size == 40
                // A read-receipt failure must not hide messages already fetched.
                runCatching { AdvisorMessagesRepository.markRead(conversationId) }
            }
        } catch (failure: Exception) {
            if (AuthRepository.session?.userId == userId) {
                error = failure.message ?: "Unable to load this conversation."
            }
        } finally {
            loading = false
        }
    }
    OutlinedButton(onClick = { refresh++ }, enabled = !loading && !sending) {
        Text("Refresh messages")
    }
    if (loading) CircularProgressIndicator()
    if (error != null) Text(error.orEmpty(), color = MaterialTheme.colorScheme.error)
    if (hasMore && messages.isNotEmpty()) {
        OutlinedButton(onClick = {
            val oldest = messages.first().createdAt
            loadingOlder = true
            scope.launch {
                try {
                    val earlier = AdvisorMessagesRepository.page(conversationId, oldest)
                    if (AuthRepository.session?.userId == userId) {
                        val ids = messages.map { it.id }.toSet()
                        messages = earlier.filterNot { it.id in ids } + messages
                        hasMore = earlier.size == 40
                    }
                } catch (failure: Exception) {
                    error = failure.message ?: "Unable to load older messages."
                } finally {
                    loadingOlder = false
                }
            }
        }, enabled = !loadingOlder) { Text("Load earlier messages") }
    }
    if (!loading && messages.isEmpty()) Text("No messages yet.")
    messages.forEach { message ->
        val mine = message.senderId == userId
        Card(
            modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
            colors = CardDefaults.cardColors(
                containerColor = if (mine) Color(0xFFDDEADB) else Color.White
            )
        ) {
            Column(Modifier.padding(12.dp)) {
                Text(if (mine) "You" else title, style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold)
                Text(message.body)
                Text(message.createdAt.take(16).replace('T', ' '),
                    style = MaterialTheme.typography.labelSmall)
            }
        }
    }
    Spacer(Modifier.height(12.dp))
    OutlinedTextField(
        value = draft,
        onValueChange = { if (it.length <= 2000) draft = it },
        label = { Text("Write a message") },
        maxLines = 4,
        modifier = Modifier.fillMaxWidth()
    )
    Text(draft.length.toString() + "/2000", style = MaterialTheme.typography.labelSmall)
    Button(
        onClick = {
            val submitted = draft.trim()
            if (submitted.isBlank() || sending) return@Button
            sending = true
            error = null
            scope.launch {
                try {
                    AdvisorMessagesRepository.send(conversationId, submitted)
                    if (AuthRepository.session?.userId == userId) {
                        draft = ""
                        refresh++
                    }
                } catch (failure: Exception) {
                    error = failure.message ?: "Message could not be sent."
                } finally {
                    sending = false
                }
            }
        },
        enabled = !sending && !loading && draft.isNotBlank() && draft.length <= 2000
    ) { Text(if (sending) "Sending…" else "Send message") }
    Text("Messages are delivered only when the server permits this advisor conversation. " +
        "Do not share passwords or payment details.", style = MaterialTheme.typography.bodySmall)
}
