package com.grantly.android

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.UUID

/**
 * Private academic profile. The role is read-only: clients must never submit role changes.
 * Profile data stays in student_profiles, protected by the existing Supabase RLS policies.
 */
internal data class StudentProfileDraft(
    val fullName: String = "",
    val nationality: String = "",
    val residenceCountry: String = "",
    val graduationYear: String = "",
    val gpaValue: String = "",
    val gpaScale: String = "10",
    val ielts: String = "",
    val intendedMajor: String = "",
    val degreeLevel: String = "Bachelor",
    val targetRegions: String = "",
    val targetCountries: String = "",
    val familyIncome: String = "",
    val role: String = "student"
) {
    val completion: Int get() {
        val fields = listOf(fullName, nationality, residenceCountry, graduationYear,
            gpaValue, ielts, intendedMajor, targetCountries)
        return fields.count { it.isNotBlank() } * 100 / fields.size
    }
}

internal object StudentProfileRepository {
    private fun validateConfig(): Pair<String, String> {
        val base = BuildConfig.SUPABASE_URL.trimEnd('/')
        val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
        if (!base.startsWith("https://") || key.isBlank()) {
            throw IOException("Profile service is not configured.")
        }
        return base to key
    }

    private fun jsonText(row: JSONObject, name: String): String =
        if (row.isNull(name)) "" else row.optString(name, "")

    private fun csv(value: String): JSONArray = JSONArray().apply {
        value.split(',').map { it.trim() }.filter { it.isNotEmpty() }
            .distinct().forEach { put(it) }
    }

    private fun numberOrNull(value: String, label: String): Double? {
        if (value.isBlank()) return null
        val number = value.trim().toDoubleOrNull()
            ?: throw IllegalArgumentException("Enter a valid $label.")
        require(number.isFinite()) { "Enter a valid $label." }
        return number
    }

    private fun yearOrNull(value: String): Int? {
        if (value.isBlank()) return null
        val year = value.trim().toIntOrNull()
            ?: throw IllegalArgumentException("Enter a valid graduation year.")
        require(year in 1900..2100) { "Graduation year must be between 1900 and 2100." }
        return year
    }

    private fun body(draft: StudentProfileDraft): JSONObject {
        val name = draft.fullName.trim()
        require(name.isNotEmpty() && name.length <= 200) { "Enter your full name (up to 200 characters)." }
        require(draft.degreeLevel in setOf("Bachelor", "Master", "PhD")) { "Select a degree level." }
        val gpa = numberOrNull(draft.gpaValue, "GPA")
        val scale = numberOrNull(draft.gpaScale, "GPA scale")
        require(scale == null || scale > 0) { "GPA scale must be positive." }
        require(gpa == null || (gpa >= 0 && scale != null && gpa <= scale)) {
            "GPA must be between zero and your GPA scale."
        }
        val ielts = numberOrNull(draft.ielts, "IELTS score")
        require(ielts == null || ielts in 0.0..9.0) { "IELTS must be between 0 and 9." }
        val income = numberOrNull(draft.familyIncome, "annual family income")
        require(income == null || income >= 0) { "Family income cannot be negative." }
        val year = yearOrNull(draft.graduationYear)
        val fields = listOf(draft.nationality, draft.residenceCountry, draft.intendedMajor,
            draft.targetRegions, draft.targetCountries)
        require(fields.all { it.length <= 1000 }) { "Please shorten the profile fields." }

        return JSONObject().apply {
            put("full_name", name)
            put("nationality", draft.nationality.trim())
            put("residence_country", draft.residenceCountry.trim())
            put("graduation_year", year ?: JSONObject.NULL)
            put("gpa_value", gpa ?: JSONObject.NULL)
            put("gpa_scale", scale ?: JSONObject.NULL)
            put("ielts", ielts ?: JSONObject.NULL)
            put("intended_major", draft.intendedMajor.trim())
            put("degree_level", draft.degreeLevel)
            put("target_regions", csv(draft.targetRegions))
            put("target_countries", csv(draft.targetCountries))
            put("family_income_usd", income ?: JSONObject.NULL)
        }
    }

    private fun read(row: JSONObject): StudentProfileDraft {
        fun arrayText(key: String): String {
            val array = row.optJSONArray(key) ?: return ""
            return (0 until array.length()).mapNotNull { index ->
                array.optString(index).takeIf { it.isNotBlank() }
            }.joinToString(", ")
        }
        return StudentProfileDraft(
            fullName = jsonText(row, "full_name"),
            nationality = jsonText(row, "nationality"),
            residenceCountry = jsonText(row, "residence_country"),
            graduationYear = jsonText(row, "graduation_year"),
            gpaValue = jsonText(row, "gpa_value"),
            gpaScale = jsonText(row, "gpa_scale").ifBlank { "10" },
            ielts = jsonText(row, "ielts"),
            intendedMajor = jsonText(row, "intended_major"),
            degreeLevel = jsonText(row, "degree_level").ifBlank { "Bachelor" },
            targetRegions = arrayText("target_regions"),
            targetCountries = arrayText("target_countries"),
            familyIncome = jsonText(row, "family_income_usd"),
            role = jsonText(row, "role").ifBlank { "student" }
        )
    }

    private fun request(method: String, session: AuthSession, payload: JSONObject? = null): JSONArray {
        val (base, key) = validateConfig()
        val id = try { UUID.fromString(session.userId).toString() }
            catch (_: IllegalArgumentException) { throw IOException("Invalid account identifier.") }
        val filter = "id=eq." + URLEncoder.encode(id, "UTF-8")
        val select = if (method == "GET") "select=*&$filter&limit=1" else "$filter"
        val connection = URL("$base/rest/v1/student_profiles?$select")
            .openConnection() as HttpURLConnection
        // Never follow redirects while sending an authenticated profile request.
        connection.instanceFollowRedirects = false
        try {
            connection.requestMethod = method
            connection.connectTimeout = 12_000
            connection.readTimeout = 15_000
            connection.setRequestProperty("apikey", key)
            connection.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
            connection.setRequestProperty("Accept", "application/json")
            if (method == "PATCH") {
                connection.doOutput = true
                connection.setRequestProperty("Content-Type", "application/json")
                connection.setRequestProperty("Prefer", "return=representation")
                connection.outputStream.use {
                    it.write((payload ?: JSONObject()).toString().toByteArray(Charsets.UTF_8))
                }
            }
            val status = connection.responseCode
            if (status !in 200..299) {
                throw IOException(when (status) {
                    401, 403 -> "Your session has expired or profile access was denied."
                    else -> "Unable to ${if (method == "GET") "load" else "save"} profile (HTTP $status)."
                })
            }
            val response = connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
            return JSONArray(response.ifBlank { "[]" })
        } finally {
            connection.disconnect()
        }
    }

    suspend fun load(): StudentProfileDraft = withContext(Dispatchers.IO) {
        val session = AuthRepository.activeSession()
        val rows = request("GET", session)
        if (rows.length() != 1) throw IOException("Your academic profile is not available yet.")
        read(rows.getJSONObject(0))
    }

    suspend fun save(draft: StudentProfileDraft): StudentProfileDraft {
        // Validate before opening a network connection.
        val payload = body(draft)
        return withContext(Dispatchers.IO) {
            val session = AuthRepository.activeSession()
            val rows = request("PATCH", session, payload)
            if (rows.length() != 1) {
                throw IOException("Your profile was not updated. Please refresh and try again.")
            }
            read(rows.getJSONObject(0))
        }
    }
}
