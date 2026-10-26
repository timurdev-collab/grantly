package com.grantly.android

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/** Read-only personalized results from the same authenticated RPC used by iOS. */
internal data class PersonalizedMatch(
    val scholarship: Scholarship,
    val score: Int,
    val eligible: Boolean,
    val reasons: List<String>,
    val blockers: List<String>
)

internal object PersonalizedMatchesRepository {
    private fun JSONArray?.strings(): List<String> =
        if (this == null) emptyList() else (0 until length()).mapNotNull { index ->
            if (isNull(index)) null else optString(index).trim().takeIf { it.isNotEmpty() }
        }

    private fun JSONObject.optionalText(key: String): String? =
        if (isNull(key)) null else optString(key).takeIf { it.isNotBlank() }

    private fun JSONObject.optionalDouble(key: String): Double? =
        if (!has(key) || isNull(key)) null else optDouble(key).takeUnless { it.isNaN() }

    private fun JSONObject.optionalInt(key: String): Int? =
        if (!has(key) || isNull(key)) null else optInt(key)

    private fun scholarship(row: JSONObject): Scholarship? {
        val id = row.optString("id")
        val title = row.optString("title")
        if (id.isBlank() || title.isBlank()) return null
        return Scholarship(
            id = id,
            title = title,
            provider = row.optString("provider"),
            country = row.optString("country"),
            fundingType = row.optString("funding_type"),
            degreeLevels = row.optJSONArray("degree_levels").strings(),
            fields = row.optJSONArray("fields").strings(),
            deadline = row.optionalText("deadline"),
            description = row.optionalText("description"),
            officialUrl = row.optionalText("official_url"),
            verificationStatus = row.optionalText("verification_status"),
            tuitionCoverage = row.optionalText("tuition_coverage"),
            stipend = row.optionalText("stipend"),
            airfare = row.optBoolean("airfare", false),
            accommodation = row.optBoolean("accommodation", false),
            healthInsurance = row.optBoolean("health_insurance", false),
            minGpaPercent = row.optionalDouble("min_gpa_percent"),
            minIelts = row.optionalDouble("min_ielts"),
            satRequired = row.optBoolean("sat_required", false),
            reliabilityScore = row.optionalInt("reliability_score"),
            lastCheckedAt = row.optionalText("last_checked_at"),
            deadlineNotes = row.optionalText("deadline_notes")
        )
    }

    suspend fun top(limit: Int = 4): List<PersonalizedMatch> = withContext(Dispatchers.IO) {
        require(limit in 1..20)
        val session = AuthRepository.activeSession()
        val base = BuildConfig.SUPABASE_URL.trimEnd('/')
        val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
        if (!base.startsWith("https://") || key.isBlank()) {
            throw IOException("Scholarship matching is not configured.")
        }
        val connection = URL("$base/rest/v1/rpc/get_my_scholarship_matches")
            .openConnection() as HttpURLConnection
        // Do not forward the session bearer token or API key through HTTP redirects.
        connection.instanceFollowRedirects = false
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 12_000
            connection.readTimeout = 15_000
            connection.doOutput = true
            connection.setRequestProperty("apikey", key)
            connection.setRequestProperty("Authorization", "Bearer " + session.accessToken)
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Accept", "application/json")
            val payload = JSONObject().put("p_offset", 0).put("p_limit", limit)
            connection.outputStream.use {
                it.write(payload.toString().toByteArray(Charsets.UTF_8))
            }
            val status = connection.responseCode
            if (status !in 200..299) {
                throw IOException(
                    if (status == 401 || status == 403) "Sign in again to see your matches."
                    else "Personalized matches unavailable (HTTP $status)."
                )
            }
            val response = connection.inputStream.bufferedReader(Charsets.UTF_8)
                .use { it.readText() }
            val rows = if (response.isBlank()) JSONArray() else JSONArray(response)
            buildList {
                for (i in 0 until rows.length()) {
                    val row = rows.optJSONObject(i) ?: continue
                    val item = row.optJSONObject("scholarship")?.let(::scholarship) ?: continue
                    add(
                        PersonalizedMatch(
                            scholarship = item,
                            score = row.optInt("score", 0).coerceIn(0, 100),
                            eligible = row.optBoolean("eligible", false),
                            reasons = row.optJSONArray("reasons").strings(),
                            blockers = row.optJSONArray("blockers").strings()
                        )
                    )
                }
            }
        } finally {
            connection.disconnect()
        }
    }
}

@Composable
internal fun PersonalizedMatchesContent(onSelect: (Scholarship) -> Unit) {
    val userId = AuthRepository.session?.userId
    var matches by remember(userId) { mutableStateOf<List<PersonalizedMatch>>(emptyList()) }
    var loading by remember(userId) { mutableStateOf(userId != null) }
    var error by remember(userId) { mutableStateOf<String?>(null) }
    var refresh by remember(userId) { mutableIntStateOf(0) }
    val forest = Color(0xFF123E30)

    LaunchedEffect(userId, refresh) {
        if (userId == null) return@LaunchedEffect
        loading = true
        error = null
        try {
            val fetched = PersonalizedMatchesRepository.top()
            if (AuthRepository.session?.userId == userId) matches = fetched
        } catch (failure: Exception) {
            if (AuthRepository.session?.userId == userId) {
                error = failure.message ?: "Unable to load matches."
            }
        } finally {
            if (AuthRepository.session?.userId == userId) loading = false
        }
    }

    when {
        userId == null -> Text(
            "Sign in and complete your academic profile to unlock personalized matches.",
            style = MaterialTheme.typography.bodyMedium
        )
        loading -> CircularProgressIndicator()
        error != null -> {
            Text(error ?: "", color = MaterialTheme.colorScheme.error)
            OutlinedButton(onClick = { refresh++ }) { Text("Try again") }
        }
        matches.isEmpty() -> {
            Text("No personalized results yet. Complete your profile and try again.")
            OutlinedButton(onClick = { refresh++ }) { Text("Refresh matches") }
        }
        else -> {
            Text(
                "Ranked using your saved profile. Always verify eligibility on the official website.",
                style = MaterialTheme.typography.bodySmall
            )
            Spacer(Modifier.height(10.dp))
            matches.forEach { match ->
                Card(
                    modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp)
                        .clickable { onSelect(match.scholarship) },
                    shape = RoundedCornerShape(16.dp)
                ) {
                    Column(Modifier.padding(15.dp)) {
                        Text(match.scholarship.title, fontWeight = FontWeight.SemiBold, color = forest)
                        Text(match.scholarship.provider + " · " + match.scholarship.country)
                        Text(
                            match.score.toString() + "% match · " +
                                if (match.eligible) "No detected blockers" else "Review eligibility",
                            color = forest,
                            style = MaterialTheme.typography.labelMedium
                        )
                        match.reasons.firstOrNull()?.let {
                            Text(it, style = MaterialTheme.typography.bodySmall)
                        }
                        match.blockers.firstOrNull()?.let {
                            Text("Check: $it", color = MaterialTheme.colorScheme.error,
                                style = MaterialTheme.typography.bodySmall)
                        }
                        Text("View scholarship →", color = forest,
                            style = MaterialTheme.typography.labelLarge)
                    }
                }
            }
            OutlinedButton(onClick = { refresh++ }) { Text("Refresh matches") }
        }
    }
}
