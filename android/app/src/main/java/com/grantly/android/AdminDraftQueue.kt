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
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

/** A bounded, read-only slice of the existing iOS administrator draft queue. */
internal data class AdminDraftSummary(
    val id: String,
    val title: String,
    val provider: String,
    val country: String,
    val verificationStatus: String,
    val updatedAt: String,
    val fundingType: String,
    val deadline: String,
    val linkStatus: String,
    val officialUrl: String
)

internal data class AdminDraftPage(val items: List<AdminDraftSummary>, val hasMore: Boolean)

internal object AdminDraftRepository {
    suspend fun load(offset: Int = 0): AdminDraftPage = withContext(Dispatchers.IO) {
        require(offset in 0..5_000) { "Invalid draft page." }
        val session = AuthRepository.activeSession()
        // This client-side check is only a UX guard; Supabase RLS is authoritative.
        if (StudentProfileRepository.load().role != "admin" ||
            AuthRepository.session?.userId != session.userId) {
            throw IOException("Administrator access is required.")
        }
        val base = BuildConfig.SUPABASE_URL.trimEnd('/')
        val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
        if (!base.startsWith("https://") || key.isBlank()) {
            throw IOException("Draft review service is not configured.")
        }
        val url = "$base/rest/v1/scholarships" +
            "?select=id,title,provider,country,status,verification_status,updated_at,funding_type,deadline,link_status,official_url" +
            "&status=eq.draft&order=updated_at.desc,id.desc&limit=16&offset=$offset"
        val connection = URL(url).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "GET"
            connection.connectTimeout = 12_000
            connection.readTimeout = 15_000
            connection.instanceFollowRedirects = false
            connection.setRequestProperty("apikey", key)
            connection.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
            connection.setRequestProperty("Accept", "application/json")
            val status = connection.responseCode
            if (status !in 200..299) {
                throw IOException(if (status == 401 || status == 403) {
                    "Administrator access was denied. Please sign in again."
                } else {
                    "Unable to load draft scholarships (HTTP $status)."
                })
            }
            val rows = JSONArray(
                connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
            )
            if (AuthRepository.session?.userId != session.userId) {
                throw IOException("Your account changed. Please reload.")
            }
            val drafts = buildList {
                for (index in 0 until minOf(15, rows.length())) {
                    val row = rows.optJSONObject(index) ?: continue
                    val uuid = row.optString("id")
                    if (runCatching { UUID.fromString(uuid) }.isFailure ||
                        row.optString("status") != "draft") continue
                    add(AdminDraftSummary(
                        id = uuid,
                        title = row.optString("title").take(200).ifBlank { "Untitled draft" },
                        provider = row.optString("provider").take(120),
                        country = row.optString("country").take(80),
                        verificationStatus = row.optString("verification_status").take(60),
                        updatedAt = row.optString("updated_at").take(10),
                        fundingType = row.optString("funding_type").take(80),
                        deadline = if (row.isNull("deadline")) "" else row.optString("deadline").take(10),
                        linkStatus = if (row.isNull("link_status")) "" else row.optString("link_status").take(50),
                        officialUrl = if (row.isNull("official_url")) "" else row.optString("official_url").take(240)
                    ))
                }
            }
            AdminDraftPage(drafts, rows.length() > 15)
        } finally {
            connection.disconnect()
        }
    }
}

/**
 * Admin-only draft review preview. Does not edit, publish, or approve records.
 * Every page is fetched through the existing server-enforced RLS policies.
 */
@Composable
internal fun AdminDraftQueueContent(userId: String) {
    var drafts by remember(userId) { mutableStateOf<List<AdminDraftSummary>>(emptyList()) }
    var loading by remember(userId) { mutableStateOf(true) }
    var loadingMore by remember(userId) { mutableStateOf(false) }
    var hasMore by remember(userId) { mutableStateOf(false) }
    var offset by remember(userId) { mutableIntStateOf(0) }
    var error by remember(userId) { mutableStateOf<String?>(null) }
    var refresh by remember(userId) { mutableIntStateOf(0) }
    var expandedDraftId by remember(userId) { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(userId, refresh) {
        loading = true
        error = null
        drafts = emptyList()
        expandedDraftId = null
        hasMore = false
        try {
            val page = AdminDraftRepository.load()
            if (AuthRepository.session?.userId == userId) {
                drafts = page.items
                hasMore = page.hasMore
                offset = 15
            }
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failure: Exception) {
            error = failure.message ?: "Unable to load drafts."
        } finally {
            loading = false
        }
    }

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("Draft scholarship review", style = MaterialTheme.typography.titleLarge)
        Text(
            "Read-only administrator preview. Drafts are not published, approved, or changed here.",
            style = MaterialTheme.typography.bodySmall
        )
        OutlinedButton(onClick = { refresh++ }, enabled = !loading && !loadingMore) {
            Text("Refresh drafts")
        }
        if (loading) LinearProgressIndicator(Modifier.fillMaxWidth())
        if (error != null) Text(error!!, color = MaterialTheme.colorScheme.error)
        if (!loading && drafts.isEmpty() && error == null) {
            Text("No drafts found in the current queue.")
        }
        drafts.forEach { draft ->
            Surface(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(14.dp),
                tonalElevation = 1.dp
            ) {
                Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(draft.title, fontWeight = FontWeight.SemiBold)
                    Text(
                        listOf(draft.provider, draft.country).filter { it.isNotBlank() }
                            .joinToString(" · "),
                        style = MaterialTheme.typography.bodySmall
                    )
                    Text(
                        "Draft · ${draft.verificationStatus.ifBlank { "Unverified" }}" +
                            if (draft.updatedAt.isBlank()) "" else " · Updated ${draft.updatedAt}",
                        style = MaterialTheme.typography.labelSmall
                    )
                    OutlinedButton(onClick = {
                        expandedDraftId = if (expandedDraftId == draft.id) null else draft.id
                    }) {
                        Text(if (expandedDraftId == draft.id) "Hide details" else "Review details")
                    }
                    if (expandedDraftId == draft.id) {
                        Text("Funding: ${draft.fundingType.ifBlank { "Not specified" }}", style = MaterialTheme.typography.bodySmall)
                        Text("Deadline: ${draft.deadline.ifBlank { "Not confirmed" }}", style = MaterialTheme.typography.bodySmall)
                        Text("Source link: ${draft.linkStatus.ifBlank { "Not checked" }}", style = MaterialTheme.typography.bodySmall)
                        if (draft.officialUrl.startsWith("https://")) {
                            Text("Official source: ${draft.officialUrl}", style = MaterialTheme.typography.bodySmall)
                        }
                        Text("Read-only details. Editing and publishing are not available on Android yet.", style = MaterialTheme.typography.labelSmall)
                    }
                }
            }
        }
        if (hasMore) {
            OutlinedButton(
                enabled = !loading && !loadingMore && offset <= 5_000,
                onClick = {
                    loadingMore = true
                    error = null
                    scope.launch {
                        try {
                            val page = AdminDraftRepository.load(offset)
                            if (AuthRepository.session?.userId == userId) {
                                val seen = drafts.map { it.id }.toHashSet()
                                drafts = drafts + page.items.filter { seen.add(it.id) }
                                hasMore = page.hasMore
                                offset += 15
                            }
                        } catch (cancelled: CancellationException) {
                            throw cancelled
                        } catch (failure: Exception) {
                            error = failure.message ?: "Unable to load more drafts."
                        } finally {
                            loadingMore = false
                        }
                    }
                }
            ) { Text(if (loadingMore) "Loading…" else "Load more drafts") }
        }
    }
}
