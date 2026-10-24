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
import kotlinx.coroutines.withContext
import org.json.JSONArray
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/** Read-only social preview. The existing RLS policy determines which posts are visible. */
internal data class CommunityPost(
    val id: String,
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
            "?select=id,kind,caption,created_at,media_type" +
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
                            kind = kind,
                            caption = row.optString("caption").take(4000),
                            createdAt = row.optString("created_at"),
                            hasMedia = !row.isNull("media_type") && row.optString("media_type").isNotBlank()
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

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        TextButton(onClick = onBack) { Text("← Back to Home") }
        Text("Community", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        Text(
            "Read-only preview of posts you are permitted to see. Creating posts, comments, likes and media playback are not available on Android yet.",
            style = MaterialTheme.typography.bodySmall
        )
        if (session == null) {
            Text("Sign in from the Profile tab to view community posts.")
        } else {
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
                    TextButton(onClick = { selectedPost = post }) {
                        Text("View comments")
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
