package com.grantly.android

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.io.Reader
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL
import java.util.UUID
import java.util.Locale

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
    private val uuidPattern = Regex("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")

    fun validCallId(value: String): String {
        val canonical = value.lowercase(Locale.ROOT)
        if (!uuidPattern.matches(canonical)) throw IOException("Invalid call session identifier.")
        return try {
            UUID.fromString(canonical).toString()
        } catch (_: IllegalArgumentException) {
            throw IOException("Invalid call session identifier.")
        }
    }

    /**
     * A call must still belong to an active student/advisor relationship.
     * This is a client preflight only; server RLS remains authoritative and
     * an assignment could change after this read.
     */
    fun requireJoinableCall(
        expectedCallId: String,
        returnedCallId: String,
        callStatus: String,
        assignmentId: String,
        returnedAssignmentId: String,
        assignmentStatus: String,
        studentId: String,
        advisorId: String,
        currentUserId: String
    ) {
        if (validCallId(expectedCallId) != returnedCallId ||
            callStatus !in setOf("requested", "scheduled", "active") ||
            runCatching { validCallId(assignmentId) }.getOrNull() != returnedAssignmentId ||
            assignmentStatus != "active" ||
            currentUserId !in setOf(studentId, advisorId)
        ) {
            throw IOException("Call is no longer available for this advisor relationship.")
        }
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
    /** Read-only, identity-scoped checks before requesting a room token. */
    private fun readSingleRow(
        base: String, key: String, accessToken: String, expectedUserId: String,
        table: String, id: String, fields: String
    ): JSONObject {
        // Table and column names are hard-coded at call sites, never user-supplied.
        val connection = URL("$base/rest/v1/$table?id=eq.$id&select=$fields&limit=1")
            .openConnection() as HttpURLConnection
        connection.instanceFollowRedirects = false
        try {
            connection.requestMethod = "GET"
            connection.connectTimeout = 12_000
            connection.readTimeout = 15_000
            connection.setRequestProperty("apikey", key)
            connection.setRequestProperty("Authorization", "Bearer $accessToken")
            connection.setRequestProperty("Accept", "application/json")
            AdvisorCallPreparationRules.requireSameAccount(expectedUserId, AuthRepository.session?.userId)
            val code = connection.responseCode
            if (code !in 200..299) {
                throw IOException("Unable to verify the call relationship (HTTP $code).")
            }
            val body = connection.inputStream.bufferedReader(Charsets.UTF_8).use {
                AdvisorCallPreparationRules.readBounded(it)
            }
            AdvisorCallPreparationRules.requireSameAccount(expectedUserId, AuthRepository.session?.userId)
            val rows = try { JSONArray(body) } catch (_: Exception) {
                throw IOException("Unexpected call relationship response.")
            }
            if (rows.length() != 1) throw IOException("Call relationship is unavailable.")
            return rows.optJSONObject(0) ?: throw IOException("Unexpected call relationship response.")
        } finally {
            connection.disconnect()
        }
    }

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
            val call = readSingleRow(
                base, key, session.accessToken, expectedUserId,
                "advisor_call_sessions", safeCallId, "id,assignment_id,status"
            )
            val assignmentId = AdvisorCallPreparationRules.validCallId(
                call.optString("assignment_id")
            )
            val assignment = readSingleRow(
                base, key, session.accessToken, expectedUserId,
                "advisor_student_assignments", assignmentId,
                "id,status,student_id,advisor_id"
            )
            AdvisorCallPreparationRules.requireJoinableCall(
                safeCallId, call.optString("id"), call.optString("status"),
                assignmentId, assignment.optString("id"), assignment.optString("status"),
                assignment.optString("student_id"), assignment.optString("advisor_id"),
                expectedUserId
            )
            AdvisorCallPreparationRules.requireSameAccount(expectedUserId, AuthRepository.session?.userId)
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
