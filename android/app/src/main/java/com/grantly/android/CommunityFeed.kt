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

internal object CommunityFeedRepository {
    suspend fun load(limit: Int = 30): List<CommunityPost> = withContext(Dispatchers.IO) {
        require(limit in 1..50) { "Invalid community page size." }
        val session = AuthRepository.activeSession()
        val base = BuildConfig.SUPABASE_URL.trimEnd('/')
        val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
        if (!base.startsWith("https://") || key.isBlank()) {
            throw IOException("Community service is not configured.")
        }
        // Explicitly exclude inactive posts; server RLS additionally enforces visibility and blocks.
        val path = "/rest/v1/social_posts" +
            "?select=id,kind,caption,created_at,media_type" +
            "&kind=neq.story&is_active=eq.true&order=created_at.desc&limit=$limit"
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
            buildList {
                for (index in 0 until rows.length()) {
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
    var refresh by remember { mutableIntStateOf(0) }

    LaunchedEffect(session?.userId, refresh) {
        if (session == null) {
            posts = emptyList()
            error = null
            loading = false
        } else {
            loading = true
            error = null
            try {
                posts = CommunityFeedRepository.load()
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
            OutlinedButton(onClick = { refresh++ }, enabled = !loading) { Text("Refresh posts") }
            if (loading) LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
            if (error != null) {
                Text(error!!, color = MaterialTheme.colorScheme.error)
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
                    Text(
                        post.createdAt.take(10),
                        style = MaterialTheme.typography.labelSmall
                    )
                }
            }
        }
    }
}
