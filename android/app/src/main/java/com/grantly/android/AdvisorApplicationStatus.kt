package com.grantly.android

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

/** Read-only status view of the user's own advisor application, as in iOS ProfileView. */
internal data class AdvisorApplicationStatus(
    val approvalStatus: String,
    val version: Int,
    val reviewNote: String
)

internal fun advisorStatusTitle(status: String): String = when (status) {
    "pending" -> "Pending review"
    "approved" -> "Approved"
    "rejected" -> "Rejected"
    "suspended" -> "Suspended"
    "changes_requested" -> "Changes requested"
    else -> "Status unavailable"
}

internal object AdvisorApplicationStatusRepository {
    suspend fun load(userId: String): AdvisorApplicationStatus? = withContext(Dispatchers.IO) {
        val session = AuthRepository.activeSession()
        if (session.userId != userId) throw IOException("Your account has changed. Refresh the profile.")
        val safeId = try { UUID.fromString(userId).toString() }
            catch (_: IllegalArgumentException) { throw IOException("Invalid account identifier.") }
        val base = BuildConfig.SUPABASE_URL.trimEnd('/')
        val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
        if (!base.startsWith("https://") || key.isBlank()) {
            throw IOException("Advisor service is not configured.")
        }
        val url = URL("$base/rest/v1/advisor_profiles?select=approval_status,application_version,review_note&id=eq.$safeId&limit=1")
        val connection = url.openConnection() as HttpURLConnection
        connection.instanceFollowRedirects = false
        try {
            connection.requestMethod = "GET"
            connection.connectTimeout = 12_000
            connection.readTimeout = 15_000
            connection.setRequestProperty("apikey", key)
            connection.setRequestProperty("Authorization", "Bearer ${session.accessToken}")
            connection.setRequestProperty("Accept", "application/json")
            val code = connection.responseCode
            if (code !in 200..299) {
                throw IOException(if (code == 401 || code == 403)
                    "Advisor application access denied. Please sign in again."
                else "Could not load advisor application (HTTP $code).")
            }
            val body = connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
            val rows = JSONArray(body.ifBlank { "[]" })
            if (rows.length() == 0) return@withContext null
            val row = rows.getJSONObject(0)
            AdvisorApplicationStatus(
                // Missing server status must not be misreported as pending review.
                approvalStatus = if (row.isNull("approval_status")) "" else row.optString("approval_status", ""),
                version = row.optInt("application_version", 1).coerceAtLeast(1),
                reviewNote = row.optString("review_note", "").takeUnless { row.isNull("review_note") }.orEmpty()
            )
        } finally {
            connection.disconnect()
        }
    }
}

@Composable
internal fun AdvisorApplicationStatusContent(userId: String) {
    var status by remember(userId) { mutableStateOf<AdvisorApplicationStatus?>(null) }
    var loading by remember(userId) { mutableStateOf(true) }
    var error by remember(userId) { mutableStateOf<String?>(null) }
    var refresh by remember(userId) { mutableIntStateOf(0) }

    LaunchedEffect(userId, refresh) {
        loading = true
        error = null
        try {
            val result = AdvisorApplicationStatusRepository.load(userId)
            if (AuthRepository.session?.userId == userId) status = result
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failure: Exception) {
            if (AuthRepository.session?.userId == userId) {
                error = failure.message ?: "Unable to load your advisor application."
            }
        } finally {
            loading = false
        }
    }

    HorizontalDivider()
    Spacer(Modifier.height(14.dp))
    Text("Advisor application", fontWeight = FontWeight.SemiBold, color = Color(0xFF123E30))
    Spacer(Modifier.height(8.dp))
    if (loading) {
        CircularProgressIndicator(color = Color(0xFF123E30))
    } else if (error != null) {
        Text(error.orEmpty(), color = Color(0xFFB3261E))
    } else if (status == null) {
        Text("No advisor application found. You can apply using the form below.")
    } else {
        val current = status!!
        Text(advisorStatusTitle(current.approvalStatus), fontWeight = FontWeight.SemiBold)
        Text("Application version ${current.version}")
        if (current.reviewNote.isNotBlank()) {
            Spacer(Modifier.height(6.dp))
            Text("Admin feedback: ${current.reviewNote}")
        }
        if (current.approvalStatus == "pending") {
            Text("Your application is awaiting administrator review.")
        }
    }
    Spacer(Modifier.height(8.dp))
    OutlinedButton(onClick = { refresh++ }, enabled = !loading, modifier = Modifier.fillMaxWidth()) {
        Text("Refresh advisor status")
    }
    Spacer(Modifier.height(16.dp))
}
