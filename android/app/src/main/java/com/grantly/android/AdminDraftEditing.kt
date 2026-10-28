package com.grantly.android

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.time.LocalDate
import java.time.format.DateTimeParseException
import java.util.UUID

/** A deliberately limited, partial draft editor; omitted fields are never overwritten. */
internal data class AdminDraftEditValues(
    val title: String,
    val provider: String,
    val country: String,
    val fundingType: String,
    val deadline: String,
    val applicationCycle: String = "",
    val region: String = "",
    val deadlineNotes: String = "",
    val description: String = "",
    val degreeLevels: List<String> = emptyList(),
    val tuitionCoverage: String = "",
    val stipend: String = "",
    val airfare: Boolean = false,
    val accommodation: Boolean = false,
    val healthInsurance: Boolean = false,
    val satRequired: Boolean = false,
    val fields: List<String> = emptyList(),
    val eligibleNationalities: List<String> = emptyList()
)

internal object AdminDraftEditRules {
    fun validate(
        title: String,
        provider: String,
        country: String,
        fundingType: String,
        deadline: String,
        applicationCycle: String = "",
        region: String = "",
        originalRegion: String = "",
        deadlineNotes: String = "",
        originalDeadlineNotes: String = "",
        description: String = "",
        originalDescription: String = "",
        degreeLevels: String = "",
        originalDegreeLevels: List<String> = emptyList(),
        tuitionCoverage: String = "",
        originalTuitionCoverage: String = "",
        stipend: String = "",
        originalStipend: String = "",
        airfare: Boolean = false,
        accommodation: Boolean = false,
        healthInsurance: Boolean = false,
        satRequired: Boolean = false,
        fields: String = "",
        originalFields: List<String> = emptyList(),
        eligibleNationalities: String = "",
        originalEligibleNationalities: List<String> = emptyList()
    ): AdminDraftEditValues {
        // Keep untouched legacy values intact; only validate newly edited lists.
        val parsedLevels = if (degreeLevels == originalDegreeLevels.joinToString(", ")) {
            originalDegreeLevels
        } else {
            require(degreeLevels.length <= 1_000) { "Study levels are too long." }
            degreeLevels.split(',').map { it.trim() }.filter { it.isNotEmpty() }.distinct().also { levels ->
                require(levels.size <= 12 && levels.all { it.length <= 80 }) {
                    "Use up to 12 study levels, each no longer than 80 characters."
                }
            }
        }
        val parsedFields = parseCommaSeparated(fields, originalFields, "Fields", 4_000, 50)
        val parsedNationalities = parseCommaSeparated(
            eligibleNationalities, originalEligibleNationalities, "Eligible nationalities", 16_000, 200
        )
        val normalized = AdminDraftEditValues(
            title.trim(), provider.trim(), country.trim(), fundingType.trim(), deadline.trim(),
            applicationCycle.trim(), region.trim(),
            if (deadlineNotes == originalDeadlineNotes) deadlineNotes else deadlineNotes.trim(),
            if (description == originalDescription) description else description.trim(),
            parsedLevels,
            if (tuitionCoverage == originalTuitionCoverage) tuitionCoverage else tuitionCoverage.trim(),
            if (stipend == originalStipend) stipend else stipend.trim(),
            airfare, accommodation, healthInsurance, satRequired,
            parsedFields, parsedNationalities
        )
        require(normalized.title.isNotEmpty() && normalized.title.length <= 200) {
            "A scholarship title (up to 200 characters) is required."
        }
        require(normalized.provider.isNotEmpty() && normalized.provider.length <= 120) {
            "A provider (up to 120 characters) is required."
        }
        require(normalized.country.isNotEmpty() && normalized.country.length <= 80) {
            "A country (up to 80 characters) is required."
        }
        require(normalized.fundingType.length <= 80) { "Funding type is too long." }
        require(normalized.applicationCycle.length <= 80) { "Application cycle is too long." }
        require(normalized.region.length <= 120) { "Region is too long." }
        if (normalized.tuitionCoverage != originalTuitionCoverage) {
            require(normalized.tuitionCoverage.length <= 120) { "Tuition coverage is too long (max 120 characters)." }
        }
        if (normalized.stipend != originalStipend) {
            require(normalized.stipend.length <= 120) { "Stipend is too long (max 120 characters)." }
        }
        if (normalized.deadlineNotes != originalDeadlineNotes) {
            require(normalized.deadlineNotes.length <= 2_000) { "Deadline notes are too long (max 2,000 characters)." }
        }
        if (normalized.description != originalDescription) {
            require(normalized.description.length <= 4_000) { "Description is too long (max 4,000 characters)." }
        }
        // Preserve legacy blank regions on unrelated edits, but never clear a populated region.
        if (normalized.region != originalRegion.trim()) {
            require(normalized.region.isNotEmpty()) { "Region cannot be cleared." }
        }
        if (normalized.deadline.isNotEmpty()) {
            require(normalized.deadline.matches(Regex("\\d{4}-\\d{2}-\\d{2}"))) {
                "Deadline must use YYYY-MM-DD."
            }
            try {
                LocalDate.parse(normalized.deadline)
            } catch (_: DateTimeParseException) {
                throw IllegalArgumentException("Deadline is not a valid calendar date.")
            }
        }
        return normalized
    }

    private fun parseCommaSeparated(
        input: String, original: List<String>, label: String, maxCharacters: Int, maxEntries: Int
    ): List<String> {
        if (input == original.joinToString(", ")) return original
        require(input.length <= maxCharacters) { "$label is too long." }
        val parsed = input.split(',').map { it.trim() }.filter { it.isNotEmpty() }.distinct()
        require(parsed.size <= maxEntries && parsed.all { it.length <= 80 }) {
            "$label must have at most $maxEntries entries, each up to 80 characters."
        }
        return parsed
    }

    /** Pure change detector: never sends unchanged flags or overwrites unseen values. */
    fun changedBooleanFields(draft: AdminDraftSummary, values: AdminDraftEditValues): Map<String, Boolean> = buildMap {
        if (values.airfare != draft.airfare) put("airfare", values.airfare)
        if (values.accommodation != draft.accommodation) put("accommodation", values.accommodation)
        if (values.healthInsurance != draft.healthInsurance) put("health_insurance", values.healthInsurance)
        if (values.satRequired != draft.satRequired) put("sat_required", values.satRequired)
    }
}

internal object AdminDraftEditorRepository {
    suspend fun save(draft: AdminDraftSummary, values: AdminDraftEditValues): Boolean =
        withContext(Dispatchers.IO) {
            val id = try {
                UUID.fromString(draft.id).toString()
            } catch (_: IllegalArgumentException) {
                throw IOException("Invalid scholarship draft.")
            }
            val patch = JSONObject()
            if (values.title != draft.title) patch.put("title", values.title)
            if (values.provider != draft.provider) patch.put("provider", values.provider)
            if (values.country != draft.country) patch.put("country", values.country)
            if (values.region != draft.region) {
                if (values.region.isEmpty()) throw IOException("Region cannot be cleared.")
                patch.put("region", values.region)
            }
            if (values.fundingType != draft.fundingType) {
                patch.put("funding_type", if (values.fundingType.isEmpty()) JSONObject.NULL else values.fundingType)
            }
            if (values.deadline != draft.deadline) {
                patch.put("deadline", if (values.deadline.isEmpty()) JSONObject.NULL else values.deadline)
            }
            if (values.applicationCycle != draft.applicationCycle) {
                patch.put("application_cycle", if (values.applicationCycle.isEmpty()) JSONObject.NULL else values.applicationCycle)
            }
            if (values.deadlineNotes != draft.deadlineNotes) {
                patch.put("deadline_notes", if (values.deadlineNotes.isEmpty()) JSONObject.NULL else values.deadlineNotes)
            }
            if (values.description != draft.description) {
                // Match the iOS draft editor: clearing the description sends an empty string.
                patch.put("description", values.description)
            }
            if (values.degreeLevels != draft.degreeLevels) {
                patch.put("degree_levels", JSONArray(values.degreeLevels))
            }
            if (values.tuitionCoverage != draft.tuitionCoverage) {
                patch.put("tuition_coverage", if (values.tuitionCoverage.isEmpty()) JSONObject.NULL else values.tuitionCoverage)
            }
            if (values.stipend != draft.stipend) {
                patch.put("stipend", if (values.stipend.isEmpty()) JSONObject.NULL else values.stipend)
            }
            for ((field, enabled) in AdminDraftEditRules.changedBooleanFields(draft, values)) {
                patch.put(field, enabled)
            }
            if (values.fields != draft.fields) patch.put("fields", JSONArray(values.fields))
            if (values.eligibleNationalities != draft.eligibleNationalities) {
                patch.put("eligible_nationalities", JSONArray(values.eligibleNationalities))
            }
            if (patch.length() == 0) return@withContext false

            val session = AuthRepository.activeSession()
            // Client guard for UX; the existing RPC enforces is_admin() on the server.
            if (StudentProfileRepository.load().role != "admin" ||
                AuthRepository.session?.userId != session.userId) {
                throw IOException("Administrator access is required.")
            }
            val base = BuildConfig.SUPABASE_URL.trimEnd('/')
            val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
            if (!base.startsWith("https://") || key.isBlank()) {
                throw IOException("Draft editing service is not configured.")
            }
            val connection = URL("$base/rest/v1/rpc/update_scholarship_draft")
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
                val request = JSONObject()
                    .put("p_scholarship_id", id)
                    .put("p_patch", patch)
                    .toString()
                connection.outputStream.use { it.write(request.toByteArray(Charsets.UTF_8)) }
                val status = connection.responseCode
                if (status !in 200..299) {
                    throw IOException(if (status == 401 || status == 403) {
                        "Administrator access was denied. Please sign in again."
                    } else {
                        "Unable to save draft fields (HTTP $status)."
                    })
                }
                // The RPC returns the updated draft row. A 2xx response alone is not
                // sufficient confirmation of a successful write.
                val response = connection.inputStream.bufferedReader(Charsets.UTF_8).use { reader ->
                    val text = StringBuilder()
                    val buffer = CharArray(4_096)
                    while (true) {
                        val count = reader.read(buffer)
                        if (count < 0) break
                        if (text.length + count > 1_048_576) {
                            throw IOException("Save response too large. Refresh to confirm the draft.")
                        }
                        text.append(buffer, 0, count)
                    }
                    text.toString()
                }
                val result = try {
                    JSONObject(response)
                } catch (_: Exception) {
                    throw IOException("Save response unclear. Refresh before trying again.")
                }
                if (result.optString("id") != id || result.optString("status") != "draft") {
                    throw IOException("Saved draft could not be confirmed. Refresh the queue.")
                }
                if (AuthRepository.session?.userId != session.userId) {
                    throw IOException("Your account changed. Reload the draft before editing again.")
                }
                true
            } finally {
                connection.disconnect()
            }
        }
}

/** Only changes the eighteen iOS-supported fields after an explicit administrator save action. */
@Composable
internal fun AdminDraftEditor(draft: AdminDraftSummary, onSaved: () -> Unit) {
    // Reset local form state whenever the server draft snapshot changes, not just its ID.
    // Otherwise a refreshed draft can reopen with stale values and overwrite newer edits.
    var editing by remember(draft) { mutableStateOf(false) }
    var title by remember(draft) { mutableStateOf(draft.title) }
    var provider by remember(draft) { mutableStateOf(draft.provider) }
    var country by remember(draft) { mutableStateOf(draft.country) }
    var region by remember(draft) { mutableStateOf(draft.region) }
    var degreeLevels by remember(draft) { mutableStateOf(draft.degreeLevels.joinToString(", ")) }
    var tuitionCoverage by remember(draft) { mutableStateOf(draft.tuitionCoverage) }
    var stipend by remember(draft) { mutableStateOf(draft.stipend) }
    var airfare by remember(draft) { mutableStateOf(draft.airfare) }
    var accommodation by remember(draft) { mutableStateOf(draft.accommodation) }
    var healthInsurance by remember(draft) { mutableStateOf(draft.healthInsurance) }
    var satRequired by remember(draft) { mutableStateOf(draft.satRequired) }
    var fields by remember(draft) { mutableStateOf(draft.fields.joinToString(", ")) }
    var eligibleNationalities by remember(draft) {
        mutableStateOf(draft.eligibleNationalities.joinToString(", "))
    }
    var funding by remember(draft) { mutableStateOf(draft.fundingType) }
    var deadline by remember(draft) { mutableStateOf(draft.deadline) }
    var applicationCycle by remember(draft) { mutableStateOf(draft.applicationCycle) }
    var deadlineNotes by remember(draft) { mutableStateOf(draft.deadlineNotes) }
    var description by remember(draft) { mutableStateOf(draft.description) }
    var saving by remember(draft) { mutableStateOf(false) }
    var error by remember(draft) { mutableStateOf<String?>(null) }
    var message by remember(draft) { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        OutlinedButton(onClick = {
            if (editing) {
                // Cancel discards local changes, even if the editor is opened again.
                title = draft.title
                provider = draft.provider
                country = draft.country
                region = draft.region
                degreeLevels = draft.degreeLevels.joinToString(", ")
                tuitionCoverage = draft.tuitionCoverage
                stipend = draft.stipend
                airfare = draft.airfare
                accommodation = draft.accommodation
                healthInsurance = draft.healthInsurance
                satRequired = draft.satRequired
                fields = draft.fields.joinToString(", ")
                eligibleNationalities = draft.eligibleNationalities.joinToString(", ")
                funding = draft.fundingType
                deadline = draft.deadline
                applicationCycle = draft.applicationCycle
                deadlineNotes = draft.deadlineNotes
                description = draft.description
                message = null
            }
            editing = !editing
            error = null
        }, enabled = !saving) {
            Text(if (editing) "Cancel field editing" else "Edit basic draft fields")
        }
        if (editing) {
            Text("Only the fields you change will be saved. Other scholarship details are preserved.",
                style = MaterialTheme.typography.bodySmall)
            OutlinedTextField(value = title, onValueChange = { title = it.take(200) },
                label = { Text("Title") }, singleLine = true, enabled = !saving, modifier = Modifier.fillMaxWidth())
            OutlinedTextField(value = provider, onValueChange = { provider = it.take(120) },
                label = { Text("Provider") }, singleLine = true, enabled = !saving, modifier = Modifier.fillMaxWidth())
            OutlinedTextField(value = country, onValueChange = { country = it.take(80) },
                label = { Text("Country") }, singleLine = true, enabled = !saving, modifier = Modifier.fillMaxWidth())
            OutlinedTextField(value = region, onValueChange = { region = it.take(120) },
                label = { Text("Region") }, singleLine = true,
                enabled = !saving, modifier = Modifier.fillMaxWidth())
            OutlinedTextField(value = degreeLevels, onValueChange = { degreeLevels = it.take(1_000) },
                label = { Text("Study levels (comma separated, optional)") },
                enabled = !saving, modifier = Modifier.fillMaxWidth())
            OutlinedTextField(value = fields, onValueChange = { fields = it.take(4_000) },
                label = { Text("Subject areas (comma separated, optional)") },
                enabled = !saving, modifier = Modifier.fillMaxWidth())
            Text("Benefits", style = MaterialTheme.typography.titleSmall)
            OutlinedTextField(value = tuitionCoverage, onValueChange = { tuitionCoverage = it.take(120) },
                label = { Text("Tuition coverage (optional)") }, singleLine = true,
                enabled = !saving, modifier = Modifier.fillMaxWidth())
            OutlinedTextField(value = stipend, onValueChange = { stipend = it.take(120) },
                label = { Text("Stipend (optional)") }, singleLine = true,
                enabled = !saving, modifier = Modifier.fillMaxWidth())
            Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                Text("Airfare")
                Switch(checked = airfare, onCheckedChange = { airfare = it }, enabled = !saving)
            }
            Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                Text("Accommodation")
                Switch(checked = accommodation, onCheckedChange = { accommodation = it }, enabled = !saving)
            }
            Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                Text("Health insurance")
                Switch(checked = healthInsurance, onCheckedChange = { healthInsurance = it }, enabled = !saving)
            }
            Text("Eligibility", style = MaterialTheme.typography.titleSmall)
            OutlinedTextField(value = eligibleNationalities,
                onValueChange = { eligibleNationalities = it.take(16_000) },
                label = { Text("Eligible nationalities (comma separated, optional)") },
                enabled = !saving, modifier = Modifier.fillMaxWidth())
            Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                Text("SAT required")
                Switch(checked = satRequired, onCheckedChange = { satRequired = it }, enabled = !saving)
            }
            OutlinedTextField(value = funding, onValueChange = { funding = it.take(80) },
                label = { Text("Funding type (optional)") }, singleLine = true, enabled = !saving, modifier = Modifier.fillMaxWidth())
            OutlinedTextField(value = deadline, onValueChange = { deadline = it.take(10) },
                label = { Text("Deadline YYYY-MM-DD (optional)") }, singleLine = true,
                enabled = !saving, modifier = Modifier.fillMaxWidth())
            OutlinedTextField(value = applicationCycle, onValueChange = { applicationCycle = it.take(80) },
                label = { Text("Application cycle (optional)") }, singleLine = true,
                enabled = !saving, modifier = Modifier.fillMaxWidth())
            OutlinedTextField(value = deadlineNotes, onValueChange = { deadlineNotes = it.take(2_000) },
                label = { Text("Deadline notes (optional)") }, minLines = 3,
                enabled = !saving, modifier = Modifier.fillMaxWidth())
            OutlinedTextField(value = description, onValueChange = { description = it.take(4_000) },
                label = { Text("Description (optional)") }, minLines = 4,
                enabled = !saving, modifier = Modifier.fillMaxWidth())
            Button(enabled = !saving, onClick = {
                error = null
                message = null
                val values = try {
                    AdminDraftEditRules.validate(title, provider, country, funding, deadline,
                        applicationCycle, region = region, originalRegion = draft.region,
                        deadlineNotes, draft.deadlineNotes, description, draft.description,
                        degreeLevels, draft.degreeLevels,
                        tuitionCoverage = tuitionCoverage, originalTuitionCoverage = draft.tuitionCoverage,
                        stipend = stipend, originalStipend = draft.stipend,
                        airfare = airfare, accommodation = accommodation,
                        healthInsurance = healthInsurance, satRequired = satRequired,
                        fields = fields, originalFields = draft.fields,
                        eligibleNationalities = eligibleNationalities,
                        originalEligibleNationalities = draft.eligibleNationalities)
                } catch (failure: IllegalArgumentException) {
                    error = failure.message ?: "Invalid draft fields."
                    return@Button
                }
                saving = true
                val expectedUser = AuthRepository.session?.userId
                scope.launch {
                    try {
                        val changed = AdminDraftEditorRepository.save(draft, values)
                        if (AuthRepository.session?.userId == expectedUser) {
                            if (changed) onSaved() else message = "No field changes to save."
                        }
                    } catch (cancelled: CancellationException) {
                        throw cancelled
                    } catch (failure: Exception) {
                        if (AuthRepository.session?.userId == expectedUser) {
                            error = failure.message ?: "Unable to save the draft."
                        }
                    } finally {
                        saving = false
                    }
                }
            }) { Text(if (saving) "Saving draft…" else "Save draft changes") }
        }
        if (message != null) Text(message!!, style = MaterialTheme.typography.bodySmall)
        if (error != null) Text(error!!, color = MaterialTheme.colorScheme.error)
    }
}
