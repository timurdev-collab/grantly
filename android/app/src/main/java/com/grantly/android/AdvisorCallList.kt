package com.grantly.android

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/** Read-only call history for active advisor/student assignments. No call is created or joined. */
internal data class AdvisorCallListItem(
    val id: String,
    val assignmentId: String,
    val studentName: String,
    val status: String,
    val scheduledFor: String,
    val createdAt: String,
    val recordingRequested: Boolean
)

internal object AdvisorCallListRules {
    private val joinableStatuses = setOf("requested", "scheduled", "active")

    fun isVisible(callId: String, assignmentId: String, status: String, activeAssignments: Set<String>): Boolean =
        status in joinableStatuses &&
            assignmentId in activeAssignments &&
            runCatching { AdvisorCallPreparationRules.validCallId(callId) }.getOrNull() == callId &&
            runCatching { AdvisorCallPreparationRules.validCallId(assignmentId) }.getOrNull() == assignmentId

    fun label(status: String): String = when (status) {
        "requested" -> "Requested"
        "scheduled" -> "Scheduled"
        "active" -> "Active"
        else -> "Unavailable"
    }

    private const val PAGE_SIZE = 100
    private const val MAX_SCANNED_ROWS = 300

    /** Scan at most three server pages; some rows may belong to inactive assignments. */
    fun scanPages(): IntRange = 0 until (MAX_SCANNED_ROWS / PAGE_SIZE)

    fun shouldScanNext(fetchedRows: Int, visibleRows: Int, pageIndex: Int): Boolean =
        fetchedRows == PAGE_SIZE && visibleRows < PAGE_SIZE &&
            pageIndex + 1 < MAX_SCANNED_ROWS / PAGE_SIZE

    /**
     * Keyset cursor follows the server's created_at DESC, id DESC ordering.
     * Offset paging can skip calls if new rows are inserted between requests.
     * Encode the entire PostgREST filter so timestamp offsets cannot be
     * misinterpreted as query separators.
     */
    fun nextPageFilter(createdAt: String, callId: String): String {
        val timestamp = try { OffsetDateTime.parse(createdAt).toString() } catch (_: Exception) {
            throw IOException("Invalid call list page cursor.")
        }
        val id = try { AdvisorCallPreparationRules.validCallId(callId) } catch (_: Exception) {
            throw IOException("Invalid call list page cursor.")
        }
        val expression = "or=(created_at.lt.$timestamp,and(created_at.eq.$timestamp,id.lt.$id))"
        return "&or=" + URLEncoder.encode(expression.removePrefix("or="), "UTF-8")
    }

    /** Defensive deduplication if the server returns overlapping rows. */
    fun appendUnique(
        items: MutableList<AdvisorCallListItem>,
        seenIds: MutableSet<String>,
        item: AdvisorCallListItem
    ): Boolean {
        if (items.size >= PAGE_SIZE || !seenIds.add(item.id)) return false
        items.add(item)
        return true
    }

    /** Render at most one page of calls initially to keep the portal responsive. */
    fun page(items: List<AdvisorCallListItem>, limit: Int): List<AdvisorCallListItem> =
        items.take(limit.coerceIn(0, PAGE_SIZE))

    private val scheduledTimeFormat =
        DateTimeFormatter.ofPattern("MMM d, yyyy h:mm a XXX", Locale.ENGLISH)

    /** Supabase timestamps include an offset; show the actual device-local instant. */
    fun displayTime(value: String, zone: ZoneId = ZoneId.systemDefault()): String {
        if (value.isBlank() || value == "null") return "Not scheduled"
        return runCatching {
            OffsetDateTime.parse(value).atZoneSameInstant(zone).format(scheduledTimeFormat)
        }.getOrElse {
            // Preserve bounded legacy/unparseable values without inventing a timezone.
            value.take(40).replace('T', ' ')
        }
    }
}

internal object AdvisorCallListRepository {
    suspend fun load(expectedUserId: String): List<AdvisorCallListItem> {
        // The advisor-students RPC checks role, approval and the authenticated identity.
        val students = AdvisorStudentsRepository.load(expectedUserId)
        AdvisorCallPreparationRules.requireSameAccount(expectedUserId, AuthRepository.session?.userId)
        val active = students.filter { it.status == "active" }
            .associateBy { it.assignmentId }
        if (active.isEmpty()) return emptyList()

        return withContext(Dispatchers.IO) {
            val session = AuthRepository.activeSession()
            AdvisorCallPreparationRules.requireSameAccount(expectedUserId, session.userId)
            AdvisorCallPreparationRules.requireSameAccount(expectedUserId, AuthRepository.session?.userId)
            val base = BuildConfig.SUPABASE_URL.trimEnd('/')
            val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
            if (!base.startsWith("https://") || key.isBlank()) {
                throw IOException("Call service is not configured.")
            }
            // RLS restricts call rows to participants. Scan up to 300 recent
            // rows with a stable keyset cursor, returning at most 100 eligible
            // calls even when newer rows arrive during pagination.
            val eligibleCalls = ArrayList<AdvisorCallListItem>(100)
            val seenCallIds = HashSet<String>()
            var cursor: Pair<String, String>? = null
            for (pageIndex in AdvisorCallListRules.scanPages()) {
                AdvisorCallPreparationRules.requireSameAccount(expectedUserId, AuthRepository.session?.userId)
                val pageFilter = cursor?.let { (createdAt, callId) ->
                    AdvisorCallListRules.nextPageFilter(createdAt, callId)
                }.orEmpty()
                val url = "$base/rest/v1/advisor_call_sessions" +
                    "?select=id,assignment_id,status,scheduled_for,created_at,recording_requested" +
                    "&status=in.(requested,scheduled,active)&order=created_at.desc,id.desc" +
                    "&limit=100$pageFilter"
                val connection = URL(url).openConnection() as HttpURLConnection
                connection.instanceFollowRedirects = false
                val fetchedRows = try {
                    connection.requestMethod = "GET"
                    connection.connectTimeout = 12_000
                    connection.readTimeout = 15_000
                    connection.setRequestProperty("apikey", key)
                    connection.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
                    connection.setRequestProperty("Accept", "application/json")
                    AdvisorCallPreparationRules.requireSameAccount(expectedUserId, AuthRepository.session?.userId)
                    val code = connection.responseCode
                    if (code !in 200..299) {
                        throw IOException(if (code == 401 || code == 403)
                            "Call access denied. Sign in again."
                        else "Unable to load advisor calls (HTTP $code).")
                    }
                    val body = connection.inputStream.bufferedReader(Charsets.UTF_8).use { reader ->
                        val buffer = CharArray(4096)
                        val result = StringBuilder()
                        while (true) {
                            val count = reader.read(buffer)
                            if (count < 0) break
                            if (result.length + count > 131_072) {
                                throw IOException("Call list response is too large.")
                            }
                            result.append(buffer, 0, count)
                        }
                        result.toString()
                    }
                    AdvisorCallPreparationRules.requireSameAccount(expectedUserId, AuthRepository.session?.userId)
                    val rows = try { JSONArray(body) } catch (_: Exception) {
                        throw IOException("Unexpected call list response.")
                    }
                    if (rows.length() > 100) throw IOException("Unexpected call list size.")
                    if (rows.length() > 0) {
                        val last = rows.optJSONObject(rows.length() - 1)
                            ?: throw IOException("Unexpected call list cursor.")
                        cursor = last.optString("created_at") to last.optString("id")
                    }
                    for (index in 0 until rows.length()) {
                        val row = rows.optJSONObject(index) ?: continue
                        val callId = row.optString("id")
                        val assignmentId = row.optString("assignment_id")
                        val status = row.optString("status")
                        if (!AdvisorCallListRules.isVisible(callId, assignmentId, status, active.keys)) continue
                        AdvisorCallListRules.appendUnique(eligibleCalls, seenCallIds, AdvisorCallListItem(
                            id = callId,
                            assignmentId = assignmentId,
                            studentName = active[assignmentId]?.fullName.orEmpty().take(120),
                            status = status,
                            scheduledFor = row.optString("scheduled_for").take(40).takeUnless { it == "null" }.orEmpty(),
                            createdAt = row.optString("created_at").take(40),
                            recordingRequested = row.optBoolean("recording_requested", false)
                        ))
                    }
                    rows.length()
                } finally {
                    connection.disconnect()
                }
                if (!AdvisorCallListRules.shouldScanNext(fetchedRows, eligibleCalls.size, pageIndex)) break
            }
            eligibleCalls
        }
    }
}

@Composable
internal fun AdvisorCallListContent(userId: String) {
    var calls by remember(userId) { mutableStateOf<List<AdvisorCallListItem>>(emptyList()) }
    var loading by remember(userId) { mutableStateOf(true) }
    var error by remember(userId) { mutableStateOf<String?>(null) }
    var refresh by remember(userId) { mutableIntStateOf(0) }
    var visibleLimit by remember(userId) { mutableIntStateOf(20) }

    LaunchedEffect(userId, refresh) {
        visibleLimit = 20
        loading = true
        error = null
        calls = emptyList()
        try {
            val result = AdvisorCallListRepository.load(userId)
            if (AuthRepository.session?.userId == userId) calls = result
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failure: Exception) {
            if (AuthRepository.session?.userId == userId) {
                error = failure.message ?: "Unable to load calls."
            }
        } finally {
            if (AuthRepository.session?.userId == userId) loading = false
        }
    }

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("Advisor calls", style = MaterialTheme.typography.titleLarge)
        Text(
            "Existing call history for your active student relationships. Video calling is unavailable.",
            style = MaterialTheme.typography.bodySmall
        )
        OutlinedButton(onClick = { refresh++ }) { Text("Refresh calls") }
        when {
            loading -> CircularProgressIndicator()
            error != null -> Text(error.orEmpty(), color = MaterialTheme.colorScheme.error)
            calls.isEmpty() -> Text("No available calls for your active students.")
            else -> AdvisorCallListRules.page(calls, visibleLimit).forEach { call ->
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                        Text(call.studentName.ifBlank { "Student" }, fontWeight = FontWeight.SemiBold)
                        Text("Call status: ${AdvisorCallListRules.label(call.status)}")
                        Text("Scheduled: ${AdvisorCallListRules.displayTime(call.scheduledFor)}")
                        if (call.recordingRequested) {
                            Text("Recording was requested; this preview does not enable recording.")
                        }
                    }
                }
            }
        }
        if (!loading && error == null && calls.size > visibleLimit) {
            OutlinedButton(onClick = { visibleLimit = (visibleLimit + 20).coerceAtMost(100) }) {
                Text("Show more calls")
            }
        }
        Spacer(Modifier.height(6.dp))
    }
}
