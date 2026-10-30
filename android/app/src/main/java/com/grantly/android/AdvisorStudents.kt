package com.grantly.android

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.TextButton
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
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
import java.util.Locale
import java.util.UUID

/** Advisor student registrations; changes require advisor-scoped RPCs and confirmation. */
internal data class AdvisorStudentItem(
    val assignmentId: String,
    val studentId: String,
    val fullName: String,
    val status: String,
    val degreeLevel: String,
    val intendedMajor: String,
    val targetCountries: List<String>
)

internal object AdvisorStudentRules {
    // Role alone is insufficient: suspended or unapproved advisors must not read student records.
    fun canAccess(role: String, approvalStatus: String?): Boolean =
        AdvisorProfessionalProfileRules.canView(role, approvalStatus)

    fun pending(items: List<AdvisorStudentItem>): Int = items.count { it.status == "requested" }
    fun active(items: List<AdvisorStudentItem>): Int = items.count { it.status == "active" }
    fun visible(items: List<AdvisorStudentItem>, filter: String): List<AdvisorStudentItem> =
        when (filter) {
            "all" -> items
            "past" -> items.filter { it.status in setOf("declined", "ended") }
            "other" -> items.filterNot { it.status in setOf("requested", "active", "declined", "ended") }
            "requested", "active" -> items.filter { it.status == filter }
            else -> emptyList()
        }
    fun count(items: List<AdvisorStudentItem>, filter: String): Int = visible(items, filter).size
    fun search(items: List<AdvisorStudentItem>, query: String): List<AdvisorStudentItem> {
        val needle = query.trim().take(100).lowercase(Locale.ROOT)
        if (needle.isEmpty()) return items
        return items.filter { student ->
            sequenceOf(student.fullName, student.degreeLevel, student.intendedMajor)
                .plus(student.targetCountries.asSequence())
                .any { it.lowercase(Locale.ROOT).contains(needle) }
        }
    }
    fun page(items: List<AdvisorStudentItem>, limit: Int): List<AdvisorStudentItem> =
        items.take(limit.coerceAtLeast(0))
}

internal object AdvisorStudentsRepository {
    suspend fun load(userId: String): List<AdvisorStudentItem> = withContext(Dispatchers.IO) {
        val session = AuthRepository.activeSession()
        if (session.userId != userId) throw IOException("Your account changed. Refresh the advisor portal.")
        val role = StudentProfileRepository.load().role
        if (role != "advisor" || AuthRepository.session?.userId != userId) {
            throw IOException("An approved advisor account is required.")
        }
        // Recheck approval for every queue read, including the read before an
        // accept/decline/end mutation. Never rely on a previously verified tab.
        val approval = AdvisorApplicationStatusRepository.load(userId)?.approvalStatus
        if (!AdvisorStudentRules.canAccess(role, approval) ||
            AuthRepository.session?.userId != userId) {
            throw IOException("An approved advisor account is required.")
        }
        val base = BuildConfig.SUPABASE_URL.trimEnd('/')
        val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
        if (!base.startsWith("https://") || key.isBlank()) {
            throw IOException("Advisor portal is not configured.")
        }
        val connection = URL("$base/rest/v1/rpc/advisor_my_students").openConnection() as HttpURLConnection
        connection.instanceFollowRedirects = false
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 12_000
            connection.readTimeout = 15_000
            connection.doOutput = true
            connection.setRequestProperty("apikey", key)
            connection.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
            connection.setRequestProperty("Accept", "application/json")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.outputStream.use { it.write("{}".toByteArray(Charsets.UTF_8)) }
            val code = connection.responseCode
            if (code !in 200..299) {
                throw IOException(if (code == 401 || code == 403)
                    "Advisor access denied. Please sign in again."
                else "Could not load your students (HTTP $code).")
            }
            // The server RPC is scoped to auth.uid(). Keep the client response bounded too.
            val body = connection.inputStream.bufferedReader(Charsets.UTF_8).use { reader ->
                val chars = CharArray(4096)
                val result = StringBuilder()
                while (true) {
                    val count = reader.read(chars)
                    if (count < 0) break
                    result.append(chars, 0, count)
                    if (result.length > 512_000) throw IOException("Advisor student response is too large.")
                }
                result.toString()
            }
            val rows = JSONArray(body.ifBlank { "[]" })
            if (rows.length() > 300) throw IOException("Too many students for this preview.")
            if (AuthRepository.session?.userId != userId) {
                throw IOException("Your account changed. Refresh the advisor portal.")
            }
            buildList {
                for (index in 0 until rows.length()) {
                    val row = rows.optJSONObject(index) ?: continue
                    val assignmentId = row.optString("assignment_id")
                    val studentId = row.optString("student_id")
                    if (runCatching { UUID.fromString(assignmentId) }.isFailure ||
                        runCatching { UUID.fromString(studentId) }.isFailure) continue
                    val countries = row.optJSONArray("target_countries") ?: JSONArray()
                    add(AdvisorStudentItem(
                        assignmentId = assignmentId,
                        studentId = studentId,
                        fullName = row.optString("full_name").take(120),
                        status = row.optString("status").take(40),
                        degreeLevel = row.optString("degree_level").take(80),
                        intendedMajor = row.optString("intended_major").take(120),
                        targetCountries = (0 until minOf(countries.length(), 20))
                            .mapNotNull { countries.optString(it).take(80).takeIf(String::isNotBlank) }
                    ))
                }
            }
        } finally {
            connection.disconnect()
        }
    }
}

@Composable
internal fun AdvisorStudentsContent(userId: String) {
    var students by remember(userId) { mutableStateOf<List<AdvisorStudentItem>>(emptyList()) }
    var loading by remember(userId) { mutableStateOf(true) }
    var error by remember(userId) { mutableStateOf<String?>(null) }
    var refresh by remember(userId) { mutableIntStateOf(0) }
    var filter by remember(userId) { mutableStateOf("all") }
    var searchText by remember(userId) { mutableStateOf("") }
    var visibleLimit by remember(userId) { mutableIntStateOf(20) }
    var pendingDecision by remember(userId) { mutableStateOf<Pair<AdvisorStudentItem, String>?>(null) }
    var busyAssignment by remember(userId) { mutableStateOf<String?>(null) }
    var actionError by remember(userId) { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(userId, refresh) {
        loading = true
        error = null
        try {
            val result = AdvisorStudentsRepository.load(userId)
            if (AuthRepository.session?.userId == userId) students = result
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failure: Exception) {
            if (AuthRepository.session?.userId == userId) {
                error = failure.message ?: "Unable to load your students."
                students = emptyList()
            }
        } finally {
            if (AuthRepository.session?.userId == userId) loading = false
        }
    }

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("Advisor portal · My students", style = MaterialTheme.typography.titleLarge)
        Text("Registration actions use the existing advisor-authorized service. Confirm each decision before proceeding.",
            style = MaterialTheme.typography.bodySmall)
        if (actionError != null) Text(actionError.orEmpty(), color = MaterialTheme.colorScheme.error)
        if (loading) {
            CircularProgressIndicator()
        } else if (error != null) {
            Text(error.orEmpty(), color = MaterialTheme.colorScheme.error)
        } else {
            val searched = AdvisorStudentRules.search(students, searchText)
            Text("${AdvisorStudentRules.pending(searched)} requests · ${AdvisorStudentRules.active(searched)} active · ${searched.size} matching of ${students.size} total",
                fontWeight = FontWeight.SemiBold)
            OutlinedTextField(
                value = searchText,
                onValueChange = { searchText = it.take(100); visibleLimit = 20 },
                label = { Text("Search students") },
                placeholder = { Text("Name, degree, major, or destination") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )
            Row(
                modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                listOf(
                    "all" to "All", "requested" to "Requests",
                    "active" to "Active", "past" to "Past", "other" to "Other"
                ).forEach { (option, label) ->
                    FilterChip(
                        selected = filter == option,
                        onClick = { filter = option; visibleLimit = 20 },
                        label = { Text("$label (${AdvisorStudentRules.count(searched, option)})") }
                    )
                }
            }
            val filtered = AdvisorStudentRules.visible(searched, filter)
            if (filtered.isEmpty()) Text(if (searchText.isNotBlank()) "No students match this search and filter." else when (filter) {
                "requested" -> "No pending registration requests."
                "active" -> "Students you accept will appear here."
                "past" -> "No past registrations yet."
                "other" -> "No registrations with other statuses."
                else -> "No students in this category."
            })
            AdvisorStudentRules.page(filtered, visibleLimit).forEach { student ->
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(14.dp),
                        verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(student.fullName.ifBlank { "Student" }, fontWeight = FontWeight.SemiBold)
                        Text(if (student.status == "requested") "Registration requested"
                            else if (student.status == "active") "Active student"
                            else "Status: ${student.status}")
                        if (student.degreeLevel.isNotBlank()) Text("Degree: ${student.degreeLevel}")
                        if (student.intendedMajor.isNotBlank()) Text("Major: ${student.intendedMajor}")
                        if (student.targetCountries.isNotEmpty()) {
                            Text("Study destinations: ${student.targetCountries.joinToString(", ")}")
                        }
                        val actions = when (student.status) {
                            "requested" -> listOf("accept", "decline")
                            "active" -> listOf("end")
                            else -> emptyList()
                        }
                        actions.forEach { action ->
                            OutlinedButton(
                                onClick = { actionError = null; pendingDecision = student to action },
                                enabled = busyAssignment == null
                            ) { Text(AdvisorStudentActionRules.label(action)) }
                        }
                    }
                }
            }
            if (filtered.size > visibleLimit) {
                OutlinedButton(onClick = { visibleLimit += 20 }, modifier = Modifier.fillMaxWidth()) {
                    Text("Load 20 more students")
                }
            }
        }
        OutlinedButton(onClick = { refresh++ }, enabled = !loading, modifier = Modifier.fillMaxWidth()) {
            Text("Refresh advisor students")
        }
        Spacer(Modifier.height(8.dp))
    }
    pendingDecision?.let { (student, action) ->
        AlertDialog(
            onDismissRequest = { if (busyAssignment == null) pendingDecision = null },
            title = { Text(AdvisorStudentActionRules.label(action) + "?") },
            text = { Text("Apply this decision to ${student.fullName.ifBlank { "this student" }}? This changes their registration status.") },
            confirmButton = {
                TextButton(enabled = busyAssignment == null, onClick = {
                    if (busyAssignment != null) return@TextButton
                    busyAssignment = student.assignmentId
                    scope.launch {
                        try {
                            AdvisorStudentActionsRepository.perform(userId, student, action)
                            actionError = null
                            pendingDecision = null
                            refresh++
                        } catch (cancelled: CancellationException) {
                            throw cancelled
                        } catch (failure: Exception) {
                            actionError = failure.message ?: "Unable to update registration."
                            pendingDecision = null
                            refresh++
                        } finally {
                            busyAssignment = null
                        }
                    }
                }) { Text("Confirm") }
            },
            dismissButton = {
                TextButton(enabled = busyAssignment == null, onClick = { pendingDecision = null }) {
                    Text("Cancel")
                }
            }
        )
    }
}
