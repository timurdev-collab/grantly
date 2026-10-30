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
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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

/** Advisor-only consultation queue. Payment verification remains administrator-only. */
internal data class AdvisorIncomingConsultation(
    val id: String,
    val studentName: String,
    val serviceTitle: String,
    val topic: String,
    val status: String,
    val durationMinutes: Int,
    val priceCents: Int,
    val currency: String,
    val preferredStart: String,
    val createdAt: String,
    // Contact details are retained only for administrator-verified payment states.
    val contactEmail: String? = null,
    val whatsappNumber: String? = null
)

internal object AdvisorIncomingConsultationRules {
    fun isOpen(status: String): Boolean = status in setOf("requested", "contacted", "awaiting_payment", "paid", "confirmed")
    fun isKnown(status: String): Boolean = isOpen(status) || status in setOf("completed", "cancelled")
    fun contactUnlocked(status: String): Boolean = status in setOf("paid", "confirmed", "completed")
    fun verifiedContact(status: String, raw: String?, maxLength: Int): String? {
        if (!contactUnlocked(status)) return null
        val value = raw?.trim()?.takeIf { it.isNotEmpty() && !it.equals("null", ignoreCase = true) }
            ?: return null
        if (value.length > maxLength || value.any { it.isISOControl() }) return null
        return value
    }
    fun visible(items: List<AdvisorIncomingConsultation>, filter: String): List<AdvisorIncomingConsultation> =
        when (filter) {
            "open" -> items.filter { isOpen(it.status) }
            "new" -> items.filter { it.status == "requested" }
            "contacted" -> items.filter { it.status == "contacted" }
            "payment" -> items.filter { it.status == "awaiting_payment" }
            "ready" -> items.filter { it.status in setOf("paid", "confirmed") }
            "closed" -> items.filter { it.status in setOf("completed", "cancelled") }
            "other" -> items.filterNot { isKnown(it.status) }
            else -> items
        }
    fun search(items: List<AdvisorIncomingConsultation>, query: String): List<AdvisorIncomingConsultation> {
        val needle = query.trim().take(100).lowercase(Locale.ROOT)
        if (needle.isEmpty()) return items
        return items.filter { request ->
            listOf(request.studentName, request.serviceTitle, request.topic)
                .any { it.lowercase(Locale.ROOT).contains(needle) }
        }
    }
    fun page(items: List<AdvisorIncomingConsultation>, count: Int): List<AdvisorIncomingConsultation> =
        items.take(count.coerceAtLeast(0))
    fun statusLabel(status: String): String = when (status) {
        "requested" -> "Requested"
        "contacted" -> "Contacted"
        "awaiting_payment" -> "Awaiting payment"
        "paid" -> "Payment verified"
        "confirmed" -> "Confirmed"
        "completed" -> "Completed"
        "cancelled" -> "Cancelled"
        else -> "Unknown status"
    }
}

internal object AdvisorIncomingConsultationsRepository {
    suspend fun load(userId: String): List<AdvisorIncomingConsultation> = withContext(Dispatchers.IO) {
        val session = AuthRepository.activeSession()
        if (session.userId != userId || AuthRepository.session?.userId != userId) {
            throw IOException("Your account changed. Sign in again.")
        }
        if (StudentProfileRepository.load().role != "advisor" ||
            AuthRepository.session?.userId != userId) {
            throw IOException("An approved advisor account is required.")
        }
        val base = BuildConfig.SUPABASE_URL.trimEnd('/')
        val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
        if (!base.startsWith("https://") || key.isBlank()) {
            throw IOException("Advisor consultations are not configured.")
        }
        val connection = URL("$base/rest/v1/rpc/advisor_consultation_requests_for_me")
            .openConnection() as HttpURLConnection
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
                    "Advisor access denied. Sign in again."
                else "Could not load consultations (HTTP $code).")
            }
            val body = connection.inputStream.bufferedReader(Charsets.UTF_8).use { reader ->
                val buffer = CharArray(4096)
                val result = StringBuilder()
                while (true) {
                    val count = reader.read(buffer)
                    if (count < 0) break
                    result.append(buffer, 0, count)
                    if (result.length > 512_000) throw IOException("Consultation response is too large.")
                }
                result.toString()
            }
            val rows = JSONArray(body.ifBlank { "[]" })
            if (rows.length() > 300) throw IOException("Too many consultations for this preview.")
            if (AuthRepository.session?.userId != userId) {
                throw IOException("Your account changed. Refresh the advisor portal.")
            }
            buildList {
                for (index in 0 until rows.length()) {
                    val row = rows.optJSONObject(index) ?: continue
                    val requestId = row.optString("id")
                    if (runCatching { UUID.fromString(requestId) }.isFailure) continue
                    // Never retain contact data for unverified payment states.
                    // Notes remain excluded from the advisor queue model.
                    val status = row.optString("status").take(40)
                    add(AdvisorIncomingConsultation(
                        id = requestId,
                        studentName = row.optString("student_name").take(120),
                        serviceTitle = row.optString("service_title").take(120),
                        topic = row.optString("topic").take(400),
                        status = status,
                        durationMinutes = row.optInt("duration_minutes").coerceAtLeast(0),
                        priceCents = row.optInt("quoted_price_cents").coerceAtLeast(0),
                        currency = row.optString("currency").take(8).ifBlank { "USD" },
                        preferredStart = row.optString("preferred_start").take(40),
                        createdAt = row.optString("created_at").take(40),
                        contactEmail = AdvisorIncomingConsultationRules.verifiedContact(
                            status, row.optString("contact_email", ""), 254
                        ),
                        whatsappNumber = AdvisorIncomingConsultationRules.verifiedContact(
                            status, row.optString("whatsapp_number", ""), 32
                        )
                    ))
                }
            }
        } finally {
            connection.disconnect()
        }
    }
}

@Composable
internal fun AdvisorIncomingConsultationsContent(userId: String) {
    var requests by remember(userId) { mutableStateOf<List<AdvisorIncomingConsultation>>(emptyList()) }
    var loading by remember(userId) { mutableStateOf(true) }
    var error by remember(userId) { mutableStateOf<String?>(null) }
    var refresh by remember(userId) { mutableIntStateOf(0) }
    var filter by remember(userId) { mutableStateOf("open") }
    var searchText by remember(userId) { mutableStateOf("") }
    var visibleLimit by remember(userId) { mutableIntStateOf(20) }
    var pendingAction by remember(userId) { mutableStateOf<Pair<AdvisorIncomingConsultation, String>?>(null) }
    var actionBusy by remember(userId) { mutableStateOf(false) }
    var actionError by remember(userId) { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(userId, refresh) {
        loading = true
        error = null
        try {
            val result = AdvisorIncomingConsultationsRepository.load(userId)
            if (AuthRepository.session?.userId == userId) requests = result
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failure: Exception) {
            if (AuthRepository.session?.userId == userId) {
                error = failure.message ?: "Unable to load consultations."
                requests = emptyList()
            }
        } finally {
            if (AuthRepository.session?.userId == userId) loading = false
        }
    }

    val pending = pendingAction
    if (pending != null) {
        AlertDialog(
            onDismissRequest = { if (!actionBusy) pendingAction = null },
            title = { Text(AdvisorConsultationActionRules.label(pending.second)) },
            text = {
                Text("Update ${pending.first.studentName.ifBlank { "this student's" }} consultation " +
                    "from ${AdvisorIncomingConsultationRules.statusLabel(pending.first.status)} " +
                    "to ${AdvisorIncomingConsultationRules.statusLabel(pending.second)}? " +
                    "Only EduT administrators can verify payments.")
            },
            confirmButton = {
                TextButton(enabled = !actionBusy, onClick = {
                    scope.launch {
                        actionBusy = true
                        actionError = null
                        try {
                            AdvisorConsultationActionsRepository.perform(userId, pending.first, pending.second)
                            pendingAction = null
                            refresh++
                        } catch (cancelled: CancellationException) {
                            throw cancelled
                        } catch (failure: Exception) {
                            pendingAction = null
                            actionError = failure.message ?: "Could not update consultation."
                        } finally {
                            actionBusy = false
                        }
                    }
                }) { Text(if (actionBusy) "Updating..." else "Confirm") }
            },
            dismissButton = {
                TextButton(enabled = !actionBusy, onClick = { pendingAction = null }) { Text("Cancel") }
            }
        )
    }

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("Advisor portal · Consultation requests", style = MaterialTheme.typography.titleLarge)
        Text("EduT administrators verify payments. Advisors can confirm paid consultations and mark confirmed consultations completed.",
            style = MaterialTheme.typography.bodySmall)
        if (actionError != null) {
            Text(actionError.orEmpty(), color = MaterialTheme.colorScheme.error)
        }
        if (loading) {
            CircularProgressIndicator()
        } else if (error != null) {
            Text(error.orEmpty(), color = MaterialTheme.colorScheme.error)
        } else {
            val searched = AdvisorIncomingConsultationRules.search(requests, searchText)
            Text("${searched.count { AdvisorIncomingConsultationRules.isOpen(it.status) }} open · ${searched.size} matching of ${requests.size} total",
                fontWeight = FontWeight.SemiBold)
            OutlinedTextField(
                value = searchText,
                onValueChange = { searchText = it.take(100); visibleLimit = 20 },
                label = { Text("Search consultations") },
                placeholder = { Text("Student, service, or topic") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )
            Row(
                modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                listOf(
                    "open" to "Open", "new" to "New", "contacted" to "Contacted",
                    "payment" to "Awaiting payment", "ready" to "Ready",
                    "closed" to "Closed", "other" to "Other", "all" to "All"
                ).forEach { (option, label) ->
                    val count = AdvisorIncomingConsultationRules.visible(searched, option).size
                    FilterChip(
                        selected = filter == option,
                        onClick = { filter = option; visibleLimit = 20 },
                        label = { Text("$label ($count)") }
                    )
                }
            }
            val filtered = AdvisorIncomingConsultationRules.visible(searched, filter)
            if (filtered.isEmpty()) Text(if (searchText.isNotBlank()) "No consultations match this search and filter." else "No consultations in this category.")
            AdvisorIncomingConsultationRules.page(filtered, visibleLimit).forEach { request ->
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                        Text(request.studentName.ifBlank { "Student" }, fontWeight = FontWeight.SemiBold)
                        Text(AdvisorIncomingConsultationRules.statusLabel(request.status))
                        Text(request.serviceTitle.ifBlank { "Consultation" })
                        if (request.topic.isNotBlank()) Text(request.topic, style = MaterialTheme.typography.bodySmall)
                        Text("${request.durationMinutes} min · ${request.currency.uppercase(Locale.US)} " +
                            String.format(Locale.US, "%.2f", request.priceCents / 100.0))
                        if (request.preferredStart.isNotBlank() && request.preferredStart != "null") {
                            Text("Preferred time (as supplied): ${request.preferredStart.take(35)}",
                                style = MaterialTheme.typography.bodySmall)
                        }
                        val nextStatus = AdvisorConsultationActionRules.nextStatus(request.status)
                        if (nextStatus != null) {
                            OutlinedButton(enabled = !actionBusy && !loading, onClick = {
                                actionError = null
                                pendingAction = request to nextStatus
                            }) { Text(AdvisorConsultationActionRules.label(nextStatus)) }
                        }
                        if (!AdvisorIncomingConsultationRules.contactUnlocked(request.status)) {
                            Text("Contact details remain locked until payment is verified.",
                                style = MaterialTheme.typography.bodySmall)
                        } else {
                            Text("Payment verified · Student contact",
                                style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold)
                            if (request.contactEmail != null) {
                                Text("Email: ${request.contactEmail}", style = MaterialTheme.typography.bodySmall)
                            }
                            if (request.whatsappNumber != null) {
                                Text("WhatsApp: ${request.whatsappNumber}", style = MaterialTheme.typography.bodySmall)
                            }
                            if (request.contactEmail == null && request.whatsappNumber == null) {
                                Text("No contact details were returned. Refresh or use Messages.",
                                    style = MaterialTheme.typography.bodySmall)
                            }
                        }
                    }
                }
            }
            if (filtered.size > visibleLimit) {
                OutlinedButton(onClick = { visibleLimit += 20 }, modifier = Modifier.fillMaxWidth()) {
                    Text("Load 20 more consultations")
                }
            }
        }
        OutlinedButton(onClick = { refresh++ }, enabled = !loading, modifier = Modifier.fillMaxWidth()) {
            Text("Refresh consultations")
        }
        Spacer(Modifier.height(8.dp))
    }
}
