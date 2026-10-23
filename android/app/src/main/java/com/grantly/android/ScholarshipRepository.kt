package com.grantly.android

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/** Public scholarship data model, mapped from the existing iOS Scholarship model. */
internal data class Scholarship(
    val id: String,
    val title: String,
    val provider: String,
    val country: String,
    val fundingType: String,
    val degreeLevels: List<String>,
    val fields: List<String>,
    val deadline: String?,
    val description: String?,
    val officialUrl: String?,
    val verificationStatus: String?
)

/**
 * Read-only public catalog search. Uses only the client-safe publishable key.
 * The server's existing search_scholarships RPC applies visibility policies.
 */
internal data class ScholarshipPage(val items: List<Scholarship>, val totalCount: Int)

/** Public catalog facets returned by the existing scholarship_filter_options RPC. */
internal data class ScholarshipFilterOptions(
    val countries: List<String>,
    val fields: List<String>,
    val funding: List<String>
)

internal object ScholarshipRepository {
    /** Read-only server-side search over the published catalog. */
    suspend fun search(
        query: String? = null,
        degree: String? = null,
        sort: String = "Verified first",
        offset: Int = 0,
        limit: Int = 20,
        country: String? = null,
        field: String? = null,
        funding: String? = null
    ): ScholarshipPage = withContext(Dispatchers.IO) {
        require(offset >= 0 && limit in 1..100) { "Invalid scholarship page." }
        val baseUrl = BuildConfig.SUPABASE_URL.trimEnd('/')
        val publicKey = BuildConfig.SUPABASE_PUBLISHABLE_KEY
        if (!baseUrl.startsWith("https://") || publicKey.isBlank()) {
            throw IOException("Scholarship service is not configured.")
        }
        val connection = URL(baseUrl + "/rest/v1/rpc/search_scholarships")
            .openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 12_000
            connection.readTimeout = 15_000
            connection.doOutput = true
            connection.setRequestProperty("apikey", publicKey)
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Accept", "application/json")
            val request = JSONObject().apply {
                put("p_query", query?.trim()?.takeIf { it.isNotEmpty() } ?: JSONObject.NULL)
                put("p_country", country?.takeIf { it.isNotBlank() } ?: JSONObject.NULL)
                put("p_degree", degree?.takeIf { it.isNotBlank() } ?: JSONObject.NULL)
                put("p_field", field?.takeIf { it.isNotBlank() } ?: JSONObject.NULL)
                put("p_funding", funding?.takeIf { it.isNotBlank() } ?: JSONObject.NULL)
                put("p_source", JSONObject.NULL)
                put("p_sort", sort)
                put("p_offset", offset)
                put("p_limit", limit)
            }
            connection.outputStream.use { it.write(request.toString().toByteArray(Charsets.UTF_8)) }
            val status = connection.responseCode
            if (status !in 200..299) throw IOException("Scholarship service unavailable (HTTP " + status + ").")
            val response = connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
            val rows = JSONArray(response)
            val totalCount = rows.optJSONObject(0)?.optInt("total_count", 0) ?: 0
            val items = buildList {
                for (i in 0 until rows.length()) {
                    val row = rows.optJSONObject(i)?.optJSONObject("scholarship") ?: continue
                    val id = row.optString("id")
                    val title = row.optString("title")
                    if (id.isBlank() || title.isBlank()) continue
                    add(
                        Scholarship(
                            id = id,
                            title = title,
                            provider = row.optString("provider"),
                            country = row.optString("country"),
                            fundingType = row.optString("funding_type"),
                            degreeLevels = row.optJSONArray("degree_levels").toStrings(),
                            fields = row.optJSONArray("fields").toStrings(),
                            deadline = row.optionalText("deadline"),
                            description = row.optionalText("description"),
                            officialUrl = row.optionalText("official_url"),
                            verificationStatus = row.optionalText("verification_status")
                        )
                    )
                }
            }
            ScholarshipPage(items, totalCount)
        } finally {
            connection.disconnect()
        }
    }

    /** Read-only dynamic filters, matching the iOS Explore options. */
    suspend fun filterOptions(): ScholarshipFilterOptions = withContext(Dispatchers.IO) {
        val baseUrl = BuildConfig.SUPABASE_URL.trimEnd('/')
        val publicKey = BuildConfig.SUPABASE_PUBLISHABLE_KEY
        if (!baseUrl.startsWith("https://") || publicKey.isBlank()) {
            throw IOException("Scholarship service is not configured.")
        }
        val connection = URL(baseUrl + "/rest/v1/rpc/scholarship_filter_options")
            .openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 12_000
            connection.readTimeout = 15_000
            connection.doOutput = true
            connection.setRequestProperty("apikey", publicKey)
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Accept", "application/json")
            connection.outputStream.use { it.write("{}".toByteArray(Charsets.UTF_8)) }
            val status = connection.responseCode
            if (status !in 200..299) {
                throw IOException("Scholarship filters unavailable (HTTP " + status + ").")
            }
            val payload = JSONObject(
                connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
            )
            ScholarshipFilterOptions(
                countries = payload.optJSONArray("countries").toStrings(),
                fields = payload.optJSONArray("fields").toStrings(),
                funding = payload.optJSONArray("funding").toStrings()
            )
        } finally {
            connection.disconnect()
        }
    }

    /** Compatibility for callers that only need the first page. */
    suspend fun fetchPublished(): List<Scholarship> = search().items

    private fun JSONArray?.toStrings(): List<String> =
        if (this == null) emptyList() else (0 until length()).mapNotNull {
            if (isNull(it)) null else optString(it).takeIf(String::isNotBlank)
        }

    private fun JSONObject.optionalText(key: String): String? =
        if (isNull(key)) null else optString(key).takeIf(String::isNotBlank)
}
