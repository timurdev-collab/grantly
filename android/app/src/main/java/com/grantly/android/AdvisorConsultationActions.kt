package com.grantly.android

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

/**
 * Only allow advisor decisions that cannot assert payment has occurred.
 * Payment verification remains exclusively administrator-controlled.
 */
internal object AdvisorConsultationActionRules {
    fun allowed(current: String, next: String): Boolean =
        (current == "paid" && next == "confirmed") ||
            (current == "confirmed" && next == "completed")

    fun label(next: String): String = when (next) {
        "confirmed" -> "Confirm consultation"
        "completed" -> "Mark consultation completed"
        else -> "Unsupported action"
    }

    fun nextStatus(current: String): String? = when (current) {
        "paid" -> "confirmed"
        "confirmed" -> "completed"
        else -> null
    }
}

internal object AdvisorConsultationActionsRepository {
    suspend fun perform(userId: String, request: AdvisorIncomingConsultation, next: String) =
        withContext(Dispatchers.IO) {
            if (!AdvisorConsultationActionRules.allowed(request.status, next)) {
                throw IOException("This consultation cannot be updated from its current status.")
            }
            val requestId = runCatching { UUID.fromString(request.id).toString() }
                .getOrElse { throw IOException("Invalid consultation identifier.") }
            val session = AuthRepository.activeSession()
            if (session.userId != userId || AuthRepository.session?.userId != userId) {
                throw IOException("Your account changed. Sign in again.")
            }
            if (StudentProfileRepository.load().role != "advisor" ||
                AuthRepository.session?.userId != userId) {
                throw IOException("An approved advisor account is required.")
            }
            // Re-read the advisor-scoped queue before any mutation; never trust a stale card.
            val latest = AdvisorIncomingConsultationsRepository.load(userId).firstOrNull {
                it.id == requestId
            } ?: throw IOException("Consultation no longer exists. Refresh your requests.")
            if (latest.status != request.status ||
                !AdvisorConsultationActionRules.allowed(latest.status, next)) {
                throw IOException("Consultation status changed. Refresh before trying again.")
            }
            val base = BuildConfig.SUPABASE_URL.trimEnd('/')
            val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
            if (!base.startsWith("https://") || key.isBlank()) {
                throw IOException("Advisor consultations are not configured.")
            }
            if (AuthRepository.session?.userId != userId) {
                throw IOException("Your account changed. Sign in again.")
            }
            val connection = URL("$base/rest/v1/rpc/advisor_update_consultation_request")
                .openConnection() as HttpURLConnection
            connection.instanceFollowRedirects = false
            try {
                connection.requestMethod = "POST"
                connection.connectTimeout = 12_000
                connection.readTimeout = 15_000
                connection.doOutput = true
                connection.setRequestProperty("apikey", key)
                connection.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
                connection.setRequestProperty("Content-Type", "application/json")
                connection.setRequestProperty("Accept", "application/json")
                val payload = JSONObject()
                    .put("p_request_id", requestId)
                    .put("p_status", next)
                connection.outputStream.use {
                    it.write(payload.toString().toByteArray(Charsets.UTF_8))
                }
                val code = connection.responseCode
                if (code !in 200..299) {
                    throw IOException(if (code == 401 || code == 403)
                        "Advisor access denied. Sign in again."
                    else "Could not update consultation (HTTP $code). Refresh and try again.")
                }
                val response = connection.inputStream.bufferedReader(Charsets.UTF_8).use { reader ->
                    val buffer = CharArray(4096)
                    val body = StringBuilder()
                    while (true) {
                        val count = reader.read(buffer)
                        if (count < 0) break
                        body.append(buffer, 0, count)
                        if (body.length > 32_000) {
                            throw IOException("Unexpected consultation response.")
                        }
                    }
                    body.toString()
                }
                val result = runCatching { JSONObject(response) }
                    .getOrElse { throw IOException("Unexpected response. Refresh your requests.") }
                if (result.optString("id") != requestId || result.optString("status") != next) {
                    throw IOException("Consultation response did not match. Refresh your requests.")
                }
                if (AuthRepository.session?.userId != userId) {
                    throw IOException("Your account changed. Sign in again.")
                }
            } finally {
                connection.disconnect()
            }
        }
}
