package com.grantly.android

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

/** Read-only social preview. The existing RLS policy determines which posts are visible. */
internal data class CommunityPost(
    val id: String,
    val authorId: String,
    val kind: String,
    val caption: String,
    val createdAt: String,
    val hasMedia: Boolean
)

internal data class CommunityPage(val posts: List<CommunityPost>, val hasMore: Boolean)

internal object CommunityFeedRepository {
    suspend fun loadPage(limit: Int = 30, offset: Int = 0): CommunityPage = withContext(Dispatchers.IO) {
        require(limit in 1..50) { "Invalid community page size." }
        require(offset in 0..10_000) { "Invalid community offset." }
        val session = AuthRepository.activeSession()
        val base = BuildConfig.SUPABASE_URL.trimEnd('/')
        val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
        if (!base.startsWith("https://") || key.isBlank()) {
            throw IOException("Community service is not configured.")
        }
        // Explicitly exclude inactive posts; server RLS additionally enforces visibility and blocks.
        val path = "/rest/v1/social_posts" +
            "?select=id,author_id,kind,caption,created_at,media_type,media_path,media_url" +
            "&kind=neq.story&is_active=eq.true&order=created_at.desc&limit=${limit + 1}&offset=$offset"
        val connection = URL(base + path).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "GET"
            connection.connectTimeout = 12_000
            connection.readTimeout = 15_000
            connection.setRequestProperty("apikey", key)
            connection.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
            connection.setRequestProperty("Accept", "application/json")
            val status = connection.responseCode
            if (status !in 200..299) {
                throw IOException(
                    if (status == 401 || status == 403)
                        "Sign in again or check your community access."
                    else "Community feed unavailable (HTTP $status)."
                )
            }
            val rows = JSONArray(
                connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
            )
            val visiblePosts = buildList {
                for (index in 0 until minOf(rows.length(), limit)) {
                    val row = rows.optJSONObject(index) ?: continue
                    val id = row.optString("id")
                    val kind = row.optString("kind")
                    if (id.isBlank() || kind !in setOf("post", "short")) continue
                    add(
                        CommunityPost(
                            id = id,
                            authorId = row.optString("author_id"),
                            kind = kind,
                            caption = row.optString("caption").take(4000),
                            createdAt = row.optString("created_at"),
                            hasMedia = (!row.isNull("media_type") && row.optString("media_type").isNotBlank()) ||
                                (!row.isNull("media_path") && row.optString("media_path").isNotBlank()) ||
                                (!row.isNull("media_url") && row.optString("media_url").isNotBlank())
                        )
                    )
                }
            }
            CommunityPage(posts = visiblePosts, hasMore = rows.length() > limit)
        } finally {
            connection.disconnect()
        }
    }
}

/**
 * Deletes only the signed-in author's text-only posts. Media posts require
 * storage cleanup and are intentionally excluded until that flow is ported.
 * The server's own-post RLS policy remains authoritative.
 */
internal object CommunityPostManager {
    suspend fun deleteOwnTextPost(post: CommunityPost) = withContext(Dispatchers.IO) {
        val session = AuthRepository.activeSession()
        val userId = try {
            UUID.fromString(session.userId).toString()
        } catch (_: IllegalArgumentException) {
            throw IOException("Invalid account. Please sign in again.")
        }
        val postId = try {
            UUID.fromString(post.id).toString()
        } catch (_: IllegalArgumentException) {
            throw IOException("Invalid post identifier.")
        }
        if (post.authorId != userId || post.hasMedia || post.kind != "post") {
            throw IOException("Only your own text-only posts can be deleted here.")
        }
        val base = BuildConfig.SUPABASE_URL.trimEnd('/')
        val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
        if (!base.startsWith("https://") || key.isBlank()) {
            throw IOException("Community service is not configured.")
        }
        val path = "/rest/v1/social_posts?id=eq.$postId&author_id=eq.$userId" +
            "&kind=eq.post&media_type=is.null&media_path=is.null&media_url=is.null"
        val connection = URL(base + path).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "DELETE"
            connection.connectTimeout = 12_000
            connection.readTimeout = 15_000
            connection.setRequestProperty("apikey", key)
            connection.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
            connection.setRequestProperty("Accept", "application/json")
            connection.setRequestProperty("Prefer", "return=representation")
            val status = connection.responseCode
            if (status !in 200..299) {
                throw IOException(when (status) {
                    401 -> "Your session expired. Sign in again."
                    403 -> "You do not have permission to delete this post."
                    else -> "Unable to delete post (HTTP $status)."
                })
            }
            val rows = JSONArray(
                connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
            )
            if (rows.length() != 1) {
                throw IOException("Post was not deleted. Refresh and try again.")
            }
        } finally {
            connection.disconnect()
        }
    }
    /** Only update the caption of an owned, text-only post under existing RLS. */
    suspend fun editOwnTextPost(post: CommunityPost, caption: String) = withContext(Dispatchers.IO) {
        val text = caption.trim()
        require(text.length in 1..2000) { "Write 1–2,000 characters." }
        val session = AuthRepository.activeSession()
        val userId = try {
            UUID.fromString(session.userId).toString()
        } catch (_: IllegalArgumentException) {
            throw IOException("Invalid account. Please sign in again.")
        }
        val postId = try {
            UUID.fromString(post.id).toString()
        } catch (_: IllegalArgumentException) {
            throw IOException("Invalid post identifier.")
        }
        if (post.authorId != userId || post.hasMedia || post.kind != "post") {
            throw IOException("Only your own text-only posts can be edited.")
        }
        val base = BuildConfig.SUPABASE_URL.trimEnd('/')
        val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
        if (!base.startsWith("https://") || key.isBlank()) {
            throw IOException("Community service is not configured.")
        }
        val path = "/rest/v1/social_posts?id=eq.$postId&author_id=eq.$userId" +
            "&kind=eq.post&media_type=is.null&media_path=is.null&media_url=is.null"
        val connection = URL(base + path).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "PATCH"
            connection.connectTimeout = 12_000
            connection.readTimeout = 15_000
            connection.doOutput = true
            connection.setRequestProperty("apikey", key)
            connection.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Accept", "application/json")
            connection.setRequestProperty("Prefer", "return=representation")
            val payload = org.json.JSONObject().put("caption", text).toString()
            connection.outputStream.use { it.write(payload.toByteArray(Charsets.UTF_8)) }
            val status = connection.responseCode
            if (status !in 200..299) {
                throw IOException(when (status) {
                    401 -> "Your session expired. Sign in again."
                    403 -> "You do not have permission to edit this post."
                    else -> "Unable to edit post (HTTP $status)."
                })
            }
            val rows = JSONArray(connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() })
            if (rows.length() != 1) throw IOException("Post was not updated. Refresh and try again.")
        } finally {
            connection.disconnect()
        }
    }

}

@Composable
internal fun CommunityFeedContent(onBack: () -> Unit) {
    val session = AuthRepository.session
    var posts by remember(session?.userId) { mutableStateOf<List<CommunityPost>>(emptyList()) }
    var loading by remember(session?.userId) { mutableStateOf(false) }
    var error by remember(session?.userId) { mutableStateOf<String?>(null) }
    var refresh by remember(session?.userId) { mutableIntStateOf(0) }
    var nextOffset by remember(session?.userId) { mutableIntStateOf(0) }
    var hasMore by remember(session?.userId) { mutableStateOf(false) }

    var selectedPost by remember(session?.userId) { mutableStateOf<CommunityPost?>(null) }
    var composing by remember(session?.userId) { mutableStateOf(false) }
    var pendingDelete by remember(session?.userId) { mutableStateOf<CommunityPost?>(null) }
    var editingPost by remember(session?.userId) { mutableStateOf<CommunityPost?>(null) }
    var deletingId by remember(session?.userId) { mutableStateOf<String?>(null) }
    var deleteError by remember(session?.userId) { mutableStateOf<String?>(null) }
    var likedIds by remember(session?.userId) { mutableStateOf<Set<String>>(emptySet()) }
    var knownLikeIds by remember(session?.userId) { mutableStateOf<Set<String>>(emptySet()) }
    var busyLikeIds by remember(session?.userId) { mutableStateOf<Set<String>>(emptySet()) }
    var likeError by remember(session?.userId) { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    if (pendingDelete != null) {
        val target = pendingDelete!!
        AlertDialog(
            onDismissRequest = { if (deletingId == null) pendingDelete = null },
            title = { Text("Delete your post?") },
            text = { Text("This permanently deletes the text post and its comments and likes. This cannot be undone.") },
            confirmButton = {
                TextButton(
                    enabled = deletingId == null,
                    onClick = {
                        deletingId = target.id
                        deleteError = null
                        scope.launch {
                            try {
                                CommunityPostManager.deleteOwnTextPost(target)
                                pendingDelete = null
                                nextOffset = 0
                                refresh++
                            } catch (cancelled: CancellationException) {
                                throw cancelled
                            } catch (failure: Exception) {
                                deleteError = failure.message ?: "Unable to delete post."
                                pendingDelete = null
                            } finally {
                                deletingId = null
                            }
                        }
                    }
                ) { Text(if (deletingId == null) "Delete" else "Deleting...") }
            },
            dismissButton = {
                TextButton(
                    enabled = deletingId == null,
                    onClick = { pendingDelete = null }
                ) { Text("Cancel") }
            }
        )
    }
    if (composing) {
        CommunityPostComposer(
            onBack = { composing = false },
            onPosted = {
                composing = false
                nextOffset = 0
                refresh++
            }
        )
        return
    }
    if (editingPost != null) {
        CommunityPostEditor(
            post = editingPost!!,
            onBack = { editingPost = null },
            onSaved = {
                editingPost = null
                nextOffset = 0
                refresh++
            }
        )
        return
    }
    if (selectedPost != null) {
        CommunityCommentsContent(post = selectedPost!!, onBack = { selectedPost = null })
        return
    }

    LaunchedEffect(session?.userId, refresh, nextOffset) {
        if (session == null) {
            posts = emptyList()
            hasMore = false
            error = null
            loading = false
        } else {
            loading = true
            error = null
            try {
                val page = CommunityFeedRepository.loadPage(offset = nextOffset)
                posts = if (nextOffset == 0) {
                    page.posts
                } else {
                    val knownIds = posts.mapTo(mutableSetOf()) { it.id }
                    posts + page.posts.filter { knownIds.add(it.id) }
                }
                hasMore = page.hasMore
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (failure: Exception) {
                // Keep already loaded content visible during a temporary network failure.
                error = failure.message ?: "Unable to load community posts."
            } finally {
                loading = false
            }
        }
    }

    // Fetch only the current user's likes for visible posts. Failed requests leave
    // previously loaded state intact, rather than falsely showing posts as unliked.
    LaunchedEffect(session?.userId, refresh, posts.map { it.id }) {
        if (session == null || posts.isEmpty()) {
            if (session == null) {
                likedIds = emptySet()
                knownLikeIds = emptySet()
            }
        } else {
            val ids = posts.map { it.id }
            try {
                // Load in bounded batches as the feed grows beyond its first page.
                val mine = ids.chunked(50).flatMap { batch ->
                    CommunityLikesRepository.loadMine(batch)
                }.toSet()
                likedIds = (likedIds - ids.toSet()) + mine
                knownLikeIds = knownLikeIds + ids
                likeError = null
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (failure: Exception) {
                likeError = failure.message ?: "Unable to load Community likes."
            }
        }
    }

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        TextButton(onClick = onBack) { Text("← Back to Home") }
        Text("Community", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        Text(
            "Preview of visible posts. You can comment, like and publish text-only posts. Media uploads, stories and playback are not available yet.",
            style = MaterialTheme.typography.bodySmall
        )
        if (session == null) {
            Text("Sign in from the Profile tab to view community posts.")
        } else {
            OutlinedButton(onClick = { composing = true }, enabled = !loading) {
                Text("Create text post")
            }
            OutlinedButton(onClick = {
                nextOffset = 0
                refresh++
            }, enabled = !loading) { Text("Refresh posts") }
            if (loading) LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
            if (error != null) {
                Text(error!!, color = MaterialTheme.colorScheme.error)
                OutlinedButton(
                    onClick = { refresh++ },
                    enabled = !loading
                ) { Text("Retry failed page") }
            }
            if (deleteError != null) {
                Text(deleteError!!, color = MaterialTheme.colorScheme.error)
            }
            if (likeError != null) {
                Text(likeError!!, color = MaterialTheme.colorScheme.error)
                TextButton(onClick = { refresh++ }, enabled = !loading) { Text("Retry likes") }
            }
            if (!loading && posts.isEmpty() && error == null) {
                Text("No visible community posts. Community profiles may be hidden by current release policies.")
            }
            posts.forEach { post ->
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Color.White, RoundedCornerShape(16.dp))
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(
                        if (post.kind == "short") "Short video" else "Community post",
                        fontWeight = FontWeight.SemiBold
                    )
                    if (post.caption.isNotBlank()) Text(post.caption)
                    if (post.hasMedia) {
                        Text(
                            "Media attached — playback is not yet available in this preview.",
                            style = MaterialTheme.typography.bodySmall
                        )
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        TextButton(
                            enabled = post.id in knownLikeIds && post.id !in busyLikeIds,
                            onClick = {
                                val wasLiked = post.id in likedIds
                                busyLikeIds = busyLikeIds + post.id
                                scope.launch {
                                    try {
                                        CommunityLikesRepository.setLiked(post.id, !wasLiked)
                                        likedIds = if (wasLiked) likedIds - post.id else likedIds + post.id
                                        likeError = null
                                    } catch (failure: Exception) {
                                        likeError = failure.message ?: "Unable to update like."
                                    } finally {
                                        busyLikeIds = busyLikeIds - post.id
                                    }
                                }
                            }
                        ) {
                            Text(when {
                                post.id in busyLikeIds -> "Updating..."
                                post.id !in knownLikeIds -> "Loading likes..."
                                post.id in likedIds -> "♥ Liked"
                                else -> "♡ Like"
                            })
                        }
                        TextButton(onClick = { selectedPost = post }) {
                            Text("View comments")
                        }
                        if (post.authorId == session.userId && !post.hasMedia && post.kind == "post") {
                            TextButton(
                                enabled = deletingId == null,
                                onClick = { editingPost = post }
                            ) { Text("Edit my post") }
                            TextButton(
                                enabled = deletingId == null,
                                onClick = { pendingDelete = post }
                            ) { Text("Delete my post") }
                        }
                    }
                    Text(
                        post.createdAt.take(10),
                        style = MaterialTheme.typography.labelSmall
                    )
                }
            }
            if (posts.isNotEmpty()) {
                Text("Showing ${posts.size} community posts", style = MaterialTheme.typography.labelSmall)
            }
            if (hasMore && nextOffset + 30 <= 10_000) {
                OutlinedButton(
                    onClick = { nextOffset += 30 },
                    enabled = !loading && error == null
                ) { Text("Load more posts") }
            }
        }
    }
}

/** Text-only editing preview; no media or privileged backend changes. */
@Composable
private fun CommunityPostEditor(post: CommunityPost, onBack: () -> Unit, onSaved: () -> Unit) {
    var caption by remember(post.id) { mutableStateOf(post.caption) }
    var saving by remember(post.id) { mutableStateOf(false) }
    var error by remember(post.id) { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    Column(
        modifier = Modifier.fillMaxWidth().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        TextButton(onClick = onBack, enabled = !saving) { Text("← Back to Community") }
        Text("Edit text post", style = MaterialTheme.typography.headlineSmall)
        OutlinedTextField(
            value = caption,
            onValueChange = { if (it.length <= 2000) caption = it },
            label = { Text("Post caption") },
            minLines = 4,
            maxLines = 10,
            enabled = !saving,
            modifier = Modifier.fillMaxWidth()
        )
        Text("${caption.length}/2,000 characters", style = MaterialTheme.typography.labelSmall)
        if (error != null) Text(error!!, color = MaterialTheme.colorScheme.error)
        if (saving) LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
        Button(
            enabled = !saving && caption.trim().isNotEmpty() && caption.trim() != post.caption,
            onClick = {
                saving = true
                error = null
                scope.launch {
                    try {
                        CommunityPostManager.editOwnTextPost(post, caption)
                        onSaved()
                    } catch (cancelled: CancellationException) {
                        throw cancelled
                    } catch (failure: Exception) {
                        error = failure.message ?: "Unable to edit post."
                    } finally {
                        saving = false
                    }
                }
            }
        ) { Text(if (saving) "Saving..." else "Save changes") }
    }
}
