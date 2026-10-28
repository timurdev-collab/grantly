package com.grantly.android

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
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
import java.net.URI
import java.net.URL
import java.util.UUID

/** Only open complete HTTPS source links from administrator review data. */
internal object AdminSourceLinkRules {
    fun safeHttpsUrl(raw: String): String? {
        if (raw.isBlank() || raw.length > 2_048 ||
            raw.any { it.isWhitespace() || it.isISOControl() }) {
            return null
        }
        val uri = runCatching { URI(raw) }.getOrNull() ?: return null
        if (!uri.scheme.equals("https", ignoreCase = true) ||
            uri.host.isNullOrBlank() || uri.rawUserInfo != null || uri.port > 65_535) {
            return null
        }
        return uri.toString()
    }
}

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

internal data class AdminDraftDuplicateCandidate(
    val id: String,
    val title: String,
    val provider: String,
    val country: String,
    val similarityScore: Double?
)

/** Match iOS's 90% warning threshold without inventing missing server scores. */
internal object AdminDraftDuplicateRules {
    fun similarityScore(raw: Any?): Double? {
        val value = (raw as? Number)?.toDouble() ?: return null
        return value.takeIf { it.isFinite() && it in 0.0..100.0 }
    }

    fun isHighSimilarity(score: Double?): Boolean = score != null && score >= 90.0
}

internal data class AdminDraftReadiness(
    val ready: Boolean,
    val blockers: List<String>,
    val warnings: List<String>,
    val lastSuccessfulCheckAt: String
)

internal data class AdminDraftEvidence(
    val available: Boolean,
    val candidateUrl: String,
    val checkedAt: String,
    val pageTitle: String,
    val metaDescription: String,
    val detectedDeadline: String,
    val deadlineConfidence: Int?,
    val detectedCycle: String,
    val cycleConfidence: Int?,
    val detectedFundingType: String,
    val fundingConfidence: Int?,
    val detectedTuitionCoverage: String,
    val detectedStipend: String,
    val detectedAirfare: Boolean?,
    val detectedAccommodation: Boolean?,
    val detectedHealthInsurance: Boolean?,
    val detectedDegreeLevels: List<String>,
    val degreeConfidence: Int?,
    val detectedEligibleNationalities: List<String>,
    val eligibilityConfidence: Int?,
    val applicationExcerpt: String,
    val fundingExcerpt: String,
    val benefitsExcerpt: String,
    val eligibilityExcerpt: String,
    val applicationRequirementsExcerpt: String
)

/** Read-only history of accepted administrator edits, as exposed by the iOS RPC. */
internal data class AdminDraftProvenance(
    val fieldName: String,
    val provenanceType: String,
    val previousValue: String,
    val acceptedValue: String,
    val confidence: Int?,
    val excerpt: String,
    val sourceUrl: String,
    val acceptedAt: String
)

internal object AdminDraftRepository {
    // Keep unexpectedly large server responses from exhausting the UI process.
    // The draft page, readiness, evidence, and history responses are all bounded.
    private fun readBoundedJson(connection: HttpURLConnection): String =
        connection.inputStream.bufferedReader(Charsets.UTF_8).use { reader ->
            val response = StringBuilder()
            val buffer = CharArray(4_096)
            while (true) {
                val count = reader.read(buffer)
                if (count < 0) break
                if (response.length + count > 1_048_576) {
                    throw IOException("Administrator response exceeds the supported size.")
                }
                response.append(buffer, 0, count)
            }
            response.toString()
        }

    /** Read-only duplicate search used by iOS before administrators publish drafts. */
    suspend fun duplicates(draft: AdminDraftSummary): List<AdminDraftDuplicateCandidate> =
        withContext(Dispatchers.IO) {
            if (runCatching { UUID.fromString(draft.id) }.isFailure ||
                draft.title.isBlank() || draft.provider.isBlank() || draft.country.isBlank()) {
                throw IOException("The draft needs a title, provider, and country for duplicate review.")
            }
            val session = AuthRepository.activeSession()
            if (StudentProfileRepository.load().role != "admin" ||
                AuthRepository.session?.userId != session.userId) {
                throw IOException("Administrator access is required.")
            }
            val base = BuildConfig.SUPABASE_URL.trimEnd('/')
            val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
            if (!base.startsWith("https://") || key.isBlank()) {
                throw IOException("Draft review service is not configured.")
            }
            val connection = URL("$base/rest/v1/rpc/find_scholarship_duplicates")
                .openConnection() as HttpURLConnection
            try {
                connection.requestMethod = "POST"
                connection.instanceFollowRedirects = false
                connection.connectTimeout = 12_000
                connection.readTimeout = 15_000
                connection.doOutput = true
                connection.setRequestProperty("apikey", key)
                connection.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
                connection.setRequestProperty("Content-Type", "application/json")
                connection.setRequestProperty("Accept", "application/json")
                val body = JSONObject()
                    .put("p_title", draft.title.take(200))
                    .put("p_provider", draft.provider.take(120))
                    .put("p_country", draft.country.take(80))
                    .toString()
                connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
                val status = connection.responseCode
                if (status !in 200..299) {
                    throw IOException(if (status == 401 || status == 403) {
                        "Administrator access was denied. Please sign in again."
                    } else {
                        "Unable to check possible duplicates (HTTP $status)."
                    })
                }
                val rows = JSONArray(readBoundedJson(connection))
                if (AuthRepository.session?.userId != session.userId) {
                    throw IOException("Your account changed. Please reload.")
                }
                // A truncated or malformed duplicate response cannot safely count as
                // a completed review. Fail closed instead of showing "no matches".
                if (rows.length() > 20) {
                    throw IOException("Duplicate review returned too many results. Publication review is incomplete.")
                }
                buildList {
                    for (index in 0 until rows.length()) {
                        val row = rows.optJSONObject(index)
                            ?: throw IOException("Duplicate review returned an invalid result. Please retry.")
                        val id = row.optString("id")
                        if (runCatching { UUID.fromString(id) }.isFailure) {
                            throw IOException("Duplicate review returned an invalid scholarship ID. Please retry.")
                        }
                        if (id == draft.id) continue
                        add(AdminDraftDuplicateCandidate(
                            id = id,
                            title = row.optString("title").take(200),
                            provider = row.optString("provider").take(120),
                            country = row.optString("country").take(80),
                            similarityScore = AdminDraftDuplicateRules.similarityScore(
                                row.opt("similarity_score")
                            )
                        ))
                    }
                }
            } finally {
                connection.disconnect()
            }
        }

    /** The existing server-enforced history RPC; never accepts or changes fields. */
    suspend fun provenance(draftId: String): List<AdminDraftProvenance> =
        withContext(Dispatchers.IO) {
            val validatedId = try {
                UUID.fromString(draftId).toString()
            } catch (_: IllegalArgumentException) {
                throw IOException("Invalid scholarship draft.")
            }
            val session = AuthRepository.activeSession()
            if (StudentProfileRepository.load().role != "admin" ||
                AuthRepository.session?.userId != session.userId) {
                throw IOException("Administrator access is required.")
            }
            val base = BuildConfig.SUPABASE_URL.trimEnd('/')
            val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
            if (!base.startsWith("https://") || key.isBlank()) {
                throw IOException("Draft review service is not configured.")
            }
            val connection = URL("$base/rest/v1/rpc/scholarship_field_provenance_history")
                .openConnection() as HttpURLConnection
            try {
                connection.requestMethod = "POST"
                connection.instanceFollowRedirects = false
                connection.connectTimeout = 12_000
                connection.readTimeout = 15_000
                connection.doOutput = true
                connection.setRequestProperty("apikey", key)
                connection.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
                connection.setRequestProperty("Content-Type", "application/json")
                connection.setRequestProperty("Accept", "application/json")
                val body = JSONObject().put("p_scholarship_id", validatedId).toString()
                connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
                val status = connection.responseCode
                if (status !in 200..299) {
                    throw IOException(if (status == 401 || status == 403) {
                        "Administrator access was denied. Please sign in again."
                    } else {
                        "Unable to load field history (HTTP $status)."
                    })
                }
                val rows = JSONArray(
                    readBoundedJson(connection)
                )
                if (AuthRepository.session?.userId != session.userId) {
                    throw IOException("Your account changed. Please reload.")
                }
                fun displayValue(value: Any?): String = when (value) {
                    null, JSONObject.NULL -> "Not set"
                    is String -> value.take(180)
                    is Boolean -> if (value) "Yes" else "No"
                    is Number -> value.toString().take(80)
                    is JSONArray -> (0 until minOf(value.length(), 8))
                        .mapNotNull { index ->
                            when (val item = value.opt(index)) {
                                is String -> item.take(60)
                                is Boolean, is Number -> item.toString().take(60)
                                else -> null
                            }
                        }.joinToString(", ").take(180).ifBlank { "Not set" }
                    else -> "Structured value"
                }
                buildList {
                    for (index in 0 until minOf(rows.length(), 30)) {
                        val row = rows.optJSONObject(index) ?: continue
                        val field = row.optString("field_name").take(80)
                        if (field.isBlank()) continue
                        add(AdminDraftProvenance(
                            fieldName = field.replace('_', ' '),
                            provenanceType = row.optString("provenance_type").take(40),
                            previousValue = displayValue(row.opt("previous_value")),
                            acceptedValue = displayValue(row.opt("accepted_value")),
                            confidence = if (row.isNull("confidence")) null else
                                row.optInt("confidence", -1).takeIf { it in 0..100 },
                            excerpt = if (row.isNull("evidence_excerpt")) "" else
                                row.optString("evidence_excerpt").take(240),
                            sourceUrl = if (row.isNull("source_url")) "" else
                                row.optString("source_url")
                                    .takeIf { it.length <= 2_048 }.orEmpty(),
                            acceptedAt = if (row.isNull("accepted_at")) "" else
                                row.optString("accepted_at").take(16)
                        ))
                    }
                }
            } finally {
                connection.disconnect()
            }
        }

    /** Read-only evidence extracted by the existing iOS-compatible RPC. */
    suspend fun evidence(draftId: String): AdminDraftEvidence = withContext(Dispatchers.IO) {
        val validatedId = try {
            UUID.fromString(draftId).toString()
        } catch (_: IllegalArgumentException) {
            throw IOException("Invalid scholarship draft.")
        }
        val session = AuthRepository.activeSession()
        if (StudentProfileRepository.load().role != "admin" ||
            AuthRepository.session?.userId != session.userId) {
            throw IOException("Administrator access is required.")
        }
        val base = BuildConfig.SUPABASE_URL.trimEnd('/')
        val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
        if (!base.startsWith("https://") || key.isBlank()) {
            throw IOException("Draft review service is not configured.")
        }
        val connection = URL("$base/rest/v1/rpc/scholarship_draft_source_evidence")
            .openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.instanceFollowRedirects = false
            connection.connectTimeout = 12_000
            connection.readTimeout = 15_000
            connection.doOutput = true
            connection.setRequestProperty("apikey", key)
            connection.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Accept", "application/json")
            val body = JSONObject().put("p_scholarship_id", validatedId).toString()
            connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            val status = connection.responseCode
            if (status !in 200..299) {
                throw IOException(if (status == 401 || status == 403) {
                    "Administrator access was denied. Please sign in again."
                } else {
                    "Unable to load source evidence (HTTP $status)."
                })
            }
            val result = JSONObject(
                readBoundedJson(connection)
            )
            if (AuthRepository.session?.userId != session.userId) {
                throw IOException("Your account changed. Please reload.")
            }
            if (!result.has("available") || result.isNull("available")) {
                throw IOException("The source evidence service returned an incomplete result.")
            }
            fun field(name: String, limit: Int = 240): String =
                if (result.isNull(name)) "" else result.optString(name).take(limit)
            fun confidence(name: String): Int? =
                if (result.isNull(name)) null else result.optInt(name, -1)
                    .takeIf { it in 0..100 }
            // Preserve unknown separately from an explicit false detection.
            fun detectedFlag(name: String): Boolean? = result.opt(name) as? Boolean
            val levels = result.optJSONArray("detected_degree_levels")
            val nationalities = result.optJSONArray("detected_eligible_nationalities")
            AdminDraftEvidence(
                available = result.getBoolean("available"),
                candidateUrl = if (result.isNull("candidate_url")) "" else
                    result.optString("candidate_url").takeIf { it.length <= 2_048 }.orEmpty(),
                checkedAt = field("checked_at", 10),
                pageTitle = field("page_title", 180),
                metaDescription = field("meta_description", 240),
                detectedDeadline = field("detected_deadline", 10),
                deadlineConfidence = confidence("deadline_confidence"),
                detectedCycle = field("detected_cycle", 80),
                cycleConfidence = confidence("cycle_confidence"),
                detectedFundingType = field("detected_funding_type", 80),
                fundingConfidence = confidence("funding_confidence"),
                detectedTuitionCoverage = field("detected_tuition_coverage", 120),
                detectedStipend = field("detected_stipend", 120),
                detectedAirfare = detectedFlag("detected_airfare"),
                detectedAccommodation = detectedFlag("detected_accommodation"),
                detectedHealthInsurance = detectedFlag("detected_health_insurance"),
                detectedDegreeLevels = if (levels == null) emptyList() else
                    (0 until minOf(levels.length(), 8)).mapNotNull {
                        levels.optString(it).take(60).takeIf(String::isNotBlank)
                    },
                degreeConfidence = confidence("degree_confidence"),
                detectedEligibleNationalities = if (nationalities == null) emptyList() else
                    (0 until minOf(nationalities.length(), 12)).mapNotNull {
                        nationalities.optString(it).take(60).takeIf(String::isNotBlank)
                    },
                eligibilityConfidence = confidence("eligibility_confidence"),
                applicationExcerpt = field("application_excerpt", 300),
                fundingExcerpt = field("funding_excerpt", 300),
                benefitsExcerpt = field("benefits_excerpt", 300),
                eligibilityExcerpt = field("eligibility_excerpt", 300),
                applicationRequirementsExcerpt = field("application_requirements_excerpt", 300)
            )
        } finally {
            connection.disconnect()
        }
    }

    /** Read-only, server-authoritative publication check; never updates a draft. */
    suspend fun readiness(draftId: String): AdminDraftReadiness = withContext(Dispatchers.IO) {
        val validatedId = try {
            UUID.fromString(draftId).toString()
        } catch (_: IllegalArgumentException) {
            throw IOException("Invalid scholarship draft.")
        }
        val session = AuthRepository.activeSession()
        if (StudentProfileRepository.load().role != "admin" ||
            AuthRepository.session?.userId != session.userId) {
            throw IOException("Administrator access is required.")
        }
        val base = BuildConfig.SUPABASE_URL.trimEnd('/')
        val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
        if (!base.startsWith("https://") || key.isBlank()) {
            throw IOException("Draft review service is not configured.")
        }
        val connection = URL("$base/rest/v1/rpc/scholarship_draft_readiness")
            .openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.instanceFollowRedirects = false
            connection.connectTimeout = 12_000
            connection.readTimeout = 15_000
            connection.doOutput = true
            connection.setRequestProperty("apikey", key)
            connection.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Accept", "application/json")
            val body = JSONObject().put("p_scholarship_id", validatedId).toString()
            connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            val status = connection.responseCode
            if (status !in 200..299) {
                throw IOException(if (status == 401 || status == 403) {
                    "Administrator access was denied. Please sign in again."
                } else {
                    "Unable to check publication readiness (HTTP $status)."
                })
            }
            val result = JSONObject(
                readBoundedJson(connection)
            )
            if (AuthRepository.session?.userId != session.userId) {
                throw IOException("Your account changed. Please reload.")
            }
            if (!result.has("ready") || result.isNull("ready")) {
                throw IOException("The readiness service returned an incomplete result.")
            }
            fun messages(field: String): List<String> {
                val values = result.optJSONArray(field) ?: return emptyList()
                return (0 until minOf(values.length(), 30)).mapNotNull { index ->
                    values.optString(index).take(240).takeIf { it.isNotBlank() }
                }
            }
            AdminDraftReadiness(
                ready = result.getBoolean("ready"),
                blockers = messages("blockers"),
                warnings = messages("warnings"),
                lastSuccessfulCheckAt = result.optString("last_successful_check_at")
                    .take(10).takeUnless { it == "null" }.orEmpty()
            )
        } finally {
            connection.disconnect()
        }
    }

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
                readBoundedJson(connection)
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
                        // Keep the full server revision so same-day changes invalidate stale editor state.
                        updatedAt = row.optString("updated_at").take(64),
                        fundingType = row.optString("funding_type").take(80),
                        deadline = if (row.isNull("deadline")) "" else row.optString("deadline").take(10),
                        linkStatus = if (row.isNull("link_status")) "" else row.optString("link_status").take(50),
                        officialUrl = if (row.isNull("official_url")) "" else
                            row.optString("official_url").takeIf { it.length <= 2_048 }.orEmpty()
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
 * Admin-only draft review with explicit basic editing and server-gated publishing.
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
    // Invalidate in-flight reviews even when a draft is closed and reopened.
    var selectionEpoch by remember(userId) { mutableIntStateOf(0) }
    var searchQuery by remember(userId) { mutableStateOf("") }
    var readinessByDraft by remember(userId) {
        mutableStateOf<Map<String, AdminDraftReadiness>>(emptyMap())
    }
    var evidenceByDraft by remember(userId) {
        mutableStateOf<Map<String, AdminDraftEvidence>>(emptyMap())
    }
    var provenanceByDraft by remember(userId) {
        mutableStateOf<Map<String, List<AdminDraftProvenance>>>(emptyMap())
    }
    var duplicatesByDraft by remember(userId) {
        mutableStateOf<Map<String, List<AdminDraftDuplicateCandidate>>>(emptyMap())
    }
    var duplicatesLoadingId by remember(userId) { mutableStateOf<String?>(null) }
    var duplicatesError by remember(userId) { mutableStateOf<String?>(null) }
    var provenanceLoadingId by remember(userId) { mutableStateOf<String?>(null) }
    var provenanceError by remember(userId) { mutableStateOf<String?>(null) }
    var evidenceLoadingId by remember(userId) { mutableStateOf<String?>(null) }
    var evidenceError by remember(userId) { mutableStateOf<String?>(null) }
    var readinessLoadingId by remember(userId) { mutableStateOf<String?>(null) }
    var readinessError by remember(userId) { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val uriHandler = LocalUriHandler.current

    LaunchedEffect(userId, refresh) {
        loading = true
        error = null
        drafts = emptyList()
        expandedDraftId = null
        readinessByDraft = emptyMap()
        evidenceByDraft = emptyMap()
        provenanceByDraft = emptyMap()
        duplicatesByDraft = emptyMap()
        duplicatesLoadingId = null
        duplicatesError = null
        provenanceLoadingId = null
        provenanceError = null
        evidenceError = null
        readinessError = null
        // Invalidate pending checks when the queue is refreshed.
        readinessLoadingId = null
        evidenceLoadingId = null
        hasMore = false
        offset = 0
        loadingMore = false
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

    val normalizedSearch = searchQuery.trim()
    val visibleDrafts = if (normalizedSearch.isEmpty()) drafts else drafts.filter { draft ->
        listOf(draft.title, draft.provider, draft.country, draft.verificationStatus,
            draft.fundingType, draft.deadline, draft.linkStatus)
            .any { it.contains(normalizedSearch, ignoreCase = true) }
    }

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("Draft scholarship review", style = MaterialTheme.typography.titleLarge)
        Text(
            "Administrator review. Editing requires saving; publication requires confirmation and server checks.",
            style = MaterialTheme.typography.bodySmall
        )
        OutlinedButton(onClick = { refresh++ }, enabled = !loading && !loadingMore) {
            Text("Refresh drafts")
        }
        OutlinedTextField(
            value = searchQuery,
            onValueChange = { searchQuery = it.take(120) },
            label = { Text("Search loaded drafts") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )
        if (drafts.isNotEmpty()) {
            Text(
                "Showing ${visibleDrafts.size} of ${drafts.size} loaded drafts. " +
                    "Search only covers loaded pages and includes funding, deadline, and link status.",
                style = MaterialTheme.typography.labelSmall
            )
        }
        if (loading) LinearProgressIndicator(Modifier.fillMaxWidth())
        if (error != null) Text(error!!, color = MaterialTheme.colorScheme.error)
        if (!loading && drafts.isEmpty() && error == null) {
            Text("No drafts found in the current queue.")
        }
        if (!loading && drafts.isNotEmpty() && visibleDrafts.isEmpty()) {
            Text("No loaded drafts match your search. Load more pages or change the search.")
        }
        visibleDrafts.forEach { draft ->
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
                            if (draft.updatedAt.isBlank()) "" else " · Updated ${draft.updatedAt.take(10)}",
                        style = MaterialTheme.typography.labelSmall
                    )
                    OutlinedButton(onClick = {
                        expandedDraftId = if (expandedDraftId == draft.id) null else draft.id
                        selectionEpoch++
                        // Reopening a review must not reuse cached publication approval,
                        // duplicate matches, evidence, or field history for this draft.
                        readinessByDraft = readinessByDraft - draft.id
                        duplicatesByDraft = duplicatesByDraft - draft.id
                        evidenceByDraft = evidenceByDraft - draft.id
                        provenanceByDraft = provenanceByDraft - draft.id
                        // A closed review must not keep another draft\u0027s request controls busy.
                        readinessLoadingId = null
                        evidenceLoadingId = null
                        provenanceLoadingId = null
                        duplicatesLoadingId = null
                        duplicatesError = null
                        readinessError = null
                        evidenceError = null
                        provenanceError = null
                    }) {
                        Text(if (expandedDraftId == draft.id) "Hide details" else "Review details")
                    }
                    if (expandedDraftId == draft.id) {
                        OutlinedButton(
                            enabled = readinessLoadingId == null && !loading,
                            onClick = {
                                readinessLoadingId = draft.id
                                readinessError = null
                                // Do not show a previous 'ready' verdict while rechecking.
                                readinessByDraft = readinessByDraft - draft.id
                                val requestedRefresh = refresh
                                val requestedSelectionEpoch = selectionEpoch
                                scope.launch {
                                    try {
                                        val result = AdminDraftRepository.readiness(draft.id)
                                        if (AuthRepository.session?.userId == userId &&
                                            refresh == requestedRefresh &&
                                            selectionEpoch == requestedSelectionEpoch &&
                                            expandedDraftId == draft.id) {
                                            readinessByDraft = readinessByDraft + (draft.id to result)
                                        }
                                    } catch (cancelled: CancellationException) {
                                        throw cancelled
                                    } catch (failure: Exception) {
                                        if (AuthRepository.session?.userId == userId &&
                                            refresh == requestedRefresh &&
                                            selectionEpoch == requestedSelectionEpoch &&
                                            expandedDraftId == draft.id) {
                                            readinessError = failure.message ?: "Readiness check failed."
                                        }
                                    } finally {
                                        if (refresh == requestedRefresh &&
                                            selectionEpoch == requestedSelectionEpoch &&
                                            readinessLoadingId == draft.id) {
                                            readinessLoadingId = null
                                        }
                                    }
                                }
                            }
                        ) {
                            Text(if (readinessLoadingId == draft.id) "Checking readiness…"
                                else if (readinessByDraft.containsKey(draft.id)) "Recheck readiness"
                                else "Check publication readiness")
                        }
                        readinessByDraft[draft.id]?.let { result ->
                            Text(
                                if (result.ready) "Server check: ready to publish"
                                else "Server check: ${result.blockers.size} publication blocker(s)",
                                style = MaterialTheme.typography.bodySmall
                            )
                            result.blockers.forEach { blocker ->
                                Text("Blocker: $blocker", style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.error)
                            }
                            result.warnings.forEach { warning ->
                                Text("Warning: $warning", style = MaterialTheme.typography.bodySmall)
                            }
                            if (result.lastSuccessfulCheckAt.isNotBlank()) {
                                Text("Source last checked: ${result.lastSuccessfulCheckAt}",
                                    style = MaterialTheme.typography.labelSmall)
                            }
                            Text("Read-only server assessment; this does not publish or approve.",
                                style = MaterialTheme.typography.labelSmall)
                        }
                        if (readinessError != null) {
                            Text(readinessError!!, color = MaterialTheme.colorScheme.error)
                        }
                        OutlinedButton(
                            enabled = duplicatesLoadingId == null && !loading,
                            onClick = {
                                duplicatesLoadingId = draft.id
                                duplicatesError = null
                                duplicatesByDraft = duplicatesByDraft - draft.id
                                val requestedRefresh = refresh
                                val requestedSelectionEpoch = selectionEpoch
                                scope.launch {
                                    try {
                                        val candidates = AdminDraftRepository.duplicates(draft)
                                        if (AuthRepository.session?.userId == userId &&
                                            refresh == requestedRefresh &&
                                            selectionEpoch == requestedSelectionEpoch &&
                                            expandedDraftId == draft.id) {
                                            duplicatesByDraft = duplicatesByDraft + (draft.id to candidates)
                                        }
                                    } catch (cancelled: CancellationException) {
                                        throw cancelled
                                    } catch (failure: Exception) {
                                        if (AuthRepository.session?.userId == userId &&
                                            refresh == requestedRefresh &&
                                            selectionEpoch == requestedSelectionEpoch &&
                                            expandedDraftId == draft.id) {
                                            duplicatesError = failure.message ?: "Duplicate check failed."
                                        }
                                    } finally {
                                        if (refresh == requestedRefresh &&
                                            selectionEpoch == requestedSelectionEpoch &&
                                            duplicatesLoadingId == draft.id) {
                                            duplicatesLoadingId = null
                                        }
                                    }
                                }
                            }
                        ) {
                            Text(if (duplicatesLoadingId == draft.id) "Checking duplicates…"
                                else if (duplicatesByDraft.containsKey(draft.id)) "Recheck possible duplicates"
                                else "Check possible duplicates")
                        }
                        duplicatesByDraft[draft.id]?.let { candidates ->
                            if (candidates.isEmpty()) {
                                Text("No similar scholarships returned by the server.",
                                    style = MaterialTheme.typography.bodySmall)
                            } else {
                                Text("Possible duplicates — review before publishing",
                                    fontWeight = FontWeight.SemiBold)
                                candidates.forEach { candidate ->
                                    val similarityLabel = candidate.similarityScore?.let { score ->
                                        val displayScore = if (score % 1.0 == 0.0) {
                                            score.toInt().toString()
                                        } else {
                                            score.toString()
                                        }
                                        " · $displayScore% similarity"
                                    } ?: " · similarity unavailable"
                                    Text("${candidate.title} · ${candidate.provider} · ${candidate.country}" +
                                        similarityLabel,
                                        style = MaterialTheme.typography.bodySmall)
                                    if (AdminDraftDuplicateRules.isHighSimilarity(candidate.similarityScore)) {
                                        Text("High similarity — review the existing record before publishing.",
                                            color = MaterialTheme.colorScheme.error,
                                            style = MaterialTheme.typography.bodySmall)
                                    }
                                }
                            }
                            Text("Read-only duplicate suggestions; no record was changed.",
                                style = MaterialTheme.typography.labelSmall)
                        }
                        if (duplicatesError != null) {
                            Text(duplicatesError!!, color = MaterialTheme.colorScheme.error)
                        }
                        OutlinedButton(
                            enabled = evidenceLoadingId == null && !loading,
                            onClick = {
                                evidenceLoadingId = draft.id
                                evidenceError = null
                                // Do not retain old evidence if a new request fails.
                                evidenceByDraft = evidenceByDraft - draft.id
                                val requestedRefresh = refresh
                                val requestedSelectionEpoch = selectionEpoch
                                scope.launch {
                                    try {
                                        val result = AdminDraftRepository.evidence(draft.id)
                                        if (AuthRepository.session?.userId == userId &&
                                            refresh == requestedRefresh &&
                                            selectionEpoch == requestedSelectionEpoch &&
                                            expandedDraftId == draft.id) {
                                            evidenceByDraft = evidenceByDraft + (draft.id to result)
                                        }
                                    } catch (cancelled: CancellationException) {
                                        throw cancelled
                                    } catch (failure: Exception) {
                                        if (AuthRepository.session?.userId == userId &&
                                            refresh == requestedRefresh &&
                                            selectionEpoch == requestedSelectionEpoch &&
                                            expandedDraftId == draft.id) {
                                            evidenceError = failure.message ?: "Source evidence unavailable."
                                        }
                                    } finally {
                                        if (refresh == requestedRefresh &&
                                            selectionEpoch == requestedSelectionEpoch &&
                                            evidenceLoadingId == draft.id) {
                                            evidenceLoadingId = null
                                        }
                                    }
                                }
                            }
                        ) {
                            Text(if (evidenceLoadingId == draft.id) "Loading evidence…"
                                else if (evidenceByDraft.containsKey(draft.id)) "Reload source evidence"
                                else "View source evidence")
                        }
                        evidenceByDraft[draft.id]?.let { evidence ->
                            if (!evidence.available) {
                                Text("No structured source evidence is available yet.",
                                    style = MaterialTheme.typography.bodySmall)
                            } else {
                                Text("Source evidence (read-only)",
                                    fontWeight = FontWeight.SemiBold)
                                val evidenceSource = AdminSourceLinkRules.safeHttpsUrl(evidence.candidateUrl)
                                if (evidenceSource != null) {
                                    OutlinedButton(onClick = {
                                        runCatching { uriHandler.openUri(evidenceSource) }
                                            .onFailure {
                                                evidenceError = "Unable to open the evidence source."
                                            }
                                    }) {
                                        Text("Open evidence source")
                                    }
                                }
                                if (evidence.checkedAt.isNotBlank()) {
                                    Text("Extracted: ${evidence.checkedAt}",
                                        style = MaterialTheme.typography.labelSmall)
                                }
                                if (evidence.pageTitle.isNotBlank()) {
                                    Text("Source page: ${evidence.pageTitle}",
                                        style = MaterialTheme.typography.bodySmall)
                                }
                                if (evidence.metaDescription.isNotBlank()) {
                                    Text("Source summary: ${evidence.metaDescription}",
                                        style = MaterialTheme.typography.bodySmall)
                                }
                                if (evidence.detectedDeadline.isNotBlank()) {
                                    Text("Detected deadline: ${evidence.detectedDeadline}" +
                                        (evidence.deadlineConfidence?.let { " ($it% confidence)" } ?: ""),
                                        style = MaterialTheme.typography.bodySmall)
                                }
                                if (evidence.detectedCycle.isNotBlank()) {
                                    Text("Detected application cycle: ${evidence.detectedCycle}" +
                                        (evidence.cycleConfidence?.let { " ($it% confidence)" } ?: ""),
                                        style = MaterialTheme.typography.bodySmall)
                                }
                                if (evidence.detectedFundingType.isNotBlank()) {
                                    Text("Detected funding: ${evidence.detectedFundingType}" +
                                        (evidence.fundingConfidence?.let { " ($it% confidence)" } ?: ""),
                                        style = MaterialTheme.typography.bodySmall)
                                }
                                if (evidence.detectedTuitionCoverage.isNotBlank()) {
                                    Text("Detected tuition coverage: ${evidence.detectedTuitionCoverage}",
                                        style = MaterialTheme.typography.bodySmall)
                                }
                                if (evidence.detectedStipend.isNotBlank()) {
                                    Text("Detected stipend: ${evidence.detectedStipend}",
                                        style = MaterialTheme.typography.bodySmall)
                                }
                                listOf(
                                    "Airfare" to evidence.detectedAirfare,
                                    "Accommodation" to evidence.detectedAccommodation,
                                    "Health insurance" to evidence.detectedHealthInsurance
                                ).forEach { (benefit, detected) ->
                                    if (detected != null) {
                                        Text("$benefit: ${if (detected) "Detected" else "Not detected"} in source",
                                            style = MaterialTheme.typography.bodySmall)
                                    }
                                }
                                if (evidence.detectedDegreeLevels.isNotEmpty()) {
                                    Text("Detected study levels: ${evidence.detectedDegreeLevels.joinToString(", ")}" +
                                        (evidence.degreeConfidence?.let { " ($it% confidence)" } ?: ""),
                                        style = MaterialTheme.typography.bodySmall)
                                }
                                if (evidence.detectedEligibleNationalities.isNotEmpty()) {
                                    Text("Detected eligible nationalities: ${evidence.detectedEligibleNationalities.joinToString(", ")}" +
                                        (evidence.eligibilityConfidence?.let { " ($it% confidence)" } ?: ""),
                                        style = MaterialTheme.typography.bodySmall)
                                }
                                if (evidence.applicationExcerpt.isNotBlank()) {
                                    Text("Application evidence: ${evidence.applicationExcerpt}",
                                        style = MaterialTheme.typography.bodySmall)
                                }
                                if (evidence.fundingExcerpt.isNotBlank()) {
                                    Text("Funding evidence: ${evidence.fundingExcerpt}",
                                        style = MaterialTheme.typography.bodySmall)
                                }
                                if (evidence.benefitsExcerpt.isNotBlank()) {
                                    Text("Benefits evidence: ${evidence.benefitsExcerpt}",
                                        style = MaterialTheme.typography.bodySmall)
                                }
                                if (evidence.eligibilityExcerpt.isNotBlank()) {
                                    Text("Eligibility evidence: ${evidence.eligibilityExcerpt}",
                                        style = MaterialTheme.typography.bodySmall)
                                }
                                if (evidence.applicationRequirementsExcerpt.isNotBlank()) {
                                    Text("Application requirements evidence: ${evidence.applicationRequirementsExcerpt}",
                                        style = MaterialTheme.typography.bodySmall)
                                }
                                Text("Extracted suggestions are not accepted or published.",
                                    style = MaterialTheme.typography.labelSmall)
                            }
                        }
                        if (evidenceError != null) {
                            Text(evidenceError!!, color = MaterialTheme.colorScheme.error)
                        }

                        OutlinedButton(
                            enabled = provenanceLoadingId == null && !loading,
                            onClick = {
                                provenanceLoadingId = draft.id
                                provenanceError = null
                                provenanceByDraft = provenanceByDraft - draft.id
                                val requestedRefresh = refresh
                                val requestedSelectionEpoch = selectionEpoch
                                scope.launch {
                                    try {
                                        val result = AdminDraftRepository.provenance(draft.id)
                                        if (AuthRepository.session?.userId == userId &&
                                            refresh == requestedRefresh &&
                                            selectionEpoch == requestedSelectionEpoch &&
                                            expandedDraftId == draft.id) {
                                            provenanceByDraft = provenanceByDraft + (draft.id to result)
                                        }
                                    } catch (cancelled: CancellationException) {
                                        throw cancelled
                                    } catch (failure: Exception) {
                                        if (AuthRepository.session?.userId == userId &&
                                            refresh == requestedRefresh &&
                                            selectionEpoch == requestedSelectionEpoch &&
                                            expandedDraftId == draft.id) {
                                            provenanceError = failure.message ?: "Field history unavailable."
                                        }
                                    } finally {
                                        if (refresh == requestedRefresh &&
                                            selectionEpoch == requestedSelectionEpoch &&
                                            provenanceLoadingId == draft.id) {
                                            provenanceLoadingId = null
                                        }
                                    }
                                }
                            }
                        ) {
                            Text(if (provenanceLoadingId == draft.id) "Loading field history…"
                                else if (provenanceByDraft.containsKey(draft.id)) "Reload field history"
                                else "View field history")
                        }
                        provenanceByDraft[draft.id]?.let { entries ->
                            if (entries.isEmpty()) {
                                Text("No accepted field changes recorded yet.",
                                    style = MaterialTheme.typography.bodySmall)
                            } else {
                                Text("Accepted field history (read-only)",
                                    fontWeight = FontWeight.SemiBold)
                                entries.forEach { entry ->
                                    Text(entry.fieldName.replaceFirstChar { it.uppercase() } +
                                        " · " + if (entry.provenanceType == "source_extracted")
                                            "Source-derived" else "Manual",
                                        style = MaterialTheme.typography.labelMedium)
                                    Text("${entry.previousValue} → ${entry.acceptedValue}",
                                        style = MaterialTheme.typography.bodySmall)
                                    entry.confidence?.let {
                                        Text("$it% source confidence",
                                            style = MaterialTheme.typography.labelSmall)
                                    }
                                    if (entry.excerpt.isNotBlank()) {
                                        Text(entry.excerpt, style = MaterialTheme.typography.bodySmall)
                                    }
                                    val supportingSource = AdminSourceLinkRules.safeHttpsUrl(entry.sourceUrl)
                                    if (supportingSource != null) {
                                        OutlinedButton(onClick = {
                                            runCatching { uriHandler.openUri(supportingSource) }
                                                .onFailure {
                                                    provenanceError = "Unable to open supporting source."
                                                }
                                        }) {
                                            Text("Open supporting source")
                                        }
                                    }
                                    if (entry.acceptedAt.isNotBlank()) {
                                        Text("Accepted ${entry.acceptedAt}",
                                            style = MaterialTheme.typography.labelSmall)
                                    }
                                    HorizontalDivider()
                                }
                            }
                        }
                        if (provenanceError != null) {
                            Text(provenanceError!!, color = MaterialTheme.colorScheme.error)
                        }
                        Text("Funding: ${draft.fundingType.ifBlank { "Not specified" }}", style = MaterialTheme.typography.bodySmall)
                        Text("Deadline: ${draft.deadline.ifBlank { "Not confirmed" }}", style = MaterialTheme.typography.bodySmall)
                        Text("Source link: ${draft.linkStatus.ifBlank { "Not checked" }}", style = MaterialTheme.typography.bodySmall)
                        val officialSource = AdminSourceLinkRules.safeHttpsUrl(draft.officialUrl)
                        if (officialSource != null) {
                            Text("Official source: $officialSource", style = MaterialTheme.typography.bodySmall)
                            OutlinedButton(onClick = {
                                runCatching { uriHandler.openUri(officialSource) }
                                    .onFailure { error = "Unable to open the official source." }
                            }) {
                                Text("Open official source")
                            }
                        }
                        AdminDraftEditor(draft) { refresh++ }
                        AdminDraftPublisher(
                            draft = draft,
                            readiness = readinessByDraft[draft.id],
                            duplicates = duplicatesByDraft[draft.id],
                            onPublished = { refresh++ }
                        )
                        Text("Advanced draft fields are not yet editable on Android.",
                            style = MaterialTheme.typography.labelSmall)
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
                    val requestedOffset = offset
                    val requestedRefresh = refresh
                    scope.launch {
                        try {
                            val page = AdminDraftRepository.load(requestedOffset)
                            // A refresh or account switch must not append an older page.
                            if (AuthRepository.session?.userId == userId &&
                                refresh == requestedRefresh && offset == requestedOffset) {
                                val seen = drafts.map { it.id }.toHashSet()
                                drafts = drafts + page.items.filter { seen.add(it.id) }
                                hasMore = page.hasMore
                                offset = requestedOffset + 15
                            }
                        } catch (cancelled: CancellationException) {
                            throw cancelled
                        } catch (failure: Exception) {
                            if (AuthRepository.session?.userId == userId &&
                                refresh == requestedRefresh && offset == requestedOffset) {
                                error = failure.message ?: "Unable to load more drafts."
                            }
                        } finally {
                            if (refresh == requestedRefresh) loadingMore = false
                        }
                    }
                }
            ) { Text(if (loadingMore) "Loading…" else "Load more drafts") }
        }
    }
}
