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
}
