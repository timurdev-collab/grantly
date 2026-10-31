package com.grantly.android

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.IOException
import java.io.Reader
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL
import java.util.UUID

/**
 * Source-only preparation for an EXISTING advisor call session.
 *
 * Do not create a persistent call record or expose a Join button until the
 * LiveKit Android client, permissions, and end-to-end lifecycle are implemented.
 * The existing Edge Function and server-side RLS remain authoritative.
 */
internal data class AdvisorCallCredentials(
    val url: String,
    val token: String,
    val roomName: String
)

internal object AdvisorCallPreparationRules {
    private const val MAX_RESPONSE_CHARS = 32_768
    private val roomPattern = Regex("grantly-[0-9a-f]{32}")
    private val jwtPattern = Regex("[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+")

    fun validCallId(value: String): String = try {
        UUID.fromString(value).toString()
    } catch (_: IllegalArgumentException) {
        throw IOException("Invalid call session identifier.")
    }

    fun requireSameAccount(expected: String, current: String?) {
        if (expected != current) {
            throw IOException("Your account changed. Please sign in again.")
        }
    }

    fun readBounded(reader: Reader): String {
        val buffer = CharArray(4096)
        val result = StringBuilder()
        while (true) {
            val count = reader.read(buffer)
            if (count < 0) break
            if (result.length + count > MAX_RESPONSE_CHARS) {
                throw IOException("Call service response is too large.")
            }
            result.append(buffer, 0, count)
        }
        return result.toString()
    }

    fun validate(url: String, token: String, roomName: String): AdvisorCallCredentials {
        val endpoint = try { URI(url) } catch (_: Exception) {
            throw IOException("Invalid secure call server address.")
        }
        if (endpoint.scheme != "wss" || endpoint.host.isNullOrBlank() ||
            endpoint.rawUserInfo != null || endpoint.rawQuery != null ||
            endpoint.rawFragment != null ||
            (endpoint.rawPath != null && endpoint.rawPath !in setOf("", "/"))) {
            throw IOException("Invalid secure call server address.")
        }
        if (!roomPattern.matches(roomName)) {
            throw IOException("Unexpected call room identifier.")
        }
        if (token.length !in 20..8192 || !jwtPattern.matches(token)) {
            throw IOException("Invalid call authorization response.")
        }
        return AdvisorCallCredentials(url, token, roomName)
    }
}

internal object AdvisorCallPreparationRepository {
    /**
     * Retrieves short-lived LiveKit credentials for an already-created call.
     * This method does NOT create a call session or join a room.
     */
    suspend fun credentialsForExistingCall(callId: String, expectedUserId: String): AdvisorCallCredentials {
        val safeCallId = AdvisorCallPreparationRules.validCallId(callId)
        val session = AuthRepository.activeSession()
        if (session.userId != expectedUserId) {
            throw IOException("Your account changed. Please sign in again.")
        }
        AdvisorCallPreparationRules.requireSameAccount(expectedUserId, AuthRepository.session?.userId)
        return withContext(Dispatchers.IO) {
            AdvisorCallPreparationRules.requireSameAccount(expectedUserId, AuthRepository.session?.userId)
            val base = BuildConfig.SUPABASE_URL.trimEnd('/')
            val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
            if (!base.startsWith("https://") || key.isBlank()) {
                throw IOException("Call service is not configured.")
            }
            val connection = URL("$base/functions/v1/livekit-token").openConnection() as HttpURLConnection
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
                AdvisorCallPreparationRules.requireSameAccount(expectedUserId, AuthRepository.session?.userId)
                connection.outputStream.use { stream ->
                    stream.write(JSONObject().put("call_id", safeCallId).toString().toByteArray(Charsets.UTF_8))
                }
                val code = connection.responseCode
                if (code !in 200..299) {
                    throw IOException(when (code) {
                        401, 403, 404 -> "Call session is unavailable or access was denied."
                        429 -> "Too many call requests. Please try again later."
                        503 -> "Video calling is not configured yet."
                        else -> "Unable to prepare the call (HTTP $code)."
                    })
                }
                val response = connection.inputStream.bufferedReader(Charsets.UTF_8).use {
                    AdvisorCallPreparationRules.readBounded(it)
                }
                AdvisorCallPreparationRules.requireSameAccount(expectedUserId, AuthRepository.session?.userId)
                val json = try { JSONObject(response) } catch (_: Exception) {
                    throw IOException("Unexpected call service response.")
                }
                AdvisorCallPreparationRules.validate(
                    json.optString("url"),
                    json.optString("token"),
                    json.optString("room_name")
                )
            } finally {
                connection.disconnect()
            }
        }
    }
}
