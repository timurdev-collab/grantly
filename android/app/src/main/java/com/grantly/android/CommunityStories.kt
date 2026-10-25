package com.grantly.android

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant
import java.util.UUID

/**
 * Read-only iOS-style stories rail. Only existing RLS-visible, active,
 * unexpired stories are queried; never changes Community visibility policies.
 */
internal object CommunityStoriesRepository {
    suspend fun load(limit: Int = 24): List<CommunityPost> = withContext(Dispatchers.IO) {
        require(limit in 1..30) { "Invalid story limit." }
        val session = AuthRepository.activeSession()
        val base = BuildConfig.SUPABASE_URL.trimEnd('/')
        val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
        if (!base.startsWith("https://") || key.isBlank()) {
            throw IOException("Community stories are not configured.")
        }
        val now = Instant.now()
        val path = "/rest/v1/social_posts" +
            "?select=id,author_id,kind,caption,created_at,media_type,media_path,media_url,expires_at,is_active" +
            "&kind=eq.story&is_active=eq.true&expires_at=gt.${now}" +
            "&order=created_at.desc&limit=$limit"
        val request = (URL(base + path).openConnection() as HttpURLConnection)
        try {
            request.requestMethod = "GET"
            request.connectTimeout = 12_000
            request.readTimeout = 15_000
            request.instanceFollowRedirects = false
            request.setRequestProperty("apikey", key)
            request.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
            request.setRequestProperty("Accept", "application/json")
            val status = request.responseCode
            if (status !in 200..299) {
                throw IOException(
                    if (status == 401 || status == 403) "Sign in again to view Community stories."
                    else "Unable to load Community stories (HTTP $status)."
                )
            }
            val rows = JSONArray(request.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() })
            buildList {
                for (index in 0 until rows.length()) {
                    val row = rows.optJSONObject(index) ?: continue
                    val id = row.optString("id")
                    if (runCatching { UUID.fromString(id) }.isFailure) continue
                    if (!CommunityStoryRules.isCurrent(
                            row.optString("kind"),
                            row.optBoolean("is_active", false),
                            row.optString("expires_at").takeUnless { row.isNull("expires_at") },
                            Instant.now()
                        )) continue
                    val mediaType = row.optString("media_type").takeUnless { row.isNull("media_type") }
                    val mediaPath = row.optString("media_path").takeUnless { row.isNull("media_path") }
                    val legacyUrl = row.optString("media_url").takeUnless { row.isNull("media_url") }
                    add(
                        CommunityPost(
                            id = id,
                            authorId = row.optString("author_id"),
                            kind = "story",
                            caption = row.optString("caption").take(2000),
                            createdAt = row.optString("created_at"),
                            hasMedia = !mediaType.isNullOrBlank() || !mediaPath.isNullOrBlank() || !legacyUrl.isNullOrBlank(),
                            mediaType = mediaType,
                            mediaPath = mediaPath,
                            expiresAt = row.optString("expires_at").takeUnless { row.isNull("expires_at") }
                        )
                    )
                }
            }
        } finally {
            request.disconnect()
        }
    }
}

@Composable
internal fun CommunityStoriesRail(refresh: Int, onOpen: (CommunityPost) -> Unit) {
    val userId = AuthRepository.session?.userId
    var stories by remember(userId) { mutableStateOf<List<CommunityPost>>(emptyList()) }
    var loading by remember(userId) { mutableStateOf(false) }
    var error by remember(userId) { mutableStateOf<String?>(null) }
    var retry by remember(userId) { mutableIntStateOf(0) }
    var currentTime by remember(userId) { mutableStateOf(Instant.now()) }

    // Stories can expire while Community stays open; don't show stale story links
    // indefinitely until the next manual refresh.
    LaunchedEffect(userId) {
        while (true) {
            currentTime = Instant.now()
            delay(30_000)
        }
    }
    val visibleStories = stories.filter {
        CommunityStoryRules.isCurrent(it.kind, true, it.expiresAt, currentTime)
    }

    LaunchedEffect(userId, refresh, retry) {
        if (userId == null) {
            stories = emptyList()
            error = null
            return@LaunchedEffect
        }
        loading = true
        error = null
        try {
            stories = CommunityStoriesRepository.load()
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failure: Exception) {
            error = failure.message ?: "Unable to load stories."
        } finally {
            loading = false
        }
    }

    if (loading || error != null || visibleStories.isNotEmpty()) {
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text("Stories · last 24 hours", style = MaterialTheme.typography.titleSmall)
            if (loading) LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
            if (error != null) {
                Text(error!!, color = MaterialTheme.colorScheme.error)
                TextButton(onClick = { retry++ }, enabled = !loading) { Text("Retry stories") }
            }
            Row(
                modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                visibleStories.forEach { story ->
                    OutlinedButton(onClick = {
                        if (CommunityStoryRules.isCurrent(story.kind, true, story.expiresAt, Instant.now())) {
                            onOpen(story)
                        } else {
                            currentTime = Instant.now()
                        }
                    }) {
                        Text(if (story.hasMedia) "▶ Story" else "Story · ${story.createdAt.take(10)}")
                    }
                }
            }
        }
    }
}

/** Story media reuses the existing authenticated private photo/video previews. */
@Composable
internal fun CommunityStoryViewer(story: CommunityPost, onBack: () -> Unit) {
    when {
        story.mediaType == "image" && !story.mediaPath.isNullOrBlank() ->
            CommunityPhotoPreview(post = story, onBack = onBack)
        story.mediaType == "video" && !story.mediaPath.isNullOrBlank() ->
            CommunityVideoPreview(post = story, onBack = onBack)
        else -> Column(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            TextButton(onClick = onBack) { Text("← Back to Community") }
            Text("Community story", style = MaterialTheme.typography.headlineSmall)
            if (story.caption.isNotBlank()) Text(story.caption)
            if (story.hasMedia) {
                Text(
                    "This story uses a legacy or unsupported media format.",
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }
    }
}
