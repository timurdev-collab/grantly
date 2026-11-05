package com.grantly.android

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import java.time.ZoneId
import java.util.UUID

internal data class ApplicationTaskItem(
    val id: String,
    val title: String,
    val taskKey: String?,
    val position: Int,
    val completed: Boolean,
    val dueDate: LocalDate?
)

/**
 * Preserve the calendar day for new checklist dates without changing the backend schema.
 * Legacy Android records used local noon and must retain their original local-time display.
 * The 23:59:59 UTC marker is distinguishable from legacy local-noon writes (seconds == 0).
 */
internal object ChecklistDueDateCodec {
    fun encode(date: LocalDate): String =
        date.atTime(23, 59, 59).toInstant(ZoneOffset.UTC).toString()

    fun decode(timestamp: String, deviceZone: ZoneId = ZoneId.systemDefault()): LocalDate {
        val instant = Instant.parse(timestamp)
        val utc = instant.atZone(ZoneOffset.UTC)
        return if (utc.hour == 23 && utc.minute == 59 && utc.second == 59) {
            utc.toLocalDate()
        } else {
            instant.atZone(deviceZone).toLocalDate()
        }
    }
}

/** Android checklist backed by the existing user-scoped application_tasks RLS table. */
internal object ApplicationTasksRepository {
    private fun uuid(value: String): String = try {
        UUID.fromString(value).toString()
    } catch (_: IllegalArgumentException) {
        throw IOException("Invalid application identifier.")
    }
    private fun enc(value: String) = URLEncoder.encode(value, "UTF-8")

    private suspend fun request(method: String, query: String, payload: JSONObject? = null): String =
        withContext(Dispatchers.IO) {
            val session = AuthRepository.activeSession()
            val base = BuildConfig.SUPABASE_URL.trimEnd('/')
            val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
            if (!base.startsWith("https://") || key.isBlank()) throw IOException("Checklist is not configured.")
            val connection = URL(base + "/rest/v1/application_tasks?" + query).openConnection() as HttpURLConnection
            try {
                // Do not forward authenticated application checklist requests to redirected hosts.
                connection.instanceFollowRedirects = false
                connection.requestMethod = method
                connection.connectTimeout = 12_000
                connection.readTimeout = 15_000
                connection.setRequestProperty("apikey", key)
                connection.setRequestProperty("Authorization", "Bearer " + session.accessToken)
                connection.setRequestProperty("Accept", "application/json")
                if (payload != null) {
                    connection.doOutput = true
                    connection.setRequestProperty("Content-Type", "application/json")
                    connection.setRequestProperty("Prefer", "return=minimal")
                    connection.outputStream.use { it.write(payload.toString().toByteArray(Charsets.UTF_8)) }
                }
                val status = connection.responseCode
                if (status !in 200..299) throw IOException(
                    if (status == 401 || status == 403) "Sign in again to access your checklist."
                    else "Checklist request failed (HTTP " + status + ")."
                )
                if (method == "GET") connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
                else ""
            } finally {
                connection.disconnect()
            }
        }

    suspend fun load(scholarshipId: String): List<ApplicationTaskItem> {
        val session = AuthRepository.activeSession()
        val query = "select=id,title,task_key,position,completed_at,due_at" +
            "&user_id=eq." + enc(uuid(session.userId)) +
            "&scholarship_id=eq." + enc(uuid(scholarshipId)) +
            "&order=position.asc&limit=100"
        val rows = JSONArray(request("GET", query))
        return buildList {
            for (i in 0 until rows.length()) {
                val row = rows.optJSONObject(i) ?: continue
                val id = row.optString("id")
                if (id.isBlank()) continue
                add(ApplicationTaskItem(
                    id, row.optString("title"),
                    row.optString("task_key").takeUnless { row.isNull("task_key") || it.isBlank() },
                    row.optInt("position"), !row.isNull("completed_at"),
                    row.optString("due_at").takeUnless { row.isNull("due_at") || it.isBlank() }
                        ?.let { timestamp ->
                            runCatching { ChecklistDueDateCodec.decode(timestamp) }
                                .getOrNull()
                        }
                ))
            }
        }
    }

    suspend fun setCompleted(taskId: String, completed: Boolean) {
        val session = AuthRepository.activeSession()
        val query = "id=eq." + enc(uuid(taskId)) + "&user_id=eq." + enc(uuid(session.userId))
        request("PATCH", query, JSONObject()
            .put("completed_at", if (completed) Instant.now().toString() else JSONObject.NULL)
            .put("updated_at", Instant.now().toString()))
    }

    /** New dates use a UTC marker; existing local-noon dates retain legacy read semantics. */
    suspend fun setDueDate(taskId: String, date: LocalDate?) {
        val session = AuthRepository.activeSession()
        val query = "id=eq." + enc(uuid(taskId)) + "&user_id=eq." + enc(uuid(session.userId))
        val dueAt = date?.let(ChecklistDueDateCodec::encode)
        request("PATCH", query, JSONObject()
            .put("due_at", dueAt ?: JSONObject.NULL)
            .put("updated_at", Instant.now().toString()))
    }

    suspend fun add(scholarshipId: String, title: String, position: Int) {
        val cleaned = title.trim()
        require(cleaned.isNotBlank() && cleaned.length <= 180) { "Enter a task up to 180 characters." }
        val session = AuthRepository.activeSession()
        request("POST", "", JSONObject()
            .put("user_id", uuid(session.userId))
            .put("scholarship_id", uuid(scholarshipId))
            .put("title", cleaned)
            .put("position", position))
    }

    suspend fun deleteCustom(task: ApplicationTaskItem) {
        require(task.taskKey == null) { "Default checklist items cannot be deleted." }
        val session = AuthRepository.activeSession()
        val query = "id=eq." + enc(uuid(task.id)) + "&user_id=eq." + enc(uuid(session.userId)) +
            "&task_key=is.null"
        request("DELETE", query)
    }
}
