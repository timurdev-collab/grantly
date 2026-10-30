package com.grantly.android

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

/** Client-side guardrails; the existing advisor_manage_student RPC remains the authority. */
internal object AdvisorStudentActionRules {
    fun allowed(status: String, action: String): Boolean =
        (status == "requested" && action in setOf("accept", "decline")) ||
            (status == "active" && action == "end")

    fun label(action: String): String = when (action) {
        "accept" -> "Accept registration"
        "decline" -> "Decline registration"
        "end" -> "End advising"
        else -> "Unsupported action"
    }

    fun resultingStatus(action: String): String = when (action) {
        "accept" -> "active"
        "decline" -> "declined"
        "end" -> "ended"
        else -> ""
    }
}

internal object AdvisorStudentActionsRepository {
    suspend fun perform(userId: String, student: AdvisorStudentItem, action: String) =
        withContext(Dispatchers.IO) {
            if (!AdvisorStudentActionRules.allowed(student.status, action)) {
                throw IOException("This action is not available for the student's current status.")
            }
            val assignmentId = runCatching { UUID.fromString(student.assignmentId).toString() }
                .getOrElse { throw IOException("Invalid student registration.") }
            val session = AuthRepository.activeSession()
            if (session.userId != userId || AuthRepository.session?.userId != userId) {
                throw IOException("Your account changed. Sign in again.")
            }
            if (StudentProfileRepository.load().role != "advisor" ||
                AuthRepository.session?.userId != userId) {
                throw IOException("An approved advisor account is required.")
            }
            // Do not act on a stale list or a different student's assignment.
            val latest = AdvisorStudentsRepository.load(userId).firstOrNull {
                it.assignmentId == assignmentId && it.studentId == student.studentId
            } ?: throw IOException("Registration no longer exists. Refresh your students.")
            if (latest.status != student.status ||
                !AdvisorStudentActionRules.allowed(latest.status, action)) {
                throw IOException("Registration status changed. Refresh before trying again.")
            }
            val base = BuildConfig.SUPABASE_URL.trimEnd('/')
            val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
            if (!base.startsWith("https://") || key.isBlank()) {
                throw IOException("Advisor portal is not configured.")
            }
            if (AuthRepository.session?.userId != userId) {
                throw IOException("Your account changed. Sign in again.")
            }
            val connection = URL("$base/rest/v1/rpc/advisor_manage_student")
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
                    .put("p_assignment_id", assignmentId)
                    .put("p_action", action)
                connection.outputStream.use {
                    it.write(payload.toString().toByteArray(Charsets.UTF_8))
                }
                val code = connection.responseCode
                if (code !in 200..299) {
                    throw IOException(if (code == 401 || code == 403)
                        "Advisor access denied. Sign in again."
                    else "Unable to update registration (HTTP $code). Refresh and try again.")
                }
                val response = connection.inputStream.bufferedReader(Charsets.UTF_8).use {
                    val buffer = CharArray(4096)
                    val body = StringBuilder()
                    while (true) {
                        val count = it.read(buffer)
                        if (count < 0) break
                        body.append(buffer, 0, count)
                        if (body.length > 32_000) throw IOException("Unexpected registration response.")
                    }
                    body.toString()
                }
                val result = runCatching { JSONObject(response) }
                    .getOrElse { throw IOException("Unexpected registration response. Refresh your students.") }
                if (result.optString("id") != assignmentId ||
                    result.optString("status") != AdvisorStudentActionRules.resultingStatus(action)) {
                    throw IOException("Registration response was unexpected. Refresh your students.")
                }
                if (AuthRepository.session?.userId != userId) {
                    throw IOException("Your account changed. Sign in again.")
                }
            } finally {
                connection.disconnect()
            }
        }
}
