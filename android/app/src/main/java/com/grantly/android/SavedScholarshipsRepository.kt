package com.grantly.android

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/** Read-only view of the signed-in user's saved scholarship tracker. */
internal data class SavedScholarshipSummary(
    val scholarshipId: String,
    val title: String,
    val provider: String,
    val country: String,
    val status: String,
    val notes: String?
)

internal object SavedScholarshipsRepository {
    suspend fun load(): List<SavedScholarshipSummary> = withContext(Dispatchers.IO) {
        val session = AuthRepository.session ?: throw IOException("Sign in to view your applications.")
        val baseUrl = BuildConfig.SUPABASE_URL.trimEnd('/')
        val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
        if (!baseUrl.startsWith("https://") || key.isBlank()) {
            throw IOException("Application tracker is not configured.")
        }
        val select = "scholarship_id,application_status,notes,scholarships!saved_scholarships_scholarship_id_fkey(title,provider,country)"
        val query = "select=" + URLEncoder.encode(select, "UTF-8") +
            "&user_id=eq." + URLEncoder.encode(session.userId, "UTF-8") +
            "&order=updated_at.desc&limit=100"
        val connection = URL("$baseUrl/rest/v1/saved_scholarships?$query")
            .openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "GET"
            connection.connectTimeout = 12_000
            connection.readTimeout = 15_000
            connection.setRequestProperty("apikey", key)
            connection.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
            connection.setRequestProperty("Accept", "application/json")
            val status = connection.responseCode
            if (status !in 200..299) {
                throw IOException(
                    if (status == 401 || status == 403) "Your session has expired. Sign out and sign in again."
                    else "Unable to load applications (HTTP $status)."
                )
            }
            val rows = JSONArray(connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() })
            buildList {
                for (i in 0 until rows.length()) {
                    val row = rows.optJSONObject(i) ?: continue
                    val scholarship = row.optJSONObject("scholarships")
                    val id = row.optString("scholarship_id")
                    if (id.isBlank()) continue
                    add(
                        SavedScholarshipSummary(
                            scholarshipId = id,
                            title = scholarship?.optString("title").orEmpty().ifBlank { "Scholarship" },
                            provider = scholarship?.optString("provider").orEmpty(),
                            country = scholarship?.optString("country").orEmpty(),
                            status = row.optString("application_status").ifBlank { "Planning" },
                            notes = row.optString("notes").takeUnless { it.isBlank() || it == "null" }
                        )
                    )
                }
            }
        } finally {
            connection.disconnect()
        }
    }

    /** Read/write access is always scoped to the authenticated user under Supabase RLS. */
    private fun savedRequest(method: String, scholarshipId: String, body: String? = null): String {
        val session = AuthRepository.session ?: throw IOException("Sign in to save scholarships.")
        val id = try { java.util.UUID.fromString(scholarshipId).toString() }
            catch (_: IllegalArgumentException) { throw IOException("Invalid scholarship identifier.") }
        val baseUrl = BuildConfig.SUPABASE_URL.trimEnd('/')
        val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
        if (!baseUrl.startsWith("https://") || key.isBlank()) {
            throw IOException("Scholarship saving is not configured.")
        }
        val url = when (method) {
            "GET", "DELETE" -> {
                val filter = "&user_id=eq." + URLEncoder.encode(session.userId, "UTF-8") +
                    "&scholarship_id=eq." + URLEncoder.encode(id, "UTF-8")
                "$baseUrl/rest/v1/saved_scholarships?select=scholarship_id$filter" +
                    if (method == "GET") "&limit=1" else ""
            }
            "POST" -> "$baseUrl/rest/v1/saved_scholarships?on_conflict=user_id,scholarship_id"
            else -> throw IOException("Unsupported scholarship operation.")
        }
        val connection = URL(url).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = method
            connection.connectTimeout = 12_000
            connection.readTimeout = 15_000
            connection.setRequestProperty("apikey", key)
            connection.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
            connection.setRequestProperty("Accept", "application/json")
            if (method == "POST") {
                connection.setRequestProperty("Content-Type", "application/json")
                connection.setRequestProperty("Prefer", "resolution=ignore-duplicates,return=minimal")
                connection.doOutput = true
                connection.outputStream.use {
                    it.write((body ?: "").toByteArray(Charsets.UTF_8))
                }
            }
            val status = connection.responseCode
            if (status !in 200..299) {
                throw IOException(
                    if (status == 401 || status == 403)
                        "Your session has expired or access was denied. Sign in again."
                    else "Unable to update saved scholarship (HTTP $status)."
                )
            }
            return if (method == "GET") {
                connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
            } else ""
        } finally {
            connection.disconnect()
        }
    }

    suspend fun isSaved(scholarshipId: String): Boolean = withContext(Dispatchers.IO) {
        JSONArray(savedRequest("GET", scholarshipId)).length() > 0
    }

    suspend fun save(scholarshipId: String) = withContext(Dispatchers.IO) {
        val session = AuthRepository.session ?: throw IOException("Sign in to save scholarships.")
        val id = try { java.util.UUID.fromString(scholarshipId).toString() }
            catch (_: IllegalArgumentException) { throw IOException("Invalid scholarship identifier.") }
        val payload = org.json.JSONObject()
            .put("user_id", session.userId)
            .put("scholarship_id", id)
            .toString()
        savedRequest("POST", id, payload)
    }

    suspend fun remove(scholarshipId: String) = withContext(Dispatchers.IO) {
        savedRequest("DELETE", scholarshipId)
    }
}
