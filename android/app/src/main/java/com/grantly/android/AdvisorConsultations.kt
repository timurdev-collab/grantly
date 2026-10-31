package com.grantly.android

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
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
import java.util.Locale
import java.util.UUID

/** Read-only advisor services and consultation history. Booking writes are isolated in AdvisorBookingRepository. */
internal data class AdvisorServiceItem(
    val id: String,
    val title: String,
    val durationMinutes: Int,
    val priceCents: Int,
    val listPriceCents: Int,
    val discountPercent: Int,
    val currency: String
)

internal data class AdvisorConsultationItem(
    val id: String,
    val advisorName: String,
    val serviceTitle: String,
    val topic: String,
    val status: String,
    val createdAt: String,
    val priceCents: Int,
    val currency: String
)

internal object AdvisorConsultationsRepository {
    private fun JSONObject.safeText(key: String): String =
        if (isNull(key)) "" else optString(key, "")

    private suspend fun rpc(name: String, payload: JSONObject): JSONArray = withContext(Dispatchers.IO) {
        val session = AuthRepository.activeSession()
        val expectedUserId = session.userId
        AdvisorConsultationResponseRules.requireSameAccount(
            expectedUserId, AuthRepository.session?.userId
        )
        val base = BuildConfig.SUPABASE_URL.trimEnd('/')
        val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
        if (!base.startsWith("https://") || key.isBlank()) {
            throw IOException("Advisor consultations are not configured.")
        }
        // Only these existing, authenticated, read-only RPCs are permitted.
        if (name !in setOf("available_advisor_services", "my_advisor_consultation_requests")) {
            throw IOException("Unsupported advisor request.")
        }
        val connection = URL(base + "/rest/v1/rpc/" + name).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 12_000
            connection.readTimeout = 15_000
            // Never forward the signed-in user's bearer token to a redirected host.
            connection.instanceFollowRedirects = false
            connection.doOutput = true
            connection.setRequestProperty("apikey", key)
            connection.setRequestProperty("Authorization", "Bearer " + session.accessToken)
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Accept", "application/json")
            AdvisorConsultationResponseRules.requireSameAccount(
                expectedUserId, AuthRepository.session?.userId
            )
            connection.outputStream.use { it.write(payload.toString().toByteArray(Charsets.UTF_8)) }
            AdvisorConsultationResponseRules.requireSameAccount(
                expectedUserId, AuthRepository.session?.userId
            )
            val status = connection.responseCode
            if (status !in 200..299) {
                throw IOException(
                    if (status == 401 || status == 403) "Sign in again to view consultations."
                    else "Consultation information unavailable (HTTP " + status + ")."
                )
            }
            val response = connection.inputStream.bufferedReader(Charsets.UTF_8).use {
                AdvisorConsultationResponseRules.readBounded(it)
            }
            AdvisorConsultationResponseRules.requireSameAccount(
                expectedUserId, AuthRepository.session?.userId
            )
            if (response.isBlank()) JSONArray() else JSONArray(response
        } finally {
            connection.disconnect()
        }
    }

    suspend fun services(advisorId: String): List<AdvisorServiceItem> {
        val id = try { UUID.fromString(advisorId).toString() }
            catch (_: IllegalArgumentException) { throw IOException("Invalid advisor identifier.") }
        val rows = rpc("available_advisor_services", JSONObject().put("p_advisor_id", id))
        return buildList {
            for (index in 0 until rows.length()) {
                val row = rows.optJSONObject(index) ?: continue
                val serviceId = row.safeText("id")
                if (runCatching { UUID.fromString(serviceId) }.isFailure) continue
                val price = row.optInt("price_cents", 0).coerceAtLeast(0)
                add(
                    AdvisorServiceItem(
                        id = serviceId,
                        title = row.safeText("title").ifBlank { "Consultation" },
                        durationMinutes = row.optInt("duration_minutes", 0).coerceAtLeast(0),
                        priceCents = price,
                        listPriceCents = row.optInt("list_price_cents", price).coerceAtLeast(price),
                        discountPercent = row.optInt("discount_percent", 0).coerceIn(0, 100),
                        currency = row.safeText("currency").ifBlank { "USD" }
                    )
                )
            }
        }
    }

    suspend fun myRequests(): List<AdvisorConsultationItem> {
        val rows = rpc("my_advisor_consultation_requests", JSONObject())
        return buildList {
            for (index in 0 until rows.length()) {
                val row = rows.optJSONObject(index) ?: continue
                val requestId = row.safeText("id")
                if (runCatching { UUID.fromString(requestId) }.isFailure) continue
                add(
                    AdvisorConsultationItem(
                        id = requestId,
                        advisorName = row.safeText("advisor_name").ifBlank { "EduT advisor" },
                        serviceTitle = row.safeText("service_title").ifBlank { "Consultation" },
                        topic = row.safeText("topic"),
                        status = row.safeText("status").ifBlank { "requested" },
                        createdAt = row.safeText("created_at"),
                        priceCents = row.optInt("quoted_price_cents", 0).coerceAtLeast(0),
                        currency = row.safeText("currency").ifBlank { "USD" }
                    )
                )
            }
        }
    }
}

private fun advisorPrice(currency: String, cents: Int): String =
    currency.uppercase(Locale.US) + " " + String.format(Locale.US, "%.2f", cents / 100.0)

@Composable
internal fun AdvisorServicesContent(advisorId: String) {
    val userId = AuthRepository.session?.userId
    var services by remember(userId, advisorId) { mutableStateOf<List<AdvisorServiceItem>>(emptyList()) }
    var loading by remember(userId, advisorId) { mutableStateOf(userId != null) }
    var error by remember(userId, advisorId) { mutableStateOf<String?>(null) }
    var refresh by remember(userId, advisorId) { mutableIntStateOf(0) }
    val forest = Color(0xFF123E30)

    LaunchedEffect(userId, advisorId, refresh) {
        if (userId == null) return@LaunchedEffect
        loading = true
        error = null
        try {
            val fetched = AdvisorConsultationsRepository.services(advisorId)
            if (AuthRepository.session?.userId == userId) services = fetched
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failure: Exception) {
            if (AuthRepository.session?.userId == userId) {
                error = failure.message ?: "Unable to load consultation options."
            }
        } finally {
            if (AuthRepository.session?.userId == userId) loading = false
        }
    }

    Spacer(Modifier.height(12.dp))
    Text("Consultation options", style = MaterialTheme.typography.titleLarge, color = forest)
    Spacer(Modifier.height(8.dp))
    when {
        userId == null -> Text("Sign in to see consultation options.")
        loading -> CircularProgressIndicator()
        error != null -> {
            Text(error ?: "", color = MaterialTheme.colorScheme.error)
            OutlinedButton(onClick = { refresh++ }) { Text("Try again") }
        }
        services.isEmpty() -> Text("No consultation services are currently available.")
        else -> services.forEach { service ->
            Card(
                modifier = Modifier.fillMaxWidth().padding(bottom = 9.dp),
                shape = RoundedCornerShape(14.dp)
            ) {
                Column(Modifier.padding(14.dp)) {
                    Text(service.title, fontWeight = FontWeight.SemiBold)
                    if (service.durationMinutes > 0) {
                        Text(service.durationMinutes.toString() + " minutes")
                    } else {
                        Text("Package")
                    }
                    Text(advisorPrice(service.currency, service.priceCents), color = forest)
                    if (service.listPriceCents > service.priceCents && service.discountPercent > 0) {
                        Text(
                            "List price " + advisorPrice(service.currency, service.listPriceCents) +
                                " · " + service.discountPercent + "% off",
                            style = MaterialTheme.typography.bodySmall
                        )
                    }
                }
            }
        }
    }
    Spacer(Modifier.height(6.dp))
    Text(
        "Prices are informational until confirmed. To request a service, use Book a consultation and accept the versioned policies first. Payment is arranged separately; no in-app payment is available.",
        style = MaterialTheme.typography.bodySmall
    )
}

@Composable
internal fun AdvisorConsultationHistoryContent() {
    val userId = AuthRepository.session?.userId
    var requests by remember(userId) { mutableStateOf<List<AdvisorConsultationItem>>(emptyList()) }
    var loading by remember(userId) { mutableStateOf(userId != null) }
    var error by remember(userId) { mutableStateOf<String?>(null) }
    var refresh by remember(userId) { mutableIntStateOf(0) }
    val forest = Color(0xFF123E30)

    LaunchedEffect(userId, refresh) {
        if (userId == null) return@LaunchedEffect
        loading = true
        error = null
        try {
            val fetched = AdvisorConsultationsRepository.myRequests()
            if (AuthRepository.session?.userId == userId) requests = fetched
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failure: Exception) {
            if (AuthRepository.session?.userId == userId) {
                error = failure.message ?: "Unable to load your consultations."
            }
        } finally {
            if (AuthRepository.session?.userId == userId) loading = false
        }
    }

    Text("Your consultation requests", style = MaterialTheme.typography.titleLarge, color = forest)
    Spacer(Modifier.height(10.dp))
    when {
        userId == null -> Text("Sign in to see your consultation requests.")
        loading -> CircularProgressIndicator()
        error != null -> {
            Text(error ?: "", color = MaterialTheme.colorScheme.error)
            OutlinedButton(onClick = { refresh++ }) { Text("Try again") }
        }
        requests.isEmpty() -> Text("You have no consultation requests yet.")
        else -> {
            OutlinedButton(onClick = { refresh++ }) { Text("Refresh status") }
            requests.forEach { request ->
                Card(
                    modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp),
                    shape = RoundedCornerShape(14.dp)
                ) {
                    Column(Modifier.padding(14.dp)) {
                        Text(request.serviceTitle, fontWeight = FontWeight.SemiBold)
                        Text(request.advisorName)
                        Text(
                            "Status: " + request.status.replace('_', ' '),
                            color = forest
                        )
                        if (request.topic.isNotBlank()) Text("Topic: " + request.topic)
                        if (request.createdAt.length >= 10) {
                            Text("Requested: " + request.createdAt.take(10))
                        }
                        Text("Quoted price: " + advisorPrice(request.currency, request.priceCents))
                    }
                }
            }
        }
    }
    Spacer(Modifier.height(8.dp))
    Text(
        "Statuses are read-only. Contact details and payment verification are managed through the existing EduT process.",
        style = MaterialTheme.typography.bodySmall
    )
}
