package com.grantly.android

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

/** Read-only administrator advisor application queue; approvals are not implemented here. */
internal data class AdminAdvisorApplication(
    val id: String,
    val name: String,
    val title: String,
    val organization: String,
    val status: String,
    val version: Int,
    val specialties: List<String>,
    val bio: String,
    val reviewNote: String
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
                    val specialties = row.optJSONArray("specialties") ?: JSONArray()
                    add(AdminAdvisorApplication(
                        id = id,
                        name = row.optString("display_name").take(120),
                        title = row.optString("title").take(120),
                        organization = row.optString("organization").take(120),
                        status = row.optString("approval_status"),
                        version = row.optInt("application_version", 1).coerceAtLeast(1),
                        specialties = (0 until minOf(specialties.length(), 12))
                            .mapNotNull { specialties.optString(it).take(80).takeIf(String::isNotBlank) },
                        bio = row.optString("bio").take(1_000),
                        reviewNote = row.optString("review_note").take(500)
                    ))
                }
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
        Text("Read-only administrator preview. Approval, rejection and suspension must still be performed in the existing iOS admin interface.",
            style = MaterialTheme.typography.bodySmall)
        OutlinedButton(onClick = { refresh++ }, enabled = !loading) { Text("Refresh applications") }
        Row(
            modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            AdminAdvisorApplicationRules.filters.forEach { option ->
                FilterChip(
                    selected = filter == option,
                    onClick = { filter = option; expandedId = null },
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
                        OutlinedButton(onClick = {
                            expandedId = if (expandedId == application.id) null else application.id
                        }) { Text(if (expandedId == application.id) "Hide details" else "View details") }
                        if (expandedId == application.id) {
                            if (application.specialties.isNotEmpty()) {
                                Text("Specialties: " + application.specialties.joinToString(", "))
                            }
                            if (application.bio.isNotBlank()) Text(application.bio)
                            if (application.reviewNote.isNotBlank()) {
                                Text("Review note: ${application.reviewNote}")
                            }
                        }
                    }
                }
            }
        }
    }
}
