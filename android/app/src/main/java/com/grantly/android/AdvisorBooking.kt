package com.grantly.android

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.TimeZone
import java.util.UUID

private const val ADVISOR_TERMS_VERSION = "2026-10-04.v1"

/** Legal wording and policy version must stay synchronized with the iOS booking flow. */
private enum class AdvisorPolicy(val title: String, val content: String) {
    Terms("Terms & Conditions", """Advisor services are provided by independent advisors through EduT. A consultation request does not charge you and does not guarantee a booking until payment and scheduling are confirmed.

            Prices, duration and included support are shown before you submit a request. The 6-month guidance package includes weekly one-to-one check-ins for six months and does not renew automatically.

            Advisors provide educational guidance and application support. EduT and its advisors do not guarantee admission, scholarships, visas, employment, test scores or any other outcome.

            You must provide accurate contact and scheduling information and use the service lawfully and respectfully. You may not misuse advisor contact details, recordings or materials.

            Any non-waivable rights available to you under applicable consumer law continue to apply. Material changes to these terms will require a new acceptance before a future paid request.""".trimIndent()),
    Privacy("Privacy Policy", """EduT uses your account information, selected service, email address, WhatsApp number, preferred time, topic and notes to coordinate the consultation.

            Your direct contact details stay hidden from the selected advisor until payment is recorded by EduT. EduT may retain booking, payment-status and consent records for customer support, fraud prevention, legal compliance and dispute handling.

            Only information reasonably necessary to provide the requested service should be shared. Do not place passwords, financial account details or other unnecessary sensitive information in consultation notes.

            You may exercise privacy rights available under applicable law. EduT will not treat acceptance of consultation terms as consent to unrelated marketing.""".trimIndent()),
    Refunds("Cancellation & Refund Policy", """Sending a consultation request does not charge you. Payment instructions are provided separately after the request is reviewed.

            If EduT or the advisor cannot provide a confirmed paid service, any payment collected for that service will be refunded.

            For scheduled one-to-one sessions, cancellation or rescheduling requests should be made as early as possible. Eligibility for a refund can depend on how close the request is to the confirmed session time and whether the service has already started.

            For multi-session packages, any legally required cancellation or withdrawal rights remain available. Services already delivered may affect the refundable amount where permitted by law.

            Before payment, EduT will show or provide any service-specific cancellation terms that apply. Mandatory consumer rights in your jurisdiction override any conflicting policy term.""".trimIndent())
}

internal object AdvisorBookingRepository {
    private suspend fun rpc(name: String, body: JSONObject): String = withContext(Dispatchers.IO) {
        require(name in setOf("accept_advisor_booking_terms", "submit_advisor_consultation_request"))
        val session = AuthRepository.activeSession()
        val base = BuildConfig.SUPABASE_URL.trimEnd('/')
        val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
        if (!base.startsWith("https://") || key.isBlank()) throw IOException("Booking is not configured.")
        val connection = URL(base + "/rest/v1/rpc/" + name).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 12_000
            connection.readTimeout = 20_000
            connection.doOutput = true
            connection.setRequestProperty("apikey", key)
            connection.setRequestProperty("Authorization", "Bearer " + session.accessToken)
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Accept", "application/json")
            connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            val status = connection.responseCode
            if (status !in 200..299) {
                val detail = connection.errorStream?.bufferedReader(Charsets.UTF_8)
                    ?.use { it.readText() }.orEmpty()
                val message = runCatching { JSONObject(detail).optString("message") }.getOrNull()
                    ?.take(180)?.takeIf { it.isNotBlank() }
                throw IOException(
                    if (status == 401 || status == 403) "Please sign in with an eligible student account."
                    else message ?: "Booking request failed (HTTP " + status + ")."
                )
            }
            connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
        } finally {
            connection.disconnect()
        }
    }

    suspend fun accept(advisorId: String): String {
        val payload = JSONObject()
            .put("p_advisor_id", UUID.fromString(advisorId).toString())
            .put("p_terms_version", ADVISOR_TERMS_VERSION)
            .put("p_privacy_version", ADVISOR_TERMS_VERSION)
            .put("p_refund_policy_version", ADVISOR_TERMS_VERSION)
        val rows = JSONArray(rpc("accept_advisor_booking_terms", payload))
        val value = rows.optJSONObject(0)?.optString("acceptance_id").orEmpty()
        return runCatching { UUID.fromString(value).toString() }
            .getOrElse { throw IOException("Acceptance was not recorded. Please try again.") }
    }

    suspend fun submit(
        advisorId: String, serviceId: String, acceptanceId: String,
        email: String, whatsapp: String, topic: String, notes: String
    ) {
        val payload = JSONObject()
            .put("p_advisor_id", UUID.fromString(advisorId).toString())
            .put("p_service_id", UUID.fromString(serviceId).toString())
            .put("p_terms_acceptance_id", UUID.fromString(acceptanceId).toString())
            .put("p_terms_version", ADVISOR_TERMS_VERSION)
            .put("p_privacy_version", ADVISOR_TERMS_VERSION)
            .put("p_refund_policy_version", ADVISOR_TERMS_VERSION)
            .put("p_contact_email", email.trim())
            .put("p_whatsapp_number", whatsapp.trim())
            .put("p_preferred_start", JSONObject.NULL)
            .put("p_timezone", TimeZone.getDefault().id)
            .put("p_topic", topic.trim())
            .put("p_notes", notes.trim())
            .put("p_contact_consent", true)
        rpc("submit_advisor_consultation_request", payload)
    }
}

@Composable
internal fun AdvisorBookingContent(advisor: AdvisorDirectoryItem, onViewRequests: () -> Unit) {
    val userId = AuthRepository.session?.userId
    val scope = rememberCoroutineScope()
    var accepted by remember(userId, advisor.id) { mutableStateOf(false) }
    var acceptanceId by remember(userId, advisor.id) { mutableStateOf<String?>(null) }
    var openedPolicy by remember(userId, advisor.id) { mutableStateOf<AdvisorPolicy?>(null) }
    var services by remember(userId, advisor.id) { mutableStateOf<List<AdvisorServiceItem>>(emptyList()) }
    var serviceId by remember(userId, advisor.id) { mutableStateOf<String?>(null) }
    var loading by remember(userId, advisor.id) { mutableStateOf(true) }
    var busy by remember(userId, advisor.id) { mutableStateOf(false) }
    var submitted by remember(userId, advisor.id) { mutableStateOf(false) }
    var error by remember(userId, advisor.id) { mutableStateOf<String?>(null) }
    var email by remember(userId, advisor.id) { mutableStateOf("") }
    var whatsapp by remember(userId, advisor.id) { mutableStateOf("") }
    var topic by remember(userId, advisor.id) { mutableStateOf("") }
    var notes by remember(userId, advisor.id) { mutableStateOf("") }
    var contactConsent by remember(userId, advisor.id) { mutableStateOf(false) }

    LaunchedEffect(userId, advisor.id) {
        if (userId == null) return@LaunchedEffect
        loading = true
        try {
            val result = AdvisorConsultationsRepository.services(advisor.id)
            if (AuthRepository.session?.userId == userId) services = result
        } catch (failure: Exception) {
            if (AuthRepository.session?.userId == userId) error = failure.message
        } finally {
            loading = false
        }
    }

    Text("Request a consultation with " + advisor.name, style = MaterialTheme.typography.titleLarge)
    Spacer(Modifier.height(12.dp))
    if (userId == null) {
        Text("Sign in with a student account to book.")
        return
    }
    if (submitted) {
        Text("Your request was submitted. No payment has been charged.", fontWeight = FontWeight.SemiBold)
        Text("EduT will contact you about scheduling and payment.")
        Button(onClick = onViewRequests) { Text("View my consultation requests") }
        return
    }
    if (acceptanceId == null) {
        Text("Review and accept the booking policies before choosing a plan.")
        AdvisorPolicy.entries.forEach { document ->
            TextButton(onClick = { openedPolicy = if (openedPolicy == document) null else document }) {
                Text(document.title + if (openedPolicy == document) " ▲" else " — Read ▼")
            }
            if (openedPolicy == document) {
                Card(Modifier.fillMaxWidth().padding(bottom = 8.dp)) {
                    Text(document.content, Modifier.padding(14.dp), style = MaterialTheme.typography.bodySmall)
                }
            }
        }
        Text("A request does not charge you. Prices are shown before submission. Contact details stay hidden from the advisor until payment is recorded. Packages do not auto-renew. No outcomes are guaranteed.",
            style = MaterialTheme.typography.bodySmall)
        Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
            Checkbox(checked = accepted, onCheckedChange = { accepted = it })
            Text("I agree to the Terms & Conditions and Cancellation & Refund Policy, and acknowledge the Privacy Policy.",
                modifier = Modifier.clickable { accepted = !accepted },
                style = MaterialTheme.typography.bodySmall)
        }
        Text("Policy version: " + ADVISOR_TERMS_VERSION, style = MaterialTheme.typography.labelSmall)
        if (error != null) Text(error.orEmpty(), color = MaterialTheme.colorScheme.error)
        Button(enabled = accepted && !busy, onClick = {
            busy = true
            error = null
            scope.launch {
                try {
                    val result = AdvisorBookingRepository.accept(advisor.id)
                    if (AuthRepository.session?.userId == userId) acceptanceId = result
                } catch (failure: Exception) {
                    error = failure.message ?: "Could not record policy acceptance."
                } finally {
                    busy = false
                }
            }
        }) { Text(if (busy) "Recording acceptance..." else "Accept & continue to plans") }
        return
    }

    Text("Choose a plan", fontWeight = FontWeight.SemiBold)
    if (loading) CircularProgressIndicator()
    else if (services.isEmpty()) Text("No consultation services are available.")
    else services.forEach { service ->
        val selected = serviceId == service.id
        Card(
            modifier = Modifier.fillMaxWidth().padding(vertical = 5.dp)
                .clickable { serviceId = service.id },
            shape = RoundedCornerShape(14.dp),
            colors = CardDefaults.cardColors(
                containerColor = if (selected) MaterialTheme.colorScheme.primaryContainer
                else MaterialTheme.colorScheme.surfaceVariant
            )
        ) {
            Column(Modifier.padding(14.dp)) {
                Text((if (selected) "✓ " else "") + service.title, fontWeight = FontWeight.SemiBold)
                Text(service.currency + " " +
                    String.format(java.util.Locale.US, "%.2f", service.priceCents / 100.0))
                if (service.durationMinutes > 0) Text(service.durationMinutes.toString() + " minutes")
                if (service.listPriceCents > service.priceCents) {
                    Text("Original price: " + service.currency + " " +
                        String.format(java.util.Locale.US, "%.2f", service.listPriceCents / 100.0))
                }
            }
        }
    }
    Spacer(Modifier.height(10.dp))
    OutlinedTextField(value = email, onValueChange = { email = it.take(254) },
        label = { Text("Contact email") }, singleLine = true, modifier = Modifier.fillMaxWidth())
    OutlinedTextField(value = whatsapp, onValueChange = { whatsapp = it.take(40) },
        label = { Text("WhatsApp with country code") }, singleLine = true, modifier = Modifier.fillMaxWidth())
    Text("Contact details are released to the advisor only after payment is recorded.",
        style = MaterialTheme.typography.bodySmall)
    Text("Preferred time: to be arranged after your request. Time zone: " + TimeZone.getDefault().id,
        style = MaterialTheme.typography.bodySmall)
    OutlinedTextField(value = topic, onValueChange = { topic = it.take(240) },
        label = { Text("What do you need help with?") }, modifier = Modifier.fillMaxWidth())
    OutlinedTextField(value = notes, onValueChange = { notes = it.take(2000) },
        label = { Text("Additional notes (optional)") }, minLines = 2, modifier = Modifier.fillMaxWidth())
    Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
        Checkbox(checked = contactConsent, onCheckedChange = { contactConsent = it })
        Text("I consent to EduT using my contact details for this booking and sharing them with the advisor only after payment is recorded.",
            modifier = Modifier.clickable { contactConsent = !contactConsent },
            style = MaterialTheme.typography.bodySmall)
    }
    val validEmail = email.trim().let {
        it.contains("@") && it.substringAfter("@").contains(".") && it.none(Char::isWhitespace)
    }
    val validPhone = whatsapp.count(Char::isDigit) in 7..15
    val canSubmit = serviceId != null && validEmail && validPhone &&
        topic.trim().length in 3..240 && notes.length <= 2000 && contactConsent && !busy && !loading
    if (error != null) Text(error.orEmpty(), color = MaterialTheme.colorScheme.error)
    Text("Requesting a consultation does not charge you. Payment is arranged separately.",
        style = MaterialTheme.typography.bodySmall)
    Button(enabled = canSubmit, onClick = {
        val selectedService = serviceId ?: return@Button
        val acceptedTerms = acceptanceId ?: return@Button
        busy = true
        error = null
        scope.launch {
            try {
                AdvisorBookingRepository.submit(
                    advisor.id, selectedService, acceptedTerms, email, whatsapp, topic, notes
                )
                if (AuthRepository.session?.userId == userId) submitted = true
            } catch (failure: Exception) {
                error = failure.message ?: "Unable to submit the request."
            } finally {
                busy = false
            }
        }
    }) { Text(if (busy) "Submitting..." else "Request consultation") }
}
