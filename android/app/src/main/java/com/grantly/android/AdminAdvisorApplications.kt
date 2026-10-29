package com.grantly.android

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

/** Administrator advisor application queue backed by the existing secured review RPCs. */
internal data class AdminAdvisorApplication(
    val id: String,
    val name: String,
    val title: String,
    val organization: String,
    val status: String,
    val version: Int,
    val specialties: List<String>,
    val bio: String,
    val reviewNote: String,
    val shortBio: String = "",
    val mentoringApproach: String = "",
    val yearsExperience: Int? = null,
    val countries: List<String> = emptyList(),
    val languages: List<String> = emptyList(),
    val introVideoUrl: String = "",
    val introVideoStoragePath: String = "",
    val linkedinUrl: String = "",
    val websiteUrl: String = ""
)

internal object AdminAdvisorApplicationRules {
    val filters = listOf("all", "pending", "changes_requested", "approved", "rejected", "suspended", "other")
    private val knownStatuses = filters.filterNot { it == "all" || it == "other" }.toSet()

    fun visible(
        items: List<AdminAdvisorApplication>,
        filter: String,
        query: String = ""
    ): List<AdminAdvisorApplication> {
        val search = query.trim()
        return items.filter { application ->
            val statusMatches = when (filter) {
                "all" -> true
                "other" -> application.status !in knownStatuses
                else -> application.status == filter
            }
            statusMatches && (search.isEmpty() || listOf(
                application.name, application.title, application.organization,
                application.specialties.joinToString(" ")
            ).any { it.contains(search, ignoreCase = true) })
        }
    }

    fun label(status: String): String =
        when (status) {
            "all" -> "All"
            "other" -> "Other"
            else -> advisorStatusTitle(status)
        }
}

/** Mirrors the action/status combinations in the read-only iOS reference. */
internal object AdminAdvisorReviewRules {
    fun actionsFor(status: String): List<String> = when (status) {
        "pending", "changes_requested" -> listOf("approve", "request_changes", "reject")
        "approved" -> listOf("suspend")
        "suspended" -> listOf("restore")
        else -> emptyList()
    }

    /** Never open untrusted schemes from administrator review data. */
    fun safeExternalUrl(raw: String): String? {
        val value = raw.trim()
        if (!value.startsWith("https://", ignoreCase = true)) return null
        return value.takeIf { runCatching {
            val url = URL(it)
            url.host.isNotBlank() && url.userInfo == null
        }.getOrDefault(false) }
    }

    fun label(action: String): String = when (action) {
        "approve" -> "Approve & publish"
        "request_changes" -> "Request changes"
        "reject" -> "Reject application"
        "suspend" -> "Suspend advisor"
        "restore" -> "Restore advisor"
        else -> "Unsupported action"
    }

    fun validationError(status: String, action: String, note: String): String? = when {
        action !in actionsFor(status) -> "This action is not available for the advisor's current status."
        note.length > 500 -> "Review notes must be 500 characters or fewer."
        action in listOf("request_changes", "reject") && note.isBlank() ->
            "Add a review note before requesting changes or rejecting an application."
        else -> null
    }
}

private data class AdminAdvisorDecision(
    val application: AdminAdvisorApplication,
    val action: String,
    val note: String
)

internal object AdminAdvisorApplicationsRepository {
    suspend fun load(userId: String): List<AdminAdvisorApplication> = withContext(Dispatchers.IO) {
        val session = AuthRepository.activeSession()
        if (session.userId != userId ||
            StudentProfileRepository.load().role != "admin" ||
            AuthRepository.session?.userId != userId) {
            throw IOException("Administrator access is required.")
        }
        val base = BuildConfig.SUPABASE_URL.trimEnd('/')
        val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
        if (!base.startsWith("https://") || key.isBlank()) {
            throw IOException("Advisor review service is not configured.")
        }
        val connection = URL("$base/rest/v1/rpc/admin_advisor_applications")
            .openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.instanceFollowRedirects = false
            connection.connectTimeout = 12_000
            connection.readTimeout = 20_000
            connection.doOutput = true
            connection.setRequestProperty("apikey", key)
            connection.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Accept", "application/json")
            connection.outputStream.use { it.write("{}".toByteArray(Charsets.UTF_8)) }
            val code = connection.responseCode
            if (code !in 200..299) {
                throw IOException(if (code == 401 || code == 403)
                    "Administrator access denied. Please sign in again."
                else "Unable to load advisor applications (HTTP $code).")
            }
            // Do not allow an unexpectedly large administrator response to exhaust memory.
            val response = connection.inputStream.bufferedReader(Charsets.UTF_8).use { reader ->
                val builder = StringBuilder()
                val buffer = CharArray(4_096)
                while (true) {
                    val count = reader.read(buffer)
                    if (count < 0) break
                    if (builder.length + count > 2_097_152) {
                        throw IOException("Advisor application queue exceeds the supported size.")
                    }
                    builder.append(buffer, 0, count)
                }
                builder.toString()
            }
            val rows = JSONArray(response)
            if (rows.length() > 300) {
                throw IOException("Advisor queue has more than 300 records; a paginated review is needed.")
            }
            if (AuthRepository.session?.userId != userId) {
                throw IOException("Your account changed. Please reload.")
            }
            buildList {
                for (index in 0 until rows.length()) {
                    val row = rows.optJSONObject(index)
                        ?: throw IOException("Advisor queue returned an invalid record.")
                    val id = row.optString("id")
                    if (runCatching { UUID.fromString(id) }.isFailure) {
                        throw IOException("Advisor queue returned an invalid advisor ID.")
                    }
                    fun listField(key: String): List<String> {
                        val values = row.optJSONArray(key) ?: JSONArray()
                        return (0 until minOf(values.length(), 12))
                            .mapNotNull { values.optString(it).take(80).takeIf(String::isNotBlank) }
                    }
                    fun textField(key: String, limit: Int): String =
                        if (row.isNull(key)) "" else row.optString(key).take(limit)
                    add(AdminAdvisorApplication(
                        id = id,
                        name = row.optString("display_name").take(120),
                        title = row.optString("title").take(120),
                        organization = row.optString("organization").take(120),
                        status = row.optString("approval_status"),
                        version = row.optInt("application_version", 1).coerceAtLeast(1),
                        specialties = listField("specialties"),
                        bio = textField("bio", 1_000),
                        reviewNote = textField("review_note", 500),
                        shortBio = textField("short_bio", 500),
                        mentoringApproach = textField("mentoring_approach", 1_000),
                        yearsExperience = if (row.isNull("years_experience")) null
                            else row.optInt("years_experience").takeIf { it in 0..80 },
                        countries = listField("countries"),
                        languages = listField("languages"),
                        introVideoUrl = textField("intro_video_url", 2_048),
                        introVideoStoragePath = textField("intro_video_storage_path", 500),
                        linkedinUrl = textField("linkedin_url", 2_048),
                        websiteUrl = textField("website_url", 2_048)
                    ))
                }
            }
        } finally {
            connection.disconnect()
        }
    }
    /** Admin-only mutation through the existing iOS RPC. Never bypasses server authorization. */
    suspend fun review(
        userId: String,
        application: AdminAdvisorApplication,
        action: String,
        note: String
    ) = withContext(Dispatchers.IO) {
        val cleanNote = note.trim()
        AdminAdvisorReviewRules.validationError(application.status, action, cleanNote)
            ?.let { throw IOException(it) }

        // Recheck role and the application version/status immediately before making a decision.
        val latest = load(userId).firstOrNull { it.id == application.id }
            ?: throw IOException("This application is no longer in the review queue.")
        if (latest.status != application.status || latest.version != application.version) {
            throw IOException("The application changed. Refresh and review the latest details.")
        }
        val session = AuthRepository.activeSession()
        if (session.userId != userId || AuthRepository.session?.userId != userId) {
            throw IOException("Your account changed. Please reload.")
        }
        val base = BuildConfig.SUPABASE_URL.trimEnd('/')
        val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
        if (!base.startsWith("https://") || key.isBlank()) {
            throw IOException("Advisor review service is not configured.")
        }
        val body = JSONObject()
            .put("p_user_id", application.id)
            .put("p_action", action)
            .put("p_note", if (cleanNote.isEmpty()) JSONObject.NULL else cleanNote)
            .toString()
        val connection = URL("$base/rest/v1/rpc/admin_review_advisor")
            .openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.instanceFollowRedirects = false
            connection.connectTimeout = 12_000
            connection.readTimeout = 20_000
            connection.doOutput = true
            connection.setRequestProperty("apikey", key)
            connection.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Accept", "application/json")
            connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            val code = connection.responseCode
            if (code !in 200..299) {
                throw IOException(if (code == 401 || code == 403)
                    "Administrator access denied. Please sign in again."
                else "Advisor decision was not accepted (HTTP $code). Refresh before retrying.")
            }
            if (AuthRepository.session?.userId != userId) {
                throw IOException("Your account changed. Please reload.")
            }
        } finally {
            connection.disconnect()
        }
    }
}

@Composable
internal fun AdminAdvisorApplicationsContent(userId: String) {
    var applications by remember(userId) { mutableStateOf<List<AdminAdvisorApplication>>(emptyList()) }
    var loading by remember(userId) { mutableStateOf(true) }
    var error by remember(userId) { mutableStateOf<String?>(null) }
    var refresh by remember(userId) { mutableIntStateOf(0) }
    var filter by remember(userId) { mutableStateOf("pending") }
    var search by remember(userId) { mutableStateOf("") }
    var expandedId by remember(userId) { mutableStateOf<String?>(null) }
    var reviewNote by remember(userId) { mutableStateOf("") }
    var actionError by remember(userId) { mutableStateOf<String?>(null) }
    var working by remember(userId) { mutableStateOf(false) }
    var pendingDecision by remember(userId) { mutableStateOf<AdminAdvisorDecision?>(null) }
    var openingVideoId by remember(userId) { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val uriHandler = LocalUriHandler.current

    LaunchedEffect(userId, refresh) {
        loading = true
        error = null
        applications = emptyList()
        expandedId = null
        try {
            val result = AdminAdvisorApplicationsRepository.load(userId)
            if (AuthRepository.session?.userId == userId) applications = result
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failure: Exception) {
            if (AuthRepository.session?.userId == userId) {
                error = failure.message ?: "Unable to load advisor applications."
            }
        } finally {
            loading = false
        }
    }

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("Advisor applications", style = MaterialTheme.typography.titleLarge)
        Text("Administrator review uses the existing secured review service. Confirm decisions carefully; authenticated testing is still pending.",
            style = MaterialTheme.typography.bodySmall)
        if (actionError != null) Text(actionError.orEmpty(), color = MaterialTheme.colorScheme.error)
        OutlinedButton(onClick = { refresh++ }, enabled = !loading && !working) { Text("Refresh applications") }
        Row(
            modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            AdminAdvisorApplicationRules.filters.forEach { option ->
                FilterChip(
                    selected = filter == option,
                    onClick = { filter = option; expandedId = null; reviewNote = ""; actionError = null },
                    label = { Text(AdminAdvisorApplicationRules.label(option)) }
                )
            }
        }
        OutlinedTextField(
            value = search,
            onValueChange = { search = it },
            label = { Text("Search applicants") },
            placeholder = { Text("Name, title, organization or specialty") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )
        if (loading) LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
        if (error != null) Text(error.orEmpty(), color = MaterialTheme.colorScheme.error)
        if (!loading && error == null) {
            val visible = AdminAdvisorApplicationRules.visible(applications, filter, search)
            Text("Showing ${visible.size} of ${applications.size} loaded applications.",
                style = MaterialTheme.typography.labelSmall)
            if (visible.isEmpty()) Text("No advisor applications match these filters.")
            visible.forEach { application ->
                ElevatedCard(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier.padding(14.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Text(application.name.ifBlank { "Advisor applicant" }, fontWeight = FontWeight.SemiBold)
                        Text(listOf(application.title, application.organization)
                            .filter(String::isNotBlank).joinToString(" · "),
                            style = MaterialTheme.typography.bodySmall)
                        Text("${AdminAdvisorApplicationRules.label(application.status)} · Application v${application.version}",
                            style = MaterialTheme.typography.labelMedium)
                        OutlinedButton(
                            onClick = {
                                expandedId = if (expandedId == application.id) null else application.id
                                reviewNote = ""
                                actionError = null
                            },
                            enabled = !working
                        ) { Text(if (expandedId == application.id) "Hide details" else "View details") }
                        if (expandedId == application.id) {
                            if (application.specialties.isNotEmpty()) {
                                Text("Specialties: " + application.specialties.joinToString(", "))
                            }
                            if (application.shortBio.isNotBlank()) {
                                Text("Summary: ${application.shortBio}")
                            }
                            Text("Background: " + application.bio.ifBlank { "Not provided" })
                            if (application.mentoringApproach.isNotBlank()) {
                                Text("How they help: ${application.mentoringApproach}")
                            }
                            application.yearsExperience?.let { Text("Experience: $it years") }
                            Text("Countries: " + application.countries.ifEmpty { listOf("Not provided") }.joinToString(", "))
                            Text("Languages: " + application.languages.ifEmpty { listOf("Not provided") }.joinToString(", "))
                            if (application.introVideoStoragePath.isNotBlank()) {
                                TextButton(
                                    enabled = !working && openingVideoId == null,
                                    onClick = {
                                        openingVideoId = application.id
                                        actionError = null
                                        scope.launch {
                                            try {
                                                val url = AdminAdvisorMediaRepository.signedIntroVideoUrl(
                                                    userId, application
                                                )
                                                if (AuthRepository.session?.userId == userId) {
                                                    uriHandler.openUri(url)
                                                }
                                            } catch (cancelled: CancellationException) {
                                                throw cancelled
                                            } catch (failure: Exception) {
                                                actionError = failure.message ?: "Unable to open introduction video."
                                            } finally {
                                                openingVideoId = null
                                            }
                                        }
                                    }
                                ) {
                                    Text(if (openingVideoId == application.id)
                                        "Opening secure introduction video…"
                                    else "Open secure introduction video")
                                }
                            }
                            listOf(
                                "introduction video" to
                                    (if (application.introVideoStoragePath.isBlank()) application.introVideoUrl else ""),
                                "LinkedIn" to application.linkedinUrl,
                                "website" to application.websiteUrl
                            ).forEach { (label, rawUrl) ->
                                AdminAdvisorReviewRules.safeExternalUrl(rawUrl)?.let { url ->
                                    TextButton(onClick = { uriHandler.openUri(url) }, enabled = !working) {
                                        Text("Open $label")
                                    }
                                }
                            }
                            if (application.reviewNote.isNotBlank()) {
                                Text("Previous review note: ${application.reviewNote}")
                            }
                            val actions = AdminAdvisorReviewRules.actionsFor(application.status)
                            if (actions.isNotEmpty()) {
                                OutlinedTextField(
                                    value = reviewNote,
                                    onValueChange = { reviewNote = it.take(500) },
                                    label = { Text("New review note") },
                                    supportingText = { Text("Required for Request changes and Reject.") },
                                    modifier = Modifier.fillMaxWidth(),
                                    minLines = 2,
                                    enabled = !working
                                )
                                actions.forEach { action ->
                                    OutlinedButton(
                                        onClick = {
                                            val note = reviewNote.trim()
                                            actionError = AdminAdvisorReviewRules.validationError(
                                                application.status, action, note
                                            )
                                            if (actionError == null) {
                                                pendingDecision = AdminAdvisorDecision(application, action, note)
                                            }
                                        },
                                        enabled = !working
                                    ) { Text(AdminAdvisorReviewRules.label(action)) }
                                }
                            } else {
                                Text("No review actions are available for this status.",
                                    style = MaterialTheme.typography.bodySmall)
                            }
                        }
                    }
                }
            }
        }
    }
    pendingDecision?.let { decision ->
        AlertDialog(
            onDismissRequest = { if (!working) pendingDecision = null },
            title = { Text(AdminAdvisorReviewRules.label(decision.action) + "?") },
            text = {
                Text("Confirm this decision for " +
                    decision.application.name.ifBlank { "the selected applicant" } +
                    (if (decision.note.isBlank()) "." else "\nReview note: " + decision.note))
            },
            confirmButton = {
                TextButton(
                    enabled = !working,
                    onClick = {
                        pendingDecision = null
                        working = true
                        actionError = null
                        scope.launch {
                            try {
                                AdminAdvisorApplicationsRepository.review(
                                    userId, decision.application, decision.action, decision.note
                                )
                                reviewNote = ""
                                refresh++
                            } catch (cancelled: CancellationException) {
                                throw cancelled
                            } catch (failure: Exception) {
                                actionError = failure.message ?: "Unable to submit advisor decision."
                            } finally {
                                working = false
                            }
                        }
                    }
                ) { Text("Confirm decision") }
            },
            dismissButton = {
                TextButton(onClick = { pendingDecision = null }, enabled = !working) {
                    Text("Cancel")
                }
            }
        )
    }
}
