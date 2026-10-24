package com.grantly.android

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
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

/** Community comments use the existing social_post_comments RLS policies. */
internal data class CommunityComment(
    val id: String,
    val authorId: String,
    val body: String,
    val createdAt: String
)

internal data class CommunityCommentsPage(
    val comments: List<CommunityComment>,
    val truncated: Boolean
)

internal object CommunityCommentsRepository {
    private fun uuid(value: String): String = try {
        UUID.fromString(value).toString()
    } catch (_: IllegalArgumentException) {
        throw IOException("Invalid community identifier.")
    }

    private suspend fun request(path: String, method: String = "GET", body: JSONObject? = null): String {
        val session = AuthRepository.activeSession()
        return withContext(Dispatchers.IO) {
            val base = BuildConfig.SUPABASE_URL.trimEnd('/')
            val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
            if (!base.startsWith("https://") || key.isBlank()) {
                throw IOException("Community service is not configured.")
            }
            val connection = URL(base + path).openConnection() as HttpURLConnection
            try {
                connection.requestMethod = method
                connection.connectTimeout = 12_000
                connection.readTimeout = 15_000
                connection.setRequestProperty("apikey", key)
                connection.setRequestProperty("Authorization", "Bearer " + session.accessToken)
                connection.setRequestProperty("Accept", "application/json")
                if (body != null) {
                    connection.doOutput = true
                    connection.setRequestProperty("Content-Type", "application/json")
                    connection.setRequestProperty("Prefer", "return=minimal")
                    connection.outputStream.use {
                        it.write(body.toString().toByteArray(Charsets.UTF_8))
                    }
                }
                val status = connection.responseCode
                if (status !in 200..299) {
                    throw IOException(when (status) {
                        401, 403 -> "Comments are unavailable for this account or post. Sign in again if needed."
                        409 -> "This comment could not be saved. Please refresh and try again."
                        429 -> "Too many requests. Please wait before retrying."
                        else -> "Community comments request failed (HTTP " + status + ")."
                    })
                }
                if (status == 204) "" else
                    connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
            } finally {
                connection.disconnect()
            }
        }
    }

    suspend fun load(postId: String): CommunityCommentsPage {
        val rows = JSONArray(request(
            "/rest/v1/social_post_comments" +
                "?select=id,author_id,body,created_at" +
                "&post_id=eq." + uuid(postId) +
                "&is_active=eq.true&order=created_at.asc&limit=101"
        ))
        val comments = buildList {
            for (index in 0 until minOf(rows.length(), 100)) {
                val row = rows.optJSONObject(index) ?: continue
                val id = row.optString("id")
                if (runCatching { uuid(id) }.isFailure) continue
                add(CommunityComment(
                    id = id,
                    authorId = row.optString("author_id"),
                    body = row.optString("body").take(1000),
                    createdAt = row.optString("created_at")
                ))
            }
        }
        return CommunityCommentsPage(comments, rows.length() > 100)
    }

    suspend fun add(postId: String, message: String) {
        val text = message.trim()
        require(text.isNotEmpty() && text.length <= 1000) {
            "Comments must contain 1 to 1,000 characters."
        }
        val userId = uuid(AuthRepository.activeSession().userId)
        request("/rest/v1/social_post_comments", "POST",
            JSONObject()
                .put("post_id", uuid(postId))
                .put("author_id", userId)
                .put("body", text)
                .put("is_active", true))
    }

    suspend fun deleteOwn(commentId: String) {
        val userId = uuid(AuthRepository.activeSession().userId)
        request(
            "/rest/v1/social_post_comments?id=eq." + uuid(commentId) +
                "&author_id=eq." + userId,
            "DELETE"
        )
    }
}

@Composable
internal fun CommunityCommentsContent(post: CommunityPost, onBack: () -> Unit) {
    val session = AuthRepository.session
    val scope = rememberCoroutineScope()
    var comments by remember(post.id, session?.userId) {
        mutableStateOf<List<CommunityComment>>(emptyList())
    }
    var truncated by remember(post.id) { mutableStateOf(false) }
    var loading by remember(post.id) { mutableStateOf(false) }
    var busy by remember(post.id) { mutableStateOf(false) }
    var error by remember(post.id) { mutableStateOf<String?>(null) }
    var draft by remember(post.id) { mutableStateOf("") }
    var reload by remember(post.id) { mutableIntStateOf(0) }
    var pendingDelete by remember(post.id) { mutableStateOf<CommunityComment?>(null) }

    BackHandler { onBack() }

    LaunchedEffect(post.id, session?.userId, reload) {
        if (session == null) {
            comments = emptyList()
            error = "Sign in to view comments."
        } else {
            loading = true
            error = null
            try {
                val page = CommunityCommentsRepository.load(post.id)
                comments = page.comments
                truncated = page.truncated
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (failure: Exception) {
                // Retain already loaded comments on transient failures.
                error = failure.message ?: "Unable to load comments."
            } finally {
                loading = false
            }
        }
    }

    pendingDelete?.let { comment ->
        AlertDialog(
            onDismissRequest = { if (!busy) pendingDelete = null },
            title = { Text("Delete comment?") },
            text = { Text("This will permanently remove your comment.") },
            confirmButton = {
                TextButton(enabled = !busy, onClick = {
                    busy = true
                    scope.launch {
                        try {
                            CommunityCommentsRepository.deleteOwn(comment.id)
                            comments = comments.filterNot { it.id == comment.id }
                            pendingDelete = null
                            error = null
                        } catch (failure: Exception) {
                            error = failure.message ?: "Unable to delete comment."
                            pendingDelete = null
                        } finally {
                            busy = false
                        }
                    }
                }) { Text("Delete") }
            },
            dismissButton = {
                TextButton(enabled = !busy, onClick = { pendingDelete = null }) {
                    Text("Cancel")
                }
            }
        )
    }

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        TextButton(onClick = onBack) { Text("← Back to Community") }
        Text("Comments", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
        if (post.caption.isNotBlank()) {
            Text(post.caption.take(180), style = MaterialTheme.typography.bodyMedium)
        }
        OutlinedButton(onClick = { reload++ }, enabled = !loading && !busy) {
            Text("Refresh comments")
        }
        if (loading) LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
        if (error != null) {
            Text(error!!, color = MaterialTheme.colorScheme.error)
            if (!loading && !busy) {
                TextButton(onClick = { reload++ }) { Text("Retry") }
            }
        }
        if (!loading && comments.isEmpty() && error == null) {
            Text("No comments yet. Be the first to join the conversation.")
        }
        comments.forEach { comment ->
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(14.dp))
                    .padding(12.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(
                        if (comment.authorId == session?.userId) "You" else "Community member",
                        fontWeight = FontWeight.SemiBold
                    )
                    Text(comment.createdAt.take(10), style = MaterialTheme.typography.labelSmall)
                }
                Text(comment.body)
                if (comment.authorId == session?.userId) {
                    TextButton(onClick = { pendingDelete = comment }, enabled = !busy) {
                        Text("Delete my comment")
                    }
                }
            }
        }
        if (truncated) {
            Text("Showing the first 100 comments. Older comments are not yet available in this preview.",
                style = MaterialTheme.typography.bodySmall)
        }
        OutlinedTextField(
            value = draft,
            onValueChange = { draft = it.take(1000) },
            label = { Text("Add a comment") },
            modifier = Modifier.fillMaxWidth(),
            maxLines = 4,
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Default),
            supportingText = { Text(draft.length.toString() + "/1000") },
            enabled = session != null && !busy
        )
        Button(
            onClick = {
                busy = true
                scope.launch {
                    try {
                        CommunityCommentsRepository.add(post.id, draft)
                        draft = ""
                        error = null
                        reload++
                    } catch (failure: Exception) {
                        error = failure.message ?: "Unable to send comment."
                    } finally {
                        busy = false
                    }
                }
            },
            enabled = session != null && !busy && !loading &&
                draft.trim().isNotEmpty() && draft.trim().length <= 1000
        ) {
            Text(if (busy) "Sending..." else "Post comment")
        }
    }
}
